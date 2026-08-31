import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' as sharing;

import '../../core/theme/app_colors.dart';
import '../../state/library_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/character_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/filter_chip.dart';
import 'character_detail_screen.dart';
import 'import_flow.dart';

/// Character library: search, filters, sorting and a responsive grid.
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
                      label: 'Import GLB',
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
                    // Refresh suffix icon visibility.
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  // Responsive grid: ~2 columns on phones, more on tablets.
                  final width = constraints.crossAxisExtent;
                  final columns = width > 1050
                      ? 5
                      : width > 820
                          ? 4
                          : width > 560
                              ? 3
                              : 2;
                  const spacing = 12.0;

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

                  if (visible.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyFor(context, library),
                    );
                  }

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final character = visible[index];
                        return StaggeredEntrance(
                          index: index,
                          child: CharacterCard(
                            character: character,
                            onOpen: () => _openDetail(character.id),
                            onFavoriteToggle: () =>
                                library.toggleFavorite(character),
                            onRename: () => _rename(character),
                            onDelete: () => _delete(character),
                            onShare: () => _share(character),
                            onDetails: () => _openDetail(character.id),
                          ),
                        );
                      },
                      childCount: visible.length,
                    ),
                  );
                },
              ),
            ),
            // Bottom padding for the nav bar.
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ),
      ),
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
      actionLabel: 'Import GLB',
      onAction: () => startImportFlow(context),
    );
  }

  void _openDetail(String characterId) {
    Navigator.of(context).push(
      fadeSlideRoute(CharacterDetailScreen(characterId: characterId)),
    );
  }

  Future<void> _rename(character) async {
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
            counterText: '',
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

  Future<void> _delete(character) async {
    final library = context.read<LibraryProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Character?',
      message:
          '"${character.displayName}" will be removed from your library. '
          'This cannot be undone.',
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

  Future<void> _share(character) async {
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
