import 'dart:io';

import 'animation_clip.dart';

enum CharacterSource { bundled, imported }

/// Overall validation state shown as a badge on cards.
enum CharacterReadiness { ready, partial, invalid }

/// A character discovered by scanning the app's character directory.
///
/// Entirely generic: every character — bundled sample or user import — is
/// described by the same structure. No character-specific code exists
/// anywhere in the app.
class Character {
  Character({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.displayName,
    required this.fileSizeBytes,
    required this.animations,
    required this.source,
    required this.createdAt,
    this.thumbnailPath,
    this.isFavorite = false,
    this.lastUsedAt,
    this.useCount = 0,
    this.generator,
    this.nodeCount = 0,
    this.meshCount = 0,
    this.materialCount = 0,
    this.textureCount = 0,
    this.skinCount = 0,
    // ---- v1.1 rig/validation/mapping fields ----
    this.charId,
    this.originalFileName,
    this.hasSkeleton = false,
    this.boneCount = 0,
    this.triangleCount = 0,
    this.readiness = CharacterReadiness.partial,
    this.animationMapping = const {},
    this.boneMapping = const {},
    this.humanoidDetected = false,
    this.updatedAt,
    this.isPending = false,
  });

  /// Unique id — the file name inside the characters directory.
  final String id;
  final String fileName;
  final String filePath;
  final CharacterSource source;

  String displayName;
  String? thumbnailPath;
  final int fileSizeBytes;
  DateTime createdAt;

  List<AnimationClip> animations;
  bool isFavorite;
  DateTime? lastUsedAt;
  int useCount;

  // Parsed GLB facts ( informational / details screen )
  final String? generator;
  final int nodeCount;
  final int meshCount;
  final int materialCount;
  final int textureCount;
  final int skinCount;

  // ---- v1.1 ----
  /// Stable generated id, e.g. "char_172839482" (persisted in metadata).
  final String? charId;
  final String? originalFileName;
  final bool hasSkeleton;
  final int boneCount;
  final int triangleCount;
  final CharacterReadiness readiness;

  /// standard action (stand/walk/run/sit/sleep/talk) → original clip name.
  Map<String, String> animationMapping;

  /// standard bone (hips/head/…) → matched node name (manual overrides OK).
  Map<String, String> boneMapping;

  final bool humanoidDetected;
  DateTime? updatedAt;

  /// True while the character is staged in pending/ (import review),
  /// before "Save Character" is pressed. Runtime-only flag.
  final bool isPending;

  int get animationCount => animations.length;
  bool get hasAnimations => animations.isNotEmpty;

  AnimationClip? clipByName(String name) {
    for (final c in animations) {
      if (c.name == name) return c;
    }
    // Fallback: case-insensitive / normalized match.
    for (final c in animations) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c;
    }
    final norm = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final c in animations) {
      if (c.normalizedName.toLowerCase() == norm) return c;
    }
    return null;
  }

  /// The clip mapped to a standard action (or null when not mapped).
  AnimationClip? clipForAction(String action) {
    final name = animationMapping[action];
    if (name == null || name.isEmpty) return null;
    return clipByName(name);
  }

  String readinessLabel() => switch (readiness) {
        CharacterReadiness.ready => 'Ready',
        CharacterReadiness.partial => 'Partial',
        CharacterReadiness.invalid => 'Invalid',
      };

  /// URL path served by the on-device loopback server.
  String get serverModelPath => isPending
      ? '/pending/${Uri.encodeComponent(fileName)}'
      : '/models/${Uri.encodeComponent(fileName)}';
}

/// Directory scanning helper used by [CharacterService].
class ScannedFile {
  ScannedFile({required this.file, required this.isBundled});
  final File file;
  final bool isBundled;
}
