// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/camera_capabilities.dart';
import '../../../../data/models/manual_camera_settings.dart';
import '../../../../data/models/motion_data_capabilities.dart';
import '../../../../data/models/recording_session_paths.dart';
import '../../../../data/repositories/camera_repository.dart';
import '../../../../data/services/imu_logging_service.dart';
import '../../../../data/services/recording_storage_service.dart';

class CameraViewModel extends ChangeNotifier {
  CameraViewModel({
    required CameraRepository cameraRepository,
    required ImuLoggingService imuLoggingService,
    required RecordingStorageService recordingStorageService,
    required bool isSupportedPlatform,
  }) : _cameraRepository = cameraRepository,
       _imuLoggingService = imuLoggingService,
       _recordingStorageService = recordingStorageService,
       _isSupportedPlatform = isSupportedPlatform;

  final CameraRepository _cameraRepository;
  final ImuLoggingService _imuLoggingService;
  final RecordingStorageService _recordingStorageService;
  final bool _isSupportedPlatform;

  CameraController? _controller;
  CameraController? get controller => _controller;

  CameraCapabilities? _capabilities;
  CameraCapabilities? get capabilities => _capabilities;

  MotionDataCapabilities? _motionDataCapabilities;
  MotionDataCapabilities? get motionDataCapabilities => _motionDataCapabilities;

  CameraDescription? _rearCamera;
  CameraFormatOption? _selectedFormat;
  CameraFormatOption? get selectedFormat => _selectedFormat;

  int _selectedFps = 24;
  int get selectedFps => _selectedFps;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  bool _stabilizationEnabled = false;
  bool get stabilizationEnabled => _stabilizationEnabled;

  bool _motionDataEnabled = true;
  bool get motionDataEnabled => _motionDataEnabled;

  bool _torchEnabled = false;
  bool get torchEnabled => _torchEnabled;

  FocusAssistMode _focusMode = FocusAssistMode.auto;
  FocusAssistMode get focusMode => _focusMode;

  double _manualFocus = 0;
  double get manualFocus => _manualFocus;

  ExposureAssistMode _exposureMode = ExposureAssistMode.auto;
  ExposureAssistMode get exposureMode => _exposureMode;

  double _iso = 100;
  double get iso => _iso;

  int _shutterMicros = 41667;
  int get shutterMicros => _shutterMicros;

  WhiteBalanceAssistMode _whiteBalanceMode = WhiteBalanceAssistMode.auto;
  WhiteBalanceAssistMode get whiteBalanceMode => _whiteBalanceMode;

  int _whiteBalanceKelvin = 5600;
  int get whiteBalanceKelvin => _whiteBalanceKelvin;

  double _zoom = 1;
  double get zoom => _zoom;

  double _minZoom = 1;
  double get minZoom => _minZoom;

  double _maxZoom = 6;
  double get maxZoom => _maxZoom;

  int _sampleRateHz = 100;
  int get sampleRateHz => _sampleRateHz;

  ManualControlPanel _activePanel = ManualControlPanel.resolution;
  ManualControlPanel get activePanel => _activePanel;

  Duration _recordingDuration = Duration.zero;
  Duration get recordingDuration => _recordingDuration;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _lastSavedVideoPath;
  String? get lastSavedVideoPath => _lastSavedVideoPath;

  String? _lastSavedGcsvPath;
  String? get lastSavedGcsvPath => _lastSavedGcsvPath;

  Offset? _focusReticle;
  Offset? get focusReticle => _focusReticle;

  RecordingSessionPaths? _activeSessionPaths;
  Timer? _recordingTimer;
  Timer? _nativeApplyDebounce;
  bool _disposed = false;

  static const String defaultImuOrientation = 'XYZ';
  static const List<int> whiteBalanceOptions = <int>[
    2800,
    3200,
    4300,
    5600,
    6500,
  ];

  Future<void> initialize() async {
    if (!_isSupportedPlatform) {
      _isInitializing = false;
      _errorMessage = 'Gyrocam runs on iPhone only.';
      _notify();
      return;
    }

    _isInitializing = true;
    _errorMessage = null;
    _notify();

    try {
      _rearCamera = await _cameraRepository.getRearCameraDescription();
      final rawCapabilities =
          await _cameraRepository.getRearCameraCapabilities();
      _capabilities = _filterCapabilities(rawCapabilities);
      try {
        _motionDataCapabilities =
            await _cameraRepository.getMotionDataCapabilities();
      } catch (_) {
        _motionDataCapabilities = const MotionDataCapabilities.safeFallback();
      }
      _motionDataEnabled = _motionDataCapabilities?.isSupported ?? false;
      _sampleRateHz = _pickDefaultSampleRate(
        _motionDataCapabilities?.sampleRateOptionsHz ?? const <int>[],
      );
      if (_capabilities!.formats.isEmpty) {
        throw StateError('No rear video formats were exposed by AVFoundation.');
      }
      _selectedFormat = _pickDefaultFormat(_capabilities!.formats);
      _selectedFps = _pickDefaultFps(_selectedFormat!);
      _iso = _capabilities!.minIso.clamp(50, _capabilities!.maxIso).toDouble();
      _shutterMicros = _pickDefaultShutter(_selectedFps);
      await _buildController();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isInitializing = false;
      _notify();
    }
  }

  Future<void> refreshCamera() => initialize();

  Future<void> selectPanel(ManualControlPanel panel) async {
    _activePanel = panel;
    _notify();
  }

  Future<void> selectFormat(CameraFormatOption format) async {
    if (_isRecording || _selectedFormat == format) {
      return;
    }
    _selectedFormat = format;
    if (!format.supportsFps(_selectedFps)) {
      _selectedFps = _pickDefaultFps(format);
      _shutterMicros = _pickDefaultShutter(_selectedFps);
    }
    await _buildController();
  }

  Future<void> selectFps(int fps) async {
    if (_isRecording || _selectedFps == fps || _selectedFormat == null) {
      return;
    }
    _selectedFps = fps;
    _shutterMicros = _pickDefaultShutter(fps);
    await _buildController();
  }

  Future<void> setSampleRate(int hz) async {
    if (!availableSampleRates.contains(hz)) {
      return;
    }
    _sampleRateHz = hz;
    _notify();
  }

  Future<void> setZoom(double value) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    _zoom = value.clamp(_minZoom, _maxZoom).toDouble();
    await controller.setZoomLevel(_zoom);
    _notify();
  }

  Future<void> setFocusMode(FocusAssistMode mode) async {
    _focusMode = mode;
    if (mode == FocusAssistMode.auto) {
      await _controller?.setFocusMode(FocusMode.auto);
    }
    _scheduleNativeApply();
    _notify();
  }

  Future<void> setManualFocus(double value) async {
    _manualFocus = value.clamp(0, 1);
    _scheduleNativeApply();
    _notify();
  }

  Future<void> setExposureMode(ExposureAssistMode mode) async {
    _exposureMode = mode;
    if (mode == ExposureAssistMode.auto) {
      await _controller?.setExposureMode(ExposureMode.auto);
    }
    _scheduleNativeApply();
    _notify();
  }

  Future<void> setIso(double value) async {
    final capabilities = _capabilities;
    if (capabilities == null) {
      return;
    }
    _iso = value.clamp(capabilities.minIso, capabilities.maxIso);
    _scheduleNativeApply();
    _notify();
  }

  Future<void> setShutterMicros(double value) async {
    final capabilities = _capabilities;
    if (capabilities == null) {
      return;
    }
    _shutterMicros = value
        .round()
        .clamp(capabilities.minShutterMicros, capabilities.maxShutterMicros);
    _scheduleNativeApply();
    _notify();
  }

  Future<void> setWhiteBalanceMode(WhiteBalanceAssistMode mode) async {
    _whiteBalanceMode = mode;
    _scheduleNativeApply();
    _notify();
  }

  Future<void> setWhiteBalanceKelvin(int value) async {
    _whiteBalanceKelvin = value;
    _scheduleNativeApply();
    _notify();
  }

  Future<void> setStabilizationEnabled(bool enabled) async {
    if (enabled) {
      _motionDataEnabled = false;
    }
    _stabilizationEnabled = enabled;
    final controller = _controller;
    if (controller != null) {
      if (!enabled) {
        await controller.setVideoStabilizationMode(VideoStabilizationMode.off);
      } else {
        final supported = await controller.getSupportedVideoStabilizationModes();
        final preferred = supported.toList()
          ..sort((left, right) => left.index.compareTo(right.index));
        final mode = preferred.lastWhere(
          (value) => value != VideoStabilizationMode.off,
          orElse: () => VideoStabilizationMode.off,
        );
        await controller.setVideoStabilizationMode(mode);
      }
    }
    _notify();
  }

  Future<void> setMotionDataEnabled(bool enabled) async {
    if (!motionDataSupported) {
      return;
    }
    if (enabled && _stabilizationEnabled) {
      _stabilizationEnabled = false;
      await _controller?.setVideoStabilizationMode(VideoStabilizationMode.off);
    }
    _motionDataEnabled = enabled;
    _notify();
  }

  Future<void> setTorchEnabled(bool enabled) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    _torchEnabled = enabled;
    await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
    _notify();
  }

  Future<void> handlePreviewTap({
    required Offset localPosition,
    required Size previewSize,
  }) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final normalized = Offset(
      (localPosition.dx / previewSize.width).clamp(0.0, 1.0),
      (localPosition.dy / previewSize.height).clamp(0.0, 1.0),
    );
    _focusReticle = normalized;
    await controller.setFocusPoint(normalized);
    await controller.setExposurePoint(normalized);
    _notify();
  }

  Future<void> startRecording() async {
    final controller = _controller;
    if (controller == null || _isRecording) {
      return;
    }

    _errorMessage = null;
    _activeSessionPaths = await _recordingStorageService.createSessionPaths();

    await _applyCurrentSettings();
    if (_motionDataEnabled) {
      await _imuLoggingService.start(
        paths: _activeSessionPaths!,
        samplingRateHz: _sampleRateHz,
        orientation: defaultImuOrientation,
      );
    }

    try {
      await controller.prepareForVideoRecording();
      await controller.startVideoRecording();
      _isRecording = true;
      _recordingDuration = Duration.zero;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _recordingDuration += const Duration(milliseconds: 200);
        _notify();
      });
      _notify();
    } catch (error) {
      if (_motionDataEnabled) {
        await _imuLoggingService.stop();
      }
      _activeSessionPaths = null;
      _errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> stopRecording() async {
    final controller = _controller;
    final sessionPaths = _activeSessionPaths;
    if (controller == null || !_isRecording || sessionPaths == null) {
      return;
    }

    try {
      final file = await controller.stopVideoRecording();
      if (_motionDataEnabled) {
        await _imuLoggingService.stop();
      }
      await _recordingStorageService.persistRecording(
        sourceFile: file,
        target: sessionPaths,
      );
      _lastSavedVideoPath = sessionPaths.videoPath;
      _lastSavedGcsvPath = _motionDataEnabled ? sessionPaths.gcsvPath : null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isRecording = false;
      _activeSessionPaths = null;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _recordingDuration = Duration.zero;
      _notify();
    }
  }

  Future<void> _buildController() async {
    final rearCamera = _rearCamera;
    final format = _selectedFormat;
    if (rearCamera == null || format == null) {
      return;
    }

    _nativeApplyDebounce?.cancel();
    final previous = _controller;
    _isInitializing = true;
    _errorMessage = null;
    _controller = null;
    _notify();

    await previous?.dispose();

    try {
      final controller = CameraController(
        rearCamera,
        _resolutionPresetFor(format),
        enableAudio: true,
      );

      await controller.initialize();
      await controller.setVideoStabilizationMode(VideoStabilizationMode.off);
      await controller.setFlashMode(_torchEnabled ? FlashMode.torch : FlashMode.off);
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _zoom = _zoom.clamp(_minZoom, _maxZoom).toDouble();
      await controller.setZoomLevel(_zoom);

      _controller = controller;
      await _applyCurrentSettings();
      await controller.pausePreview();
      await controller.resumePreview();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isInitializing = false;
      _notify();
    }
  }

  Future<void> _applyCurrentSettings() async {
    final controller = _controller;
    final format = _selectedFormat;
    if (controller == null || format == null) {
      return;
    }

    final settings = ManualCameraSettings(
      width: format.width,
      height: format.height,
      fps: _selectedFps,
      focusMode: _focusMode,
      manualFocus: _manualFocus,
      exposureMode: _exposureMode,
      iso: _iso,
      shutterMicros: _shutterMicros,
      whiteBalanceMode: _whiteBalanceMode,
      whiteBalanceKelvin: _whiteBalanceKelvin,
    );

    await _cameraRepository.applyCaptureFormat(settings);
    await _cameraRepository.applyManualControls(settings);
    if (_focusMode == FocusAssistMode.auto) {
      await controller.setFocusMode(FocusMode.auto);
    }
    if (_exposureMode == ExposureAssistMode.auto) {
      await controller.setExposureMode(ExposureMode.auto);
    }
    if (!_stabilizationEnabled) {
      await controller.setVideoStabilizationMode(VideoStabilizationMode.off);
    }
  }

  void _scheduleNativeApply() {
    _nativeApplyDebounce?.cancel();
    _nativeApplyDebounce = Timer(
      const Duration(milliseconds: 60),
      () => _applyCurrentSettings(),
    );
  }

  CameraFormatOption _pickDefaultFormat(List<CameraFormatOption> formats) {
    return formats.firstWhere(
      (format) => format.width == 3840 && format.height == 2160,
      orElse: () => formats.first,
    );
  }

  int _pickDefaultFps(CameraFormatOption format) {
    final fpsOptions = format.fpsOptions;
    if (fpsOptions.contains(60)) {
      return 60;
    }
    return fpsOptions.isEmpty ? 30 : fpsOptions.first;
  }

  int _pickDefaultShutter(int fps) {
    return (1000000 / fps).round();
  }

  int _pickDefaultSampleRate(List<int> sampleRates) {
    if (sampleRates.contains(100)) {
      return 100;
    }
    if (sampleRates.isNotEmpty) {
      return sampleRates.last;
    }
    return 100;
  }

  ResolutionPreset _resolutionPresetFor(CameraFormatOption format) {
    if (format.width >= 3840 || format.height >= 2160) {
      return ResolutionPreset.ultraHigh;
    }
    if (format.width >= 1920 || format.height >= 1080) {
      return ResolutionPreset.veryHigh;
    }
    if (format.width >= 1280 || format.height >= 720) {
      return ResolutionPreset.high;
    }
    return ResolutionPreset.medium;
  }

  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String formatShutter(int micros) {
    final reciprocal = (1000000 / micros).round();
    return '1/$reciprocal';
  }

  String get compactFormatLabel {
    final format = _selectedFormat;
    if (format == null) {
      return 'Rear Wide';
    }
    final resolutionLabel = switch ((format.width, format.height)) {
      (3840, 2160) => '4K',
      (1920, 1080) => '1080p',
      _ => format.label,
    };
    return '$resolutionLabel$_selectedFps';
  }

  List<int> get availableSampleRates =>
      _motionDataCapabilities?.sampleRateOptionsHz ?? const <int>[];

  bool get motionDataSupported =>
      _motionDataCapabilities?.isSupported == true &&
      availableSampleRates.isNotEmpty;

  String get motionDataRateRangeLabel {
    final capabilities = _motionDataCapabilities;
    if (capabilities == null || !motionDataSupported) {
      return 'Motion data unavailable';
    }
    return '${capabilities.minSampleRateHz}-${capabilities.maxSampleRateHz} Hz';
  }

  CameraCapabilities _filterCapabilities(CameraCapabilities capabilities) {
    const allowedResolutions = <String>{
      '3840x2160',
      '1920x1080',
    };
    const allowedFps = <int>{24, 30, 60};

    final filteredFormats = capabilities.formats
        .where((format) => allowedResolutions.contains('${format.width}x${format.height}'))
        .map((format) {
          final filteredFps = format.fpsOptions
              .where(allowedFps.contains)
              .toList()
            ..sort();
          return CameraFormatOption(
            width: format.width,
            height: format.height,
            fpsOptions: filteredFps,
          );
        })
        .where((format) => format.fpsOptions.isNotEmpty)
        .toList()
      ..sort(CameraFormatOption.compareByQuality);

    return CameraCapabilities(
      formats: filteredFormats,
      minIso: capabilities.minIso,
      maxIso: capabilities.maxIso,
      minShutterMicros: capabilities.minShutterMicros,
      maxShutterMicros: capabilities.maxShutterMicros,
      minZoom: capabilities.minZoom,
      maxZoom: capabilities.maxZoom,
    );
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _nativeApplyDebounce?.cancel();
    _recordingTimer?.cancel();
    unawaited(_imuLoggingService.stop());
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }
}
