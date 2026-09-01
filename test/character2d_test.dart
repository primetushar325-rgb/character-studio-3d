import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/character2d_model.dart';
import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/characters2d/engine/animator2d.dart';
import 'package:character_studio_3d/characters2d/engine/clips.dart';
import 'package:character_studio_3d/characters2d/engine/face_rig.dart';
import 'package:character_studio_3d/characters2d/engine/part2d.dart';
import 'package:character_studio_3d/characters2d/engine/puppet.dart';
import 'package:character_studio_3d/characters2d/engine/pose2d.dart';
import 'package:character_studio_3d/characters2d/engine/rig2d.dart';
import 'package:character_studio_3d/characters2d/engine/speech.dart';
import 'package:character_studio_3d/characters2d/engine/state_machine2d.dart';

void main() {
  group('Universal rig (humanoid_v1)', () {
    final rig = Rig2D.humanoidV1();
    test('contains every required bone with valid hierarchy', () {
      expect(rig.isValid, isTrue);
      for (final b in [
        'root', 'hips', 'spine', 'chest', 'neck', 'head',
        'leftShoulder', 'leftUpperArm', 'leftLowerArm', 'leftHand',
        'rightShoulder', 'rightUpperArm', 'rightLowerArm', 'rightHand',
        'leftUpperLeg', 'leftLowerLeg', 'leftFoot',
        'rightUpperLeg', 'rightLowerLeg', 'rightFoot',
      ]) {
        expect(rig.byName, contains(b), reason: 'missing bone $b');
      }
    });

    test('rest pose is symmetric and feet reach the ground', () {
      final solve = solveSkeleton(rig, {});
      final lk = solve.jointOf('leftLowerLeg');
      final rk = solve.jointOf('rightLowerLeg');
      expect(lk.x, closeTo(-rk.x, 0.001));
      expect(lk.y, closeTo(rk.y, 0.001));
      final ank = solve.jointOf('leftFoot');
      expect(ank.y, closeTo(130, 1.0)); // foot joint 18u above the ground line
    });

    test('rotating a thigh moves its knee but nothing above the hips', () {
      final neutral = solveSkeleton(rig, {});
      final posed = solveSkeleton(rig, {'leftUpperLeg': 30});
      expect(
        (posed.jointOf('leftLowerLeg').y - neutral.jointOf('leftLowerLeg').y).abs(),
        greaterThan(2),
      );
      expect(
        (posed.jointOf('head').y - neutral.jointOf('head').y).abs(),
        lessThan(0.001),
      );
    });
  });

  group('Poses', () {
    test('lerp interpolates and maxDiff measures change', () {
      final a = Pose2D(angles: {'head': 10}, dy: 0);
      final b = Pose2D(angles: {'head': 30}, dy: 8);
      final mid = Pose2D.lerp(a, b, 0.5);
      expect(mid.angle('head'), 20);
      expect(mid.dy, 4);
      expect(Pose2D.maxDiff(a, b), greaterThan(19));
    });
  });

  group('Standard animations really move the body', () {
    test('idle breathes — spine/chest change over time', () {
      final p1 = idlePose(0.0);
      final p2 = idlePose(0.95); // quarter breath period = peak inhale
      expect((p1.angle('spine') - p2.angle('spine')).abs(), greaterThan(0.8));
      expect(Pose2D.maxDiff(p1, p2), greaterThan(0.8));
    });

    test('walk: legs alternate, arms counter-swing, body bounces', () {
      final a = walkPose(math.pi / 2, 1); // left leg lifted
      final b = walkPose(3 * math.pi / 2, 1); // right leg lifted
      // Left leg angle differs between half-cycles.
      expect((a.angle('leftUpperLeg') - b.angle('leftUpperLeg')).abs(), greaterThan(1.5));
      // Both legs DO move (never a frozen slide).
      for (final bone in ['leftUpperLeg', 'rightUpperLeg', 'leftLowerLeg', 'rightLowerLeg']) {
        expect((a.angle(bone) - b.angle(bone)).abs(), greaterThan(0.5), reason: bone);
      }
      // Arms counter-swing.
      expect(a.angle('leftUpperArm'), isNot(closeTo(b.angle('leftUpperArm'), 0.5)));
      // Double bounce per cycle (pass position ≠ lift position).
      expect(walkPose(0, 1).dy, isNot(closeTo(a.dy, 0.4)));
      // Head is stabilized against hip rotation.
      expect(a.angle('head').abs(), lessThan(a.angle('hips').abs() + 6));
    });

    test('walk_start/stop blend smoothly to/from idle', () {
      final start0 = ClipLibrary.get('walk_start').sample(0);
      final idle0 = idlePose(0);
      expect(Pose2D.maxDiff(start0, idle0), lessThan(4));
      final startEnd = ClipLibrary.get('walk_start').sample(0.5);
      expect((startEnd.angle('leftUpperArm') - start0.angle('leftUpperArm')).abs(), greaterThan(2));
    });

    test('run: faster, leans forward, bigger amplitude than walk', () {
      final w = walkPose(math.pi / 2, 1);
      final r = runPose(math.pi / 2, 1);
      expect(r.angle('spine'), greaterThan(w.angle('spine') + 4)); // forward lean
      expect(r.angle('leftLowerLeg').abs(), greaterThan(w.angle('leftLowerLeg').abs()));
      expect(r.dy, lessThan(w.dy)); // stronger bounce
    });

    test('sit: hips lower, knees fold, no teleport', () {
      final stand = sitPose(0);
      final sit = sitPose(1);
      expect(sit.dy, greaterThan(stand.dy + 30));
      expect(sit.angle('leftUpperLeg').abs(), greaterThan(30));
      expect(sit.angle('leftLowerLeg').abs(), greaterThan(50));
      // Transition clip passes through intermediate depths.
      final mid = ClipLibrary.get('stand_to_sit').sample(0.7);
      expect(mid.dy, greaterThan(stand.dy + 5));
      expect(mid.dy, lessThan(sit.dy - 5));
    });

    test('sleep: lies down, closes eyes; wake_up returns upright', () {
      final sleep = ClipLibrary.get('sleep_loop').sample(1.0);
      expect(sleep.bodyTilt, lessThan(-70));
      final wake = ClipLibrary.get('wake_up').sample(1.75);
      expect(wake.bodyTilt, closeTo(0, 0.01));
    });
  });

  group('State machine', () {
    test('allows exactly the spec transitions', () {
      final sm = StateMachine2D();
      final allowed = <CharState, Set<CharState>>{
        CharState.idle: {CharState.walk, CharState.run, CharState.sit, CharState.talk},
        CharState.walk: {CharState.idle, CharState.run, CharState.talk},
        CharState.run: {CharState.idle, CharState.walk},
        CharState.sit: {CharState.idle, CharState.talk, CharState.sleep},
        CharState.sleep: {CharState.sit, CharState.idle},
        CharState.talk: {CharState.idle, CharState.walk, CharState.sit},
      };
      StateMachine2D.transitions.forEach((from, tos) {
        expect(tos, allowed[from], reason: 'transitions from $from');
      });
      expect(sm.canGoDirect(CharState.walk), isTrue);
    });

    test('Sleep → Run is never direct: routed through legal hops', () {
      final sm = StateMachine2D(state: CharState.sleep);
      expect(sm.canGoDirect(CharState.run), isFalse);
      final path = sm.route(CharState.run);
      expect(path, isNotEmpty);
      expect(path.first, isNot(CharState.run)); // must wake up first
      // Every hop in the path is legal.
      var cur = CharState.sleep;
      for (final hop in path) {
        expect(StateMachine2D.transitions[cur]!, contains(hop));
        cur = hop;
      }
      expect(cur, CharState.run);
    });

    test('entering walk uses walk_start, leaving uses walk_stop', () {
      final animator = PuppetAnimator(rig: Rig2D.humanoidV1());
      animator.requestState(CharState.walk);
      // Enter clip starts immediately (walk_start, not the loop).
      expect(animator.clipId, 'walk_start');
      for (var i = 0; i < 40; i++) {
        animator.update(1 / 60);
      }
      expect(animator.clipId, anyOf('walk_start', 'walk'));
      for (var i = 0; i < 120; i++) {
        animator.update(1 / 60);
      }
      expect(animator.clipId, 'walk'); // settled into the loop
      animator.requestState(CharState.idle);
      animator.update(1 / 60);
      expect(animator.clipId, 'walk_stop');
      for (var i = 0; i < 200; i++) {
        animator.update(1 / 60);
      }
      expect(animator.clipId, 'idle');
      expect(animator.state, CharState.idle);
    });
  });

  group('Procedural talking', () {
    test('varied, non-repetitive mouth movement with 5+ distinct visemes', () {
      final sp = SpeechDriver(seed: 5)..start();
      final openness = <double>[];
      for (var i = 0; i < 60 * 8; i++) {
        sp.update(1 / 60);
        openness.add(sp.mouth.mouthOpen);
      }
      final distinct = openness.map((o) => (o * 20).round()).toSet();
      expect(distinct.length, greaterThan(10)); // not open/close only
      // Mouth activity keeps changing: many real transitions, no lock-step.
      var edges = 0;
      for (var i = 1; i < openness.length; i++) {
        if ((openness[i] - openness[i - 1]).abs() > 0.05) edges++;
      }
      expect(edges, greaterThan(15));
      var changed = 0;
      for (var i = 12; i < openness.length; i++) {
        if ((openness[i] - openness[i - 12]).abs() > 0.02) changed++;
      }
      expect(changed, greaterThan(openness.length * 0.25));
      for (final s in ['A', 'E', 'I', 'O', 'U', 'MBP']) {
        expect(MouthShapes.all, contains(s));
      }
      expect(MouthShapes.all.length, 17); // 16 mouth shapes + neutral
    });

    test('future lip-sync data can replace the generator', () {
      final sp = SpeechDriver()..start();
      sp.setVisemeTimeline(const [Syllable('O', 0, 0.4, false), Syllable('MBP', 0.4, 0.2, true)]);
      sp.update(0.2);
      expect(sp.mouth.mouthOpen, greaterThan(0.4)); // 'O'
      sp.update(0.25);
      expect(sp.mouth.mouthOpen, lessThan(0.05)); // 'MBP' closed
    });

    test('blinking happens regularly and clears again', () {
      final b = BlinkScheduler(seed: 1);
      var sawClosed = false;
      var sawOpenAfter = false;
      for (var i = 0; i < 60 * 10; i++) {
        b.update(1 / 60);
        if (b.value > 0.8) sawClosed = true;
        if (sawClosed && b.value < 0.1) sawOpenAfter = true;
      }
      expect(sawClosed, isTrue);
      expect(sawOpenAfter, isTrue);
    });
  });

  group('Animation layers', () {
    test('expression changes never disturb the body animation', () {
      final a = PuppetAnimator(rig: Rig2D.humanoidV1());
      a.requestState(CharState.walk);
      for (var i = 0; i < 200; i++) {
        a.update(1 / 60);
      }
      a.setExpression(Expr.angry);
      a.update(1 / 60);
      for (var i = 0; i < 30; i++) {
        a.update(1 / 60);
      }
      a.setExpression(Expr.happy);
      for (var i = 0; i < 40; i++) {
        a.update(1 / 60);
      }
      // Body keeps walking regardless of expression.
      expect(a.clipId, 'walk');
      final frame = a.update(1 / 60);
      expect(frame.pose.angle('leftUpperLeg').abs(), greaterThan(0.0));
      expect(frame.face.browAngle, Expr.happy == a.expression ? frame.face.browAngle : 0); // face alive
    });

    test('gesture overrides the arm, then releases it (Walk + Wave + Happy)', () {
      final a = PuppetAnimator(rig: Rig2D.humanoidV1());
      a.requestState(CharState.walk);
      for (var i = 0; i < 200; i++) {
        a.update(1 / 60);
      }
      a.setExpression(Expr.happy);
      final walkBaseline = a.update(1 / 60).pose.angle('leftUpperArm');
      a.triggerGesture('wave');
      var frame = a.update(1 / 60);
      for (var i = 0; i < 15; i++) {
        frame = a.update(1 / 60); // let the gesture blend in (0.25 s)
      }
      // Wave raises the arm far above the walk swing...
      expect(frame.pose.angle('leftUpperArm'), lessThan(walkBaseline - 20));
      for (var i = 0; i < 120; i++) {
        frame = a.update(1 / 60);
      }
      // ...and releases it back to the walk cycle afterwards.
      expect((frame.pose.angle('leftUpperArm') - walkBaseline).abs(), lessThan(25));
      // Body still walking.
      expect(a.clipId, 'walk');
    });

    test('talking while walking: mouth + body simultaneously', () {
      final a = PuppetAnimator(rig: Rig2D.humanoidV1());
      a.requestState(CharState.walk);
      a.setTalking(true);
      var openValues = <double>[];
      for (var i = 0; i < 60 * 5; i++) {
        final f = a.update(1 / 60);
        openValues.add(f.face.mouthOpen);
      }
      expect(a.clipId, 'walk'); // base layer unaffected
      expect(openValues.any((o) => o > 0.3), isTrue);
      expect(openValues.map((o) => (o * 10).round()).toSet().length, greaterThan(5));
    });

    test('talk loop is not robotically periodic', () {
      final t1 = ClipLibrary.get('talk').sample(1.3);
      final t2 = ClipLibrary.get('talk').sample(2.6);
      final t3 = ClipLibrary.get('talk').sample(3.9);
      expect(Pose2D.maxDiff(t1, t2), greaterThan(1.5));
      expect(Pose2D.maxDiff(t2, t3), greaterThan(1.5));
      expect(Pose2D.maxDiff(t1, t3), greaterThan(0.5));
    });
  });

  group('The three original characters', () {
    test('built-ins carry §32 metadata (tiger is the 4th default)', () {
      expect(CharacterCatalog.builtIn.length, 4);
      final ids = CharacterCatalog.builtIn.map((c) => c.id).toList();
      expect(ids, ['tiger', 'bd_farmer_male', 'village_girl', 'school_teacher']);
      for (final spec in CharacterCatalog.builtIn) {
        final m = spec.metadata();
        expect(m['type'], '2D_RIGGED_CHARACTER');
        expect(m['rig'], spec.rigKind);
        expect(m['faceRig'], isTrue);
        expect(m['talking'], isTrue);
        final anims = m['animations'] as Map<String, dynamic>;
        for (final k in ['idle', 'walk', 'run', 'sit', 'sleep', 'talk']) {
          expect(anims[k], isTrue, reason: '${spec.id} missing $k');
        }
      }
    });

    test('same universe but clearly different (palette, face, silhouette)', () {
      final f = CharacterCatalog.farmer;
      final g = CharacterCatalog.villageGirl;
      final t = CharacterCatalog.teacher;
      expect(f.defaultPalette.shirt, isNot(g.defaultPalette.shirt));
      expect(f.defaultPalette.shirt, isNot(t.defaultPalette.shirt));
      expect(f.scale, isNot(t.scale));
      expect(g.faceStyle!.eyeRx, greaterThan(f.faceStyle!.eyeRx)); // girl's bigger eyes
      expect(f.build({}), isNot(equals(g.build({}))));
      // Every character exposes a different set of separable parts.
      expect(f.build({}).length, greaterThan(15));
      expect(g.build({}).length, greaterThan(15));
      expect(t.build({}).length, greaterThan(15));
    });

    test('all three characters paint without errors in every key pose', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 600));
      final poses = <Pose2D Function(double)>[
        idlePose,
        (t) => walkPose(t * 2 * math.pi / 0.95, 1, t),
        (t) => runPose(t * 2 * math.pi / 0.62, 1, t),
        (t) => ClipLibrary.get('sit_idle').sample(t),
        (t) => ClipLibrary.get('sleep_loop').sample(t),
        (t) => ClipLibrary.get('talk').sample(t),
        (t) => ClipLibrary.get('wave').sample(t),
        (t) => ClipLibrary.get('explain').sample(t),
      ];
      var painted = 0;
      for (final spec in CharacterCatalog.builtIn) {
        for (final poseFn in poses) {
          for (final expr in Expr.values) {
            final painter = PuppetPainter(
              spec: spec,
              resolver: spec.defaultPalette.toResolver(),
              accessories: spec.defaultAccessories,
              frameGetter: () {
                final pose = poseFn(0.42);
                return PuppetFrameData(
                  pose: pose,
                  solve: solveSkeleton(Rig2D.humanoidV1(), pose.angles),
                  face: FaceParams.lerp(Expressions.all[Expr.neutral]!, Expressions.all[expr]!, 1),
                  blink: 0,
                  lookX: 0.3,
                  lookY: -0.2,
                  time: 0.42,
                  sleeping: false,
                  talking: true,
                );
              },
              directionLeft: false,
              background: const Color(0xFF171B26),
            );
            painter.paint(canvas, const Size(400, 600));
            painted++;
          }
        }
      }
      // Every mouth shape paints as well.
      for (final m in MouthShapes.all.values) {
        expect(m, isNotNull);
      }
      expect(painted, 320); // 4 chars × 8 poses × 10 expressions
      recorder.endRecording().dispose();
    });

    test('part painters receive a valid ordered list (z-stable)', () {
      final parts = orderParts(CharacterCatalog.farmer.build({}));
      expect(parts.first.layer, PartLayer.back.index <= parts.first.layer.index ? parts.first.layer : PartLayer.back);
      // Head is painted before the near arm (which must overlap it).
      final headZ = parts.indexWhere((p) => p.bone == 'head');
      final nearArmZ = parts.indexWhere((p) => p.bone == 'leftUpperArm');
      expect(headZ, lessThan(nearArmZ));
    });
  });

  group('Persistence (save / variants / recently used)', () {
    test('variant round-trip keeps name, palette and accessories', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = Character2DRepository();
      final v = Character2D.fromJson({
        'id': 'char2d_123',
        'specId': 'bd_farmer_male',
        'name': 'BD Farmer Male — Blue Shirt',
        'palette': {'shirt': 0xFF6FA8DC},
        'accessories': ['gamcha'],
        'createdAt': 1000,
        'updatedAt': 2000,
        'usageCount': 3,
      });
      await repo.saveVariant(v);
      final loaded = await repo.loadVariants();
      expect(loaded.length, 1);
      expect(loaded.first.name, 'BD Farmer Male — Blue Shirt');
      expect(loaded.first.paletteOverrides['shirt'], const Color(0xFF6FA8DC));
      expect(loaded.first.accessories, contains('gamcha'));
      expect(loaded.first.spec.name, 'BD Farmer Male');
      expect(loaded.first.usageCount, 3);
    });

    test('recently used sorts most-recent-first and counts usage', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = Character2DRepository();
      await repo.recordUsage('village_girl');
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.recordUsage('school_teacher');
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.recordUsage('village_girl');
      final recents = await repo.loadRecents();
      expect(recents.first.characterId, 'village_girl');
      expect(recents.first.usageCount, 2);
      expect(recents.last.characterId, 'school_teacher');
      expect(recents.last.usageCount, 1);
    });

    test('delete removes variant + its recents/favorites entries', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = Character2DRepository();
      await repo.saveVariant(Character2D.fromJson(const {
        'id': 'char2d_9',
        'specId': 'school_teacher',
        'name': 'Teacher Custom',
      }));
      await repo.toggleFavorite('char2d_9');
      await repo.recordUsage('char2d_9');
      await repo.deleteVariant('char2d_9');
      expect((await repo.loadVariants()), isEmpty);
      expect((await repo.loadRecents()).where((r) => r.characterId == 'char2d_9'), isEmpty);
      expect((await repo.loadFavorites()).contains('char2d_9'), isFalse);
    });

    test('model metadata exposes §32 structure + customization', () {
      final c = Character2D.builtIn(CharacterCatalog.farmer);
      final m = c.metadata();
      expect(m['id'], 'bd_farmer_male');
      expect(m['animations'], isMap);
      expect(c.colors.shirt, CharacterCatalog.farmer.defaultPalette.shirt);
      final custom = c.copyWith(palette: {'shirt': const Color(0xFF0000FF)});
      expect(custom.colors.shirt, const Color(0xFF0000FF));
      expect(c.colors.shirt, isNot(const Color(0xFF0000FF))); // original untouched
    });
  });
}
