import 'dart:convert';
import 'dart:io';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'engine/part2d.dart';
import 'engine/rig2d.dart';
import 'engine/shapes.dart';
import 'art/character_catalog.dart';
import 'art/palettes.dart';

/// PHASE 5 — Custom character packs (ZIP import, § spec "custom ZIP pack
/// import + validation").
///
/// Pack layout:
///   manifest.json   { name, rig?, groundY?, bones?: [...], parts: [...] }
///   art/*.png       part artwork referenced by the manifest
///
/// A pack either targets a built-in rig (rig: "humanoid_v1" / "quadruped_v1"
/// / "fox_v1") or ships its own bone list. Validation rejects: missing or
/// malformed manifest, circular / dangling bone parents, parts bound to
/// unknown bones, missing art files and non-PNG art — all with explicit
/// messages surfaced to the user.
class ZipPackException implements Exception {
  ZipPackException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ---------------------------------------------------------------- zip reader

/// Minimal ZIP reader (stored + deflate entries). Central-directory based so
/// entries are read exactly once; raw DEFLATE is inflated with dart:io.
Map<String, Uint8List> readZipArchive(Uint8List bytes) {
  // Find End Of Central Directory (scan back for the signature).
  var eocd = -1;
  for (var i = bytes.length - 22; i >= 0 && i > bytes.length - 22 - 65536; i--) {
    if (bytes[i] == 0x50 && bytes[i + 1] == 0x4B && bytes[i + 2] == 0x05 && bytes[i + 3] == 0x06) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw ZipPackException('Not a ZIP archive (end-of-directory record missing).');
  final bd = ByteData.sublistView(bytes);
  final entryCount = bd.getUint16(eocd + 10, Endian.little);
  var off = bd.getUint32(eocd + 16, Endian.little);

  final out = <String, Uint8List>{};
  for (var n = 0; n < entryCount; n++) {
    if (off + 46 > bytes.length ||
        bytes[off] != 0x50 || bytes[off + 1] != 0x4B || bytes[off + 2] != 0x01 || bytes[off + 3] != 0x02) {
      throw ZipPackException('Corrupt ZIP: central directory entry #$n is malformed.');
    }
    final method = bd.getUint16(off + 10, Endian.little);
    final compSize = bd.getUint32(off + 20, Endian.little);
    final nameLen = bd.getUint16(off + 28, Endian.little);
    final extraLen = bd.getUint16(off + 30, Endian.little);
    final commentLen = bd.getUint16(off + 32, Endian.little);
    final localOff = bd.getUint32(off + 42, Endian.little);
    final name = utf8.decode(bytes.sublist(off + 46, off + 46 + nameLen), allowMalformed: true);
    if (!name.endsWith('/')) {
      // Local header: skip its own name/extra fields to reach the payload.
      if (localOff + 30 > bytes.length) throw ZipPackException('Corrupt ZIP: entry "$name" is truncated.');
      final lName = bd.getUint16(localOff + 26, Endian.little);
      final lExtra = bd.getUint16(localOff + 28, Endian.little);
      final start = localOff + 30 + lName + lExtra;
      final payload = bytes.sublist(start, start + compSize);
      if (method == 0) {
        out[name] = Uint8List.fromList(payload);
      } else if (method == 8) {
        try {
          out[name] = Uint8List.fromList(io.ZLibDecoder(raw: true).convert(payload));
        } catch (_) {
          throw ZipPackException('Corrupt ZIP: entry "$name" could not be decompressed.');
        }
      } else {
        throw ZipPackException('Unsupported ZIP compression (method $method) in "$name".');
      }
    }
    off += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

// ---------------------------------------------------------------- manifest

class ZipPackBone {
  ZipPackBone(this.name, this.parent, this.attach, this.restAngle, this.length);
  final String name;
  final String parent;
  final Offset attach;
  final double restAngle;
  final double length;
}

class ZipPackPart {
  ZipPackPart(this.bone, this.z, this.file, this.dx, this.dy, this.targetH, this.visible);
  final String bone;
  final double z;
  final String file;
  final double dx;
  final double dy;

  /// Rendered height in rig units (width keeps aspect).
  final double targetH;
  final bool visible;
}

class ZipPackManifest {
  ZipPackManifest(this.name, this.rigKind, this.bones, this.parts, this.groundY);

  final String name;

  /// 'humanoid_v1' / 'quadruped_v1' / 'fox_v1' / 'zip:<id>' (custom bones).
  final String rigKind;
  final List<ZipPackBone> bones; // empty when targeting a built-in rig.
  final List<ZipPackPart> parts;
  final double groundY;

  static ZipPackManifest parse(Map<String, dynamic> j, Map<String, Uint8List> files, {required String fallbackId}) {
    if (j['name'] is! String || (j['name'] as String).trim().isEmpty) {
      throw ZipPackException('Manifest error: "name" is missing or empty.');
    }
    final name = (j['name'] as String).trim();

    final rawBones = j['bones'];
    final rawParts = j['parts'];
    if (rawParts is! List || rawParts.isEmpty) {
      throw ZipPackException('Manifest error: "parts" must be a non-empty list.');
    }

    // --- Bones (optional → built-in rig target).
    final builtinRigs = {'humanoid_v1', 'quadruped_v1', 'fox_v1'};
    final bones = <ZipPackBone>[];
    var rigKind = 'humanoid_v1';
    var groundY = 148.0;
    if (rawBones is List && rawBones.isNotEmpty) {
      rigKind = 'zip:$fallbackId';
      final names = <String>{};
      for (final rb in rawBones) {
        if (rb is! Map) throw ZipPackException('Manifest error: every bone must be an object.');
        final bName = rb['name'];
        final bParent = rb['parent'];
        if (bName is! String || bName.trim().isEmpty) throw ZipPackException('Manifest error: bone "name" missing.');
        if (!names.add(bName)) throw ZipPackException('Manifest error: duplicate bone "$bName".');
        final attach = rb['attach'];
        final ax = attach is List && attach.length == 2 ? (attach[0] as num).toDouble() : 0.0;
        final ay = attach is List && attach.length == 2 ? (attach[1] as num).toDouble() : 0.0;
        bones.add(ZipPackBone(
          bName,
          bParent is String ? bParent : '',
          Offset(ax, ay),
          rb['restAngle'] is num ? (rb['restAngle'] as num).toDouble() : 0,
          rb['length'] is num ? (rb['length'] as num).toDouble() : 30,
        ));
      }
      if (!names.contains('root')) {
        // Synthesize a root at the origin so FK has a single chain start.
        bones.insert(0, ZipPackBone('root', 'root', Offset.zero, 0, 0));
      }
      // Dangling parents + cycles: walk each chain to root with a guard.
      final byName = {for (final b in bones) b.name: b};
      for (final b in bones) {
        var cur = b;
        var guard = 0;
        while (cur.name != 'root') {
          final p = byName[cur.parent];
          if (p == null) {
            throw ZipPackException('Manifest error: bone "${cur.name}" has unknown parent "${cur.parent}".');
          }
          cur = p;
          if (++guard > bones.length) {
            throw ZipPackException('Manifest error: bone "$b" is in a circular parent chain.');
          }
        }
      }
      groundY = j['groundY'] is num ? (j['groundY'] as num).toDouble() : _guessGroundY(bones);
    } else if (j['rig'] is String && builtinRigs.contains(j['rig'])) {
      rigKind = j['rig'] as String;
      groundY = Rig2D.byKind(rigKind).groundY;
    } else if (j['rig'] is String) {
      throw ZipPackException('Manifest error: unknown rig "${j['rig']}" (use humanoid_v1, quadruped_v1, fox_v1 or a custom "bones" list).');
    }

    // --- Parts: every one must bind to a real bone and an existing PNG.
    final boneNames = bones.isNotEmpty
        ? {for (final b in bones) b.name}
        : Rig2D.byKind(rigKind).byName.keys.toSet();
    final parts = <ZipPackPart>[];
    for (final rp in rawParts) {
      if (rp is! Map) throw ZipPackException('Manifest error: every part must be an object.');
      final bone = rp['bone'];
      if (bone is! String || !boneNames.contains(bone)) {
        throw ZipPackException('Manifest error: part bone "${bone ?? '?'}" is not in the rig.');
      }
      final file = rp['file'];
      if (file is! String || !files.containsKey(file)) {
        throw ZipPackException('Manifest error: art file "${file ?? '?'}" is missing from the ZIP.');
      }
      final data = files[file]!;
      if (data.length < 8 || data[0] != 0x89 || data[1] != 0x50 || data[2] != 0x4E || data[3] != 0x47) {
        throw ZipPackException('Manifest error: art file "$file" is not a PNG.');
      }
      parts.add(ZipPackPart(
        bone,
        rp['z'] is num ? (rp['z'] as num).toDouble() : 5,
        file,
        rp['dx'] is num ? (rp['dx'] as num).toDouble() : 0,
        rp['dy'] is num ? (rp['dy'] as num).toDouble() : 0,
        rp['h'] is num ? (rp['h'] as num).toDouble() : 120,
        rp['visible'] is bool ? rp['visible'] as bool : true,
      ));
    }
    return ZipPackManifest(name, rigKind, bones, parts, groundY);
  }

  /// Longest downward chain from root — a decent default ground line.
  static double _guessGroundY(List<ZipPackBone> bones) {
    double down(String n, double acc, int guard) {
      if (guard > bones.length) return acc;
      var best = acc;
      for (final c in bones) {
        if (c.parent == n) {
          final v = down(c.name, acc + c.attach.distance + c.length, guard + 1);
          if (v > best) best = v;
        }
      }
      return best;
    }

    return down('root', 0, 0).clamp(40, 320);
  }
}

// ---------------------------------------------------------------- art cache

/// Decoded pack artwork cache: one decode per file, shared by library cards,
/// stage painting and export (never re-decodes per frame).
class PackArtCache {
  PackArtCache._();
  static final PackArtCache instance = PackArtCache._();
  static const _cap = 32;

  final Map<String, ui.Image> _images = {};

  /// Test hook: headless test runners have no raster thread, so PNG decode
  /// never completes there. Tests supply pre-made images instead. Production
  /// leaves this null and always decodes real files.
  ui.Image? Function(String path)? testImageFor;

  Future<ui.Image> load(String path) async {
    final hit = _images[path];
    if (hit != null) return hit;
    ui.Image img;
    final injected = testImageFor?.call(path);
    if (injected != null) {
      img = injected;
    } else {
      final data = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      img = (await codec.getNextFrame()).image;
    }
    if (_images.length >= _cap) _images.remove(_images.keys.first);
    _images[path] = img;
    return img;
  }

  ui.Image? peek(String path) => _images[path];
  void evict(String path) => _images.remove(path);
  void clear() => _images.clear();
}

// ---------------------------------------------------------------- import

/// Result of a successful import.
class ZipPackImport {
  ZipPackImport(this.specId, this.name, this.dir, this.rigKind);
  final String specId;
  final String name;
  final String dir;
  final String rigKind;
}

Future<void> _ensureImagesPreloaded(String dir, ZipPackManifest m) async {
  for (final p in m.parts.where((p) => p.visible)) {
    await PackArtCache.instance.load('$dir/${p.file}');
  }
}

Character2DSpec _buildSpec({
  required String id,
  required ZipPackManifest m,
  required String dir,
}) {
  return Character2DSpec(
    id: id,
    name: m.name,
    category: 'ZIP Pack',
    description: 'Imported pack "${m.name}" on rig ${m.rigKind}.',
    defaultPalette: Palettes.farmerDefault,
    slots: const [],
    faceStyle: null,
    scale: 1,
    rigKind: m.rigKind,
    build: (accessories) => [
      for (final p in m.parts.where((p) => p.visible))
        Part2D(
          bone: p.bone,
          z: p.z,
          build: (ctx) {
            final img = PackArtCache.instance.peek('$dir/${p.file}');
            if (img == null) return const [];
            final s = p.targetH / img.height;
            final w = img.width * s;
            return [
              DynShape(
                base: Shape(kind: ShapeKind.image, args: [-w / 2 + p.dx, -p.targetH + p.dy, w, p.targetH]),
                image: img,
              ),
            ];
          },
        ),
    ],
  );
}

/// Validates + installs a pack from raw ZIP bytes. Throws [ZipPackException]
/// with a user-readable reason on any validation failure.
Future<ZipPackImport> importZipPackBytes(Uint8List bytes, {String? idHint, Directory? baseDir}) async {
  final files = readZipArchive(bytes);
  final manifestData = files['manifest.json'];
  if (manifestData == null) {
    throw ZipPackException('Pack rejected: manifest.json is missing.');
  }
  final Map<String, dynamic> mj;
  try {
    mj = jsonDecode(utf8.decode(manifestData)) as Map<String, dynamic>;
  } catch (_) {
    throw ZipPackException('Pack rejected: manifest.json is not valid JSON.');
  }

  final id = idHint ?? 'zip_${DateTime.now().millisecondsSinceEpoch}';
  ZipPackManifest.parse(mj, files, fallbackId: id); // validate before writing anything

  final docs = baseDir ?? await getApplicationDocumentsDirectory();
  final dir = '${docs.path}/character_packs/$id';
  await Directory(dir).create(recursive: true);
  for (final e in files.entries) {
    if (e.key == 'manifest.json') continue;
    final f = File('$dir/${e.key}');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(e.value);
  }
  await File('$dir/manifest.json').writeAsBytes(manifestData);

  return registerZipPackFromDir(dir, id: id);
}

/// Registers (or re-registers) a previously unzipped pack directory. Used by
/// both the import flow and post-restart rehydration so both produce the
/// identical character.
Future<ZipPackImport> registerZipPackFromDir(String dir, {required String id}) async {
  final manifestFile = File('$dir/manifest.json');
  if (!await manifestFile.exists()) {
    throw ZipPackException('Pack rejected: $dir has no manifest.json.');
  }
  final mj = jsonDecode(utf8.decode(await manifestFile.readAsBytes())) as Map<String, dynamic>;

  // Art files on disk.
  final files = <String, Uint8List>{};
  for (final rp in (mj['parts'] as List).whereType<Map>()) {
    final f = rp['file'];
    if (f is String) {
      final file = File('$dir/$f');
      if (await file.exists()) files[f] = await file.readAsBytes();
    }
  }
  final m = ZipPackManifest.parse(mj, files, fallbackId: id);
  // (Validation itself happens inside parse: bad packs throw before any
  // files are written or specs registered.)

  // Custom bones → runtime rig through the shared byKind registry.
  if (m.bones.isNotEmpty) {
    Rig2D.registerKind(m.rigKind, Rig2D([
      for (final b in m.bones) Bone2D(name: b.name, parent: b.parent, attach: _p(b.attach), restAngle: b.restAngle, length: b.length),
    ], groundY: m.groundY, kind: m.rigKind));
  }

  await _ensureImagesPreloaded(dir, m);
  CharacterCatalog.register(_buildSpec(id: id, m: m, dir: dir));
  return ZipPackImport(id, m.name, dir, m.rigKind);
}

math.Point<double> _p(Offset o) => math.Point(o.dx, o.dy);
