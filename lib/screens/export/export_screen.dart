import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/character.dart';
import '../../models/viewer_enums.dart';
import '../../state/export_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/color_picker_sheet.dart';
import '../../widgets/error_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/section_header.dart';

/// Export screen — REAL on-device video export via MediaProjection.
///
/// The 3D scene renders inside a WebView (model-viewer/three.js), whose frame
/// buffers are not directly accessible from Dart. The closest *real* capture
/// pipeline is Android's MediaProjection screen recorder: it encodes the
/// actual animation preview into an H.264 MP4 saved via MediaStore. If the
/// user denies the permission or the encoder fails, an honest error is shown.
/// Nothing here is simulated.
class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    required this.character,
    required this.currentAnimationName,
    required this.onPrepareBackground,
    required this.onRestartAnimation,
  });

  final Character character;
  final String? currentAnimationName;
  final void Function(BackgroundPreset preset, String? customHex)
      onPrepareBackground;
  final VoidCallback onRestartAnimation;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

enum _ExportBackground { current, dark, custom }

class _ExportScreenState extends State<ExportScreen> {
  String _resolution = '720p';
  int _fps = 30;
  int _seconds = 10;
  _ExportBackground _background = _ExportBackground.current;
  String? _customHex;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _resolution = settings.exportResolution;
    _fps = settings.exportFps;
    _seconds = settings.exportDuration;
  }

  int get _width => _resolution == '1080p' ? 1920 : 1280;
  int get _height => _resolution == '1080p' ? 1080 : 720;

  Future<void> _startExport() async {
    final export = context.read<ExportProvider>();
    final supported = await export.isSupported;

    if (!supported) {
      setState(() =>
          _error = 'Screen recording is not supported on this device.');
      return;
    }

    // Apply the chosen stage background to the live player behind this sheet.
    switch (_background) {
      case _ExportBackground.current:
        break;
      case _ExportBackground.dark:
        widget.onPrepareBackground(BackgroundPreset.dark, null);
      case _ExportBackground.custom:
        widget.onPrepareBackground(
            BackgroundPreset.custom, _customHex ?? '#06070A');
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    // Make sure the animation is running before the recorder starts.
    widget.onRestartAnimation();

    try {
      await export.startRecording(
        width: _width,
        height: _height,
        fps: _fps,
        seconds: _seconds,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;

    if (export.phase == ExportPhase.error && export.error != null) {
      setState(() => _error = export.error);
      return;
    }

    if (export.phase == ExportPhase.recording ||
        export.phase == ExportPhase.requesting) {
      // Pop back to the player so the recorded video shows the animation,
      // not this settings screen. The player shows the REC badge.
      Navigator.of(context).pop();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final export = context.watch<ExportProvider>();
    final finished = export.phase == ExportPhase.done && export.lastEvent != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export'),
            Text(
              '${widget.character.displayName}'
              '${widget.currentAnimationName != null ? ' · ${widget.currentAnimationName!.split('|').last}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _infoCard(context),
          const SectionHeader(title: 'Resolution'),
          _optionRow(
            options: const ['720p', '1080p'],
            selected: _resolution,
            onSelect: (v) => setState(() => _resolution = v),
          ),
          const SectionHeader(title: 'Frame Rate'),
          _optionRow(
            options: const ['24', '30', '60'],
            selected: '$_fps',
            onSelect: (v) => setState(() => _fps = int.parse(v)),
          ),
          const SectionHeader(title: 'Duration'),
          _optionRow(
            options: const ['5', '10', '15', '30'],
            selected: '$_seconds',
            onSelect: (v) => setState(() => _seconds = int.parse(v)),
            suffixBuilder: (v) => 's',
          ),
          const SectionHeader(title: 'Background'),
          _optionRow(
            options: const ['Current', 'Dark', 'Custom'],
            selected: switch (_background) {
              _ExportBackground.current => 'Current',
              _ExportBackground.dark => 'Dark',
              _ExportBackground.custom => 'Custom',
            },
            onSelect: (v) async {
              if (v == 'Custom') {
                final hex = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ColorPickerSheet(
                      title: 'Export Background'),
                );
                if (hex == null) return;
                setState(() {
                  _background = _ExportBackground.custom;
                  _customHex = hex;
                });
              } else {
                setState(() => _background = v == 'Dark'
                    ? _ExportBackground.dark
                    : _ExportBackground.current);
              }
            },
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            ErrorView(
              title: 'Export failed',
              message: _error!,
              compact: true,
              onRetry: _startExport,
            ),
            const SizedBox(height: 18),
          ],
          PremiumButton(
            label: export.isBusy
                ? 'Starting…'
                : 'Start Recording ($_seconds s)',
            icon: Icons.videocam_rounded,
            style: PremiumButtonStyle.primary,
            expanded: true,
            onPressed: (export.isBusy || _busy) ? null : _startExport,
          ),
          const SizedBox(height: 10),
          if (finished) _finishedCard(context, export),
          const SizedBox(height: 12),
          Text(
            'Recording captures the live animation preview using Android\'s '
            'system screen recorder. The video is saved to '
            'Movies/Character Studio 3D in your gallery.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      blur: 8,
      shadow: false,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.movie_creation_rounded,
                color: Color(0xFF0A0C11), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export Video',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'On-device recording · $_resolution · $_fps fps · $_seconds s',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
    String Function(String)? suffixBuilder,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _OptionChip(
            label: suffixBuilder != null
                ? '$option${suffixBuilder(option)}'
                : option,
            selected: selected == option,
            onTap: () => onSelect(option),
          ),
      ],
    );
  }

  Widget _finishedCard(BuildContext context, ExportProvider export) {
    final uri = export.lastEvent?.uri ?? '';
    final size = export.lastEvent?.sizeBytes ?? 0;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      blur: 8,
      shadow: false,
      border: Border.all(color: AppColors.success.withOpacity(0.4)),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Video exported successfully.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Saved to gallery · ${Formatters.fileSize(size)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: 'Open',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => export.service.openMedia(uri),
                  small: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PremiumButton(
                  label: 'Share',
                  icon: Icons.share_rounded,
                  onPressed: () =>
                      export.service.shareMedia(uri),
                  small: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PremiumButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  style: PremiumButtonStyle.danger,
                  onPressed: () async {
                    await export.service.deleteMedia(uri);
                    export.reset();
                  },
                  small: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withOpacity(0.55)
                  : AppColors.stroke,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
