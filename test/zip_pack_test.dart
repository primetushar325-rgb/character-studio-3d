// PHASE 5 — ZIP character pack import (§ custom pack import + validation).
//
// Covers: ZIP reading (stored + deflate), manifest validation rejections
// (missing/bad manifest, circular or dangling parents, unknown part bones,
// missing art, non-PNG art), successful import onto built-in and custom
// rigs, art caching and re-registration from disk (restart rehydration).
import 'dart:convert';
import 'dart:io' show Directory, File, ZLibCodec;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/engine/palette_resolver.dart';
import 'package:character_studio_3d/characters2d/engine/part2d.dart';
import 'package:character_studio_3d/characters2d/engine/shapes.dart';
import 'package:character_studio_3d/characters2d/engine/rig2d.dart';
import 'package:character_studio_3d/characters2d/zip_pack.dart';

final zlib = ZLibCodec();

// ---- tiny store-only ZIP writer (test-side pack builder) ------------------
Uint8List buildZip(Map<String, List<int>> entries) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  for (final e in entries.entries) {
    final name = utf8.encode(e.key);
    final data = e.value;
    final crc = _crc32(Uint8List.fromList(data));

    // Local file header (30 bytes + name).
    out.add([
      0x50, 0x4B, 0x03, 0x04, // signature
      ..._u16(20),            // version needed
      ..._u16(0),             // flags
      ..._u16(0),             // method: stored
      ..._u16(0), ..._u16(0), // mod time / date
      ..._u32(crc), ..._u32(data.length), ..._u32(data.length),
      ..._u16(name.length), ..._u16(0),
    ]);
    out.add(name);
    out.add(data);

    // Central directory entry (46 bytes + name).
    central.add([
      0x50, 0x4B, 0x01, 0x02, // signature
      ..._u16(20), ..._u16(20),
      ..._u16(0),             // flags
      ..._u16(0),             // method
      ..._u16(0), ..._u16(0), // time / date
      ..._u32(crc), ..._u32(data.length), ..._u32(data.length),
      ..._u16(name.length), ..._u16(0), ..._u16(0), // name/extra/comment len
      ..._u16(0),             // disk number start
      ..._u16(0),             // internal attrs
      ..._u32(0),             // external attrs
      ..._u32(out.length - data.length - name.length - 30), // local offset
    ]);
    central.add(name);
  }
  final cdStart = out.length;
  final cd = central.takeBytes();
  out.add(cd);
  out.add([
    0x50, 0x4B, 0x05, 0x06, // EOCD signature
    ..._u16(0), ..._u16(0), ..._u16(entries.length), ..._u16(entries.length),
    ..._u32(cd.length), ..._u32(cdStart), ..._u16(0),
  ]);
  return out.takeBytes();
}

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _u32(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
    }
  }
  return ~crc & 0xFFFFFFFF;
}

// ---- fixtures ---------------------------------------------------------------
final png1x1 = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, 0, 1, 0, 1, 8, 6, 0, 0, 0,
  0x1F, 0x15, 0xC4, 0x89, // IHDR 1×1
  0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, // IEND
]);

Map<String, List<int>> validPack(String name, {String? rig, List<Map<String, dynamic>>? bones}) => {
      'manifest.json': utf8.encode(jsonEncode({
            'name': name,
            if (rig != null) 'rig': rig,
            if (bones != null) 'bones': bones,
            'parts': [
              {'bone': 'hips', 'file': 'art/body.png', 'z': 5, 'h': 140},
              {'bone': 'head', 'file': 'art/head.png', 'z': 9, 'h': 60},
            ],
          })),
      'art/body.png': png1x1,
      'art/head.png': png1x1,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('zip_pack_test');
    CharacterCatalog.dynamicSpecs.clear();
    Rig2D.dynamicKinds.clear();
    PackArtCache.instance.clear();
  });
  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('ZIP reader: stored entries + EOCD scan', () {
    final zip = buildZip({'a.txt': utf8.encode('hello'), 'dir/b.txt': utf8.encode('world')});
    final files = readZipArchive(zip);
    expect(files.keys, containsAll(['a.txt', 'dir/b.txt']));
    expect(utf8.decode(files['a.txt']!), 'hello');
  });

  test('ZIP reader rejects non-zip bytes', () {
    expect(() => readZipArchive(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ZipPackException>()));
  });

  testWidgets('valid pack (built-in rig) imports, registers and draws parts', (tester) async {
    await _installTestImages(tester);
    final zip = buildZip(validPack('Robo Buddy', rig: 'humanoid_v1'));
    final pack = await tester.runAsync(() => importZipPackBytes(zip, idHint: 'robo', baseDir: tmp));
    expect(pack, isNotNull);
    expect(pack!.rigKind, 'humanoid_v1');
    expect(CharacterCatalog.byId('robo')!.category, 'ZIP Pack');

    // Art was written to disk and preloaded through the cache.
    expect(File('${pack.dir}/art/body.png').existsSync(), isTrue);
    expect(PackArtCache.instance.peek('${pack.dir}/art/body.png'), isNotNull);

    final spec = CharacterCatalog.byId('robo')!;
    final parts = orderParts(spec.build(const {}));
    expect(parts.length, 2);
    expect(parts.map((p) => p.bone).toSet(), {'hips', 'head'});
    // Image parts draw (cache hit) once preloaded.
    expect(parts.first.build(dummyCtx()), isNotEmpty);
  });

  testWidgets('custom bones register a runtime rig reachable through byKind', (tester) async {
    await _installTestImages(tester);
    // Custom rig → part bones must exist in the custom skeleton.
    final zip2 = <String, List<int>>{
      'art/body.png': png1x1,
      'art/head.png': png1x1,
      'manifest.json': utf8.encode(jsonEncode({
      'name': 'Wormy',
      'bones': [
        {'name': 'root', 'parent': '', 'attach': [0, 0], 'restAngle': 0, 'length': 0},
        {'name': 'seg1', 'parent': 'root', 'attach': [0, 0], 'restAngle': 90, 'length': 40},
        {'name': 'seg2', 'parent': 'seg1', 'attach': [0, 40], 'restAngle': -10, 'length': 30},
      ],
      'parts': [
        {'bone': 'seg1', 'file': 'art/body.png', 'h': 60},
        {'bone': 'seg2', 'file': 'art/head.png', 'h': 40},
      ],
      })), 
    };
    final pack = await tester.runAsync(() => importZipPackBytes(buildZip(zip2), idHint: 'wormy', baseDir: tmp));
    expect(pack, isNotNull);
    expect(pack!.rigKind, 'zip:wormy');
    final rig = Rig2D.byKind('zip:wormy');
    expect(rig.isValid, isTrue);
    expect(rig.byName['seg2']!.parent, 'seg1');
    // FK through the custom chain works.
    final s = solveSkeleton(rig, {'seg1': 30});
    expect(s.angleOf('seg2'), closeTo(s.angleOf('seg1') - 10 * 3.14159265 / 180, 0.001));
  });

  testWidgets('rehydration: re-registering from the unpacked dir is idempotent', (tester) async {
    await _installTestImages(tester);
    final zip = buildZip(validPack('Robo Buddy', rig: 'fox_v1'));
    final first = await tester.runAsync(() => importZipPackBytes(zip, idHint: 'robo', baseDir: tmp));
    expect(first, isNotNull);
    PackArtCache.instance.clear();
    CharacterCatalog.dynamicSpecs.clear();

    final second = await tester.runAsync(() => registerZipPackFromDir(first!.dir, id: 'robo'));
    expect(second!.rigKind, 'fox_v1');
    final spec = CharacterCatalog.byId('robo');
    expect(spec, isNotNull);
    expect(orderParts(spec!.build(const {})).length, 2);
  });

  test('rejections carry explicit reasons', () async {
    Future<String> reject(Map<String, List<int>> entries) async {
      try {
        await importZipPackBytes(buildZip(entries), idHint: 'bad', baseDir: tmp);
        return 'ACCEPTED';
      } on ZipPackException catch (e) {
        return e.message;
      }
    }

    // Missing manifest.
    expect(await reject({'art/body.png': png1x1}), contains('manifest.json'));
    // Malformed JSON manifest.
    expect(await reject({'manifest.json': utf8.encode('{oops')}), contains('valid JSON'));
    // Empty parts list.
    expect(
        await reject({
          'manifest.json': utf8.encode(jsonEncode({'name': 'X', 'parts': []})),
        }),
        contains('parts'));
    // Circular parents.
    expect(
        await reject({
          'manifest.json': utf8.encode(jsonEncode({
            'name': 'X',
            'bones': [
              {'name': 'a', 'parent': 'b', 'attach': [0, 0], 'length': 10},
              {'name': 'b', 'parent': 'a', 'attach': [0, 0], 'length': 10},
            ],
            'parts': [
              {'bone': 'a', 'file': 'art/body.png'},
            ],
          })),
          'art/body.png': png1x1,
        }),
        anyOf(contains('circular'), contains('unknown parent')));
    // Dangling parent.
    expect(
        await reject({
          'manifest.json': utf8.encode(jsonEncode({
            'name': 'X',
            'bones': [
              {'name': 'root', 'parent': '', 'attach': [0, 0], 'length': 0},
              {'name': 'a', 'parent': 'ghost', 'attach': [0, 0], 'length': 10},
            ],
            'parts': [
              {'bone': 'a', 'file': 'art/body.png'},
            ],
          })),
          'art/body.png': png1x1,
        }),
        contains('unknown parent'));
    // Part bound to a bone the rig doesn't have.
    expect(
        await reject({
          'manifest.json': utf8.encode(jsonEncode({
            'name': 'X',
            'parts': [
              {'bone': 'tail42', 'file': 'art/body.png'},
            ],
          })),
          'art/body.png': png1x1,
        }),
        contains('not in the rig'));
    // Art file missing from the archive.
    expect(
        await reject({
          'manifest.json': utf8.encode(jsonEncode({
            'name': 'X',
            'parts': [
              {'bone': 'hips', 'file': 'art/ghost.png'},
            ],
          })),
        }),
        contains('missing from the ZIP'));
    // Art file is not a PNG.
    expect(
        await reject({
          'manifest.json': utf8.encode(jsonEncode({
            'name': 'X',
            'parts': [
              {'bone': 'hips', 'file': 'art/body.jpg'},
            ],
          })),
          'art/body.jpg': utf8.encode('not a png'),
        }),
        contains('not a PNG'));
    // Unknown built-in rig.
    expect(
        await reject({
          'manifest.json': utf8.encode(jsonEncode({
            'name': 'X',
            'rig': 'spider_v9',
            'parts': [
              {'bone': 'hips', 'file': 'art/body.png'},
            ],
          })),
          'art/body.png': png1x1,
        }),
        contains('unknown rig'));
  });

  test('rejected packs leave no partial install behind', () async {
    final zip = buildZip({
      'manifest.json': utf8.encode(jsonEncode({
        'name': 'X',
        'parts': [
          {'bone': 'hips', 'file': 'art/none.png'},
        ],
      })),
    });
    await expectLater(importZipPackBytes(zip, idHint: 'bad', baseDir: tmp), throwsA(isA<ZipPackException>()));
    expect(Directory('${tmp.path}/character_packs/bad').existsSync(), isFalse);
    expect(CharacterCatalog.byId('bad'), isNull);
  });
}

/// Renders a tiny real ui.Image via a paint boundary (decode is impossible
/// headless) and installs it as the pack art cache's test image.
Future<void> _installTestImages(tester) async {
  tester.binding.window; // ensure binding
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: const SizedBox(width: 4, height: 4),
  ));
  await tester.pump();
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final img = await boundary.toImage(pixelRatio: 1);
  PackArtCache.instance.testImageFor = (_) => img;
}

ShapeCtx dummyCtx() => ShapeCtx(
      colors: const PaletteResolver({}),
      extras: const {},
      face: const FaceView(),
    );
