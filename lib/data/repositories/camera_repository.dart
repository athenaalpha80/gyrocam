// ignore_for_file: prefer_initializing_formals

import 'package:camera/camera.dart';

import '../models/camera_capabilities.dart';
import '../models/manual_camera_settings.dart';
import '../services/ios_camera_bridge.dart';

class CameraRepository {
  const CameraRepository({
    required IosCameraBridge iosCameraBridge,
  }) : _iosCameraBridge = iosCameraBridge;

  final IosCameraBridge _iosCameraBridge;

  Future<CameraDescription> getRearCameraDescription() async {
    final cameras = await availableCameras();
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
  }

  Future<CameraCapabilities> getRearCameraCapabilities() {
    return _iosCameraBridge.getRearCameraCapabilities();
  }

  Future<void> applyCaptureFormat(ManualCameraSettings settings) {
    return _iosCameraBridge.applyCaptureFormat(settings);
  }

  Future<void> applyManualControls(ManualCameraSettings settings) {
    return _iosCameraBridge.applyManualControls(settings);
  }
}
