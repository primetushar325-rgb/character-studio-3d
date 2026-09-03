// §7 Multi-character scenes — this app has had multi-actor scenes since its
// scene-graph phase; these tests LOCK the invariants the RigStudio prompt
// asks for: independent per-actor animation, per-actor clips/phases,
// z-order layering, and whole-scene compositing through the one renderer
// that preview AND export share.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/characters2d/character2d_model.dart';
import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/characters2d/props.dart';
import 'package:character_studio_3d/characters2d/engine/pose2d.dart';
import 'package:character_studio_3d/project/project_document.dart';
import 'package:character_studio_3d/state/editor_provider.dart';
import 'package:character_studio_3d/state/library2d_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  late EditorProvider ed;
  setUp(() async {
    await SharedPreferences.getInstance();
    ed = EditorProvider(Library2DProvider(repo: Character2DRepository()));
  });

  test('two actors get independent controllers (no shared animation state)', () {
    final fox = ed.addCharacter('fox');
    final farmer = ed.addCharacter('bd_farmer_male');
    final cFox = ed.controllerFor(fox)!;
    final cFarmer = ed.controllerFor(farmer)!;
    expect(identical(cFox, cFarmer), isFalse);

    // Different clips at the same scene moment: fox walks, farmer waves.
    ed.addAnimClip(fox.id, 'walk', startMs: 0, endMs: 4000);
    ed.addAnimClip(farmer.id, 'wave', startMs: 0, endMs: 4000);
    ed.applySceneTime(700);
    final foxPose = cFox.animator.update(0).pose;
    final farmerPose = cFarmer.animator.update(0).pose;
    expect(foxPose.angles['leftUpperLeg']!, isNot(farmerPose.angles['leftUpperLeg'] ?? 0),
        reason: 'walk legs ≠ wave legs');
    // Wave lifts the farmer's arm far above the fox's walking arm at the
    // sampled moment (wave raises the arm through the middle of its cycle).
    expect((farmerPose.angles['leftUpperArm'] ?? 0).abs(),
        greaterThan((foxPose.angles['leftUpperArm'] ?? 0).abs() + 2));
  });

  test('actors can run the same clip out of phase (start offset)', () {
    final a = ed.addCharacter('fox');
    final b = ed.addCharacter('fox');
    ed.addAnimClip(a.id, 'walk', startMs: 0, endMs: 4000);
    ed.addAnimClip(b.id, 'walk', startMs: 700, endMs: 4700);
    ed.applySceneTime(300); // a inside its clip, b still outside (static idle)
    final pa = ed.controllerFor(a)!.animator.update(0).pose;
    final pb = ed.controllerFor(b)!.animator.update(0).pose;
    expect(Pose2D.maxDiff(pa, pb), greaterThan(0.5),
        reason: 'phase offset must desynchronise the actors');
  });

  test('scene z-order: the higher object paints in front', () {
    final a = ed.addCharacter('fox'); // z 1
    final b = ed.addCharacter('tiger'); // z 2
    expect(ed.objectsInPaintOrder.last.id, b.id);
    a.zIndex = 5;
    expect(ed.objectsInPaintOrder.last.id, a.id);
  });

  test('props attach per character and reach the scene controller', () async {
    final lib = Library2DProvider(repo: Character2DRepository());
    final edWithLib = EditorProvider(lib);
    final character = Character2D(
      id: 'fox_prop',
      specId: 'fox',
      name: 'Fox with stick',
      props: [PropAttachment(id: 'p1', kind: PropKind.stick, attachedBoneId: 'rightHand')],
    );
    await lib.saveVariantFull(character);
    final obj = edWithLib.addCharacter('fox_prop');
    final c = edWithLib.controllerFor(obj)!;
    expect(c.props, hasLength(1));
    expect(c.props.first.attachedBoneId, 'rightHand');
    // The puppet renders with props through the same painter the export uses
    // (paintScene → PuppetPainter(props)).
    expect(() => edWithLib.applySceneTime(1200), returnsNormally);
  });

  test('multi-actor project round-trips (both actors + their clips)', () async {
    final fox = ed.addCharacter('fox');
    final farmer = ed.addCharacter('bd_farmer_male');
    ed.addAnimClip(fox.id, 'run', startMs: 0, endMs: 3000);
    ed.addAnimClip(farmer.id, 'talk', startMs: 500, endMs: 3500);
    ed.upsertKeyframe(fox.id, atMs: 0);

    final doc = ProjectDocument(id: 'scene1', name: 'Two-hander', orientation: 'landscape', canvasWidth: 1920, canvasHeight: 1080);
    captureEditorIntoProject(ed, doc);
    final json = jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;

    final ed2 = EditorProvider(Library2DProvider(repo: Character2DRepository()));
    applyProjectToEditor(ed2, ProjectDocument.fromJson(json));
    await applyProjectRuntimeToEditor(ed2, ProjectDocument.fromJson(json));
    expect(ed2.objects, hasLength(2));
    expect(ed2.objects.map((o) => o.characterId), containsAll(['fox', 'bd_farmer_male']));
    final fox2 = ed2.objects.firstWhere((o) => o.characterId == 'fox');
    expect(ed2.timeline.trackOf(fox2.id)!.clips.first.animId, 'run');
  });
}
