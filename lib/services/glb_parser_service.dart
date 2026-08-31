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

/// Skeleton information extracted from a glTF skin.
class GlbSkinData {
  const GlbSkinData({
    required this.name,
    required this.boneNames,
    required this.hierarchyDepth,
  });
  final String name;
  final List<String> boneNames;
  final int hierarchyDepth;
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
    this.rootNodeCount = 0,
    this.cameraCount = 0,
    this.lightCount = 0,
    this.triangleCount = 0,
    this.vertexCount = 0,
    this.hasSkeleton = false,
    this.totalBoneCount = 0,
    this.skins = const [],
    this.boneNames = const [],
  });

  final List<GlbAnimationData> animations;
  final int nodeCount;
  final int meshCount;
  final int materialCount;
  final int textureCount;
  final int skinCount;
  final String? generator;

  // ---- scene facts (validation) ----
  final int rootNodeCount;
  final int cameraCount;
  final int lightCount; // KHR_lights_punctual
  final int triangleCount;
  final int vertexCount;

  // ---- character/rig facts ----
  final bool hasSkeleton;
  final int totalBoneCount;
  final List<GlbSkinData> skins;
  final List<String> boneNames; // flat, capped list for mapping UIs
}

/// Pure-Dart GLB (binary glTF 2.0) container parser.
///
/// The GLB layout is:
///   [ magic "glTF" | version | totalLength ]        12 bytes header
///   [ chunkLength | chunkType | chunkData ] ...     chunks
///
/// The first JSON chunk fully describes the scene graph — animations, skins
/// (skeletons), meshes, materials and node hierarchy — so the whole
/// validation/rig/animation report can be produced for ANY valid GLB,
/// offline, before the model is ever rendered.
class GlbParserService {
  static const int _glbMagic = 0x46546C67; // "glTF"
  static const int _jsonChunkType = 0x4E4F534A; // "JSON"

  static const int maxBonesReported = 240;
  static const int hardFailTriangles = 4000000;
  static const int warnTriangles = 1500000;

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
          'This is not a GLB model. Please choose a valid .glb or .gltf file.');
    }
    final version = bd.getUint32(4, Endian.little);
    if (version != 2) {
      throw GlbParseException('Unsupported glTF container version ($version). '
          'Only glTF 2.0 (.glb/.gltf) is supported.');
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
        throw const GlbParseException(
            'This GLB file is corrupted (invalid chunk data).');
      }
      if (chunkType == _jsonChunkType) {
        jsonChunk = Uint8List.sublistView(bytes, offset, offset + chunkLength);
        break;
      }
      offset += chunkLength;
    }
    if (jsonChunk == null) {
      throw const GlbParseException(
          'This GLB file is missing its model description.');
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
    final skinsRaw = (doc['skins'] as List?) ?? const [];
    final accessors = (doc['accessors'] as List?) ?? const [];
    final cameras = (doc['cameras'] as List?) ?? const [];
    final animationsRaw = (doc['animations'] as List?) ?? const [];

    if (nodes.isEmpty && meshes.isEmpty) {
      throw const GlbParseException(
          'No 3D geometry was found in this file — it is not a usable character.');
    }
    if (meshes.isEmpty) {
      throw const GlbParseException(
          'No mesh was found in this model. A character needs at least one mesh.');
    }

    // ---- animations (names + durations) ---------------------------------
    final animations = <GlbAnimationData>[];
    for (var i = 0; i < animationsRaw.length; i++) {
      final anim = animationsRaw[i] as Map<String, dynamic>;
      final rawName = (anim['name'] as String?)?.trim() ?? '';
      final name = rawName.isNotEmpty ? rawName : 'Animation ${i + 1}';
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
      animations.add(GlbAnimationData(
        name: name,
        durationSeconds: duration == null || duration <= 0 ? null : duration,
      ));
    }

    // ---- polygon / vertex budget ----------------------------------------
    var triangles = 0;
    var vertices = 0;
    for (final m in meshes) {
      if (m is! Map) continue;
      final primitives = (m['primitives'] as List?) ?? const [];
      for (final p in primitives) {
        if (p is! Map) continue;
        final indicesRef = p['indices'];
        if (indicesRef is int && indicesRef >= 0 && indicesRef < accessors.length) {
          final acc = accessors[indicesRef];
          final count = acc is Map ? (acc['count'] as num?)?.toInt() ?? 0 : 0;
          triangles += count ~/ 3;
        } else {
          final attrs = p['attributes'];
          if (attrs is Map) {
            final posRef = attrs['POSITION'];
            if (posRef is int && posRef >= 0 && posRef < accessors.length) {
              final acc = accessors[posRef];
              final count = acc is Map ? (acc['count'] as num?)?.toInt() ?? 0 : 0;
              triangles += count ~/ 3;
            }
          }
        }
        final attrs = p['attributes'];
        if (attrs is Map) {
          final posRef = attrs['POSITION'];
          if (posRef is int && posRef < accessors.length) {
            final acc = accessors[posRef];
            vertices += acc is Map ? (acc['count'] as num?)?.toInt() ?? 0 : 0;
          }
        }
      }
    }
    if (triangles > hardFailTriangles) {
      throw GlbParseException('This model is too heavy '
          '(${(triangles / 1000000).toStringAsFixed(1)}M triangles). '
          'Please reduce the polygon count below 4M triangles.');
    }

    // ---- scene graph / roots / lights ------------------------------------
    final scenes = (doc['scenes'] as List?) ?? const [];
    final defaultScene = (doc['scene'] as num?)?.toInt() ?? 0;
    var rootNodeCount = 0;
    if (scenes.isNotEmpty && defaultScene >= 0 && defaultScene < scenes.length) {
      final scene = scenes[defaultScene];
      rootNodeCount = scene is Map ? ((scene['nodes'] as List?) ?? const []).length : 0;
    }

    var lightCount = 0;
    final ext = doc['extensions'];
    if (ext is Map) {
      final lightsExt = ext['KHR_lights_punctual'];
      if (lightsExt is Map) {
        lightCount = (lightsExt['lights'] as List?)?.length ?? 0;
      }
    }

    // ---- skins → skeleton / bones / hierarchy -----------------------------
    final nodeNames = <String>[
      for (var i = 0; i < nodes.length; i++)
        ((nodes[i] as Map)['name'] as String?)?.trim().isNotEmpty == true
            ? ((nodes[i] as Map)['name'] as String)
            : 'node_$i'
    ];

    final skins = <GlbSkinData>[];
    final allBones = <String>[];
    for (final s in skinsRaw) {
      if (s is! Map) continue;
      final joints = (s['joints'] as List?) ?? const [];
      final boneNames = <String>[];
      final jointSet = <int>{};
      for (final j in joints) {
        if (j is! int || j < 0 || j >= nodes.length) continue;
        jointSet.add(j);
        boneNames.add(nodeNames[j]);
      }
      if (boneNames.isNotEmpty) {
        allBones.addAll(boneNames.take(maxBonesReported));
      }
      skins.add(GlbSkinData(
        name: (s['name'] as String?)?.isNotEmpty == true
            ? s['name'] as String
            : 'Skeleton ${skins.length + 1}',
        boneNames: boneNames,
        hierarchyDepth: _hierarchyDepth(nodes, jointSet),
      ));
    }

    final asset = doc['asset'];
    final generator = asset is Map ? asset['generator'] as String? : null;

    return GlbModelData(
      animations: animations,
      nodeCount: nodes.length,
      meshCount: meshes.length,
      materialCount: materials.length,
      textureCount: images.length,
      skinCount: skinsRaw.length,
      generator: (generator == null || generator.isEmpty) ? null : generator,
      rootNodeCount: rootNodeCount,
      cameraCount: cameras.length,
      lightCount: lightCount,
      triangleCount: triangles,
      vertexCount: vertices,
      hasSkeleton: skins.isNotEmpty && skins.any((s) => s.boneNames.isNotEmpty),
      totalBoneCount: allBones.length <= maxBonesReported
          ? skins.fold<int>(0, (sum, s) => sum + s.boneNames.length)
          : maxBonesReported,
      skins: skins,
      boneNames: allBones.take(maxBonesReported).toList(),
    );
  }

  /// Deepest chain of joints inside a skin (bone hierarchy depth).
  static int _hierarchyDepth(List<dynamic> nodes, Set<int> jointSet) {
    if (jointSet.isEmpty) return 0;
    // Build child → parent map for joint nodes only.
    final parent = <int, int>{};
    for (var i = 0; i < nodes.length; i++) {
      if (!jointSet.contains(i)) continue;
      final node = nodes[i];
      if (node is! Map) continue;
      final children = node['children'];
      if (children is! List) continue;
      for (final c in children) {
        if (c is int && jointSet.contains(c)) parent[c] = i;
      }
    }
    int depthOf(int n) {
      var depth = 1;
      var current = n;
      while (parent.containsKey(current)) {
        current = parent[current]!;
        depth++;
        if (depth > 256) break; // cycle guard
      }
      return depth;
    }

    var max = 0;
    for (final j in jointSet) {
      final d = depthOf(j);
      if (d > max) max = d;
    }
    return max;
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
