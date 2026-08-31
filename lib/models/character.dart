import 'dart:io';

import 'animation_clip.dart';

enum CharacterSource { bundled, imported }

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

  /// URL path served by the on-device loopback server.
  String get serverModelPath => '/models/${Uri.encodeComponent(fileName)}';
}

/// Directory scanning helper used by [CharacterService].
class ScannedFile {
  ScannedFile({required this.file, required this.isBundled});
  final File file;
  final bool isBundled;
}
