import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' as sharing;

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/character.dart';
import '../../characters2d/character2d_model.dart';
import '../../characters2d/widgets2d/puppet_stage.dart' show PuppetThumbnail;
import '../../state/library2d_provider.dart';
import '../../state/library_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/character_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/filter_chip.dart';
import '../../widgets/thumbnail.dart';
import 'character_detail_screen.dart';
import 'import_flow.dart';
import '../characters2d/character2d_preview_screen.dart';
import '../player/player_screen.dart';

/// Character library: search, filters, sorting, grouped sections
/// (Recently Used · Built-in · Imported) and a responsive grid.
class CharactersScreen extends StatefulWidget {
  const CharactersScreen({super.key});

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final settings = context.watch<SettingsProvider>();
    final visible = library.visibleCharacters;
    final grouped =
        library.query.trim().isEmpty && library.filter == LibraryFilter.all;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Characters',
                              style: Theme.of(context).textTheme.headlineMedium),
                          Text(
                            '${library.characterCount} in your library · '
                            'search names or animations',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    PremiumButton(
                      label: 'Import',
                      icon: Icons.add_rounded,
                      onPressed: () => startImportFlow(context),
                      small: true,
                      style: PremiumButtonStyle.tonal,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: StudioSearchBar(
                  controller: _searchController,
                  hint: 'Search characters...',
                  onChanged: (q) {
                    library.setQuery(q);
                    setState(() {});
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            StudioFilterChip(
                              label: 'All',
                              selected: library.filter == LibraryFilter.all,
                              onTap: () => library.setFilter(LibraryFilter.all),
                            ),
                            const SizedBox(width: 8),
                            StudioFilterChip(
                              label: 'Recent',
                              icon: Icons.history_rounded,
                              selected: library.filter == LibraryFilter.recent,
                              onTap: () => library.setFilter(LibraryFilter.recent),
                            ),
                            const SizedBox(width: 8),
                            StudioFilterChip(
                              label: 'Favorites',
                              icon: Icons.favorite_rounded,
                              selected: library.filter == LibraryFilter.favorites,
                              onTap: () =>
                                  library.setFilter(LibraryFilter.favorites),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _SortButton(current: settings.sortMode),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              sliver: SliverToBoxAdapter(child: _TwoDSection(visible: grouped)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              sliver: grouped
                  ? _buildGrouped(context, library)
                  : _buildFlatGrid(context, library, visible),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Grouped view: Recently Used → Built-in → Imported
  // ---------------------------------------------------------------------
  Widget _buildGrouped(BuildContext context, LibraryProvider library) {
    if (library.loading && library.characters.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
        ),
      );
    }

    if (library.error != null && library.characters.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ErrorView(
              title: 'Library unavailable',
              message: library.error!,
              onRetry: () => library.refresh(),
            ),
          ),
        ),
      );
    }

    if (library.characters.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.view_in_ar_outlined,
          title: 'No characters yet',
          message: 'Import a GLB/GLTF file from your device to start animating.',
          actionLabel: 'Import Character',
          onAction: () => startImportFlow(context),
        ),
      );
    }

    final recents = library.recents;
    final bundled = library.bundledCharacters;
    final imported = library.importedCharacters;

    return MultiSliver(
      children: [
        if (recents.isNotEmpty) ...[
          _sectionLabel(context, 'Recently Used'),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: recents.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final recent = recents[index];
                  return _RecentMiniCard(
                    character: recent.character,
                    animationDisplay: recent.entry.animationDisplay,
                    timeLabel: Formatters.relativeTime(recent.entry.timestamp),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        if (bundled.isNotEmpty) ...[
          _sectionLabel(context, 'Built-in Characters'),
          _gridFor(bundled, showImportedDate: false),
        ],
        if (imported.isNotEmpty) ...[
          _sectionLabel(context, 'Imported Characters'),
          _gridFor(imported, showImportedDate: true),
        ],
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
              ),
        ),
      ),
    );
  }

  Widget _gridFor(List<Character> characters,
      {required bool showImportedDate}) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = width > 1050
            ? 5
            : width > 820
                ? 4
                : width > 560
                    ? 3
                    : 2;
        const spacing = 12.0;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 0.76,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final character = characters[index];
              return StaggeredEntrance(
                index: index,
                child: _cardFor(character,
                    showImportedDate: showImportedDate),
              );
            },
            childCount: characters.length,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Flat (filtered/searched) view
  // ---------------------------------------------------------------------
  Widget _buildFlatGrid(
      BuildContext context, LibraryProvider library, List<Character> visible) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        if (library.loading && library.characters.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ),
          );
        }
        if (visible.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyFor(context, library),
          );
        }
        final width = constraints.crossAxisExtent;
        final columns = width > 1050
            ? 5
            : width > 820
                ? 4
                : width > 560
                    ? 3
                    : 2;
        const spacing = 12.0;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 0.76,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final character = visible[index];
              return StaggeredEntrance(
                index: index,
                child: _cardFor(character, showImportedDate: false),
              );
            },
            childCount: visible.length,
          ),
        );
      },
    );
  }

  Widget _cardFor(Character character, {required bool showImportedDate}) {
    final library = context.read<LibraryProvider>();
    return CharacterCard(
      character: character,
      showImportedDate: showImportedDate,
      onOpen: () => _openDetail(character.id),
      onFavoriteToggle: () => library.toggleFavorite(character),
      onRename: () => _rename(character),
      onDelete: () => _delete(character),
      onShare: () => _share(character),
      onDuplicate: () => _duplicate(character),
      onDetails: () => _openDetail(character.id),
    );
  }

  Widget _emptyFor(BuildContext context, LibraryProvider library) {
    final query = library.query.trim();
    if (query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message:
            'Nothing matches "$query" — try a different name, file or animation '
            '(e.g. "walk").',
        actionLabel: 'Clear search',
        onAction: () {
          _searchController.clear();
          library.setQuery('');
        },
      );
    }
    if (library.filter == LibraryFilter.favorites) {
      return const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No favorites yet',
        message: 'Tap the heart on any character to pin it here.',
      );
    }
    if (library.filter == LibraryFilter.recent) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No recently used characters',
        message: 'Play an animation and it will appear here.',
      );
    }
    return EmptyState(
      icon: Icons.view_in_ar_outlined,
      title: 'No characters yet',
      message: 'Import a GLB file from your device to start animating.',
      actionLabel: 'Import Character',
      onAction: () => startImportFlow(context),
    );
  }

  void _openDetail(String characterId) {
    Navigator.of(context).push(
      fadeSlideRoute(CharacterDetailScreen(characterId: characterId)),
    );
  }

  Future<void> _rename(Character character) async {
    final library = context.read<LibraryProvider>();
    final controller = TextEditingController(text: character.displayName);
    final result = await showPremiumDialog<String>(
      context,
      PremiumDialog(
        title: 'Rename Character',
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
      await library.rename(character, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed to "${result.trim()}"')),
        );
      }
    }
  }

  Future<void> _delete(Character character) async {
    final library = context.read<LibraryProvider>();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${character.displayName} deleted')),
        );
      }
    }
  }

  Future<void> _duplicate(Character character) async {
    final library = context.read<LibraryProvider>();
    try {
      await library.duplicate(character);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${character.displayName} duplicated as a new character')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The character could not be duplicated.')),
        );
      }
    }
  }

  Future<void> _share(Character character) async {
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
}

// ======================================================================
// Recently-used mini card (Library top section)
// ======================================================================
class _RecentMiniCard extends StatelessWidget {
  const _RecentMiniCard({
    required this.character,
    required this.animationDisplay,
    required this.timeLabel,
  });

  final Character character;
  final String animationDisplay;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final library = context.read<LibraryProvider>();
    return GlassCard(
      onTap: () {
        Navigator.of(context).push(
          fadeSlideRoute(PlayerScreen(
            characterId: character.id,
            initialAnimationName: library.lastUsageOf(character.id)?.animationName,
          )),
        );
      },
      padding: const EdgeInsets.all(8),
      borderRadius: 18,
      blur: 8,
      shadow: false,
      child: SizedBox(
        width: 218,
        child: Row(
          children: [
            CharacterAvatar(character: character, size: 62, borderRadius: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    character.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.animation_rounded,
                          size: 11,
                          color: isDark
                              ? AppColors.accentAlt
                              : AppColors.lightAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          animationDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.accentAlt
                                : AppColors.lightAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textMuted
                          : const Color(0xFF8B94A6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current});

  final StudioSortMode current;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    return Semantics(
      label: 'Sort characters',
      button: true,
      child: PopupMenuButton<StudioSortMode>(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.stroke),
          ),
          child: const Icon(Icons.sort_rounded,
              size: 18, color: AppColors.textSecondary),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (mode) => settings.setSortMode(mode),
        itemBuilder: (context) => [
          for (final mode in StudioSortMode.values)
            PopupMenuItem(
              value: mode,
              child: Row(
                children: [
                  if (mode == current)
                    const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.accent)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(mode.label),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Lightweight multi-sliver so grouped sections can live in one sliver context.
class MultiSliver extends StatelessWidget {
  const MultiSliver({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(slivers: children.cast());
  }
}

/// §20 Character Library section for the original 2D cartoon characters:
/// thumbnail, name, category, rig/animation/face/talking status and
/// Preview / Use / Favorite actions, plus saved customization variants.
class _TwoDSection extends StatelessWidget {
  const _TwoDSection({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final library2d = context.watch<Library2DProvider>();
    final characters = library2d.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.animation_rounded, color: AppColors.accentAlt, size: 20),
            const SizedBox(width: 8),
            Text(
              '2D Cartoon Characters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Text(
              '${characters.length}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Rigged 2D actors with faces, talking and gestures',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 252,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: characters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = characters[i];
              return _TwoDCard(character: c, library2d: library2d);
            },
          ),
        ),
      ],
    );
  }
}

class _TwoDCard extends StatelessWidget {
  const _TwoDCard({required this.character, required this.library2d});

  final Character2D character;
  final Library2DProvider library2d;

  @override
  Widget build(BuildContext context) {
    final fav = library2d.isFavorite(character.id);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 232,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail (auto-generated from the vector rig).
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: PuppetThumbnail(
                        spec: character.spec,
                        palette: character.colors,
                        accessories: character.accessories,
                        background: const Color(0xFF1B2130),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.glassOverlay,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Text(
                        character.isVariant ? 'Variant · ${character.spec.category}' : character.spec.category,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      tooltip: 'Favorite',
                      icon: Icon(
                        fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: fav ? AppColors.favorite : AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () => library2d.toggleFavorite(character.id),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rig: Ready   Animations: 6 Core\nFace: Ready   Talking: Ready',
                    style: TextStyle(color: AppColors.success, fontSize: 11, height: 1.45, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: PremiumButton(
                          label: 'Preview',
                          small: true,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Character2DPreviewScreen(characterId: character.id),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PremiumButton(
                          label: 'Use',
                          small: true,
                          style: PremiumButtonStyle.primary,
                          onPressed: () {
                            library2d.recordUsage(character.id);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PlayerScreen(characterId: '', character2dId: character.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
