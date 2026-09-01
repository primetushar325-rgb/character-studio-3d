import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'dart:ui' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/project/project_document.dart';
import 'package:character_studio_3d/project/project_repository.dart';
import 'package:character_studio_3d/scene/scene_object.dart';
import 'package:character_studio_3d/scene/scene_renderer.dart';
import 'package:character_studio_3d/state/editor_provider.dart';
import 'package:character_studio_3d/state/library2d_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('SceneObject serialization (1+2)', () {
    test('character object round-trips with animation state', () {
      final o = characterObject(id: 'obj_1', characterId: 'tiger', name: 'Tiger', zIndex: 3, actionId: 'walk')
        ..expression = 'happy'
        ..talking = true
        ..directionLeft = true
        ..transform = ObjectTransform(x: .3, y: .8, scaleX: 1.4, scaleY: 1.4, rotation: -8, opacity: .85, flipH: true);
      final back = SceneObject.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
      expect(back.type, SceneObjectType.character);
      expect(back.characterId, 'tiger');
      expect(back.actionId, 'walk');
      expect(back.expression, 'happy');
      expect(back.talking, true);
      expect(back.directionLeft, true);
      expect(back.transform.x, closeTo(.3, 1e-9));
      expect(back.transform.scaleY, closeTo(1.4, 1e-9));
      expect(back.transform.rotation, closeTo(-8, 1e-9));
      expect(back.transform.opacity, closeTo(.85, 1e-9));
      expect(back.transform.flipH, true);
    });

    test('image object round-trips with project-relative path', () {
      final o = imageObject(id: 'obj_2', relPath: 'assets/images/img_1.png', name: 'Tree', zIndex: 5);
      o.transform..x = .2..y = .5..scaleX = 2..rotation = 15..opacity = .5;
      final back = SceneObject.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
      expect(back.type, SceneObjectType.image);
      expect(back.imagePath, 'assets/images/img_1.png');
      expect(back.transform.scaleX, 2);
      expect(back.transform.rotation, 15);
    });

    test('text object round-trips with styling', () {
      final o = textObject(id: 'obj_3', zIndex: 7, text: 'Hello\nWorld')
        ..fontSize = 96
        ..fontWeight = 900
        ..textColor = 0xFFFFEE00
        ..strokeColor = 0xFF000000
        ..strokeWidth = 6
        ..textAlign = 'left'
        ..textBgColor = 0x88000000;
      final back = SceneObject.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
      expect(back.text, 'Hello\nWorld');
      expect(back.fontSize, 96);
      expect(back.fontWeight, 900);
      expect(back.textColor, 0xFFFFEE00);
      expect(back.strokeWidth, 6);
      expect(back.textAlign, 'left');
      expect(back.textBgColor, 0x88000000);
    });

    test('shape object round-trips (rect/circle/line)', () {
      for (final kind in ['rect', 'circle', 'line']) {
        final o = shapeObject(id: 'obj_4_$kind', zIndex: 9, kind: kind)
          ..width = .5
          ..height = .1
          ..fillColor = 0xFF4C7BD9
          ..shapeStrokeColor = 0xFF111111
          ..shapeStrokeWidth = 4;
        final back = SceneObject.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
        expect(back.shapeKind, kind);
        expect(back.width, .5);
        expect(back.fillColor, 0xFF4C7BD9);
        expect(back.shapeStrokeWidth, 4);
      }
    });
  });

  group('Editor scene graph (3–11)', () {
    late Library2DProvider library;
    late EditorProvider ed;

    setUp(() async {
      library = Library2DProvider(repo: Character2DRepository());
      await library.load();
      ed = EditorProvider(library);
    });

    test('3. multiple characters coexist — adding never replaces', () {
      ed.addCharacter('bd_farmer_male');
      ed.addCharacter('village_girl');
      final chars = ed.objects.where((o) => o.isCharacter).toList();
      expect(chars.length, 2);
      expect(chars[0].characterId, 'bd_farmer_male');
      expect(chars[1].characterId, 'village_girl');
      // Two controllers exist independently.
      expect(ed.controllerFor(chars[0]), isNot(same(ed.controllerFor(chars[1]))));
      // Selection switched to the newest, first still present.
      expect(ed.selectedId, chars[1].id);
    });

    test('7. zIndex ordering drives paint order', () {
      ed.addShape('rect'); // z1
      ed.addText();        // z2
      ed.addCharacter('tiger'); // z3
      final order = ed.objectsInPaintOrder.map((o) => o.type.name).toList();
      expect(order, ['shape', 'text', 'character']);
      // Move character to the bottom → paints first.
      final charObj = ed.objects.firstWhere((o) => o.isCharacter);
      ed.moveObjectDown(charObj.id);
      ed.moveObjectDown(charObj.id);
      expect(ed.objectsInPaintOrder.first.type, SceneObjectType.character);
    });

    test('8. hidden objects are excluded from paint order but kept in scene', () {
      final a = ed.addText();
      ed.addShape('circle');
      ed.setVisibility(a.id, false);
      expect(ed.objectsInPaintOrder.any((o) => o.id == a.id), false);
      expect(ed.objects.length, 2);
    });

    test('9. locked objects cannot be transformed', () {
      final a = ed.addText();
      ed.toggleLock(a.id);
      expect(a.locked, true);
      final x0 = a.transform.x;
      ed.updateTransform(a.id, (t) => t.x = .99); // must be a NO-OP
      expect(a.transform.x, x0);
      ed.toggleLock(a.id);
      ed.updateTransform(a.id, (t) => t.x = .99);
      expect(a.transform.x, .99);
    });

    test('10+11. transforms + opacity persist on the object', () {
      final a = ed.addShape('line');
      ed.updateTransform(a.id, (t) {
        t.x = .25;
        t.y = .6;
        t.scaleX = 2.5;
        t.scaleY = .75;
        t.rotation = -45;
        t.opacity = .35;
      });
      expect(a.transform.x, .25);
      expect(a.transform.scaleX, 2.5);
      expect(a.transform.rotation, -45);
      expect(a.transform.opacity, .35);
    });

    test('per-character animation state is independent', () {
      ed.addCharacter('bd_farmer_male');
      ed.addCharacter('village_girl');
      final c1 = ed.objects.where((o) => o.isCharacter).first;
      ed.select(c1.id);
      ed.setAction('walk');
      expect(c1.actionId, 'walk');
      final c2 = ed.objects.where((o) => o.isCharacter).last;
      expect(c2.actionId, 'idle'); // untouched
    });

    test('15. hit test returns the topmost object on overlap', () {
      final t = ed.addText();
      t.transform..x = .5..y = .4;
      final s = ed.addShape('rect'); // higher z, same spot
      s.transform..x = .5..y = .4;
      final hit = hitTest(ed.objects, const Offset(50, 40), _canvasSizeForHit());
      expect(hit!.type, SceneObjectType.shape); // topmost wins
      // With size (100,100), point (50,40) is inside both → topmost = shape.
      expect(hit, isNotNull);
    });
  });

  group('Project integration (4–6, 12, migration)', () {
    late Directory tmp;
    late ProjectRepository repo;
    late Library2DProvider library;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('p2');
      repo = ProjectRepository(baseDir: tmp);
      library = Library2DProvider(repo: Character2DRepository());
      await library.load();
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('12. full composition survives save → load (multi-object)', () async {
      final ed = EditorProvider(library);
      final doc = ProjectDocument(
        id: 'prj_p2',
        name: 'Scene',
        orientation: ProjectOrientation.landscape16x9,
        canvasWidth: 1920,
        canvasHeight: 1080,
      );
      ed.project = doc;
      ed.projectDirPath = (await repo.projectDir(doc.id)).path;

      final farmer = ed.addCharacter('bd_farmer_male');
      ed.updateTransform(farmer.id, (t) { t.x = .3; t.scaleY = 1.2; });
      final girl = ed.addCharacter('village_girl');
      ed.updateTransform(girl.id, (t) { t.x = .7; t.opacity = .8; });
      final txt = ed.addText();
      ed.updateObject(txt.id, (o) => o.text = 'HELLO');
      final shp = ed.addShape('circle');
      ed.updateObject(shp.id, (o) => o.fillColor = 0xFF123456);
      await ed.addImage('/nonexistent.png', 'assets/images/x.png');

      captureEditorIntoProject(ed, doc);
      await repo.save(doc);

      // ---- "restart" -------------------------------------------------------
      final doc2 = (await repo.load('prj_p2'))!;
      final ed2 = EditorProvider(library);
      ed2.projectDirPath = ed.projectDirPath;
      await applyProjectRuntimeToEditor(ed2, doc2);

      expect(ed2.objects.length, 5);
      final f2 = ed2.objects.firstWhere((o) => o.characterId == 'bd_farmer_male');
      expect(f2.transform.x, closeTo(.3, 1e-9));
      expect(f2.transform.scaleY, closeTo(1.2, 1e-9));
      final g2 = ed2.objects.firstWhere((o) => o.characterId == 'village_girl');
      expect(g2.transform.opacity, closeTo(.8, 1e-9));
      expect(ed2.objects.firstWhere((o) => o.type == SceneObjectType.text).text, 'HELLO');
      expect(ed2.objects.firstWhere((o) => o.type == SceneObjectType.shape).fillColor, 0xFF123456);
      expect(ed2.objects.firstWhere((o) => o.type == SceneObjectType.image).imagePath, 'assets/images/x.png');
    });

    test('legacy Phase-1 project migrates to a scene object (never crashes)', () async {
      final legacy = ProjectDocument.fromJson({
        'id': 'prj_old',
        'name': 'Old',
        'orientation': 'landscape16x9',
        'canvas': {'width': 1920, 'height': 1080},
        'characterId': 'tiger',
        'actionId': 'walk',
        'characterTransform': {'x': .4, 'y': .8, 'scale': 1.5, 'rotation': 0, 'flipH': false, 'flipV': false, 'opacity': 1},
        'scene': <String, dynamic>{},
      });
      final ed = EditorProvider(library);
      await applyProjectRuntimeToEditor(ed, legacy);
      expect(ed.objects.length, 1);
      final o = ed.objects.single;
      expect(o.characterId, 'tiger');
      expect(o.actionId, 'walk');
      expect(o.transform.scaleY, 1.5);
      // Re-capture writes the NEW format (objects list) without duplication.
      captureEditorIntoProject(ed, legacy);
      final reloaded = SceneGraph.fromJson(legacy.scene);
      expect(reloaded.objects.length, 1);
    });

    test('empty new project stays empty (no auto character)', () async {
      final doc = ProjectDocument(
          id: 'prj_e', name: 'E', orientation: ProjectOrientation.square1x1, canvasWidth: 1080, canvasHeight: 1080);
      final ed = EditorProvider(library);
      await applyProjectRuntimeToEditor(ed, doc);
      expect(ed.objects, isEmpty);
      expect(ed.controller, isNull);
    });
  });

  group('Renderer (14)', () {
    test('paintScene renders all object types without throwing', () async {
      final library = Library2DProvider(repo: Character2DRepository());
      await library.load();
      final ed = EditorProvider(library);
      ed.addCharacter('tiger');
      ed.addText();
      ed.addShape('rect');
      final imgObj = await ed.addImage('/nonexistent.png', 'assets/images/none.png');

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      paintScene(canvas, const Size(640, 360), ed);
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 36);
      expect(image.width, 64);
      expect(image.height, 36);
      picture.dispose();
      image.dispose();
      expect(imgObj.type, SceneObjectType.image);
    });
  });
}

ui.Size _canvasSizeForHit() => const Size(100, 100);
