import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/library_provider.dart';
import '../../widgets/animation_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/search_bar.dart';
import '../player/player_screen.dart';

/// "Choose Animation" — shows only the animations actually detected inside
/// the selected character's GLB.
class ActionSelectScreen extends StatefulWidget {
  const ActionSelectScreen({super.key, required this.characterId});

  final String characterId;

  @override
  State<ActionSelectScreen> createState() => _ActionSelectScreenState();
}

class _ActionSelectScreenState extends State<ActionSelectScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final character = library.byId(widget.characterId);

    if (character == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose Animation')),
        body: EmptyState(
          icon: Icons.person_off_rounded,
          title: 'Character not found',
          message: 'This character is no longer in the library.',
        ),
      );
    }

    final clips = character.animations.where((clip) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return clip.displayName.toLowerCase().contains(q) ||
          clip.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Animation'),
            Text(
              '${character.displayName} · ${character.animationCount} detected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (character.animations.length > 4) ...[
            StudioSearchBar(
              hint: 'Filter animations...',
              onChanged: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: 14),
          ],
          if (clips.isEmpty)
            EmptyState(
              icon: Icons.animation_outlined,
              title: 'No animations detected',
              message: _query.isEmpty
                  ? 'This GLB contains no animation clips. You can still view the '
                      'model in 3D from the character page.'
                  : 'No animation matches "$_query".',
              compact: true,
            )
          else
            ...List.generate(clips.length, (index) {
              final clip = clips[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == clips.length - 1 ? 0 : 10),
                child: StaggeredEntrance(
                  index: index,
                  child: AnimationCard(
                    animation: clip,
                    onPlay: () {
                      library.recordUsage(character, clip.name);
                      Navigator.of(context).pushReplacement(
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
          const SizedBox(height: 18),
          Text(
            'Only clips embedded in this GLB are listed — nothing is assumed.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }
}
