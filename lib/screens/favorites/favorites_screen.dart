import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/library_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/thumbnail.dart';
import '../characters/character_detail_screen.dart';
import '../player/player_screen.dart';

/// Favorites screen — favorite characters with quick play.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final favorites = library.favorites;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Favorite Characters',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(
                    favorites.isEmpty
                        ? 'Pin your go-to characters here'
                        : '${favorites.length} pinned · tap play to animate instantly',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (favorites.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'No favorite characters yet.',
                  message:
                      'Tap the heart on any character card to pin it here for quick access.',
                ),
              )
            else
              ...List.generate(favorites.length, (index) {
                final character = favorites[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20,
                      index == favorites.length - 1 ? 0 : 0),
                  child: StaggeredEntrance(
                    index: index,
                    child: _FavoriteCard(characterId: character.id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final character = library.byId(characterId);
    if (character == null) return const SizedBox.shrink();

    return GlassCard(
      onTap: () => Navigator.of(context).push(
        fadeSlideRoute(CharacterDetailScreen(characterId: character.id)),
      ),
      padding: const EdgeInsets.all(10),
      borderRadius: 20,
      blur: 8,
      shadow: false,
      child: Row(
        children: [
          CharacterAvatar(character: character, size: 64, borderRadius: 15),
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
                      fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
                const SizedBox(height: 3),
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
            size: 19,
          ),
          const SizedBox(width: 4),
          // Quick play.
          Semantics(
            label: 'Play ${character.displayName}',
            button: true,
            child: GestureDetector(
              onTap: () {
                final last = library.lastUsageOf(character.id)?.animationName;
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
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFF0A0C11), size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
