import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/models/camera_capabilities.dart';
import '../../../../data/models/manual_camera_settings.dart';
import '../view_models/camera_view_model.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({
    super.key,
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _PreviewSurface(viewModel: viewModel),
              const Positioned.fill(child: _PreviewScrim()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    children: <Widget>[
                      _TopBar(viewModel: viewModel),
                      const Spacer(),
                      _BottomChrome(viewModel: viewModel),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final controller = viewModel.controller;

    if (!viewModel.isInitializing &&
        (viewModel.errorMessage != null || controller == null)) {
      return _ErrorState(
        message: viewModel.errorMessage ?? 'Camera unavailable.',
        onRetry: viewModel.refreshCamera,
      );
    }

    if (viewModel.isInitializing || controller == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewAspectRatio = _effectivePreviewAspectRatio(controller);
        final viewportAspectRatio =
            constraints.maxWidth / constraints.maxHeight;
        final scale = previewAspectRatio > viewportAspectRatio
            ? previewAspectRatio / viewportAspectRatio
            : viewportAspectRatio / previewAspectRatio;

        return GestureDetector(
          onTapDown: (details) {
            viewModel.handlePreviewTap(
              localPosition: details.localPosition,
              previewSize: constraints.biggest,
            );
          },
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Transform.scale(
                  scale: scale,
                  child: Center(
                    child: CameraPreview(controller),
                  ),
                ),
                const Positioned.fill(child: _RuleOfThirdsOverlay()),
                if (viewModel.focusReticle case final point?)
                  Align(
                    alignment: Alignment(
                      point.dx * 2 - 1,
                      point.dy * 2 - 1,
                    ),
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFFFD24C)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _effectivePreviewAspectRatio(CameraController controller) {
    final orientation = controller.value.previewPauseOrientation ??
        controller.value.lockedCaptureOrientation ??
        controller.value.recordingOrientation ??
        controller.value.deviceOrientation;

    final landscapeOrientations = <DeviceOrientation>{
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    };

    if (landscapeOrientations.contains(orientation)) {
      return controller.value.aspectRatio;
    }
    return 1 / controller.value.aspectRatio;
  }
}

class _PreviewScrim extends StatelessWidget {
  const _PreviewScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0x77000000),
              Color(0x08000000),
              Color(0x08000000),
              Color(0xAA000000),
            ],
            stops: <double>[0, 0.16, 0.7, 1],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final timerText = viewModel.isRecording
        ? viewModel.formatDuration(viewModel.recordingDuration)
        : '00:00';

    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: _TopIconButton(
              icon: viewModel.torchEnabled
                  ? CupertinoIcons.bolt_fill
                  : CupertinoIcons.bolt_slash_fill,
              onTap: () => viewModel.setTorchEnabled(!viewModel.torchEnabled),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0x22101010),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                timerText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _TopIconButton(
              icon: CupertinoIcons.settings,
              onTap: () => _openSettings(context, viewModel),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0x22101010),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x22101010),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            viewModel.compactFormatLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: viewModel.isRecording
              ? viewModel.stopRecording
              : viewModel.startRecording,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 5),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: viewModel.isRecording ? 24 : 52,
                height: viewModel.isRecording ? 24 : 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(
                    viewModel.isRecording ? 8 : 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.title,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double min;
  final double max;
  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFFFCC33),
              ),
            ),
          ],
        ),
        Slider(
          min: min,
          max: max,
          value: value.clamp(min, max),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<int>(
      groupValue: index,
      backgroundColor: const Color(0xFF1B1B1B),
      thumbColor: const Color(0xFFFFCC33),
      children: <int, Widget>{
        for (var i = 0; i < labels.length; i++)
          i: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              labels[i],
              style: TextStyle(
                color: index == i ? Colors.black : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      },
      onValueChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFFFFCC33),
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final formats =
            viewModel.capabilities?.formats ?? const <CameraFormatOption>[];
        final fpsOptions = viewModel.selectedFormat?.fpsOptions ?? const <int>[];

        return Scaffold(
          backgroundColor: const Color(0xFF080808),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                8,
                18,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        GestureDetector(
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.of(context).pop();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox(
                            width: 24,
                            height: 28,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Icon(
                                CupertinoIcons.back,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Settings',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SettingsSection(
                      title: 'Resolution',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: formats.map((format) {
                          final selected = format == viewModel.selectedFormat;
                          final label = switch ((format.width, format.height)) {
                            (3840, 2160) => '4K',
                            (1920, 1080) => '1080p',
                            _ => format.label,
                          };
                          return FilterChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (_) => viewModel.selectFormat(format),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSection(
                      title: 'Frame Rate',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: fpsOptions.map((fps) {
                          return FilterChip(
                            label: Text('$fps fps'),
                            selected: fps == viewModel.selectedFps,
                            onSelected: (_) => viewModel.selectFps(fps),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSection(
                      title: 'Stabilization',
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable stabilization'),
                        subtitle: viewModel.motionDataEnabled
                            ? const Text(
                                'Turn off motion data to enable stabilization.',
                              )
                            : null,
                        value: viewModel.stabilizationEnabled,
                        onChanged: viewModel.motionDataEnabled
                            ? null
                            : viewModel.setStabilizationEnabled,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSection(
                      title: 'Exposure',
                      child: Column(
                        children: <Widget>[
                          _ModeSegment(
                            labels: const <String>['Auto', 'Manual'],
                            index:
                                viewModel.exposureMode == ExposureAssistMode.auto
                                ? 0
                                : 1,
                            onChanged: (index) => viewModel.setExposureMode(
                              index == 0
                                  ? ExposureAssistMode.auto
                                  : ExposureAssistMode.custom,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (viewModel.capabilities case final caps?)
                            _LabeledSlider(
                              title: 'ISO',
                              valueLabel: viewModel.iso.round().toString(),
                              min: caps.minIso,
                              max: caps.maxIso,
                              value: viewModel.iso,
                              onChanged:
                                  viewModel.exposureMode ==
                                      ExposureAssistMode.auto
                                  ? null
                                  : viewModel.setIso,
                            ),
                          if (viewModel.capabilities case final caps?)
                            _LabeledSlider(
                              title: 'Shutter',
                              valueLabel: viewModel.formatShutter(
                                viewModel.shutterMicros,
                              ),
                              min: caps.minShutterMicros.toDouble(),
                              max: caps.maxShutterMicros.toDouble(),
                              value: viewModel.shutterMicros.toDouble(),
                              onChanged: viewModel.setShutterMicros,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSection(
                      title: 'Focus',
                      child: Column(
                        children: <Widget>[
                          _ModeSegment(
                            labels: const <String>['Auto', 'Manual'],
                            index:
                                viewModel.focusMode == FocusAssistMode.auto
                                ? 0
                                : 1,
                            onChanged: (index) => viewModel.setFocusMode(
                              index == 0
                                  ? FocusAssistMode.auto
                                  : FocusAssistMode.locked,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LabeledSlider(
                            title: 'Focus',
                            valueLabel: viewModel.manualFocus.toStringAsFixed(2),
                            min: 0,
                            max: 1,
                            value: viewModel.manualFocus,
                            onChanged:
                                viewModel.focusMode == FocusAssistMode.auto
                                ? null
                                : viewModel.setManualFocus,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSection(
                      title: 'White Balance',
                      child: Column(
                        children: <Widget>[
                          _ModeSegment(
                            labels: const <String>['Auto', 'Locked'],
                            index:
                                viewModel.whiteBalanceMode ==
                                    WhiteBalanceAssistMode.auto
                                ? 0
                                : 1,
                            onChanged: (index) => viewModel.setWhiteBalanceMode(
                              index == 0
                                  ? WhiteBalanceAssistMode.auto
                                  : WhiteBalanceAssistMode.locked,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: CameraViewModel.whiteBalanceOptions.map((
                              value,
                            ) {
                              return FilterChip(
                                label: Text('${value}K'),
                                selected: value == viewModel.whiteBalanceKelvin,
                                onSelected:
                                    viewModel.whiteBalanceMode ==
                                        WhiteBalanceAssistMode.auto
                                    ? null
                                    : (_) => viewModel.setWhiteBalanceKelvin(
                                      value,
                                    ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSection(
                      title: 'Motion Logging',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Record motion data'),
                            subtitle: Text(
                              viewModel.motionDataSupported
                                  ? 'Detected ${viewModel.motionDataRateRangeLabel}'
                                  : 'Motion sensors unavailable',
                            ),
                            value: viewModel.motionDataEnabled,
                            onChanged: viewModel.stabilizationEnabled
                                ? null
                                : viewModel.motionDataSupported
                                ? viewModel.setMotionDataEnabled
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: viewModel.availableSampleRates.map((
                              value,
                            ) {
                              return FilterChip(
                                label: Text('$value Hz'),
                                selected: value == viewModel.sampleRateHz,
                                onSelected: viewModel.motionDataEnabled
                                    ? (_) => viewModel.setSampleRate(value)
                                    : null,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            viewModel.motionDataEnabled
                                ? 'Uses gyro + accelerometer with gravity included.'
                                : 'Motion logging off. No .gcsv file is written.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(CupertinoIcons.exclamationmark_triangle, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onRetry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleOfThirdsOverlay extends StatelessWidget {
  const _RuleOfThirdsOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RuleOfThirdsPainter(),
    );
  }
}

class _RuleOfThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;

    final oneThirdWidth = size.width / 3;
    final oneThirdHeight = size.height / 3;

    for (var i = 1; i < 3; i++) {
      final x = oneThirdWidth * i;
      final y = oneThirdHeight * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> _openSettings(
  BuildContext context,
  CameraViewModel viewModel,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => _SettingsSheet(viewModel: viewModel),
    ),
  );
}
