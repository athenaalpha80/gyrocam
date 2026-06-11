import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    constraints.maxWidth > constraints.maxHeight;
                return DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF151515), Color(0xFF040404)],
                    ),
                  ),
                  child: isLandscape
                      ? _buildLandscapeLayout(context)
                      : _buildPortraitLayout(context),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: <Widget>[
        _TopBar(viewModel: viewModel),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _PreviewSurface(viewModel: viewModel),
          ),
        ),
        const SizedBox(height: 12),
        _ManualPanel(viewModel: viewModel),
        const SizedBox(height: 12),
        _BottomChrome(viewModel: viewModel),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              _TopBar(viewModel: viewModel),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 12),
                  child: _PreviewSurface(viewModel: viewModel),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 320,
          child: Column(
            children: <Widget>[
              Expanded(child: _ManualPanel(viewModel: viewModel)),
              _BottomChrome(viewModel: viewModel),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
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
    final format = viewModel.selectedFormat;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: <Widget>[
          _InfoPill(
            label: format == null
                ? 'Rear Wide'
                : '${format.label} • ${viewModel.selectedFps} FPS',
          ),
          const SizedBox(width: 8),
          _InfoPill(label: 'VIDEO', highlighted: true),
          const Spacer(),
          _TogglePill(
            label: 'Stab',
            enabled: viewModel.stabilizationEnabled,
            onTap: () => viewModel.setStabilizationEnabled(
              !viewModel.stabilizationEnabled,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x221A1A1A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showAdvancedSheet(context, viewModel),
            icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 22),
          ),
        ],
      ),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        color: Colors.black,
        child: GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            final size = box?.size;
            if (size == null) {
              return;
            }
            viewModel.handlePreviewTap(
              localPosition: details.localPosition,
              previewSize: size,
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 1,
                    height: 1 / controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  ),
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
              Positioned(
                left: 14,
                top: 14,
                child: _MetadataCard(viewModel: viewModel),
              ),
              if (viewModel.isRecording)
                Positioned(
                  right: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xBB0D0D0D),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF453A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          viewModel.formatDuration(viewModel.recordingDuration),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final format = viewModel.selectedFormat;
    if (format == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xAA060606),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${format.width}×${format.height}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${viewModel.selectedFps} fps • ${viewModel.formatShutter(viewModel.shutterMicros)} • ISO ${viewModel.iso.round()}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${viewModel.whiteBalanceKelvin}K • ${viewModel.sampleRateHz} Hz IMU',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualPanel extends StatelessWidget {
  const _ManualPanel({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xCC111111),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ManualControlPanel.values.map((panel) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_panelLabel(panel)),
                    selected: viewModel.activePanel == panel,
                    onSelected: (_) => viewModel.selectPanel(panel),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _buildPanelContent(context),
        ],
      ),
    );
  }

  Widget _buildPanelContent(BuildContext context) {
    switch (viewModel.activePanel) {
      case ManualControlPanel.resolution:
        final formats = viewModel.capabilities?.formats ?? const <CameraFormatOption>[];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: formats.map((format) {
            final selected = format == viewModel.selectedFormat;
            return FilterChip(
              label: Text(format.label),
              selected: selected,
              onSelected: (_) => viewModel.selectFormat(format),
            );
          }).toList(),
        );
      case ManualControlPanel.fps:
        final format = viewModel.selectedFormat;
        final fpsOptions = format?.fpsOptions ?? const <int>[];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fpsOptions.map((fps) {
            return FilterChip(
              label: Text('$fps fps'),
              selected: fps == viewModel.selectedFps,
              onSelected: (_) => viewModel.selectFps(fps),
            );
          }).toList(),
        );
      case ManualControlPanel.shutter:
        final caps = viewModel.capabilities;
        if (caps == null) {
          return const SizedBox.shrink();
        }
        return _LabeledSlider(
          title: 'Shutter',
          valueLabel: viewModel.formatShutter(viewModel.shutterMicros),
          min: caps.minShutterMicros.toDouble(),
          max: caps.maxShutterMicros.toDouble(),
          value: viewModel.shutterMicros.toDouble(),
          onChanged: viewModel.setShutterMicros,
        );
      case ManualControlPanel.iso:
        final caps = viewModel.capabilities;
        if (caps == null) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ModeSegment(
              labels: const <String>['Auto', 'Manual'],
              index: viewModel.exposureMode == ExposureAssistMode.auto ? 0 : 1,
              onChanged: (index) => viewModel.setExposureMode(
                index == 0
                    ? ExposureAssistMode.auto
                    : ExposureAssistMode.custom,
              ),
            ),
            const SizedBox(height: 12),
            _LabeledSlider(
              title: 'ISO',
              valueLabel: viewModel.iso.round().toString(),
              min: caps.minIso,
              max: caps.maxIso,
              value: viewModel.iso,
              onChanged: viewModel.exposureMode == ExposureAssistMode.auto
                  ? null
                  : viewModel.setIso,
            ),
          ],
        );
      case ManualControlPanel.whiteBalance:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ModeSegment(
              labels: const <String>['Auto', 'Locked'],
              index:
                  viewModel.whiteBalanceMode == WhiteBalanceAssistMode.auto ? 0 : 1,
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
              children: CameraViewModel.whiteBalanceOptions.map((value) {
                return FilterChip(
                  label: Text('${value}K'),
                  selected: value == viewModel.whiteBalanceKelvin,
                  onSelected: viewModel.whiteBalanceMode ==
                          WhiteBalanceAssistMode.auto
                      ? null
                      : (_) => viewModel.setWhiteBalanceKelvin(value),
                );
              }).toList(),
            ),
          ],
        );
      case ManualControlPanel.focus:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ModeSegment(
              labels: const <String>['Auto', 'Manual'],
              index: viewModel.focusMode == FocusAssistMode.auto ? 0 : 1,
              onChanged: (index) => viewModel.setFocusMode(
                index == 0 ? FocusAssistMode.auto : FocusAssistMode.locked,
              ),
            ),
            const SizedBox(height: 12),
            _LabeledSlider(
              title: 'Focus',
              valueLabel: viewModel.manualFocus.toStringAsFixed(2),
              min: 0,
              max: 1,
              value: viewModel.manualFocus,
              onChanged: viewModel.focusMode == FocusAssistMode.auto
                  ? null
                  : viewModel.setManualFocus,
            ),
          ],
        );
      case ManualControlPanel.sampleRate:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CameraViewModel.sampleRateOptions.map((value) {
            return FilterChip(
              label: Text('$value Hz'),
              selected: value == viewModel.sampleRateHz,
              onSelected: (_) => viewModel.setSampleRate(value),
            );
          }).toList(),
        );
    }
  }

  String _panelLabel(ManualControlPanel panel) {
    switch (panel) {
      case ManualControlPanel.resolution:
        return 'RES';
      case ManualControlPanel.fps:
        return 'FPS';
      case ManualControlPanel.shutter:
        return 'SHT';
      case ManualControlPanel.iso:
        return 'ISO';
      case ManualControlPanel.whiteBalance:
        return 'WB';
      case ManualControlPanel.focus:
        return 'FOCUS';
      case ManualControlPanel.sampleRate:
        return 'IMU';
    }
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _FooterDetail(
              title: 'Last',
              value: viewModel.lastSavedVideoPath == null
                  ? 'No clip saved'
                  : 'Saved .mov + .gcsv',
              subtitle: viewModel.lastSavedVideoPath,
            ),
          ),
          GestureDetector(
            onTap: viewModel.isRecording
                ? viewModel.stopRecording
                : viewModel.startRecording,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 6),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: viewModel.isRecording ? 34 : 68,
                  height: viewModel.isRecording ? 34 : 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(
                      viewModel.isRecording ? 10 : 34,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _FooterDetail(
              title: 'Lens',
              value: 'Rear Wide',
              subtitle: 'iPhone 8 • Gyro + Gravity ACC',
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterDetail extends StatelessWidget {
  const _FooterDetail({
    required this.title,
    required this.value,
    required this.subtitle,
    this.alignEnd = false,
  });

  final String title;
  final String value;
  final String? subtitle;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final alignment =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFFFFCC33),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white60,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    this.highlighted = false,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFCC33) : const Color(0x221A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: highlighted ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0x22FFCC33) : const Color(0x221A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? const Color(0xFFFFCC33) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
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

Future<void> _showAdvancedSheet(
  BuildContext context,
  CameraViewModel viewModel,
) async {
  final controller = TextEditingController(text: viewModel.imuOrientation);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF121212),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Advanced', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'IMU orientation',
                hintText: 'XYZ',
              ),
              onSubmitted: (value) => viewModel.setImuOrientation(value),
            ),
            const SizedBox(height: 14),
            Text(
              'Use Gyroflow orientation syntax. Default is `XYZ`.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {
                  viewModel.setImuOrientation(controller.text.trim());
                  Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
}
