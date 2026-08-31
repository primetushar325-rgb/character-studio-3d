import 'package:flutter/material.dart';

import '../models/animation_clip.dart';
import '../models/character.dart';

/// The "AnimationRepository" of the architecture: turns raw parsed GLB
/// animation data into friendly, generic action information. It contains
/// zero character-specific logic — everything is keyed by clip names.
class AnimationService {
  const AnimationService();

  /// Friendly label for a raw clip name (used in recents/projects).
  String displayFor(String rawName) {
    final n = AnimationClip.fromGlbName(rawName);
    return n.displayName;
  }

  /// All distinct animation actions across the library, sorted by how many
  /// characters provide them (used by Home → "Animations").
  List<AnimationSummary> distinctAcrossLibrary(List<Character> characters) {
    final map = <String, AnimationSummary>{};
    for (final c in characters) {
      for (final clip in c.animations) {
        final existing = map[clip.displayName];
        if (existing == null) {
          map[clip.displayName] = AnimationSummary(
            display: clip.displayName,
            canonicalNames: {clip.normalizedName},
            characterIds: {c.id},
            icon: animationIconFor(clip.normalizedName),
          );
        } else {
          existing.characterIds.add(c.id);
          existing.canonicalNames.add(clip.normalizedName);
        }
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.characterIds.length.compareTo(a.characterIds.length));
    return list;
  }

  /// Characters that provide a given animation (matched on friendly display
  /// name or canonical key) — powers animation-first navigation.
  List<Character> charactersWith(List<Character> characters, String displayOrCanonical) {
    final needle = displayOrCanonical.toLowerCase();
    return characters.where((c) {
      return c.animations.any((clip) =>
          clip.displayName.toLowerCase() == needle ||
          clip.normalizedName == needle ||
          clip.name.toLowerCase() == needle);
    }).toList();
  }
}

class AnimationSummary {
  AnimationSummary({
    required this.display,
    required this.canonicalNames,
    required this.characterIds,
    required this.icon,
  });

  final String display;
  final Set<String> canonicalNames;
  final Set<String> characterIds;
  final IconData icon;
}
