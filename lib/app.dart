import 'dart:io';

import 'package:flutter/material.dart';

import 'data/repositories/camera_repository.dart';
import 'data/services/imu_logging_service.dart';
import 'data/services/ios_camera_bridge.dart';
import 'data/services/recording_storage_service.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/camera/view_models/camera_view_model.dart';
import 'ui/features/camera/views/camera_screen.dart';

class GyrocamApp extends StatelessWidget {
  const GyrocamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gyrocam',
      theme: buildGyrocamTheme(),
      home: const _GyrocamBootstrap(),
    );
  }
}

class _GyrocamBootstrap extends StatefulWidget {
  const _GyrocamBootstrap();

  @override
  State<_GyrocamBootstrap> createState() => _GyrocamBootstrapState();
}

class _GyrocamBootstrapState extends State<_GyrocamBootstrap> {
  late final CameraViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CameraViewModel(
      cameraRepository: CameraRepository(
        iosCameraBridge: const IosCameraBridge(),
      ),
      imuLoggingService: ImuLoggingService(),
      recordingStorageService: RecordingStorageService(),
      isSupportedPlatform: Platform.isIOS,
    )..initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameraScreen(viewModel: _viewModel);
  }
}
