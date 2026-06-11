import 'package:flutter/services.dart';

import '../models/camera_capabilities.dart';
import '../models/manual_camera_settings.dart';
import '../models/motion_data_capabilities.dart';

class IosCameraBridge {
  const IosCameraBridge();

  static const MethodChannel _channel = MethodChannel('gyrocam/manual_camera');

  Future<CameraCapabilities> getRearCameraCapabilities() async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getRearCameraCapabilities',
    );
    if (raw == null) {
      throw const CameraBridgeException('missing-capabilities');
    }
    return CameraCapabilities.fromMap(raw);
  }

  Future<MotionDataCapabilities> getMotionDataCapabilities() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getMotionDataCapabilities',
      );
      if (raw == null) {
        return const MotionDataCapabilities.safeFallback();
      }
      return MotionDataCapabilities.fromMap(raw);
    } on MissingPluginException {
      return const MotionDataCapabilities.safeFallback();
    } on PlatformException {
      return const MotionDataCapabilities.safeFallback();
    }
  }

  Future<void> applyCaptureFormat(ManualCameraSettings settings) async {
    await _channel.invokeMethod<void>(
      'applyCaptureFormat',
      settings.toCaptureFormatMap(),
    );
  }

  Future<void> applyManualControls(ManualCameraSettings settings) async {
    await _channel.invokeMethod<void>(
      'applyManualControls',
      settings.toManualControlMap(),
    );
  }
}

class CameraBridgeException implements Exception {
  const CameraBridgeException(this.code);

  final String code;

  @override
  String toString() => 'CameraBridgeException($code)';
}
