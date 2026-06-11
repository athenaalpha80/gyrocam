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
              if (viewModel.isQuickControlOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: viewModel.closeQuickControl,
                  ),
                ),
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
        : '00:00:00';

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
              orientationTurns: viewModel.orientationTurns,
            ),
          ),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(
                horizontal: viewModel.isRecording ? 12 : 0,
                vertical: viewModel.isRecording ? 4 : 0,
              ),
              decoration: BoxDecoration(
                color: viewModel.isRecording
                    ? const Color(0xFFFF3B30)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                timerText,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: viewModel.isRecording ? 22 : 20,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _TopIconButton(
              icon: CupertinoIcons.settings,
              onTap: () => _openSettings(context, viewModel),
              orientationTurns: viewModel.orientationTurns,
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
    required this.orientationTurns,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double orientationTurns;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedRotation(
        turns: orientationTurns,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0x22101010),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
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
        _QuickControlPanelHost(viewModel: viewModel),
        const SizedBox(height: 12),
        _QuickControlStrip(viewModel: viewModel),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: viewModel.isStartingRecording
              ? null
              : viewModel.isRecording
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
              child: viewModel.isStartingRecording
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF3B30),
                        ),
                      ),
                    )
                  : AnimatedContainer(
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

class _QuickControlStrip extends StatelessWidget {
  const _QuickControlStrip({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: _QuickControlButton(
            label: 'RES',
            value: _resolutionSummary(viewModel),
            selected:
                viewModel.activeQuickControl == QuickControlPanel.resolution,
            onTap: () =>
                viewModel.toggleQuickControl(QuickControlPanel.resolution),
            orientationTurns: viewModel.orientationTurns,
          ),
        ),
        Expanded(
          child: _QuickControlButton(
            label: 'FR',
            value: '${viewModel.selectedFps}',
            selected:
                viewModel.activeQuickControl == QuickControlPanel.frameRate,
            onTap: () =>
                viewModel.toggleQuickControl(QuickControlPanel.frameRate),
            orientationTurns: viewModel.orientationTurns,
          ),
        ),
        Expanded(
          child: _QuickControlButton(
            label: 'EXP',
            value: _exposureSummary(viewModel),
            selected:
                viewModel.activeQuickControl == QuickControlPanel.exposure,
            onTap: () =>
                viewModel.toggleQuickControl(QuickControlPanel.exposure),
            orientationTurns: viewModel.orientationTurns,
          ),
        ),
        Expanded(
          child: _QuickControlButton(
            label: 'FOCUS',
            value: viewModel.focusMode == FocusAssistMode.auto
                ? 'AUTO'
                : viewModel.manualFocus.toStringAsFixed(2),
            selected: viewModel.activeQuickControl == QuickControlPanel.focus,
            onTap: () => viewModel.toggleQuickControl(QuickControlPanel.focus),
            orientationTurns: viewModel.orientationTurns,
          ),
        ),
        Expanded(
          child: _QuickControlButton(
            label: 'WB',
            value: viewModel.whiteBalanceMode == WhiteBalanceAssistMode.auto
                ? 'AUTO'
                : '${viewModel.whiteBalanceKelvin}K',
            selected:
                viewModel.activeQuickControl == QuickControlPanel.whiteBalance,
            onTap: () =>
                viewModel.toggleQuickControl(QuickControlPanel.whiteBalance),
            orientationTurns: viewModel.orientationTurns,
          ),
        ),
      ],
    );
  }

  String _resolutionSummary(CameraViewModel viewModel) {
    final format = viewModel.selectedFormat;
    if (format == null) {
      return '--';
    }
    return switch ((format.width, format.height)) {
      (3840, 2160) => '4K',
      (1920, 1080) => '1080p',
      _ => format.label,
    };
  }

  String _exposureSummary(CameraViewModel viewModel) {
    if (viewModel.exposureMode == ExposureAssistMode.auto) {
      return 'AUTO';
    }
    return viewModel.iso.round().toString();
  }
}

class _QuickControlButton extends StatelessWidget {
  const _QuickControlButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.orientationTurns,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final double orientationTurns;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            color: selected ? const Color(0xFFFFCC33) : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        child: AnimatedRotation(
          turns: orientationTurns,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFFFCC33) : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              DefaultTextStyle(
                style: TextStyle(
                  color: selected ? const Color(0xFFFFCC33) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 24 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC33),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _QuickControlPanelHost extends StatelessWidget {
  const _QuickControlPanelHost({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: switch (viewModel.activeQuickControl) {
        QuickControlPanel.none => const SizedBox.shrink(),
        QuickControlPanel.resolution => _QuickControlCard(
          key: const ValueKey<String>('resolution'),
          child: _ResolutionQuickControl(viewModel: viewModel),
        ),
        QuickControlPanel.frameRate => _QuickControlCard(
          key: const ValueKey<String>('frame-rate'),
          child: _FrameRateQuickControl(viewModel: viewModel),
        ),
        QuickControlPanel.exposure => _QuickControlCard(
          key: const ValueKey<String>('exposure'),
          child: _ExposureQuickControl(viewModel: viewModel),
        ),
        QuickControlPanel.focus => _QuickControlCard(
          key: const ValueKey<String>('focus'),
          child: _FocusQuickControl(viewModel: viewModel),
        ),
        QuickControlPanel.whiteBalance => _QuickControlCard(
          key: const ValueKey<String>('wb'),
          child: _WhiteBalanceQuickControl(viewModel: viewModel),
        ),
      },
    );
  }
}

class _ResolutionQuickControl extends StatelessWidget {
  const _ResolutionQuickControl({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final formats = viewModel.capabilities?.formats ?? const <CameraFormatOption>[];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: formats.map((format) {
        final selected = format == viewModel.selectedFormat;
        final label = switch ((format.width, format.height)) {
          (3840, 2160) => '4K',
          (1920, 1080) => '1080p',
          _ => format.label,
        };
        return _OptionPill(
          label: label,
          selected: selected,
          onTap: () => viewModel.selectFormat(format),
        );
      }).toList(),
    );
  }
}

class _FrameRateQuickControl extends StatelessWidget {
  const _FrameRateQuickControl({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final fpsOptions = viewModel.selectedFormat?.fpsOptions ?? const <int>[];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: fpsOptions.map((fps) {
        return _OptionPill(
          label: '$fps fps',
          selected: fps == viewModel.selectedFps,
          onTap: () => viewModel.selectFps(fps),
        );
      }).toList(),
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFCC33) : const Color(0x22101010),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _QuickControlCard extends StatelessWidget {
  const _QuickControlCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
        child: child,
      ),
    );
  }
}

class _ExposureQuickControl extends StatelessWidget {
  const _ExposureQuickControl({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isoValues = viewModel.availableIsoValues;
    final shutterValues = viewModel.availableShutterMicros;
    if (isoValues.isEmpty || shutterValues.isEmpty) {
      return const SizedBox.shrink();
    }

    final isIso = viewModel.activeExposureControl == ExposureControlMode.iso;
    final currentIsoIndex = isoValues.indexOf(viewModel.iso.round()).clamp(
      0,
      isoValues.length - 1,
    );
    final currentShutterIndex = shutterValues
        .indexOf(viewModel.shutterMicros)
        .clamp(0, shutterValues.length - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _MiniModeButton(
              label: 'ISO',
              selected: isIso,
              onTap: () =>
                  viewModel.selectExposureControlMode(ExposureControlMode.iso),
            ),
            const SizedBox(width: 8),
            _MiniModeButton(
              label: 'SHT',
              selected: !isIso,
              onTap: () => viewModel.selectExposureControlMode(
                ExposureControlMode.shutter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _AutoRulerRow(
          valueLabel: isIso
              ? viewModel.iso.round().toString()
              : viewModel.formatShutter(viewModel.shutterMicros),
          autoSelected: viewModel.exposureMode == ExposureAssistMode.auto,
          value: isIso
              ? currentIsoIndex.toDouble()
              : currentShutterIndex.toDouble(),
          min: 0,
          max: isIso
              ? (isoValues.length - 1).toDouble()
              : (shutterValues.length - 1).toDouble(),
          divisions: isIso ? isoValues.length - 1 : shutterValues.length - 1,
          onAutoTap: () => viewModel.setExposureMode(ExposureAssistMode.auto),
          onChanged: (value) {
            final index = value.round();
            if (isIso) {
              viewModel.setIso(isoValues[index].toDouble());
            } else {
              viewModel.setShutterMicros(shutterValues[index].toDouble());
            }
          },
        ),
      ],
    );
  }
}

class _FocusQuickControl extends StatelessWidget {
  const _FocusQuickControl({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _AutoRulerRow(
      valueLabel: viewModel.manualFocus.toStringAsFixed(2),
      autoSelected: viewModel.focusMode == FocusAssistMode.auto,
      value: viewModel.manualFocus,
      min: 0,
      max: 1,
      divisions: 20,
      onAutoTap: () => viewModel.setFocusMode(FocusAssistMode.auto),
      onChanged: viewModel.setManualFocus,
    );
  }
}

class _WhiteBalanceQuickControl extends StatelessWidget {
  const _WhiteBalanceQuickControl({
    required this.viewModel,
  });

  final CameraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final options = CameraViewModel.whiteBalanceOptions;
    final currentIndex = options.indexOf(viewModel.whiteBalanceKelvin).clamp(
      0,
      options.length - 1,
    );

    return _AutoRulerRow(
      valueLabel: '${viewModel.whiteBalanceKelvin}K',
      autoSelected: viewModel.whiteBalanceMode == WhiteBalanceAssistMode.auto,
      value: currentIndex.toDouble(),
      min: 0,
      max: (options.length - 1).toDouble(),
      divisions: options.length - 1,
      onAutoTap: () =>
          viewModel.setWhiteBalanceMode(WhiteBalanceAssistMode.auto),
      onChanged: (value) {
        final index = value.round().clamp(0, options.length - 1);
        viewModel.setWhiteBalanceKelvin(options[index]);
      },
    );
  }
}

class _MiniModeButton extends StatelessWidget {
  const _MiniModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFCC33) : const Color(0x22101010),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _AutoRulerRow extends StatelessWidget {
  const _AutoRulerRow({
    required this.valueLabel,
    required this.autoSelected,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onAutoTap,
    required this.onChanged,
  });

  final String valueLabel;
  final bool autoSelected;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final VoidCallback onAutoTap;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        GestureDetector(
          onTap: onAutoTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 54,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: autoSelected
                  ? const Color(0xFFFFCC33)
                  : const Color(0x22101010),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'AUTO',
              style: TextStyle(
                color: autoSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.2),
              activeTickMarkColor: const Color(0xFFFFCC33),
              inactiveTickMarkColor: Colors.white24,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions > 0 ? divisions : null,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 0),
        SizedBox(
          width: 52,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
                      title: 'Video Codec',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <VideoCodec>[VideoCodec.h265, VideoCodec.h264].map((codec) {
                          final selected = codec == viewModel.videoCodec;
                          return FilterChip(
                            label: Text(codec == VideoCodec.h265 ? 'HEVC (H.265)' : 'H.264'),
                            selected: selected,
                            onSelected: (_) => viewModel.setVideoCodec(codec),
                          );
                        }).toList(),
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
