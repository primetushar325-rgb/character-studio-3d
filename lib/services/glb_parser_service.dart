import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

/// Thrown with a *user-friendly* message when a GLB cannot be parsed.
class GlbParseException implements Exception {
  const GlbParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Raw animation data extracted straight from the GLB JSON chunk.
class GlbAnimationData {
  const GlbAnimationData({required this.name, this.durationSeconds});
  final String name;
  final double? durationSeconds;
}

/// Facts extracted from a GLB file without loading it into a renderer.
class GlbModelData {
  const GlbModelData({
    required this.animations,
    required this.nodeCount,
    required this.meshCount,
    required this.materialCount,
    required this.textureCount,
    required this.skinCount,
    required this.generator,
  });

  final List<GlbAnimationData> animations;
  final int nodeCount;
  final int meshCount;
  final int materialCount;
  final int textureCount;
  final int skinCount;
  final String? generator;
}

/// Pure-Dart GLB (binary glTF 2.0) container parser.
///
/// The GLB layout is:
///   [ magic "glTF" | version | totalLength ]        12 bytes header
///   [ chunkLength | chunkType | chunkData ] ...     chunks
///
/// The first JSON chunk fully describes the scene graph, including the
/// `animations` array — so animation names can be detected for ANY valid
/// GLB, offline, before the model is ever rendered. This is the app's
/// primary animation-detection layer (the viewer verifies it afterwards).
class GlbParserService {
  static const int _glbMagic = 0x46546C67; // "glTF"
  static const int _jsonChunkType = 0x4E4F534A; // "JSON"

  /// Parse a GLB file. Runs in a background isolate for large files.
  Future<GlbModelData> parseFile(String path) async {
    try {
      return await compute(_parseFileSync, path);
    } catch (e) {
      if (e is GlbParseException) rethrow;
      throw GlbParseException(_friendly(e));
    }
  }

  /// Parse from bytes already in memory (used by the import pipeline).
  GlbModelData parseBytes(Uint8List bytes) => parseBytesSync(bytes);

  // ---------------------------------------------------------------------
  // Synchronous implementation (also the isolate entry point).
  // ---------------------------------------------------------------------

  static Future<GlbModelData> _parseFileSync(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const GlbParseException('The character file is missing from storage.');
    }
    final bytes = await file.readAsBytes();
    return parseBytesSync(bytes);
  }

  static GlbModelData parseBytesSync(Uint8List bytes) {
    if (bytes.length < 20) {
      throw const GlbParseException(
          'This file is too small to be a 3D character. Expected a GLB model.');
    }
    final bd = ByteData.sublistView(bytes);

    final magic = bd.getUint32(0, Endian.little);
    if (magic != _glbMagic) {
      throw const GlbParseException(
          'This is not a GLB model. Please choose a .glb file exported with embedded textures.');
    }
    final version = bd.getUint32(4, Endian.little);
    if (version != 2) {
      throw GlbParseException('Unsupported glTF container version ($version). '
          'Only glTF 2.0 binary (.glb) is supported.');
    }
    final total = bd.getUint32(8, Endian.little);
    if (total > bytes.length) {
      throw const GlbParseException(
          'This GLB file appears to be truncated or corrupted.');
    }

    // Walk chunks until the JSON chunk is found.
    var offset = 12;
    Uint8List? jsonChunk;
    while (offset + 8 <= bytes.length) {
      final chunkLength = bd.getUint32(offset, Endian.little);
      final chunkType = bd.getUint32(offset + 4, Endian.little);
      offset += 8;
      if (chunkLength < 0 || offset + chunkLength > bytes.length) {
        throw const GlbParseException('This GLB file is corrupted (invalid chunk data).');
      }
      if (chunkType == _jsonChunkType) {
        jsonChunk = Uint8List.sublistView(bytes, offset, offset + chunkLength);
        break;
      }
      offset += chunkLength;
    }
    if (jsonChunk == null) {
      throw const GlbParseException('This GLB file is missing its model description.');
    }

    Map<String, dynamic> doc;
    try {
      doc = jsonDecode(utf8.decode(jsonChunk)) as Map<String, dynamic>;
    } catch (_) {
      throw const GlbParseException(
          'The model description inside this GLB is invalid or corrupted.');
    }

    final nodes = (doc['nodes'] as List?) ?? const [];
    final meshes = (doc['meshes'] as List?) ?? const [];
    final materials = (doc['materials'] as List?) ?? const [];
    final images = (doc['images'] as List?) ?? const [];
    final skins = (doc['skins'] as List?) ?? const [];

    if (nodes.isEmpty && meshes.isEmpty) {
      throw const GlbParseException('No 3D geometry was found in this file.');
    }

    final accessors = (doc['accessors'] as List?) ?? const [];
    final animationsRaw = (doc['animations'] as List?) ?? const [];
    final animations = <GlbAnimationData>[];

    for (var i = 0; i < animationsRaw.length; i++) {
      final anim = animationsRaw[i] as Map<String, dynamic>;
      final rawName = (anim['name'] as String?)?.trim() ?? '';
      final name = rawName.isNotEmpty ? rawName : 'Animation ${i + 1}';

      // Duration = max "max" of input accessors across all samplers.
      double? duration;
      final samplers = (anim['samplers'] as List?) ?? const [];
      for (final s in samplers) {
        if (s is! Map) continue;
        final inputIndex = s['input'];
        if (inputIndex is! int || inputIndex < 0 || inputIndex >= accessors.length) {
          continue;
        }
        final accessor = accessors[inputIndex];
        if (accessor is! Map) continue;
        final max = accessor['max'];
        if (max is List && max.isNotEmpty) {
          final value = (max.last as num?)?.toDouble();
          if (value != null && value > 0) {
            duration = duration == null ? value : (value > duration ? value : duration);
          }
        }
      }

      animations.add(
        GlbAnimationData(
          name: name,
          durationSeconds: duration == null || duration <= 0 ? null : duration,
        ),
      );
    }

    final asset = doc['asset'];
    final generator = asset is Map ? asset['generator'] as String? : null;

    return GlbModelData(
      animations: animations,
      nodeCount: nodes.length,
      meshCount: meshes.length,
      materialCount: materials.length,
      textureCount: images.length,
      skinCount: skins.length,
      generator: (generator == null || generator.isEmpty) ? null : generator,
    );
  }

  static String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('FileSystemException')) {
      return 'The character file could not be read from storage.';
    }
    if (error is GlbParseException) return error.message;
    return 'This character could not be loaded. The file may be corrupted.';
  }
}
