import AVFoundation
import CoreMotion
import Flutter
import UIKit

final class ManualCameraControlPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "gyrocam/manual_camera",
      binaryMessenger: registrar.messenger()
    )
    let instance = ManualCameraControlPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getRearCameraCapabilities":
      result(buildCapabilities())
    case "getMotionDataCapabilities":
      buildMotionDataCapabilities(result: result)
    case "applyCaptureFormat":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(code: "invalid-arguments", message: "Missing capture format payload.", details: nil))
        return
      }
      applyCaptureFormat(arguments: arguments, result: result)
    case "applyManualControls":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(code: "invalid-arguments", message: "Missing manual control payload.", details: nil))
        return
      }
      applyManualControls(arguments: arguments, result: result)
    case "applyVideoOrientation":
      guard let arguments = call.arguments as? [String: Any],
        let videoPath = arguments["videoPath"] as? String,
        let degrees = arguments["degrees"] as? Int
      else {
        result(
          FlutterError(code: "invalid-arguments", message: "Missing videoPath or degrees.", details: nil))
        return
      }
      applyVideoOrientation(videoPath: videoPath, degrees: degrees, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func rearCamera() throws -> AVCaptureDevice {
    guard
      let device = AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: .back
      )
    else {
      throw NSError(
        domain: "gyrocam.manual",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Rear wide camera unavailable."]
      )
    }
    return device
  }

  private func buildCapabilities() -> [String: Any]? {
    do {
      let device = try rearCamera()
      let preferredFrameRates = [24, 25, 30, 48, 50, 60, 120, 240]
      var grouped: [String: Set<Int>] = [:]
      var dimensions: [String: (width: Int32, height: Int32)] = [:]
      var minISO = device.activeFormat.minISO
      var maxISO = device.activeFormat.maxISO
      var minExposureMicros = Int(device.activeFormat.minExposureDuration.seconds * 1_000_000)
      var maxExposureMicros = Int(device.activeFormat.maxExposureDuration.seconds * 1_000_000)

      for format in device.formats {
        let description = format.formatDescription
        let size = CMVideoFormatDescriptionGetDimensions(description)
        let aspectRatio = Double(size.width) / Double(size.height)
        guard aspectRatio > 1.7, aspectRatio < 1.9, size.width >= 720 else {
          continue
        }

        minISO = min(minISO, format.minISO)
        maxISO = max(maxISO, format.maxISO)
        minExposureMicros = min(
          minExposureMicros,
          Int(format.minExposureDuration.seconds * 1_000_000)
        )
        maxExposureMicros = max(
          maxExposureMicros,
          Int(format.maxExposureDuration.seconds * 1_000_000)
        )

        let key = "\(size.width)x\(size.height)"
        dimensions[key] = (size.width, size.height)
        var fpsSet = grouped[key, default: Set<Int>()]
        for range in format.videoSupportedFrameRateRanges {
          for rate in preferredFrameRates {
            let frameRate = Double(rate)
            if frameRate >= range.minFrameRate - 0.1 && frameRate <= range.maxFrameRate + 0.1 {
              fpsSet.insert(rate)
            }
          }
        }
        if !fpsSet.isEmpty {
          grouped[key] = fpsSet
        }
      }

      let formats = grouped.compactMap { key, fpsSet -> [String: Any]? in
        guard let size = dimensions[key] else {
          return nil
        }
        return [
          "width": Int(size.width),
          "height": Int(size.height),
          "fpsOptions": fpsSet.sorted()
        ]
      }.sorted { left, right in
        let leftArea = ((left["width"] as? Int) ?? 0) * ((left["height"] as? Int) ?? 0)
        let rightArea = ((right["width"] as? Int) ?? 0) * ((right["height"] as? Int) ?? 0)
        if leftArea == rightArea {
          let leftMax = ((left["fpsOptions"] as? [Int]) ?? []).last ?? 0
          let rightMax = ((right["fpsOptions"] as? [Int]) ?? []).last ?? 0
          return rightMax < leftMax
        }
        return rightArea < leftArea
      }

      return [
        "formats": formats,
        "minIso": Double(minISO),
        "maxIso": Double(maxISO),
        "minShutterMicros": max(125, minExposureMicros),
        "maxShutterMicros": max(1_000_000 / 2, maxExposureMicros),
        "minZoom": Double(device.minAvailableVideoZoomFactor),
        "maxZoom": Double(device.maxAvailableVideoZoomFactor)
      ]
    } catch {
      return nil
    }
  }

  private func buildMotionDataCapabilities(result: @escaping FlutterResult) {
    let motionManager = CMMotionManager()
    let hasRawMotion = motionManager.isGyroAvailable && motionManager.isAccelerometerAvailable

    guard hasRawMotion else {
      result([
        "isSupported": false,
        "sampleRateOptionsHz": [],
        "minSampleRateHz": 0,
        "maxSampleRateHz": 0
      ])
      return
    }

    let candidateRates = [50, 100, 120, 200, 240]
    probeMotionRates(
      manager: motionManager,
      candidates: candidateRates,
      index: 0,
      supported: [],
      fallback: [50, 100],
      result: result
    )
  }

  private func applyCaptureFormat(arguments: [String: Any], result: @escaping FlutterResult) {
    do {
      let device = try rearCamera()
      let width = arguments["width"] as? Int ?? 1920
      let height = arguments["height"] as? Int ?? 1080
      let fps = arguments["fps"] as? Int ?? 30

      guard let selectedFormat = selectFormat(
        device: device,
        width: width,
        height: height,
        fps: fps
      ) else {
        result(
          FlutterError(
            code: "format-unavailable",
            message: "No AVFoundation format matched requested size/fps.",
            details: ["width": width, "height": height, "fps": fps]
          )
        )
        return
      }

      try device.lockForConfiguration()
      device.activeFormat = selectedFormat
      let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
      device.activeVideoMinFrameDuration = duration
      device.activeVideoMaxFrameDuration = duration
      device.unlockForConfiguration()
      result(nil)
    } catch {
      result(
        FlutterError(code: "apply-format-failed", message: error.localizedDescription, details: nil))
    }
  }

  private func applyManualControls(arguments: [String: Any], result: @escaping FlutterResult) {
    do {
      let device = try rearCamera()
      let focusMode = (arguments["focusMode"] as? String) ?? "auto"
      let manualFocus = Float((arguments["manualFocus"] as? Double) ?? 0)
      let exposureMode = (arguments["exposureMode"] as? String) ?? "auto"
      let iso = Float((arguments["iso"] as? Double) ?? Double(device.iso))
      let shutterMicros = arguments["shutterMicros"] as? Int ?? 33_333
      let whiteBalanceMode = (arguments["whiteBalanceMode"] as? String) ?? "auto"
      let whiteBalanceKelvin = Float((arguments["whiteBalanceKelvin"] as? Int) ?? 5600)

      try device.lockForConfiguration()

      if focusMode == "locked", device.isFocusModeSupported(.locked) {
        device.setFocusModeLocked(lensPosition: manualFocus)
      } else if device.isFocusModeSupported(.continuousAutoFocus) {
        device.focusMode = .continuousAutoFocus
      }

      if exposureMode == "custom" {
        let duration = CMTime(value: CMTimeValue(shutterMicros), timescale: 1_000_000)
        let clampedISO = max(device.activeFormat.minISO, min(iso, device.activeFormat.maxISO))
        device.setExposureModeCustom(duration: duration, iso: clampedISO, completionHandler: nil)
      } else if device.isExposureModeSupported(.continuousAutoExposure) {
        device.exposureMode = .continuousAutoExposure
      }

      if whiteBalanceMode == "locked", device.isWhiteBalanceModeSupported(.locked) {
        let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
          temperature: whiteBalanceKelvin,
          tint: 0
        )
        let gains = clamp(
          whiteBalanceGains: device.deviceWhiteBalanceGains(for: temperatureAndTint),
          maxGain: device.maxWhiteBalanceGain
        )
        device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
      } else if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
        device.whiteBalanceMode = .continuousAutoWhiteBalance
      }

      device.unlockForConfiguration()
      result(nil)
    } catch {
      result(
        FlutterError(code: "apply-controls-failed", message: error.localizedDescription, details: nil))
    }
  }

  private func selectFormat(
    device: AVCaptureDevice,
    width: Int,
    height: Int,
    fps: Int
  ) -> AVCaptureDevice.Format? {
    var fallback: AVCaptureDevice.Format?

    for format in device.formats {
      let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
      guard size.width == width, size.height == height else {
        continue
      }
      fallback = fallback ?? format
      if format.videoSupportedFrameRateRanges.contains(where: {
        Double(fps) >= $0.minFrameRate - 0.1 && Double(fps) <= $0.maxFrameRate + 0.1
      }) {
        return format
      }
    }

    return fallback
  }

  private func clamp(
    whiteBalanceGains gains: AVCaptureDevice.WhiteBalanceGains,
    maxGain: Float
  ) -> AVCaptureDevice.WhiteBalanceGains {
    var clamped = gains
    clamped.redGain = min(max(1.0, gains.redGain), maxGain)
    clamped.greenGain = min(max(1.0, gains.greenGain), maxGain)
    clamped.blueGain = min(max(1.0, gains.blueGain), maxGain)
    return clamped
  }

  private func probeMotionRates(
    manager: CMMotionManager,
    candidates: [Int],
    index: Int,
    supported: [Int],
    fallback: [Int],
    result: @escaping FlutterResult
  ) {
    guard index < candidates.count else {
      let sorted = supported.sorted()
      let finalRates = sorted.isEmpty ? fallback : sorted
      result([
        "isSupported": true,
        "sampleRateOptionsHz": finalRates,
        "minSampleRateHz": finalRates.first ?? 0,
        "maxSampleRateHz": finalRates.last ?? 0
      ])
      return
    }

    let candidate = candidates[index]
    measureSupportedRate(manager: manager, requestedHz: candidate) { isSupported in
      var nextSupported = supported
      if isSupported {
        nextSupported.append(candidate)
      }
      self.probeMotionRates(
        manager: manager,
        candidates: candidates,
        index: index + 1,
        supported: nextSupported,
        fallback: fallback,
        result: result
      )
    }
  }

  private func applyVideoOrientation(videoPath: String, degrees: Int, result: @escaping FlutterResult) {
    do {
      try modifyOrientationMatrixInPlace(at: URL(fileURLWithPath: videoPath), degrees: degrees)
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "orientation-failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  // MARK: - In-place QuickTime matrix modification (no re-encode)

  private func modifyOrientationMatrixInPlace(at url: URL, degrees: Int) throws {
    let fileHandle = try FileHandle(forUpdating: url)
    defer { fileHandle.closeFile() }

    let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! UInt64
    let (moovOffset, moovSize) = try findMoovRange(fileHandle: fileHandle, fileSize: fileSize)

    try fileHandle.seek(toOffset: moovOffset)
    guard let moovData = try fileHandle.read(upToCount: Int(moovSize)) else {
      throw NSError(domain: "gyrocam.orientation", code: 10,
        userInfo: [NSLocalizedDescriptionKey: "Failed to read moov atom"])
    }

    var mutableMoov = moovData
    try modifyVideoTrackMatrix(moovData: &mutableMoov, degrees: degrees)

    try fileHandle.seek(toOffset: moovOffset)
    try fileHandle.write(Data(mutableMoov))
  }

  private func findMoovRange(fileHandle: FileHandle, fileSize: UInt64) throws -> (offset: UInt64, size: UInt64) {
    var offset: UInt64 = 0

    while offset < fileSize {
      try fileHandle.seek(toOffset: offset)
      guard let header = try fileHandle.read(upToCount: 8), header.count == 8 else {
        throw NSError(domain: "gyrocam.orientation", code: 20,
          userInfo: [NSLocalizedDescriptionKey: "Premature EOF while scanning atoms"])
      }

      var atomSize = UInt64(
        header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
      )
      let atomType = String(data: header[4...7], encoding: .ascii) ?? ""

      if atomSize == 1 {
        guard let extSize = try fileHandle.read(upToCount: 8), extSize.count == 8 else {
          throw NSError(domain: "gyrocam.orientation", code: 21,
            userInfo: [NSLocalizedDescriptionKey: "Premature EOF reading extended atom size"])
        }
        atomSize = extSize.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self).bigEndian }
      }

      if atomType == "moov" {
        return (offset, atomSize)
      }

      if atomSize == 0 { break }
      offset += atomSize
    }

    throw NSError(domain: "gyrocam.orientation", code: 22,
      userInfo: [NSLocalizedDescriptionKey: "moov atom not found in file"])
  }

  private func modifyVideoTrackMatrix(moovData: inout Data, degrees: Int) throws {
    guard let videoTkhdRange = findVideoTkhdRange(in: moovData) else {
      throw NSError(domain: "gyrocam.orientation", code: 30,
        userInfo: [NSLocalizedDescriptionKey: "Video track tkhd not found"])
    }

    let payload = videoTkhdRange.payloadStart
    let version = moovData[payload]

    let matrixOffset: Int
    let widthOffset: Int
    let heightOffset: Int
    if version == 1 {
      matrixOffset = 52
      widthOffset = 52 + 36
      heightOffset = widthOffset + 4
    } else {
      matrixOffset = 40
      widthOffset = 40 + 36
      heightOffset = widthOffset + 4
    }

    func readU32BE(_ pos: Int) -> UInt32 {
      moovData[pos..<pos + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
    }

    let trackWidth = Double(readU32BE(payload + widthOffset)) / 65_536.0
    let trackHeight = Double(readU32BE(payload + heightOffset)) / 65_536.0

    let matrix = buildDisplayMatrix(
      degrees: degrees,
      trackWidth: trackWidth,
      trackHeight: trackHeight
    )

    let writeStart = payload + matrixOffset
    for i in 0..<9 {
      let value = matrix[i]
      let start = writeStart + i * 4
      moovData[start..<start + 4] = withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
  }

  private struct AtomRange {
    let dataOffset: Int
    let size: Int
    let payloadStart: Int
  }

  private func findVideoTkhdRange(in data: Data) -> AtomRange? {
    var offset = 8  // skip moov header
    let moovEnd = data.count

    while offset + 8 <= moovEnd {
      let size = Int(
        data[offset..<offset + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
      )
      let type = String(data: data[offset + 4..<offset + 8], encoding: .ascii) ?? ""
      guard size >= 8, offset + size <= moovEnd else { break }

      if type == "trak" {
        if let tkhd = findVideoTkhdInTrak(data: data, trakStart: offset, trakSize: size) {
          return tkhd
        }
      }

      offset += size
    }
    return nil
  }

  private func findVideoTkhdInTrak(data: Data, trakStart: Int, trakSize: Int) -> AtomRange? {
    var offset = trakStart + 8
    let trakEnd = trakStart + trakSize

    var isVideoTrack = false
    var tkhdRange: AtomRange?

    while offset + 8 <= trakEnd {
      let size = Int(
        data[offset..<offset + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
      )
      let type = String(data: data[offset + 4..<offset + 8], encoding: .ascii) ?? ""
      guard size >= 8, offset + size <= trakEnd else { break }

      if type == "tkhd" {
        tkhdRange = AtomRange(
          dataOffset: offset,
          size: size,
          payloadStart: offset + 8
        )
      } else if type == "mdia" {
        isVideoTrack = isHandlerTypeVideo(data: data, mdiaStart: offset, mdiaSize: size)
      }

      if type == "tkhd" && isVideoTrack {
        return tkhdRange
      }

      offset += size
    }

    // Fallback: if only one tkhd exists and we think it's video
    if isVideoTrack, let tkhd = tkhdRange {
      return tkhd
    }
    return nil
  }

  private func isHandlerTypeVideo(data: Data, mdiaStart: Int, mdiaSize: Int) -> Bool {
    var offset = mdiaStart + 8
    let mdiaEnd = mdiaStart + mdiaSize

    while offset + 8 <= mdiaEnd {
      let size = Int(
        data[offset..<offset + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
      )
      let type = String(data: data[offset + 4..<offset + 8], encoding: .ascii) ?? ""
      guard size >= 8, offset + size <= mdiaEnd else { break }

      if type == "hdlr" {
        let payloadStart = offset + 8
        // hdlr: version(1) + flags(3) + pre_defined(4) + handler_type(4)
        if payloadStart + 12 <= data.count {
          let handlerType = String(data: data[payloadStart + 8..<payloadStart + 12], encoding: .ascii) ?? ""
          return handlerType == "vide"
        }
        return false
      }

      offset += size
    }
    return false
  }

  private func buildDisplayMatrix(degrees: Int, trackWidth: Double, trackHeight: Double) -> [UInt32] {
    // QuickTime display matrix: 9 × 16.16 fixed-point values (big-endian)
    // [a, b, u, c, d, v, tx, ty, w]
    // x' = a*x + c*y + tx,  y' = b*x + d*y + ty
    let one: UInt32 = 0x0001_0000
    let minusOne: UInt32 = 0xFFFF_0000
    let zero: UInt32 = 0x0000_0000

    func fixed(_ value: Double) -> UInt32 {
      return UInt32(max(0, value)) << 16
    }

    switch degrees {
    case 0:
      return [one, zero, zero, zero, one, zero, zero, zero, one]

    case 90:
      return [zero, one, zero, minusOne, zero, zero, fixed(trackHeight), zero, one]

    case 180:
      return [minusOne, zero, zero, zero, minusOne, zero, fixed(trackWidth), fixed(trackHeight), one]

    case 270:
      return [zero, minusOne, zero, one, zero, zero, zero, fixed(trackWidth), one]

    default:
      return [one, zero, zero, zero, one, zero, zero, zero, one]
    }
  }

  private func measureSupportedRate(
    manager: CMMotionManager,
    requestedHz: Int,
    completion: @escaping (Bool) -> Void
  ) {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.qualityOfService = .userInitiated

    let requestedInterval = 1.0 / Double(requestedHz)
    manager.gyroUpdateInterval = requestedInterval
    manager.accelerometerUpdateInterval = requestedInterval

    var previousTimestamp: TimeInterval?
    var intervals: [TimeInterval] = []
    var finished = false

    func complete(_ supported: Bool) {
      guard !finished else {
        return
      }
      finished = true
      manager.stopGyroUpdates()
      manager.stopAccelerometerUpdates()
      DispatchQueue.main.async {
        completion(supported)
      }
    }

    let timeout = max(0.45, requestedInterval * 18)
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
      guard !finished else {
        return
      }
      let averageInterval = intervals.isEmpty
        ? 0
        : intervals.reduce(0, +) / Double(intervals.count)
      let achievedHz = averageInterval > 0 ? 1.0 / averageInterval : 0
      complete(achievedHz >= Double(requestedHz) * 0.85)
    }

    manager.startGyroUpdates(to: queue) { data, error in
      guard error == nil, let data else {
        complete(false)
        return
      }

      if let previousTimestamp {
        intervals.append(data.timestamp - previousTimestamp)
      }
      previousTimestamp = data.timestamp

      guard intervals.count >= 12 else {
        return
      }

      let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
      let achievedHz = averageInterval > 0 ? 1.0 / averageInterval : 0
      complete(achievedHz >= Double(requestedHz) * 0.85)
    }
  }
}
