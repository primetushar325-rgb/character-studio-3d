import 'package:flutter/material.dart';

import '../core/utils/animation_names.dart';

/// A single animation clip detected inside a GLB file.
///
/// [name] is the *original* clip identifier used to address the clip inside
/// the model; [displayName]/[normalizedName] are user-facing values.
class AnimationClip {
  const AnimationClip({
    required this.name,
    required this.displayName,
    required this.normalizedName,
    required this.knownAction,
    this.durationSeconds,
    this.loopable = true,
  });

  factory AnimationClip.fromGlbName(
    String rawName, {
    double? duration,
    int fallbackIndex = 1,
  }) {
    final n = AnimationNames.normalize(rawName, fallbackIndex: fallbackIndex);
    return AnimationClip(
      name: rawName,
      displayName: n.display,
      normalizedName: n.canonical,
      knownAction: n.known,
      durationSeconds: duration,
    );
  }

  final String name;
  final String displayName;
  final String normalizedName;
  final bool knownAction;
  final double? durationSeconds;
  final bool loopable;

  Map<String, dynamic> toJson() => {
        'name': name,
        'display': displayName,
        'normalized': normalizedName,
        'duration': durationSeconds,
      };

  static AnimationClip fromJson(Map<String, dynamic> json) => AnimationClip(
        name: json['name'] as String? ?? '',
        displayName: json['display'] as String? ?? json['name'] as String? ?? '',
        normalizedName: json['normalized'] as String? ?? '',
        knownAction: false,
        durationSeconds: (json['duration'] as num?)?.toDouble(),
      );
}

/// Icon mapping for animation actions (generic — keyed by canonical name,
/// never by character).
IconData animationIconFor(String canonicalOrDisplay) {
  final key = canonicalOrDisplay.toLowerCase();
  switch (key) {
    case 'idle':
      return Icons.person_outline_rounded;
    case 'walk':
      return Icons.directions_walk_rounded;
    case 'run':
      return Icons.directions_run_rounded;
    case 'jump':
      return Icons.north_rounded;
    case 'stand':
      return Icons.accessibility_new_rounded;
    case 'sit':
      return Icons.chair_alt_rounded;
    case 'sleep':
      return Icons.bedtime_rounded;
    case 'talk':
      return Icons.chat_bubble_outline_rounded;
    case 'dance':
      return Icons.music_note_rounded;
    case 'attack':
      return Icons.sports_mma_rounded;
    case 'wave':
      return Icons.waving_hand_rounded;
    case 'cry':
      return Icons.water_drop_rounded;
    case 'laugh':
      return Icons.sentiment_very_satisfied_rounded;
    case 'fight':
      return Icons.sports_kabaddi_rounded;
    case 'fall':
      return Icons.south_rounded;
    case 'clap':
      return Icons.back_hand_rounded;
    case 'punch':
      return Icons.sports_martial_arts_rounded;
    case 'kick':
      return Icons.sports_soccer_rounded;
    case 'shout':
      return Icons.campaign_rounded;
    case 'die':
    case 'death':
      return Icons.heart_broken_rounded;
    case 'fly':
      return Icons.flight_rounded;
    case 'swim':
      return Icons.pool_rounded;
    case 'crawl':
      return Icons.baby_changing_station_rounded;
    case 'crouch':
      return Icons.downhill_skiing_rounded;
    case 'climb':
      return Icons.stairs_rounded;
    case 'push':
      return Icons.front_hand_rounded;
    case 'pull':
      return Icons.pan_tool_alt_rounded;
    case 'throw':
      return Icons.sports_baseball_rounded;
    case 'eat':
      return Icons.restaurant_rounded;
    case 'victory':
      return Icons.emoji_events_rounded;
    case 'hurt':
      return Icons.healing_rounded;
    case 'spawn':
      return Icons.auto_awesome_rounded;
    case 'block':
      return Icons.shield_rounded;
    case 'roll':
      return Icons.rotate_right_rounded;
    case 'survey':
      return Icons.visibility_rounded;
    default:
      return Icons.animation_rounded;
  }
}
