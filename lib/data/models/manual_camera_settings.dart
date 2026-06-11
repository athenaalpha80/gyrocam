class ManualCameraSettings {
  const ManualCameraSettings({
    required this.width,
    required this.height,
    required this.fps,
    required this.focusMode,
    required this.manualFocus,
    required this.exposureMode,
    required this.iso,
    required this.shutterMicros,
    required this.whiteBalanceMode,
    required this.whiteBalanceKelvin,
    this.videoCodec = VideoCodec.h265,
  });

  final int width;
  final int height;
  final int fps;
  final FocusAssistMode focusMode;
  final double manualFocus;
  final ExposureAssistMode exposureMode;
  final double iso;
  final int shutterMicros;
  final WhiteBalanceAssistMode whiteBalanceMode;
  final int whiteBalanceKelvin;
  final VideoCodec videoCodec;

  Map<String, Object> toManualControlMap() {
    return <String, Object>{
      'focusMode': focusMode.name,
      'manualFocus': manualFocus,
      'exposureMode': exposureMode.name,
      'iso': iso,
      'shutterMicros': shutterMicros,
      'whiteBalanceMode': whiteBalanceMode.name,
      'whiteBalanceKelvin': whiteBalanceKelvin,
    };
  }

  Map<String, Object> toCaptureFormatMap() {
    return <String, Object>{
      'width': width,
      'height': height,
      'fps': fps,
      'videoCodec': videoCodec.name,
    };
  }
}

enum FocusAssistMode { auto, locked }

enum ExposureAssistMode { auto, custom }

enum WhiteBalanceAssistMode { auto, locked }

enum VideoCodec { h265, h264 }

enum QuickControlPanel {
  none,
  resolution,
  frameRate,
  exposure,
  whiteBalance,
  focus,
}

enum ExposureControlMode {
  iso,
  shutter,
}
