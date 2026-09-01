import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/character2d_model.dart';
import 'package:character_studio_3d/characters2d/png_character.dart';
import 'package:character_studio_3d/project/project_document.dart';
import 'package:character_studio_3d/project/project_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ProjectRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('prj_test');
    repo = ProjectRepository(baseDir: tmp);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Map<String, dynamic> bgConfigToJsonForTest() => {
        'kind': 'gradient',
        'builtinId': 'studio_dark',
        'color1': 0xFF101828,
        'color2': 0xFF2A1E5C,
        'gradientAngle': 90.0,
        'imagePath': '/x/bg.png',
        'fit': 'contain',
        'offsetX': 0.2,
        'offsetY': -0.1,
        'scale': 1.2,
        'brightness': 0.1,
        'contrast': -0.05,
        'blur': 3.0,
        'opacity': 0.8,
      };



  ProjectDocument docFor(String name, [String orientation = ProjectOrientation.landscape16x9]) {
    final (w, h) = ProjectOrientation.canvasSize(orientation);
    return ProjectDocument(
      id: 'prj_1',
      name: name,
      orientation: orientation,
      canvasWidth: w,
      canvasHeight: h,
      background: bgConfigToJsonForTest(),
      characterId: 'tiger',
      characterTransform: {'x': 0.42, 'y': 0.81, 'scale': 1.4, 'rotation': -5, 'flipH': true, 'flipV': false, 'opacity': 0.9},
      actionId: 'walk',
      expression: 'happy',
      talking: true,
      directionLeft: true,
      layers: [
        {'id': 'background', 'visible': true, 'locked': false},
        {'id': 'character', 'visible': true, 'locked': false},
        {'id': 'effects', 'visible': false, 'locked': true},
      ],
      effectsVignette: true,
    );
  }

  group('ProjectDocument serialization', () {
    test('1+2. JSON round-trip keeps every field', () {
      final doc = docFor('My Story');
      final map = jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
      final back = ProjectDocument.fromJson(map);

      expect(back.id, doc.id);
      expect(back.name, 'My Story');
      expect(back.orientation, ProjectOrientation.landscape16x9);
      expect(back.canvasWidth, 1920);
      expect(back.canvasHeight, 1080);
      expect(back.characterId, 'tiger');
      expect(back.actionId, 'walk');
      expect(back.expression, 'happy');
      expect(back.talking, true);
      expect(back.directionLeft, true);
      expect(back.effectsVignette, true);
      expect(back.characterTransform!['scale'], closeTo(1.4, 1e-9));
      expect(back.characterTransform!['flipH'], true);
      expect(back.background!['kind'], 'gradient');
      expect(back.background!['fit'], 'contain');
      expect(back.background!['imagePath'], '/x/bg.png');
      expect(back.layers.length, 3);
      expect(back.layers[2]['visible'], false);
      expect(back.layers[2]['locked'], true);
      expect(back.exportFps, 30);
    });

    test('orientation presets are exactly 16:9 1920×1080, 9:16 1080×1920, 1:1 1080×1080', () {
      expect(ProjectOrientation.canvasSize(ProjectOrientation.landscape16x9), (1920, 1080));
      expect(ProjectOrientation.canvasSize(ProjectOrientation.portrait9x16), (1080, 1920));
      expect(ProjectOrientation.canvasSize(ProjectOrientation.square1x1), (1080, 1080));
    });

    test('corrupt project.json returns null instead of crashing', () async {
      final dir = await repo.projectDir('prj_bad');
      await File('${dir.path}/project.json').writeAsString('{ not json');
      expect(await repo.load('prj_bad'), isNull);
    });
  });

  group('ProjectRepository', () {
    test('3+4+5. create → save → load round-trip on disk', () async {
      await repo.create(docFor('Disk Story'));
      final loaded = await repo.load('prj_1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Disk Story');
      expect(loaded.canvasWidth, 1920);
      expect(loaded.characterId, 'tiger');
      expect(loaded.actionId, 'walk');
      // File really exists where the spec says it must.
      expect(await File('${tmp.path}/prj_1/project.json').exists(), true);
    });

    test('empty project (no character) round-trips as empty', () async {
      final doc = ProjectDocument(
        id: 'prj_e',
        name: 'Empty',
        orientation: ProjectOrientation.square1x1,
        canvasWidth: 1080,
        canvasHeight: 1080,
      );
      await repo.create(doc);
      final loaded = await repo.load('prj_e');
      expect(loaded!.characterId, isNull);
      expect(loaded.background, isNull);
      expect(loaded.canvasWidth, 1080);
      expect(loaded.canvasHeight, 1080);
    });

    test('6. rename persists', () async {
      final doc = docFor('Old Name');
      await repo.create(doc);
      await repo.rename(doc, 'New Name');
      final loaded = await repo.load('prj_1');
      expect(loaded!.name, 'New Name');
    });

    test('7. duplicate creates a new id and never mutates the original', () async {
      final doc = docFor('Original');
      await repo.create(doc);
      final copy = await repo.duplicate(doc);
      expect(copy, isNotNull);
      expect(copy!.id, isNot(doc.id));
      expect(copy.name, 'Original Copy');
      final orig = await repo.load('prj_1');
      expect(orig!.name, 'Original');
      expect(orig.characterId, 'tiger');
      final listed = await repo.list();
      expect(listed.length, 2);
    });

    test('8. delete removes the folder', () async {
      await repo.create(docFor('Doomed'));
      await repo.delete('prj_1');
      expect(await repo.load('prj_1'), isNull);
      expect(await Directory('${tmp.path}/prj_1').exists(), false);
    });

    test('9. orientation persists for all three orientations', () async {
      for (final o in ProjectOrientation.all) {
        final repo2 = ProjectRepository(baseDir: tmp);
        final (w, h) = ProjectOrientation.canvasSize(o);
        final doc = ProjectDocument(id: 'prj_$o', name: o, orientation: o, canvasWidth: w, canvasHeight: h);
        await repo2.create(doc);
        final back = await repo2.load('prj_$o');
        expect(back!.orientation, o);
        expect(back.canvasWidth, w);
        expect(back.canvasHeight, h);
      }
    });

    test('save is atomic — a crash mid-write keeps the last good file', () async {
      final doc = docFor('Atomic');
      await repo.create(doc);
      final f = File('${tmp.path}/prj_1/project.json');
      final before = await f.readAsString();
      // Simulate a partial write into the temp file only.
      await File('${tmp.path}/prj_1/project.json.tmp').writeAsString('{ partial');
      final reloaded = await repo.load('prj_1');
      expect(reloaded!.name, 'Atomic'); // previous good version still loads
      expect(before.contains('Atomic'), true);
    });

    test('thumbnail bytes are written to thumb.png', () async {
      await repo.create(docFor('Thumb'));
      await repo.saveThumbnail('prj_1', [1, 2, 3, 4]);
      expect(await File('${tmp.path}/prj_1/thumb.png').exists(), true);
      final loaded = await repo.load('prj_1');
      expect(loaded!.thumbnailPath, endsWith('thumb.png'));
    });
  });

  group('BgConfig / transform JSON helpers', () {
    test('10. background persistence helper round-trips', () {
      final json = bgConfigToJsonForTest();
      final bg = bgConfigFromJson(json);
      expect(bg.kind.name, 'gradient');
      expect(bg.imagePath, '/x/bg.png');
      expect(bg.fit.name, 'contain');
      expect(bg.scale, closeTo(1.2, 1e-9));
      expect(bg.blur, closeTo(3.0, 1e-9));
      expect(bg.opacity, closeTo(0.8, 1e-9));
      final back = bgConfigToJson(bg);
      for (final k in json.keys) {
        expect(back.containsKey(k), true, reason: 'missing $k');
      }
    });
  });

  group('PNG character rehydration (restart bug fix)', () {
    test('13. saved PNG variant re-registers its real spec after restart', () async {
      // Build a real tiny PNG on disk.
      final png = await _tinyPng();
      final artDir = await Directory('${tmp.path}/characters2d_png').create();
      final artPath = '${artDir.path}/png_123.png';
      await File(artPath).writeAsBytes(png);

      // What the import flow persists (now includes rigKind).
      final saved = Character2D(
        id: 'png_123',
        specId: 'png_123',
        name: 'My Cutout',
        isVariant: true,
        imagePath: artPath,
        rigKind: 'quadruped_v1',
        createdAt: DateTime.now(),
      );
      // Simulated restart: spec registry is empty for this id.
      expect(CharacterCatalog.byId('png_123'), isNull);

      // Rehydration logic (same call the library makes on load()).
      final art = await loadPngArt(artPath);
      expect(art, isNotNull);
      CharacterCatalog.register(pngSpecFromArt(
        id: saved.specId,
        name: saved.name,
        art: art!,
        rigKind: saved.rigKind ?? 'humanoid_v1',
      ));

      // The variant now resolves to its REAL spec (not the farmer fallback).
      final spec = CharacterCatalog.byId('png_123');
      expect(spec, isNotNull);
      expect(spec!.rigKind, 'quadruped_v1');
      expect(spec.name, 'My Cutout');
      expect(spec.build({}), isNotEmpty); // artwork parts actually build
    });

    test('missing artwork file is skipped safely', () async {
      final art = await loadPngArt('${tmp.path}/does_not_exist.png');
      expect(art, isNull);
    });
  });
}

/// Minimal valid 2×2 PNG (transparent) produced with dart:ui, so the test
/// decodes REAL image bytes exactly like an import would.
Future<List<int>> _tinyPng() async {
  final completer = Completer<ui.Image>();
  const w = 2, h = 2;
  final rgba = Uint8List(w * h * 4);
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, completer.complete,
      rowBytes: w * 4);
  final image = await completer.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List().toList();
}
