import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/characters2d/puppet_controller.dart';
import 'package:character_studio_3d/project/project_document.dart';
import 'package:character_studio_3d/scene/scene_object.dart';
import 'package:character_studio_3d/state/editor_provider.dart';
import 'package:character_studio_3d/state/library2d_provider.dart';
import 'package:flutter/material.dart';

import 'package:character_studio_3d/screens/editor/timeline_panel.dart';
import 'package:character_studio_3d/timeline/playback_clock.dart';
import 'package:character_studio_3d/timeline/story_timeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Easing (§11)', () {
    test('exact curve values', () {
      expect(KfEase.linear.apply(.5), .5);
      expect(KfEase.easeIn.apply(.5), closeTo(.25, 1e-9));
      expect(KfEase.easeOut.apply(.5), closeTo(.75, 1e-9));
      final io = KfEase.easeInOut;
      expect(io.apply(0), 0);
      expect(io.apply(.5), closeTo(.5, 1e-9));
      expect(io.apply(1), closeTo(1, 1e-9));
      // symmetric: easeInOut(0.25) + easeInOut(0.75) == 1
      expect(io.apply(.25) + io.apply(.75), closeTo(1, 1e-9));
    });

    test('label round-trip', () {
      for (final e in KfEase.values) {
        expect(KfEaseX.fromLabel(e.label), e);
        expect(KfEaseX.fromJson(e.json), e);
      }
    });
  });

  group('Clip local time (§4/§15/§16)', () {
    AnimClip clip({bool loop = true, double speed = 1}) => AnimClip(
        id: 'c1', animId: 'walk', startMs: 1000, endMs: 6000,
        speed: speed, loop: loop);

    test('1x maps scene time to local time', () {
      final c = clip();
      expect(c.localMs(1000, 1050), 0);
      expect(c.localMs(2500, 2000), 1500); // source clip 2s
    });

    test('loop wraps instead of duplicating keyframes (§15)', () {
      final c = clip(); // walk source 1.05s
      // 4s into the clip → wraps many times, never negative/overlong
      final l = c.localMs(5000, 1050);
      expect(l >= 0 && l < 1050, isTrue);
      expect(l, 5000 - 1000 - (4000 ~/ 1050) * 1050);
    });

    test('one-shot clamps: holds first/last frame', () {
      final c = clip(loop: false);
      expect(c.localMs(500, 1050), 0); // before clip start
      expect(c.localMs(9000, 1050), 1050); // past end → last frame held
    });

    test('2x speed scales local time (§16)', () {
      final c = clip(speed: 2);
      expect(c.localMs(2000, 3000), 2000); // (2000-1000)*2 = 2000, no wrap
      expect(c.localMs(3000, 3000), 1000); // (3000-1000)*2=4000 % 3000 = 1000
    });

    test('activeAt boundaries', () {
      final c = clip();
      expect(c.activeAt(999), isFalse);
      expect(c.activeAt(1000), isTrue);
      expect(c.activeAt(5999), isTrue);
      expect(c.activeAt(6000), isFalse);
    });
  });

  group('Transform keyframes (§10/§11) — TEST D/E/F', () {
    TimelineTrack trackWith(List<TransformKeyframe> kfs) =>
        TimelineTrack(objectId: 'o1', keyframes: kfs);

    test('linear interpolation 0.2 → 0.9 across 0–5s', () {
      final tr = trackWith([
        TransformKeyframe(id: 'a', timeMs: 0, props: {'x': .2}),
        TransformKeyframe(id: 'b', timeMs: 5000, props: {'x': .9}),
      ]);
      expect(evalProp(tr, 'x', 0, .5), closeTo(.2, 1e-9));
      expect(evalProp(tr, 'x', 2500, .5), closeTo(.55, 1e-9)); // midpoint
      expect(evalProp(tr, 'x', 5000, .5), closeTo(.9, 1e-9));
      // holds outside the keyed range
      expect(evalProp(tr, 'x', 7000, .5), closeTo(.9, 1e-9));
    });

    test('easeInOut changes the midpoint path (TEST F)', () {
      final tr = trackWith([
        TransformKeyframe(id: 'a', timeMs: 0, props: {'scaleX': 1}),
        TransformKeyframe(id: 'b', timeMs: 5000, props: {'scaleX': 1.5}, ease: KfEase.easeInOut),
      ]);
      final mid = evalProp(tr, 'scaleX', 2500, 1);
      expect(mid, closeTo(1.25, 1e-9)); // symmetric curve hits exact middle
      // quarter point is slower than linear (eases in)
      final q = evalProp(tr, 'scaleX', 1250, 1);
      expect(q < 1.125, isTrue);
    });

    test('partial props: keyed x leaves y at base (§11 missing properties)', () {
      final obj = textObject(id: 'o1', zIndex: 1);
      obj.transform..x = .5..y = .8;
      final tr = trackWith([
        TransformKeyframe(id: 'a', timeMs: 0, props: {'x': .1}),
        TransformKeyframe(id: 'b', timeMs: 2000, props: {'x': .4}),
      ]);
      final ev = evalTransform(obj, tr, 1000);
      expect(ev.x, closeTo(.25, 1e-9));
      expect(ev.y, closeTo(.8, 1e-9)); // untouched by keyframes
    });

    test('single keyframe holds a constant value', () {
      final tr = trackWith([TransformKeyframe(id: 'a', timeMs: 1000, props: {'rotation': 45})]);
      expect(evalProp(tr, 'rotation', 0, 0), 45);
      expect(evalProp(tr, 'rotation', 19000, 0), 45);
    });

    test('multi-segment bracketing picks correct pair', () {
      final tr = trackWith([
        TransformKeyframe(id: 'a', timeMs: 0, props: {'x': 0}),
        TransformKeyframe(id: 'b', timeMs: 1000, props: {'x': 10}),
        TransformKeyframe(id: 'c', timeMs: 2000, props: {'x': 30}),
      ]);
      expect(evalProp(tr, 'x', 500, -1), closeTo(5, 1e-9));
      expect(evalProp(tr, 'x', 1500, -1), closeTo(20, 1e-9));
    });
  });

  group('Visibility ranges (§9) — TEST C', () {
    test('visible only 8s→12s', () {
      final tr = TimelineTrack(objectId: 't1', visClips: [
        VisibilityClip(startMs: 8000, endMs: 12000),
      ]);
      expect(tr.visibleAt(7999, baseVisible: true), isFalse);
      expect(tr.visibleAt(9000, baseVisible: true), isTrue);
      expect(tr.visibleAt(11000, baseVisible: true), isTrue);
      expect(tr.visibleAt(12000, baseVisible: true), isFalse); // TEST G: 15s gone
      expect(tr.visibleAt(15000, baseVisible: true), isFalse);
    });

    test('static hidden object stays hidden even inside its range', () {
      final tr = TimelineTrack(objectId: 't1', visClips: [VisibilityClip(startMs: 0, endMs: 20000)]);
      expect(tr.visibleAt(5000, baseVisible: false), isFalse);
    });

    test('no visibility clips = always visible', () {
      final tr = TimelineTrack(objectId: 't1');
      expect(tr.visibleAt(0, baseVisible: true), isTrue);
    });
  });

  group('StoryTimeline persistence (§19)', () {
    test('full timeline JSON round-trip — TEST H data', () {
      final tl = StoryTimeline(durationMs: 20000);
      final farmer = tl.ensureTrack('obj_f');
      farmer.clips.add(AnimClip(
          id: 'clip_1', animId: 'walk', startMs: 0, endMs: 5000,
          loop: true, blendInMs: 200, blendOutMs: 300));
      farmer.clips.add(AnimClip(
          id: 'clip_2', animId: 'wave', startMs: 5000, endMs: 8000, loop: false, speed: 1.5));
      farmer.keyframes.addAll([
        TransformKeyframe(id: 'kf1', timeMs: 0, props: {'x': .2, 'scaleX': 1}),
        TransformKeyframe(id: 'kf2', timeMs: 5000, props: {'x': .9, 'scaleX': 1.5}, ease: KfEase.easeInOut),
      ]);
      final text = tl.ensureTrack('obj_t');
      text.visClips.add(VisibilityClip(startMs: 8000, endMs: 12000));

      final back = StoryTimeline.fromJson(
          jsonDecode(jsonEncode(tl.toJson())) as Map<String, dynamic>?);
      expect(back.durationMs, 20000);
      expect(back.tracks.length, 2);
      final f2 = back.trackOf('obj_f')!;
      expect(f2.clips.length, 2);
      expect(f2.clips[0].animId, 'walk');
      expect(f2.clips[0].loop, true);
      expect(f2.clips[0].blendInMs, 200);
      expect(f2.clips[1].speed, 1.5);
      expect(f2.keyframes[1].ease, KfEase.easeInOut);
      expect(f2.keyframes[1].props['scaleX'], 1.5);
      expect(back.trackOf('obj_t')!.visClips.single.endMs, 12000);
    });

    test('null/legacy project timeline → clean 20s default', () {
      final back = StoryTimeline.fromJson(null);
      expect(back.durationMs, 20000);
      expect(back.tracks, isEmpty);
    });

    test('pruneTo drops orphaned tracks but keeps background', () {
      final tl = StoryTimeline();
      tl.ensureTrack('obj_gone');
      tl.ensureTrack(kBackgroundTrackId).visClips.add(VisibilityClip(startMs: 0, endMs: 5000));
      tl.pruneTo({'obj_other'});
      expect(tl.tracks.containsKey('obj_gone'), isFalse);
      expect(tl.tracks.containsKey(kBackgroundTrackId), isTrue);
    });
  });

  group('PlaybackClock (§2/§3)', () {
    test('seek never passes durationMs', () {
      final c = PlaybackClock(durationMs: 20000);
      c.seek(999999);
      expect(c.currentTimeMs, 20000);
      c.seek(-5);
      expect(c.currentTimeMs, 0);
    });

    test('steps and speed clamps', () {
      final c = PlaybackClock(durationMs: 20000);
      c.seek(10000);
      c.stepForward();
      expect(c.currentTimeMs, 10033);
      c.stepBackward();
      c.stepBackward();
      expect(c.currentTimeMs, 9967);
      c.setSpeed(99);
      expect(c.speed, 2.0);
      c.setSpeed(0.01);
      expect(c.speed, 0.25);
      expect(c.isPlaying, isFalse);
    });

    test('duration change is safe', () {
      final c = PlaybackClock(durationMs: 20000);
      c.seek(18000);
      c.durationMs = 10000;
      c.seek(c.currentTimeMs);
      expect(c.currentTimeMs, 10000);
    });
  });

  group('Snap (§6)', () {
    test('snaps to grid, zero and other clip edges', () {
      final tl = StoryTimeline(durationMs: 20000);
      final t = tl.ensureTrack('o1');
      t.clips.add(AnimClip(id: 'other', animId: 'walk', startMs: 0, endMs: 5000));
      // 10070 → 10000? no target nearby except 0.5s grid 10000
      expect(snapMs(10060, timeline: tl, thresholdMs: 100), 10000);
      // near other clip's end (5000)
      expect(snapMs(4960, timeline: tl, thresholdMs: 100), 5000);
      // near zero
      expect(snapMs(40, timeline: tl, thresholdMs: 100), 0);
      // far from anything: unchanged (clamped to duration)
      expect(snapMs(7323, timeline: tl, thresholdMs: 100), 7323);
      // respects exceptIds
      expect(snapMs(4960, timeline: tl, thresholdMs: 100, exceptIds: {'other'}), 5000); // grid 5000 still applies
    });
  });

  group('Scene evaluation in the editor (§20/§21) — TEST A/B/D/G', () {
    late Library2DProvider library;
    late EditorProvider ed;

    setUp(() {
      library = Library2DProvider(repo: Character2DRepository());
      ed = EditorProvider(library);
    });

    test('animation clips drive the character (walk 0–5s, wave 5–8s)', () {
      final obj = ed.addCharacter('bd_farmer_male');
      ed.addAnimClip(obj.id, 'walk', startMs: 0, endMs: 5000);
      ed.addAnimClip(obj.id, 'wave', startMs: 5000, endMs: 8000);

      ed.applySceneTime(2000); // TEST G @2s → walk
      final c = ed.controllerFor(obj)!;
      expect(c.animator.clipId, 'walk');
      // local time = scene time wrapped by the rig's real walk cycle length
      expect(c.animator.clipTime,
          closeTo(2.0 % c.animator.clipDuration, .01));
      expect(c.actionId, 'walk');

      ed.applySceneTime(6000); // TEST G @6s → wave
      expect(c.animator.clipId, 'wave');
      expect(c.actionId, 'wave');

      ed.applySceneTime(9000); // outside clips → static action (idle default)
      expect(c.animator.clipId, 'idle');
    });

    test('walk clip local time follows loop length', () {
      final obj = ed.addCharacter('bd_farmer_male');
      ed.addAnimClip(obj.id, 'walk', startMs: 0, endMs: 5000);
      ed.applySceneTime(4200); // 4.2s in
      final c = ed.controllerFor(obj)!;
      // walk source clip duration, looped
      final dur = c.animator.clipDuration;
      expect(dur, greaterThan(0));
      expect(c.animator.clipTime, lessThan(dur));
      expect(c.animator.clipTime, closeTo(4.2 % dur, .01));
    });

    test('transform keyframes move the object (TEST D)', () {
      final obj = ed.addText();
      obj.transform.x = .2;
      ed.clock.durationMs = 20000;
      ed.upsertKeyframe(obj.id, atMs: 0, props: {'x': .2});
      ed.upsertKeyframe(obj.id, atMs: 5000, props: {'x': .9});

      ed.applySceneTime(2500);
      expect(ed.transformFor(obj).x, closeTo(.55, 1e-6));

      ed.applySceneTime(0);
      expect(ed.transformFor(obj).x, closeTo(.2, 1e-6));
      ed.applySceneTime(5000);
      expect(ed.transformFor(obj).x, closeTo(.9, 1e-6));
    });

    test('visibility ranges hide objects in preview evaluation (TEST C/G)', () {
      final t = ed.addText();
      ed.setVisibilityClips(t.id, [VisibilityClip(startMs: 8000, endMs: 12000)]);
      ed.applySceneTime(10000);
      expect(ed.runtimeHidden(t.id), isFalse); // 10s: visible
      ed.applySceneTime(15000);
      expect(ed.runtimeHidden(t.id), isTrue); // 15s: gone
      ed.applySceneTime(9000);
      expect(ed.runtimeHidden(t.id), isFalse);
    });

    test('background visibility range applies', () {
      ed.setVisibilityClips(kBackgroundTrackId, [VisibilityClip(startMs: 0, endMs: 3000)]);
      ed.applySceneTime(1000);
      expect(ed.runtimeHidden(kBackgroundTrackId), isFalse);
      ed.applySceneTime(4000);
      expect(ed.runtimeHidden(kBackgroundTrackId), isTrue);
    });

    test('deterministic: same time → same pose', () {
      final obj = ed.addCharacter('village_girl');
      ed.addAnimClip(obj.id, 'talk', startMs: 0, endMs: 6000);
      ed.applySceneTime(3321);
      final pose1 = '${ed.controllerFor(obj)!.frame.pose.angles}';
      ed.applySceneTime(9999);
      ed.applySceneTime(3321);
      final pose2 = '${ed.controllerFor(obj)!.frame.pose.angles}';
      expect(pose1, pose2);
    });

    test('AUTO KEY creates/updates keyframes on transform edit (§13)', () {
      final obj = ed.addShape('rect');
      ed.clock.seek(4000);
      ed.autoKey = true;
      ed.updateTransform(obj.id, (t) => t.x = .7);
      final track = ed.timeline.trackOf(obj.id);
      expect(track, isNotNull);
      expect(track!.keyframes.single.timeMs, 4000);
      expect(track.keyframes.single.props['x'], .7);

      // second edit at same playhead updates, not duplicates
      ed.updateTransform(obj.id, (t) => t.y = .3);
      expect(track.keyframes.length, 1);
      expect(track.keyframes.single.props['y'], .3);

      // AUTO KEY off + keyframe exactly at playhead → still updates (§12)
      ed.autoKey = false;
      ed.updateTransform(obj.id, (t) => t.x = .1);
      expect(track.keyframes.single.props['x'], .1);
    });

    test('undo/redo restores timeline + transforms (§18)', () {
      final obj = ed.addText();
      ed.upsertKeyframe(obj.id, atMs: 0, props: {'x': .5});
      expect(ed.canUndo, isTrue);
      ed.undoTimelineEdit();
      expect(ed.timeline.trackOf(obj.id), isNull);
      expect(obj.transform.x, .5); // transform untouched by timeline undo
      ed.redoTimelineEdit();
      expect(ed.timeline.trackOf(obj.id)!.keyframes.single.props['x'], .5);
    });

    test('setDurationMs clamps playhead + notifies', () {
      ed.clock.seek(19000);
      ed.setDurationMs(5000);
      expect(ed.durationMs, 5000);
      expect(ed.playheadMs, 5000);
    });

    test('removeObject drops its track', () {
      final obj = ed.addText();
      ed.upsertKeyframe(obj.id, atMs: 0);
      ed.removeObject(obj.id);
      expect(ed.timeline.trackOf(obj.id), isNull);
    });

    test('scrubSceneTo evaluates the scene (export path, §22)', () {
      final obj = ed.addText();
      ed.upsertKeyframe(obj.id, atMs: 0, props: {'x': .1});
      ed.upsertKeyframe(obj.id, atMs: 10000, props: {'x': .9});
      ed.scrubSceneTo(5000);
      expect(ed.playheadMs, 5000);
      expect(ed.transformFor(obj).x, closeTo(.5, 1e-6));
      expect(ed.clock.isPlaying, isFalse);
    });
  });

  group('Project persistence with timeline (§19) — TEST H', () {
    test('timeline survives capture → document → restore', () {
      final library = Library2DProvider(repo: Character2DRepository());
      final ed = EditorProvider(library);
      final doc = ProjectDocument(
          id: 'p1', name: 'P', orientation: 'landscape', canvasWidth: 1920, canvasHeight: 1080);
      final farmer = ed.addCharacter('bd_farmer_male');
      ed.addAnimClip(farmer.id, 'walk', startMs: 0, endMs: 5000);
      ed.addAnimClip(farmer.id, 'wave', startMs: 5000, endMs: 8000);
      ed.clock.seek(1234);
      ed.setDurationMs(30000);

      captureEditorIntoProject(ed, doc);
      final json = jsonEncode(doc.toJson());
      final back = ProjectDocument.fromJson(
          jsonDecode(json) as Map<String, dynamic>);

      final tl = StoryTimeline.fromJson(back.timeline);
      expect(tl.durationMs, 30000);
      final track = tl.trackOf(farmer.id)!;
      expect(track.clips.length, 2);
      expect(track.clips[0].animId, 'walk');
      expect(track.clips[1].endMs, 8000);
    });

    test('phase-2 project (no timeline) opens with empty default', () {
      final doc = ProjectDocument.fromJson({
        'id': 'p2', 'name': 'Old', 'orientation': 'landscape',
        'canvas': {'width': 1920, 'height': 1080},
        'scene': {
          'objects': [
            textObject(id: 'obj_t1', zIndex: 1, text: 'Hi').toJson(),
          ],
        },
      });
      final tl = StoryTimeline.fromJson(doc.timeline);
      expect(tl.durationMs, 20000);
      expect(tl.tracks, isEmpty);
    });
  });

  group('Animation + transform combination (§14)', () {
    test('character walks AND moves across the scene', () {
      final library = Library2DProvider(repo: Character2DRepository());
      final ed = EditorProvider(library);
      final farmer = ed.addCharacter('bd_farmer_male');
      ed.addAnimClip(farmer.id, 'walk', startMs: 0, endMs: 5000);
      ed.upsertKeyframe(farmer.id, atMs: 0, props: {'x': .2});
      ed.upsertKeyframe(farmer.id, atMs: 5000, props: {'x': .9});

      ed.applySceneTime(2500);
      final c = ed.controllerFor(farmer)!;
      expect(c.animator.clipId, 'walk'); // animating…
      expect(ed.transformFor(farmer).x, closeTo(.55, 1e-6)); // …and moving
      // the object's base transform is NOT overwritten by the animation
      expect(farmer.transform.x, closeTo(.5, 1e-9)); // addCharacter default
    });
  });

  group('TimelinePanel widget (§23/§24)', () {
    testWidgets('renders rows/clips/keyframes and play drives the clock', (tester) async {
      final library = Library2DProvider(repo: Character2DRepository());
      final ed = EditorProvider(library);
      final farmer = ed.addCharacter('bd_farmer_male');
      ed.addAnimClip(farmer.id, 'walk', startMs: 0, endMs: 5000);
      final t = ed.addText();
      ed.upsertKeyframe(t.id, atMs: 0);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TimelinePanel(ed: ed)),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('WALK'), findsOneWidget); // clip chip rendered
      expect(find.text('AUTO KEY'), findsOneWidget);
      expect(find.text('Background'), findsOneWidget);

      // Play: the scene clock (not a widget-local clock) advances.
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump(); // ticker start frame
      await tester.pump(const Duration(milliseconds: 400));
      expect(ed.clock.isPlaying, isTrue);
      expect(ed.playheadMs, greaterThan(0));
      ed.clock.pause();

      // Seek via duration menu sanity: 20s default restored projects.
      expect(ed.durationMs, 20000);
    });
  });

  group('PuppetController.cycleLengthSeconds', () {
    test('known + unknown ids', () {
      expect(PuppetController.cycleLengthSeconds('walk'), 1.05);
      expect(PuppetController.cycleLengthSeconds('nope'), 4.2);
    });
  });
}
