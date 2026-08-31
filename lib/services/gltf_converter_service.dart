import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'glb_parser_service.dart';

/// Converts a `.gltf` file (JSON) with sibling resources (`.bin`, textures)
/// into a self-contained `.glb`, fully offline.
///
/// How it works:
///  1. Parse the .gltf JSON.
///  2. Every `buffers[].uri` and `images[].uri` that points to a local file
///     is read and inlined as a `data:` URI (base64).
///  3. The JSON is written into a GLB container (header + padded JSON chunk).
///
/// This lets Meshy/Blender/mixamo users drop a multi-file glTF export into
/// the app and still end up with a portable GLB character.
class GltfConverterService {
  static const int _glbMagic = 0x46546C67;
  static const int _jsonChunkType = 0x4E4F534A;

  Future<File> convertToGlb({
    required File gltfFile,
    required String outputFileName,
    required Directory outputDirectory,
  }) async {
    if (!await gltfFile.exists()) {
      throw const GlbParseException('The selected .gltf file is missing.');
    }

    Map<String, dynamic> doc;
    try {
      doc = jsonDecode(await gltfFile.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      throw const GlbParseException(
          'This .gltf file is not valid JSON — it may be corrupted.');
    }

    final baseDir = gltfFile.parent;

    // ---- embed buffers -------------------------------------------------
    final buffers = (doc['buffers'] as List?) ?? [];
    for (final b in buffers) {
      if (b is! Map) continue;
      final uri = b['uri'];
      if (uri is! String || uri.startsWith('data:')) continue;
      final file = _resolve(baseDir, uri);
      if (file == null || !await file.exists()) {
        throw GlbParseException(
            'This .gltf references a missing file ("$uri"). '
            'Select the .gltf together with its .bin and texture files when importing.');
      }
      final bytes = await file.readAsBytes();
      b['uri'] = 'data:application/octet-stream;base64,${base64.encode(bytes)}';
    }

    // ---- embed images ----------------------------------------------------
    final images = (doc['images'] as List?) ?? [];
    for (final img in images) {
      if (img is! Map) continue;
      final uri = img['uri'];
      if (uri is! String || uri.startsWith('data:')) continue;
      final file = _resolve(baseDir, uri);
      if (file == null || !await file.exists()) {
        throw GlbParseException(
            'This .gltf references a missing texture ("$uri"). '
            'Select the .gltf together with its textures when importing.');
      }
      final bytes = await file.readAsBytes();
      final mime = _mimeFor(file.path);
      img['uri'] = 'data:$mime;base64,${base64.encode(bytes)}';
    }

    // ---- build the GLB container -----------------------------------------
    var jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(doc)));
    final pad = (4 - (jsonBytes.length % 4)) % 4;
    if (pad > 0) {
      final padded = Uint8List(jsonBytes.length + pad);
      padded.setAll(0, jsonBytes);
      padded.fillRange(jsonBytes.length, padded.length, 0x20); // Space padding
      jsonBytes = padded;
    }

    final totalLength = 12 + 8 + jsonBytes.length;
    final out = ByteData(totalLength);
    out.setUint32(0, _glbMagic, Endian.little);
    out.setUint32(4, 2, Endian.little);
    out.setUint32(8, totalLength, Endian.little);
    out.setUint32(12, jsonBytes.length, Endian.little);
    out.setUint32(16, _jsonChunkType, Endian.little);

    final result = Uint8List.view(out.buffer);
    result.setAll(20, jsonBytes);

    final name = outputFileName.toLowerCase().endsWith('.glb')
        ? outputFileName
        : '$outputFileName.glb';
    final outFile = File(p.join(outputDirectory.path, name));
    await outFile.writeAsBytes(result, flush: true);
    return outFile;
  }

  File? _resolve(Directory baseDir, String uri) {
    try {
      final decoded = Uri.decodeComponent(uri);
      if (p.isAbsolute(decoded)) return File(decoded);
      final path = p.normalize(p.join(baseDir.path, decoded));
      if (!p.isWithin(baseDir.path, path)) return null; // path traversal guard
      return File(path);
    } catch (_) {
      return null;
    }
  }

  String _mimeFor(String path) {
    final ext = p.extension(path).toLowerCase();
    return switch (ext) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.webp' => 'image/webp',
      '.ktx' || '.ktx2' => 'image/ktx2',
      '.gif' => 'image/gif',
      '.bmp' => 'image/bmp',
      _ => 'application/octet-stream',
    };
  }
}
