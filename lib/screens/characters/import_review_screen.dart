import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/animation_names.dart';
import '../../models/character.dart';
import '../../models/viewer_enums.dart';
import '../../services/character_service.dart';
import '../../services/validation_service.dart';
import '../../state/library_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mapping_editor.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/three_d_viewer.dart';
import 'bone_mapping_sheet.dart';
import 'character_detail_screen.dart';

/// Post-import review: live 3D preview + full validation report +
/// animation status table + manual mapping + "Save Character".
class ImportReviewScreen extends StatefulWidget {
  const ImportReviewScreen({super.key, required this.staged});

  final StagedImport staged;

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  ThreeDController? _viewer;
  late Map<String, String?> _mapping;
  late Map<String, String> _suggestions;
  late Map<String, double> _confidences;
  late Map<String, String> _boneMapping;
  String _selectedActionForPreview = '';
  bool _saving = false;
  bool _gridVisible = false;
  bool _autoRotate = true;
  bool _showAllChecks = false;

  @override
  void initState() {
    super.initState();
    final report = widget.staged.report;
    _mapping = {
      for (final action in StandardAction.all)
        action: report.autoMapping[action],
    };
    _suggestions = Map<String, String>.from(report.suggestions);
    _confidences = {
      for (final a in report.actions)
        if (a.clipName != null || a.suggestedClip != null)
          a.action: a.confidence,
    };
    _boneMapping = Map<String, String>.from(
      widget.staged.character.boneMapping,
    );
  }

  @override
  void dispose() {
    // Never leave a staged WebView/model alive after leaving the screen.
    _viewer?.disposeModel();
    _viewer?.dispose();
    super.dispose();
  }

  void _ensureViewer() {
    if (_viewer != null) return;
    final settings = context.read<SettingsProvider>();
    final viewer = ThreeDController();
    final character = widget.staged.character;
    viewer
      ..loadCharacter(character)
      ..applyBackground(BackgroundPreset.studio)
      ..applyLighting(LightingPreset.studio)
      ..setAutoRotateCamera(_autoRotate && settings.autoRotateCamera)
      ..setGridVisible(false);
    _viewer = viewer;
  }

  Future<void> _previewAction(String action) async {
    final clipName = _mapping[action];
    final viewer = _viewer;
    if (viewer == null) return;
    if (clipName == null || clipName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${StandardAction.label(action)} animation is not available for this character.'),
        ),
      );
      return;
    }
    setState(() => _selectedActionForPreview = action);
    await viewer.setLoop(true);
    await viewer.playAnimation(
      widget.staged.character.serverModelPath,
      clipName,
      loop: true,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final library = context.read<LibraryProvider>();
    // Capture a context-free messenger before awaits (lint safety).
    try {
      final committed = await library.commitImport(
        widget.staged,
        animationMapping: {
          for (final e in _mapping.entries)
            if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
        },
        boneMapping: _boneMapping,
      );
      if (!mounted) return;
      await showPremiumDialog<void>(
        context,
        PremiumDialog(
          title: 'Character Saved',
          message:
              '${committed.displayName} has been added to your library with its '
              'animation mapping.',
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.success,
          actions: [
            PremiumTextButton(
              label: 'Done',
              onPressed: () {
                Navigator.of(context).pop(); // dialog
                Navigator.of(context).pop(); // review screen
              },
            ),
            PremiumButton(
              label: 'Open Character',
              small: true,
              icon: Icons.view_in_ar_rounded,
              onPressed: () {
                Navigator.of(context).pop(); // dialog
                Navigator.of(context).pop(); // review screen
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CharacterDetailScreen(characterId: committed.id),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('The character could not be saved. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    final navigator = Navigator.of(context);
    final library = context.read<LibraryProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard import?',
      message:
          'This model will not be saved and all temporary import files will be '
          'removed from your device.',
      confirmLabel: 'Discard',
    );
    if (!confirmed) return;
    await library.discardImport(widget.staged);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    _ensureViewer();
    final report = widget.staged.report;
    final character = widget.staged.character;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Character Validation'),
            Text(
              character.originalFileName ?? character.fileName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _gridVisible ? 'Hide grid' : 'Show grid',
            icon: Icon(
              _gridVisible ? Icons.grid_on_rounded : Icons.grid_off_rounded,
              color: _gridVisible ? AppColors.accent : null,
            ),
            onPressed: () {
              setState(() => _gridVisible = !_gridVisible);
              _viewer?.setGridVisible(_gridVisible);
            },
          ),
          IconButton(
            tooltip: _autoRotate ? 'Stop auto-rotate' : 'Auto-rotate',
            icon: Icon(
              Icons.screen_rotation_rounded,
              color: _autoRotate ? AppColors.accent : null,
            ),
            onPressed: () {
              setState(() => _autoRotate = !_autoRotate);
              _viewer?.setAutoRotateCamera(_autoRotate);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ---- readiness banner ----
          _ReadinessBanner(report: report, character: character),
          const SizedBox(height: 12),

          // ---- 3D preview ----
          GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: 22,
            blur: 6,
            child: AspectRatio(
              aspectRatio: 1.25,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Stack(
                  children: [
                    Positioned.fill(child: ThreeDViewer(controller: _viewer!)),
                    if (_viewer!.state == ViewerLoadState.loading)
                      Positioned.fill(
                        child: Container(
                          color: AppColors.bg,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(strokeWidth: 2.6),
                                ),
                                const SizedBox(height: 14),
                                Text('Preparing preview…',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Text(
                        'Drag to rotate · pinch to zoom · double-tap to reset',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.textMuted : Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The character is framed automatically (auto bounding-box + centering).',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),

          // ---- standard action preview buttons ----
          const SectionHeader(title: 'Preview Action'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in StandardAction.all)
                _ActionPreviewChip(
                  action: action,
                  enabled: _mapping[action] != null,
                  selected: _selectedActionForPreview == action,
                  onTap: () => _previewAction(action),
                ),
            ],
          ),

          // ---- validation checks ----
          SectionHeader(
            title: 'Validation',
            actionLabel: _showAllChecks ? 'Show less' : 'Show all',
            onAction: () =>
                setState(() => _showAllChecks = !_showAllChecks),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            blur: 6,
            shadow: false,
            child: Column(
              children: [
                for (final (i, check) in report.checks.indexed)
                  if (_showAllChecks || i < 9 || check.status != ValidationStatus.info)
                    _CheckRow(check: check),
              ],
            ),
          ),

          // ---- animation status table ----
          const SectionHeader(title: 'Animation Status'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            blur: 6,
            shadow: false,
            child: Column(
              children: [
                for (final status in report.actions)
                  _ActionStatusRow(
                    status: status,
                    mappedClip: _mapping[status.action],
                    onTap: status.isFound
                        ? () => _previewAction(status.action)
                        : null,
                  ),
                const SizedBox(height: 4),
                Text(
                  '✅ Found · ⚠️ Low-confidence candidate (confirm below) · '
                  '❌ Not found in this model',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted, fontSize: 10.5),
                ),
              ],
            ),
          ),

          // ---- manual mapping ----
          SectionHeader(
            title: 'Animation Mapping',
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionMappingEditor(
              clips: character.animations,
              mapping: _mapping,
              suggestions: _suggestions,
              confidences: _confidences,
              onChanged: (action, clip) {
                setState(() => _mapping[action] = clip);
              },
            ),
          ),

          // ---- skeleton / bone mapping ----
          if (character.hasSkeleton) ...[
            const SectionHeader(title: 'Skeleton & Bones'),
            GlassCard(
              padding: const EdgeInsets.all(14),
              blur: 6,
              shadow: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.accessibility_rounded,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          character.humanoidDetected
                              ? 'Humanoid rig detected'
                              : 'Skeleton detected (non-humanoid naming)',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${character.boneCount} bones · '
                    '${_boneMapping.length}/17 humanoid bones mapped',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  PremiumButton(
                    label: 'Bone Mapping',
                    icon: Icons.accessibility_new_rounded,
                    small: true,
                    style: PremiumButtonStyle.tonal,
                    onPressed: () async {
                      final result =
                          await showModalBottomSheet<Map<String, String>>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => BoneMappingSheet(
                          boneNames: widget.staged.boneNames,
                          initialMapping: _boneMapping,
                        ),
                      );
                      if (result != null) {
                        setState(() => _boneMapping = result);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],

          if (widget.staged.warnings.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final w in widget.staged.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 15, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(w,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: 'Discard',
                  icon: Icons.delete_outline_rounded,
                  style: PremiumButtonStyle.ghost,
                  onPressed: _saving ? null : _discard,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PremiumButton(
                  label: _saving ? 'Saving…' : 'Save Character',
                  icon: Icons.save_rounded,
                  style: PremiumButtonStyle.primary,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// ======================================================================
// Pieces
// ======================================================================

class _ReadinessBanner extends StatelessWidget {
  const _ReadinessBanner({required this.report, required this.character});

  final ValidationReport report;
  final Character character;

  @override
  Widget build(BuildContext context) {
    final color = ValidationReport.readinessColor(report.readiness);
    final label = ValidationReport.readinessLabel(report.readiness);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              report.readiness == CharacterReadiness.ready
                  ? Icons.verified_rounded
                  : report.readiness == CharacterReadiness.partial
                      ? Icons.error_outline_rounded
                      : Icons.cancel_rounded,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · ${report.foundActionCount}/6 actions mapped',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${character.animations.length} clips · '
                  '${character.meshCount} meshes · '
                  '${character.materialCount} materials · '
                  '${character.hasSkeleton ? '${character.boneCount} bones' : 'no skeleton'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final ValidationCheck check;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon(check.status),
              size: 17, color: statusColor(check.status)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (check.detail != null && check.detail!.isNotEmpty)
                  Text(
                    check.detail!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionStatusRow extends StatelessWidget {
  const _ActionStatusRow({
    required this.status,
    required this.mappedClip,
    this.onTap,
  });

  final ActionStatus status;
  final String? mappedClip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status.state) {
      'found' => (
        Icons.check_circle_rounded,
        const Color(0xFF6BD9A5),
        '✅ Found'
      ),
      'suggested' => (
        Icons.error_outline_rounded,
        const Color(0xFFFFC46B),
        '⚠️ Missing'
      ),
      _ => (
        Icons.cancel_rounded,
        const Color(0xFFFF6B7A),
        '❌ Not Found'
      ),
    };

    final clipLabel = status.isFound
        ? (status.clipName ?? '').split('|').last
        : status.isSuggested
            ? 'candidate: ${(status.suggestedClip ?? '').split('|').last} '
                '(${(status.confidence * 100).round()}%)'
            : 'no matching clip';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(StandardAction.label(status.action),
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800)),
            ),
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            Flexible(
              child: Text(
                clipLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.play_arrow_rounded,
                  size: 17, color: AppColors.accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionPreviewChip extends StatelessWidget {
  const _ActionPreviewChip({
    required this.action,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final String action;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '$action ${enabled ? 'available' : 'not available for this character'}',
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: !enabled
                ? AppColors.surface
                : selected
                    ? AppColors.accent
                    : AppColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: !enabled
                  ? AppColors.stroke
                  : selected
                      ? AppColors.accent
                      : AppColors.accent.withOpacity(0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled
                    ? Icons.check_rounded
                    : Icons.horizontal_rule_rounded,
                size: 14,
                color: !enabled
                    ? AppColors.textMuted
                    : selected
                        ? const Color(0xFF0A0C11)
                        : AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                StandardAction.label(action),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: !enabled
                      ? AppColors.textMuted
                      : selected
                          ? const Color(0xFF0A0C11)
                          : AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
