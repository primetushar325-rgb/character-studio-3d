import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' as sharing;

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/character.dart';
import '../../models/viewer_enums.dart';
import '../../state/library_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/animation_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/three_d_viewer.dart';
import '../../widgets/thumbnail.dart';
import '../actions/action_select_screen.dart';
import '../player/player_screen.dart';

/// Premium character details: live 3D preview, file facts, animations list.
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
                          '${character.animationCount} '
                          '${character.animationCount == 1 ? 'Animation' : 'Animations'}',
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
                      PopupMenuItem(value: 'share', child: Text('Share')),
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
                          label: 'Animate',
                          icon: Icons.animation_rounded,
                          style: PremiumButtonStyle.primary,
                          onPressed: character.animations.isEmpty ? null : () {
                            library.recordUsage(
                              character,
                              library.lastUsageOf(character.id)?.animationName ??
                                  (character.animations.isNotEmpty
                                      ? character.animations.first.name
                                      : null),
                            );
                            Navigator.of(context).push(
                              fadeSlideRoute(ActionSelectScreen(
                                  characterId: character.id)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PremiumButton(
                          label: 'Play',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () {
                            final last =
                                library.lastUsageOf(character.id)?.animationName;
                            Navigator.of(context).push(
                              fadeSlideRoute(PlayerScreen(
                                characterId: character.id,
                                initialAnimationName: last ??
                                    (character.animations.isNotEmpty
                                        ? character.animations.first.name
                                        : null),
                              )),
                            );
                          },
                        ),
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
                          _InfoRow(
                              label: 'File',
                              value: character.fileName),
                          _InfoRow(
                              label: 'Size',
                              value:
                                  Formatters.fileSize(character.fileSizeBytes)),
                          _InfoRow(
                              label: 'Animations',
                              value: '${character.animationCount}'),
                          _InfoRow(
                              label: 'Meshes',
                              value: '${character.meshCount}'),
                          _InfoRow(
                              label: 'Materials',
                              value: '${character.materialCount}'),
                          if (character.skinCount > 0)
                            _InfoRow(
                                label: 'Rig (skins)',
                                value: '${character.skinCount}'),
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
                              label: 'Source',
                              value: character.source == CharacterSource.bundled
                                  ? 'Bundled sample'
                                  : 'Imported'),
                        ],
                      ),
                    ),
                  ),
                ],
                // Animations
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

  void _onMenu(String action, Character character, LibraryProvider library) {
    switch (action) {
      case 'rename':
        _showRenameDialog(character, library);
      case 'share':
        _shareCharacter(character);
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
          '"${character.displayName}" will be removed from your library. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      await library.delete(character);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.small = false});

  final String label;
  final String value;
  final bool small;

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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
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
