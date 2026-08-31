import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/character.dart';
import '../../state/library_provider.dart';
import '../../state/shell_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/thumbnail.dart';
import '../actions/action_select_screen.dart';
import '../characters/character_detail_screen.dart';
import '../characters/import_flow.dart';
import '../characters2d/character2d_preview_screen.dart';
import '../player/player_screen.dart';

/// Premium dashboard: hero, featured character, stats, recents, favorites
/// and quick actions. All values are computed from the live library.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final shell = context.read<ShellProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          bottom: false,
          child: library.loading && library.characters.isEmpty
              ? const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  onRefresh: () => library.refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _Header(library: library),
                      _HeroSection(),
                      const SizedBox(height: 8),
                      _StatsRow(),
                      _FeaturedCard(),
                      _RecentSection(),
                      _FavoritesSection(),
                      _QuickActions(onNavigate: (i) => shell.go(i)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.library});

  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.view_in_ar_rounded,
                color: Color(0xFF0A0C11), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Character Studio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Create. Animate. Preview.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Import GLB',
            semanticLabel: 'Import GLB character',
            onPressed: () => startImportFlow(context),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(22),
        blur: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bring Your Characters\nTo Life.',
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(height: 1.08),
            ),
            const SizedBox(height: 10),
            Text(
              'Animate your 3D characters directly on your device — '
              '${library.characterCount} ${library.characterCount == 1 ? 'character' : 'characters'} '
              'and ${library.animationCount} animations ready.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 18),
            PremiumButton(
              label: 'Start Creating',
              onPressed: () {
                final featured = library.featured;
                if (featured == null) {
                  context.read<ShellProvider>().go(1); // Characters tab
                  return;
                }
                Navigator.of(context).push(
                  fadeSlideRoute(
                    CharacterDetailScreen(characterId: featured.id),
                  ),
                );
              },
              icon: Icons.play_arrow_rounded,
              style: PremiumButtonStyle.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Characters',
                  value: '${library.characterCount}',
                  icon: Icons.view_in_ar_rounded,
                  onTap: () => context.read<ShellProvider>().go(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Favorites',
                  value: '${library.favoriteCount}',
                  icon: Icons.favorite_rounded,
                  onTap: () => context.read<ShellProvider>().go(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Recent',
                  value: '${library.recentCount}',
                  icon: Icons.history_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Animations',
                  value: '${library.animationCount}',
                  icon: Icons.animation_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final featured = library.featured;

    if (featured == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Featured Character',
          actionLabel: 'Characters',
          onAction: () => context.read<ShellProvider>().go(1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StaggeredEntrance(
            index: 0,
            child: GlassCard(
              onTap: () => Navigator.of(context).push(
                fadeSlideRoute(
                    CharacterDetailScreen(characterId: featured.id)),
              ),
              padding: EdgeInsets.zero,
              blur: 12,
              child: Row(
                children: [
                  CharacterAvatar(character: featured, size: 112, borderRadius: 0),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  featured.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              FavoriteHeart(
                                favorite: featured.isFavorite,
                                onToggle: () => library.toggleFavorite(featured),
                                size: 19,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${featured.animationCount} '
                            '${featured.animationCount == 1 ? 'animation' : 'animations'} · '
                            '${Formatters.fileSize(featured.fileSizeBytes)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          PremiumButton(
                            label: 'Animate',
                            icon: Icons.play_arrow_rounded,
                            small: true,
                            onPressed: () {
                              Navigator.of(context).push(
                                fadeSlideRoute(ActionSelectScreen(
                                  characterId: featured.id,
                                )),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final recents = library.recents;

    if (recents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Recently Used'),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final recent = recents[index];
              final character = recent.character;
              return StaggeredEntrance(
                index: index,
                child: _RecentTile(
                  character: character,
                  animationDisplay: recent.entry.animationDisplay,
                  animationName: recent.entry.animationName,
                  timeLabel: Formatters.relativeTime(recent.entry.timestamp),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.character,
    required this.animationDisplay,
    required this.animationName,
    required this.timeLabel,
  });

  final Character character;
  final String animationDisplay;
  final String animationName;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Quick play: open the player immediately with character + animation.
    return GlassCard(
      onTap: () {
        Navigator.of(context).push(
          fadeSlideRoute(
            PlayerScreen(
              characterId: character.id,
              initialAnimationName: animationName,
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(10),
      borderRadius: 18,
      blur: 8,
      shadow: false,
      child: SizedBox(
        width: 208,
        child: Row(
          children: [
            CharacterAvatar(character: character, size: 64, borderRadius: 14),
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
                        fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.animation_rounded,
                          size: 12,
                          color: isDark ? AppColors.accentAlt : AppColors.lightAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          animationDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.accentAlt : AppColors.lightAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMuted : const Color(0xFF8B94A6),
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

class _FavoritesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final favorites = library.favorites;

    if (favorites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Favorites',
          actionLabel: 'View all',
          onAction: () => context.read<ShellProvider>().go(3),
        ),
        ...List.generate(favorites.take(3).length, (index) {
          final character = favorites[index];
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: index == 2 || index == favorites.take(3).length - 1 ? 0 : 10,
            ),
            child: StaggeredEntrance(
              index: index,
              child: _FavoriteRow(character: character),
            ),
          );
        }),
      ],
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return GlassCard(
      onTap: () => Navigator.of(context).push(
        fadeSlideRoute(CharacterDetailScreen(characterId: character.id)),
      ),
      padding: const EdgeInsets.all(10),
      borderRadius: 18,
      blur: 8,
      shadow: false,
      child: Row(
        children: [
          CharacterAvatar(character: character, size: 54, borderRadius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
                const SizedBox(height: 2),
                Text(
                  '${character.animationCount} '
                  '${character.animationCount == 1 ? 'Animation' : 'Animations'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Quick play button.
          Semantics(
            label: 'Play ${character.displayName}',
            button: true,
            child: GestureDetector(
              onTap: () {
                final lastAnim =
                    library.lastUsageOf(character.id)?.animationName;
                final anim = lastAnim ??
                    (character.animations.isNotEmpty
                        ? character.animations.first.name
                        : null);
                Navigator.of(context).push(
                  fadeSlideRoute(PlayerScreen(
                    characterId: character.id,
                    initialAnimationName: anim,
                  )),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFF0A0C11), size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Quick Actions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.add_rounded,
                  label: 'Import GLB',
                  onTap: () => startImportFlow(context),
                  accent: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.view_in_ar_rounded,
                  label: 'Characters',
                  onTap: () => onNavigate(1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.animation_rounded,
                  label: 'Animations',
                  onTap: () => _openAnimationsSheet(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () => onNavigate(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.face_rounded,
                  label: '2D Cartoon Studio',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Character2DPreviewScreen(characterId: 'bd_farmer_male'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ],
    );
  }

  void _openAnimationsSheet(BuildContext context) {
    final library = context.read<LibraryProvider>();
    final animations = library.allAnimations;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('All Animations',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  '${animations.length} distinct actions detected across your library',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              Flexible(
                child: animations.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No animations detected yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView(shrinkWrap: true, 
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          for (final summary in animations)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.accentSoft,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(summary.icon,
                                    size: 19, color: AppColors.accent),
                              ),
                              title: Text(summary.display,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14)),
                              subtitle: Text(
                                summary.characterIds.length == 1
                                    ? '1 character'
                                    : '${summary.characterIds.length} characters',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  size: 20, color: AppColors.textMuted),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                _openCharactersFor(context, library,
                                    summary.display, summary.characterIds.toList());
                              },
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCharactersFor(BuildContext context, LibraryProvider library,
      String display, List<String> characterIds) {
    final characters = library.characters
        .where((c) => characterIds.contains(c.id))
        .toList();

    if (characters.isEmpty) return;

    if (characters.length == 1) {
      final character = characters.first;
      final clip = character.animations
          .where((a) => a.displayName == display)
          .firstOrNull;
      Navigator.of(context).push(
        fadeSlideRoute(PlayerScreen(
          characterId: character.id,
          initialAnimationName: clip?.name,
        )),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text('"$display" — pick a character',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, 
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    for (final character in characters)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: CharacterAvatar(
                            character: character, size: 42, borderRadius: 12),
                        title: Text(character.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        trailing: const Icon(Icons.play_arrow_rounded,
                            color: AppColors.accent),
                        onTap: () {
                          final clip = character.animations
                              .where((a) => a.displayName == display)
                              .firstOrNull;
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            fadeSlideRoute(PlayerScreen(
                              characterId: character.id,
                              initialAnimationName: clip?.name,
                            )),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      borderRadius: 18,
      blur: 8,
      shadow: false,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: accent ? AppColors.primaryGradient : null,
              color: accent ? null : AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 21,
                color: accent ? const Color(0xFF0A0C11) : AppColors.accent),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.1),
          ),
        ],
      ),
    );
  }
}
