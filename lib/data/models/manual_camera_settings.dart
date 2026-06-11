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
    };
  }
}

enum FocusAssistMode { auto, locked }

enum ExposureAssistMode { auto, custom }

enum WhiteBalanceAssistMode { auto, locked }

enum ManualControlPanel {
  resolution,
  fps,
  shutter,
  iso,
  whiteBalance,
  focus,
  sampleRate,
}
