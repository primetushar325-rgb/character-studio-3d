import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' as sharing;

import '../../core/theme/app_colors.dart';
import '../../core/utils/animation_names.dart';
import '../../core/utils/formatters.dart';
import '../../models/character.dart';
import '../../models/viewer_enums.dart';
import '../../state/library_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/animation_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mapping_editor.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/three_d_viewer.dart';
import '../../widgets/thumbnail.dart';
import '../actions/action_select_screen.dart';
import '../characters/bone_mapping_sheet.dart';
import '../player/player_screen.dart';

/// Premium character details: live 3D preview, validation facts, standard
/// action grid, mapping editors and full management actions.
class CharacterDetailScreen extends StatefulWidget {
  const CharacterDetailScreen({super.key, required this.characterId});

  final String characterId;

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  ThreeDController? _viewer;
  String? _viewerForCharacterId;

  @override
  void dispose() {
    // Release model GPU resources when leaving the screen.
    _viewer?.disposeModel();
    _viewer?.dispose();
    super.dispose();
  }

  void _ensureViewer(Character character, SettingsProvider settings) {
    if (_viewerForCharacterId == character.id) return;
    _viewer?.dispose();
    _viewer = ThreeDController();
    _viewerForCharacterId = character.id;
    _viewer!
      ..loadCharacter(character)
      ..applyBackground(BackgroundPreset.studio)
      ..applyLighting(LightingPreset.studio)
      ..setAutoRotateCamera(settings.autoRotateCamera);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final settings = context.watch<SettingsProvider>();
    final character = library.byId(widget.characterId);

    if (character == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Character'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.person_off_rounded,
              title: 'Character not found',
              message:
                  'This character was removed from the library. It may have been deleted.',
              actionLabel: 'Back to library',
              onAction: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      );
    }

    _ensureViewer(character, settings);
    final viewer = _viewer!;

    return Scaffold(
      body: Column(
        children: [
          // ---- top bar ----
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  const BackButton(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          character.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${character.source == CharacterSource.bundled ? 'Bundled Sample' : 'Imported Character'} · '
                          '${character.readinessLabel()} · '
                          '${character.animationCount} '
                          '${character.animationCount == 1 ? 'Animation' : 'Animations'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FavoriteHeart(
                    favorite: character.isFavorite,
                    onToggle: () => library.toggleFavorite(character),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (value) => _onMenu(value, character, library),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Edit Name')),
                      PopupMenuItem(value: 'mapping', child: Text('Edit Mapping')),
                      PopupMenuItem(value: 'bones', child: Text('Bone Mapping')),
                      PopupMenuItem(value: 'share', child: Text('Share')),
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      PopupMenuItem(value: 'export', child: Text('Export')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ---- content ----
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Live 3D preview
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: StaggeredEntrance(
                    index: 0,
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: 24,
                      blur: 6,
                      child: AspectRatio(
                        aspectRatio: 1.05,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(23),
                          child: Stack(
                            children: [
                              Positioned.fill(child: ThreeDViewer(controller: viewer)),
                              if (viewer.state == ViewerLoadState.loading)
                                Positioned.fill(
                                  child: _LoadingOverlay(name: character.displayName),
                                ),
                              if (viewer.state == ViewerLoadState.error)
                                Positioned.fill(
                                  child: _PreviewErrorOverlay(viewer: viewer),
                                ),
                              if (viewer.state == ViewerLoadState.ready)
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: _spinHint(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Primary actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PremiumButton(
                          label: 'Use Character',
                          icon: Icons.play_arrow_rounded,
                          style: PremiumButtonStyle.primary,
                          onPressed: () => _useCharacter(character, library),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PremiumButton(
                          label: 'All Clips',
                          icon: Icons.animation_rounded,
                          onPressed: character.animations.isEmpty
                              ? null
                              : () => Navigator.of(context).push(
                                    fadeSlideRoute(ActionSelectScreen(
                                        characterId: character.id)),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick facts
                SectionHeader(title: 'Character'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    blur: 6,
                    shadow: false,
                    child: Row(
                      children: [
                        _FactTile(
                          icon: character.hasSkeleton
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          iconColor: character.hasSkeleton
                              ? AppColors.success
                              : AppColors.danger,
                          label: 'Skeleton',
                          value: character.hasSkeleton
                              ? '✓ ${character.boneCount} bones'
                              : 'None',
                        ),
                        _FactTile(
                          icon: Icons.animation_rounded,
                          iconColor: AppColors.accent,
                          label: 'Animations',
                          value:
                              '${character.animationCount} found · '
                              '${character.animationMapping.length} mapped',
                        ),
                        _FactTile(
                          icon: Icons.view_in_ar_rounded,
                          iconColor: AppColors.accent,
                          label: 'Meshes',
                          value: '${character.meshCount}',
                        ),
                        _FactTile(
                          icon: Icons.palette_outlined,
                          iconColor: AppColors.accent,
                          label: 'Materials',
                          value: '${character.materialCount}',
                        ),
                      ],
                    ),
                  ),
                ),
                // Standard action grid
                SectionHeader(
                  title: 'Actions',
                  actionLabel: character.animations.isNotEmpty ? 'Edit Mapping' : null,
                  onAction: character.animations.isNotEmpty
                      ? () => _editMapping(character, library)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.6,
                    children: [
                      for (final action in StandardAction.all)
                        _StandardActionTile(
                          action: action,
                          clipName: character.animationMapping[action],
                          onTap: () => _playStandard(character, action, library),
                        ),
                    ],
                  ),
                ),
                // File information
                if (settings.showFileInfo) ...[
                  SectionHeader(title: 'File Information'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      blur: 6,
                      shadow: false,
                      child: Column(
                        children: [
                          _InfoRow(label: 'File', value: character.fileName),
                          _InfoRow(label: 'Character ID',
                              value: character.charId ?? '—'),
                          _InfoRow(
                              label: 'Original file',
                              value: character.originalFileName ?? character.fileName),
                          _InfoRow(
                              label: 'Size',
                              value:
                                  Formatters.fileSize(character.fileSizeBytes)),
                          _InfoRow(
                              label: 'Animations',
                              value: '${character.animationCount}'),
                          _InfoRow(label: 'Meshes', value: '${character.meshCount}'),
                          _InfoRow(
                              label: 'Materials', value: '${character.materialCount}'),
                          if (character.hasSkeleton)
                            _InfoRow(
                                label: 'Rig (bones)',
                                value: '${character.boneCount}'),
                          if (character.humanoidDetected)
                            const _InfoRow(
                                label: 'Humanoid rig',
                                value: 'Detected',
                                good: true),
                          _InfoRow(
                              label: 'Triangles',
                              value:
                                  '${(character.triangleCount / 1000).toStringAsFixed(1)}K'),
                          if (character.generator != null)
                            _InfoRow(
                                label: 'Exported with',
                                value: character.generator!,
                                small: true),
                          _InfoRow(
                              label: 'Added',
                              value: Formatters.relativeTime(character.createdAt)),
                          _InfoRow(
                              label: 'Last used',
                              value: character.lastUsedAt == null
                                  ? 'Never'
                                  : Formatters.relativeTime(character.lastUsedAt)),
                          _InfoRow(
                              label: 'Used',
                              value: character.useCount == 0
                                  ? 'Never'
                                  : '${character.useCount} times'),
                          _InfoRow(
                              label: 'Source',
                              value: character.source == CharacterSource.bundled
                                  ? 'Bundled sample'
                                  : 'Imported'),
                        ],
                      ),
                    ),
                  ),
                ],
                // All detected animations
                SectionHeader(
                  title: 'Available Animations',
                  actionLabel: character.animations.length > 3 ? 'Choose' : null,
                  onAction: character.animations.length > 3
                      ? () => Navigator.of(context).push(
                            fadeSlideRoute(
                                ActionSelectScreen(characterId: character.id)),
                          )
                      : null,
                ),
                if (character.animations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      blur: 6,
                      shadow: false,
                      child: EmptyState(
                        icon: Icons.animation_outlined,
                        title: 'No animations detected',
                        message:
                            'This model has no embedded animation clips, but you can '
                            'still rotate and inspect it in 3D.',
                        compact: true,
                      ),
                    ),
                  )
                else
                  ...List.generate(character.animations.length, (index) {
                    final clip = character.animations[index];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20,
                          index == character.animations.length - 1 ? 0 : 10),
                      child: StaggeredEntrance(
                        index: index,
                        child: AnimationCard(
                          animation: clip,
                          onPlay: () {
                            library.recordUsage(character, clip.name);
                            Navigator.of(context).push(
                              fadeSlideRoute(PlayerScreen(
                                characterId: character.id,
                                initialAnimationName: clip.name,
                              )),
                            );
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------
  void _useCharacter(Character character, LibraryProvider library) {
    final mapped = character.animationMapping.entries
        .where((e) => e.value.isNotEmpty)
        .toList();
    final clipName = mapped.isNotEmpty
        ? mapped.first.value
        : (character.animations.isNotEmpty ? character.animations.first.name : null);
    Navigator.of(context).push(
      fadeSlideRoute(PlayerScreen(
        characterId: character.id,
        initialAnimationName: clipName,
      )),
    );
    if (clipName != null) {
      library.recordUsage(character, clipName);
    }
  }

  void _playStandard(
      Character character, String action, LibraryProvider library) {
    final clip = character.clipForAction(action);
    if (clip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${StandardAction.label(action)} animation is not available for this character.'),
          action: SnackBarAction(
            label: 'Use another',
            onPressed: () => Navigator.of(context).push(
              fadeSlideRoute(ActionSelectScreen(characterId: character.id)),
            ),
          ),
        ),
      );
      return;
    }
    library.recordUsage(character, clip.name);
    Navigator.of(context).push(
      fadeSlideRoute(PlayerScreen(
        characterId: character.id,
        initialAnimationName: clip.name,
      )),
    );
  }

  Future<void> _editMapping(
      Character character, LibraryProvider library) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MappingSheet(character: character),
    );
    if (result != null) {
      await library.saveAnimationMapping(character, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Animation mapping saved')),
        );
      }
    }
  }

  Future<void> _editBones(
      Character character, LibraryProvider library) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BoneMappingSheet(
        boneNames: _boneNamesFor(character),
        initialMapping: character.boneMapping,
      ),
    );
    if (result != null) {
      await library.saveBoneMapping(character, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bone mapping saved')),
        );
      }
    }
  }

  List<String> _boneNamesFor(Character character) {
    // Bone names come from the last parse; when the library was re-scanned
    // the metadata mapping keeps every previously matched name, and the
    // remaining bones can be re-listed from the mapping sheet detector.
    final known = <String>{...character.boneMapping.values};
    // Add common armature node names derived from the mapping keys so the
    // dropdown always offers the current selection.
    return known.toList();
  }

  void _onMenu(String action, Character character, LibraryProvider library) {
    switch (action) {
      case 'rename':
        _showRenameDialog(character, library);
      case 'mapping':
        _editMapping(character, library);
      case 'bones':
        _editBones(character, library);
      case 'share':
        _shareCharacter(character);
      case 'duplicate':
        _duplicate(character, library);
      case 'export':
        final last = library.lastUsageOf(character.id)?.animationName;
        Navigator.of(context).push(
          fadeSlideRoute(PlayerScreen(
            characterId: character.id,
            initialAnimationName: last ??
                (character.animations.isNotEmpty
                    ? character.animations.first.name
                    : null),
            openExportOnReady: true,
          )),
        );
      case 'delete':
        _confirmDelete(character, library);
    }
  }

  Future<void> _duplicate(
      Character character, LibraryProvider library) async {
    try {
      await library.duplicate(character);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${character.displayName} duplicated')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('The character could not be duplicated.')),
        );
      }
    }
  }

  Future<void> _showRenameDialog(
      Character character, LibraryProvider library) async {
    final controller = TextEditingController(text: character.displayName);
    final result = await showPremiumDialog<String>(
      context,
      PremiumDialog(
        title: 'Edit Name',
        message: 'Only the display name changes — the GLB file stays untouched.',
        icon: Icons.edit_rounded,
        actions: [
          PremiumTextButton(
              label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
          PremiumButton(
            label: 'Save',
            small: true,
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            hintText: 'Display name',
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.stroke),
            ),
          ),
        ),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await library.rename(character, result.trim());
    }
  }

  Future<void> _shareCharacter(Character character) async {
    try {
      await sharing.Share.shareXFiles(
        [sharing.XFile(character.filePath)],
        text: '${character.displayName} — shared from Character Studio 3D',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This file could not be shared.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
      Character character, LibraryProvider library) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Character?',
      message:
          '"${character.displayName}" will be removed from your library and its '
          'files deleted from app storage. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      await library.delete(character);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Widget _spinHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz_rounded, size: 12, color: Colors.white70),
          SizedBox(width: 5),
          Text(
            'Drag to rotate',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Pieces
// ======================================================================

class _MappingSheet extends StatelessWidget {
  const _MappingSheet({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapping = Map<String, String?>.from(character.animationMapping);
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              Text('Animation Mapping',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Map standard actions to the clips embedded in this model.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ActionMappingEditor(
                clips: character.animations,
                mapping: mapping,
                suggestions: const {},
                confidences: const {},
                onChanged: (action, clip) => mapping[action] = clip,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: PremiumButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                      style: PremiumButtonStyle.ghost,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PremiumButton(
                      label: 'Save Mapping',
                      icon: Icons.check_rounded,
                      style: PremiumButtonStyle.primary,
                      onPressed: () => Navigator.of(context).pop({
                        for (final e in mapping.entries)
                          if (e.value != null && e.value!.isNotEmpty)
                            e.key: e.value!,
                      }),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isDark ? 0 : 0),
            ],
          );
        },
      ),
    );
  }
}

class _StandardActionTile extends StatelessWidget {
  const _StandardActionTile({
    required this.action,
    required this.clipName,
    required this.onTap,
  });

  final String action;
  final String? clipName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = clipName != null && clipName!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label:
          '$action ${enabled ? 'play' : 'not available for this character'}',
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? AppColors.accent.withOpacity(0.5) : AppColors.stroke,
              width: enabled ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enabled ? AppColors.accentSoft : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: enabled ? AppColors.accent : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          StandardAction.label(action),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: enabled
                                ? null
                                : (isDark
                                    ? AppColors.textMuted
                                    : const Color(0xFF8B94A6)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          enabled
                              ? Icons.check_rounded
                              : Icons.remove_rounded,
                          size: 14,
                          color: enabled ? AppColors.success : AppColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled
                          ? (clipName ?? '').split('|').last
                          : 'Not available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 19, color: iconColor),
          const SizedBox(height: 6),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.small = false, this.good = false});

  final String label;
  final String value;
  final bool small;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    )),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: small ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: good ? AppColors.success : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading 3D Character...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewErrorOverlay extends StatelessWidget {
  const _PreviewErrorOverlay({required this.viewer});

  final ThreeDController viewer;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined,
                  size: 42, color: AppColors.danger),
              const SizedBox(height: 12),
              Text('Animation unavailable',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'This model could not be rendered. The GLB may use an unsupported '
                'feature or the file may be corrupted.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              PremiumButton(
                label: 'Try Again',
                icon: Icons.refresh_rounded,
                small: true,
                onPressed: () {
                  final character = viewer.character;
                  if (character != null) viewer.loadCharacter(character);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
