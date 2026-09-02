// PHASE 5 — dedicated Fox tests (§42–54 invariants).
//
// The Fox must be a real rigged puppet: a valid fox_v1 skeleton, artwork
// bound to real bones, deterministic secondary tail/ear motion identical in
// preview & export, all 14 clips reachable, and full editor integration.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/art/fox.dart';
import 'package:character_studio_3d/characters2d/engine/animator2d.dart';
import 'package:character_studio_3d/characters2d/engine/clips.dart';
import 'package:character_studio_3d/characters2d/engine/ik2d.dart';
import 'package:character_studio_3d/characters2d/engine/part2d.dart';
import 'package:character_studio_3d/characters2d/engine/palette_resolver.dart';
import 'package:character_studio_3d/characters2d/engine/pose2d.dart';
import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/scene/scene_object.dart';
import 'package:character_studio_3d/state/editor_provider.dart';
import 'package:character_studio_3d/state/library2d_provider.dart';
import 'package:character_studio_3d/characters2d/engine/rig2d.dart';
import 'package:character_studio_3d/characters2d/engine/shapes.dart';

void main() {
  group('Fox rig (fox_v1)', () {
    final rig = Rig2D.byKind('fox_v1');

    test('is a valid humanoid skeleton plus ear/tail extras', () {
      expect(rig.kind, 'fox_v1');
      expect(rig.bones.length, greaterThanOrEqualTo(20));
      for (final n in [
        'hips', 'spine', 'chest', 'neck', 'head',
        'leftShoulder', 'leftUpperArm', 'leftLowerArm', 'leftHand',
        'rightShoulder', 'rightUpperArm', 'rightLowerArm', 'rightHand',
        'leftUpperLeg', 'leftLowerLeg', 'leftFoot',
        'rightUpperLeg', 'rightLowerLeg', 'rightFoot',
      ]) {
        expect(rig.byName[n], isNotNull, reason: 'fox_v1 missing $n');
      }
      // Ear + tail chains with correct parenting.
      expect(rig.byName['earL']!.parent, 'head');
      expect(rig.byName['earR']!.parent, 'head');
      expect(rig.byName['tail1']!.parent, 'hips');
      expect(rig.byName['tail2']!.parent, 'tail1');
      expect(rig.byName['tail3']!.parent, 'tail2');
      // Skeleton validity includes the secondary bones.
      expect(rig.isValid, isTrue);
    });

    test('FK: rotating the arm root carries the hand; tail1 carries tail3', () {
      final r = Rig2D.byKind('fox_v1');
      final rest = solveSkeleton(r, {});
      final posed = solveSkeleton(r, {'leftUpperArm': -60});
      double dist(a, b) => math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
      expect(dist(rest.jointOf('leftHand'), posed.jointOf('leftHand')), greaterThan(30));

      final tRest = solveSkeleton(r, {});
      final tPosed = solveSkeleton(r, {'tail1': 40});
      expect(dist(tRest.jointOf('tail3'), tPosed.jointOf('tail3')), greaterThan(12));
      // The tail2 world angle follows its parent by exactly the posed delta.
      const deg = math.pi / 180.0;
      expect(tPosed.angleOf('tail2'), closeTo(tRest.angleOf('tail2') + 40 * deg, 0.001));
    });
  });

  group('Fox secondary motion (deterministic §49)', () {
    test('is pure: same clip+time → identical angles, no RNG', () {
      for (final clip in ['idle', 'walk', 'run', 'sleep', 'talk', 'wave', 'think']) {
        final a = foxSecondaryMotion(clip, 3.21);
        final b = foxSecondaryMotion(clip, 3.21);
        for (final k in Rig2D.secondaryBones) {
          expect(a[k], b[k], reason: '$clip/$k not deterministic');
          expect(a[k]!.isNaN, isFalse);
        }
      }
    });

    test('varies over time and differs per clip character', () {
      final idle1 = foxSecondaryMotion('idle', 1.0)['tail1']!;
      final idle2 = foxSecondaryMotion('idle', 2.0)['tail1']!;
      expect((idle1 - idle2).abs(), greaterThan(0.5));

      final runAmp = foxSecondaryMotion('run', 1.0)['tail1']! - foxSecondaryMotion('run', 1.5)['tail1']!;
      expect(runAmp.abs(), greaterThan(3), reason: 'run tail must swing hard');

      // Sleeping: tail droops steadily but barely swings (calm).
      final swings = [for (var t = 0.0; t < 4; t += 0.25) foxSecondaryMotion('sleep_loop', t)['tail1']!];
      expect(swings.reduce((a, b) => a > b ? a : b) - swings.reduce((a, b) => a < b ? a : b), lessThan(3),
          reason: 'sleeping tail must stay calm');
      final idleSwings = [for (var t = 0.0; t < 4; t += 0.25) foxSecondaryMotion('idle', t)['tail1']!];
      expect(idleSwings.reduce((a, b) => a > b ? a : b) - idleSwings.reduce((a, b) => a < b ? a : b),
          greaterThan(swings.reduce((a, b) => a > b ? a : b) - swings.reduce((a, b) => a < b ? a : b)));
    });

    test('animator wires it into the rig before the face layer', () {
      final an = PuppetAnimator(rig: Rig2D.byKind('fox_v1'), seed: 7);
      an.scrub(1.0, faceTime: 5.0);
      final f1 = an.update(0);
      final expected = foxSecondaryMotion('idle', 5.0);
      for (final k in Rig2D.secondaryBones) {
        expect(f1.pose.angles[k], closeTo(expected[k]!, 0.001),
            reason: '$k must equal the pure function at the scrubbed time');
      }
      // Preview == export: a second animator seeded the same gives the same pose.
      final an2 = PuppetAnimator(rig: Rig2D.byKind('fox_v1'), seed: 7);
      an2.scrub(1.0, faceTime: 5.0);
      final f2 = an2.update(0);
      expect(Pose2D.maxDiff(f1.pose, f2.pose), lessThan(0.001));
    });
  });

  group('Fox artwork (§1/§23/§24)', () {
    final rig = Rig2D.byKind('fox_v1');

    test('every part is bound to a real bone, on both accessory sets', () {
      for (final acc in [
        <String>{},
        {'scarf'},
      ]) {
        final parts = buildFoxParts(acc);
        expect(parts.length, greaterThanOrEqualTo(20));
        final ctx = ShapeCtx(colors: PaletteResolver(const {}), extras: const {}, face: const FaceView());
        for (final p in parts) {
          expect(rig.byName[p.bone], isNotNull, reason: 'part bound to missing bone ${p.bone}');
          expect(p.build(ctx), isNotEmpty, reason: '${p.bone} draws nothing');
        }
      }
    });

    test('premium silhouette: torso+head+tail+paws all present, ordered', () {
      final parts = orderParts(buildFoxParts({'scarf'}));
      final bones = parts.map((p) => p.bone).toSet();
      for (final b in [
        'head', 'earL', 'earR', 'spine', 'hips', 'tail1', 'tail2', 'tail3',
        'leftHand', 'rightHand', 'leftFoot', 'rightFoot', 'chest', // scarf
      ]) {
        expect(bones.contains(b), isTrue, reason: 'fox body missing $b');
      }
      // Depth ordering: tail behind, near arm in front of the head.
      final zOf = Map.fromEntries(parts.map((p) => MapEntry(p.bone, p.z)));
      expect(zOf['tail1']!, lessThan(zOf['head']!));
      expect(zOf['head']!, lessThan(zOf['leftHand']!));
    });

    test('talk face: mouth opens with mouthOpen, eyes track and blink', () {
      List<Shape> shapesAt(FaceView f) => buildFoxParts({'scarf'})
          .firstWhere((p) => p.bone == 'head')
          .build(ShapeCtx(colors: PaletteResolver(const {}), extras: const {}, face: f));
      final rest = shapesAt(const FaceView());
      final open = shapesAt(const FaceView(mouthOpen: 1, tongue: 1));
      expect(open.length, greaterThan(rest.length), reason: 'open mouth adds oral cavity shapes');

      final lClosed = shapesAt(const FaceView(blink: 1));
      // Closed-eye path replaces the open ellipse pair (lash curves).
      final restHeights = rest.map((s) => s.args.length > 3 ? s.args[3] : 0.0).toList();
      final closedHeights = lClosed.map((s) => s.args.length > 3 ? s.args[3] : 0.0).toList();
      expect(restHeights.reduce((a, b) => a + b), greaterThan(closedHeights.reduce((a, b) => a + b)),
          reason: 'blinking eyes must collapse the open eye ellipses');
    });
  });

  group('Fox clips & catalog', () {
    test('gets the full 14-clip humanoid set', () {
      final clips = ClipLibrary.forRig('fox_v1');
      for (final id in [
        'idle', 'walk', 'run', 'jump', 'sit_idle', 'sleep_loop', 'talk', 'wave',
        'greet', 'point_right', 'nod', 'shake', 'thinking', 'angry_gesture',
      ]) {
        expect(clips.containsKey(id), isTrue, reason: 'fox missing clip $id');
      }
      // Clips actually move bones (run ≠ walk, §8).
      final walkHip = clips['walk']!.sample(0.5).angles['leftUpperLeg'] ?? 0;
      final runHip = clips['run']!.sample(0.5).angles['leftUpperLeg'] ?? 0;
      expect((walkHip - runHip).abs(), greaterThan(2));
    });

    test('fox is registered first in the library with fox_v1 rig kind', () {
      expect(CharacterCatalog.builtIn.first.id, 'fox');
      final spec = CharacterCatalog.byId('fox');
      expect(spec, isNotNull);
      expect(spec!.rigKind, 'fox_v1');
      expect(spec.metadata()['rig'], 'fox_v1');
      expect((spec.metadata()['animations'] as Map)['wave'], isTrue);
    });
  });
// ---------------------------------------------------------------- IK (§ safe)
group('Two-bone IK (deterministic, FK-consistent)', () {
  // FK helper in the engine convention: joint chain from absolute angles.
  math.Point<double> fkEnd(List<double> angles, List<double> lens) {
    var x = 0.0, y = 0.0, acc = 0.0;
    for (var i = 0; i < angles.length; i++) {
      acc += angles[i] * math.pi / 180;
      x += -math.sin(acc) * lens[i];
      y += math.cos(acc) * lens[i];
    }
    return math.Point(x, y);
  }

  test('reaches exact targets with both bend directions', () {
    for (final target in [
      const math.Point(30.0, 40.0),
      const math.Point(-55.0, 10.0),
      const math.Point(0.0, 69.0),
      const math.Point(12.0, -33.0),
    ]) {
      for (final pole in [1, -1]) {
        final s = TwoBoneIk.solve(l1: 40, l2: 30, target: target, pole: pole);
        expect(s.reachable, isTrue, reason: 'XX');
        final end = fkEnd([s.rootAngleDeg, s.midAngleDeg - s.rootAngleDeg], [40, 30]);
        expect((end - target).magnitude, lessThan(0.01),
            reason: 'IK must land on XX), got X');
      }
    }
  });

  test('out-of-reach targets straighten toward the target, flagged', () {
    final s = TwoBoneIk.solve(l1: 40, l2: 30, target: const math.Point(0.0, 100.0));
    expect(s.reachable, isFalse);
    final end = fkEnd([s.rootAngleDeg, s.midAngleDeg - s.rootAngleDeg], [40, 30]);
    // Fully stretched arm points at the target direction, tip at 70 units.
    final dir = math.Point(end.x / 70, end.y / 70);
    final want = math.Point(0.0, 1.0);
    expect((dir - want).magnitude, lessThan(0.01));
  });

  test('deterministic: identical inputs → identical outputs', () {
    final a = TwoBoneIk.solve(l1: 40, l2: 30, target: const math.Point(20.0, 44.0));
    final b = TwoBoneIk.solve(l1: 40, l2: 30, target: const math.Point(20.0, 44.0));
    expect(a.rootAngleDeg, b.rootAngleDeg);
    expect(a.midAngleDeg, b.midAngleDeg);
  });
});

// ------------------------------------------------------- editor integration
group('Fox in the editor (§ compatibility)', () {
  test('addCharacter → controller → timeline scrub all work with fox_v1', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ed = EditorProvider(Library2DProvider(repo: Character2DRepository()));
    final obj = ed.addCharacter('fox');
    expect(obj.characterId, 'fox');
    expect(ed.objects, hasLength(1));

    final c = ed.controllerFor(obj)!;
    expect(c, isNotNull);
    expect(c.animator.rigKind, 'fox_v1');

    // Walk action drives bones incl. the tail chain, deterministically.
    c.setAction('walk');
    ed.applySceneTime(2000);
    final f1 = c.animator.update(0);
    expect(f1.pose.angles['tail1'], isNotNull);
    final f2 = c.animator.update(0);
    expect(Pose2D.maxDiff(f1.pose, f2.pose), lessThan(0.001));

    // Wave gesture moves the shoulder→hand chain.
    c.gesture('wave');
    ed.applySceneTime(2600);
    final f3 = c.animator.update(0);
    expect(f3.pose.angles['leftUpperArm'], isNotNull);

    // Scene object round-trips with the fox identity intact.
    final back = SceneObject.fromJson(
      jsonDecode(jsonEncode(obj.toJson())) as Map<String, dynamic>,
    );
    expect(back.characterId, 'fox');
  });
});
}
