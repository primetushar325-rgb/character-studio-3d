// PHASE 6 — data-driven effect clips: determinism, math, timeline
// persistence, and application through the SAME evaluation the preview and
// the frame-rendered export use.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/state/editor_provider.dart';
import 'package:character_studio_3d/state/library2d_provider.dart';
import 'package:character_studio_3d/timeline/effects.dart';
import 'package:character_studio_3d/timeline/story_timeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('evaluateEffects (pure math)', () {
    test('fadeIn ramps opacity smoothly 0 → 1', () {
      final e = [EffectClip(id: 'a', kind: EffectKind.fadeIn, startMs: 1000, durationMs: 1000)];
      expect(evaluateEffects(e, 999).opacityMul, 1); // not started yet
      expect(evaluateEffects(e, 1000).opacityMul, closeTo(0, 0.01));
      final mid = evaluateEffects(e, 1500).opacityMul;
      expect(mid, greaterThan(0.4));
      expect(mid, lessThan(0.6));
      expect(evaluateEffects(e, 1999).opacityMul, greaterThan(0.9));
      expect(evaluateEffects(e, 2200).opacityMul, 1); // finished
    });

    test('fadeOut mirrors fadeIn', () {
      final e = [EffectClip(id: 'a', kind: EffectKind.fadeOut, startMs: 0, durationMs: 800)];
      expect(evaluateEffects(e, 0).opacityMul, closeTo(1, 0.01));
      expect(evaluateEffects(e, 800 - 1).opacityMul, lessThan(0.05));
    });

    test('shake is deterministic from seed+time and actually moves', () {
      final e = [EffectClip(id: 'a', kind: EffectKind.shake, startMs: 0, durationMs: 2000, seed: 42)];
      final a = evaluateEffects(e, 743);
      final b = evaluateEffects(e, 743);
      expect(a.dx, b.dx);
      expect(a.dy, b.dy);

      var moved = false;
      for (var t = 0; t < 2000; t += 50) {
        final v = evaluateEffects(e, t);
        if (v.dx.abs() > 0.002 || v.dy.abs() > 0.002) moved = true;
      }
      expect(moved, isTrue, reason: 'shake must displace the object over time');
      // Different seeds → different phases (not one global pattern).
      final other = evaluateEffects(
          [EffectClip(id: 'b', kind: EffectKind.shake, startMs: 0, durationMs: 2000, seed: 7)], 743);
      expect((other.dx - a.dx).abs(), greaterThan(0.0001));
    });

    test('zoom grows scale; pulse oscillates around 1; flash peaks mid-clip', () {
      final z = [EffectClip(id: 'z', kind: EffectKind.zoom, startMs: 0, durationMs: 1000)];
      expect(evaluateEffects(z, 0).scaleMul, closeTo(1, 0.001));
      expect(evaluateEffects(z, 1000 - 1).scaleMul, greaterThan(1.2));

      final p = [EffectClip(id: 'p', kind: EffectKind.pulse, startMs: 0, durationMs: 1200)];
      final scales = [for (var t = 0; t < 1200; t += 40) evaluateEffects(p, t).scaleMul];
      expect(scales.reduce((a, b) => a < b ? a : b), closeTo(1, 0.01));
      expect(scales.reduce((a, b) => a > b ? a : b), greaterThan(1.1));

      final f = [EffectClip(id: 'f', kind: EffectKind.flash, startMs: 0, durationMs: 400)];
      expect(evaluateEffects(f, 0).flash, closeTo(0, 0.01));
      expect(evaluateEffects(f, 200).flash, greaterThan(0.8));
      expect(evaluateEffects(f, 399).flash, lessThan(0.05));
    });

    test('stacking fades multiply (never negative)', () {
      final e = [
        EffectClip(id: 'a', kind: EffectKind.fadeIn, startMs: 0, durationMs: 1000),
        EffectClip(id: 'b', kind: EffectKind.fadeOut, startMs: 0, durationMs: 1000),
      ];
      final v = evaluateEffects(e, 500);
      expect(v.opacityMul, inInclusiveRange(0, 1));
    });
  });

  group('timeline persistence', () {
    test('effect clips round-trip through track JSON (legacy docs unaffected)', () {
      final t = TimelineTrack(objectId: 'obj_1', effects: [
        EffectClip(id: 'fx_1', kind: EffectKind.shake, startMs: 500, durationMs: 900, intensity: 1.4, seed: 9),
        EffectClip(id: 'fx_2', kind: EffectKind.fadeIn, startMs: 0, durationMs: 600),
      ]);
      final back = TimelineTrack.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
      expect(back.effects, hasLength(2));
      // Tracks sort by start time; find by kind, not by position.
      final shake = back.effects.firstWhere((e) => e.kind == EffectKind.shake);
      expect(shake.intensity, 1.4);
      expect(shake.seed, 9);
      final fade = back.effects.firstWhere((e) => e.kind == EffectKind.fadeIn);
      expect(fade.startMs, 0);
      expect(fade.activeAt(100), isTrue);

      // Legacy timeline without an effects field loads with zero effects.
      final legacy = TimelineTrack.fromJson({
        'objectId': 'obj_1',
        'clips': [],
        'visClips': [],
        'keyframes': [],
      });
      expect(legacy.effects, isEmpty);
    });
  });

  group('editor integration (preview == export evaluation)', () {
    late EditorProvider ed;
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ed = EditorProvider(Library2DProvider(repo: Character2DRepository()));
    });

    test('addEffectClip applies through applySceneTime into the paint view', () {
      final obj = ed.addCharacter('fox');
      ed.addEffectClip(obj.id, EffectKind.shake, startMs: 0, durationMs: 2000);
      ed.addEffectClip(obj.id, EffectKind.fadeIn, startMs: 0, durationMs: 1000);

      final base = ed.evaluatedTransformView(obj);
      ed.applySceneTime(400); // inside both effects
      final v = ed.evaluatedTransformView(obj);

      // Fade-in mid-way → dimmer than the object's full opacity.
      expect(v.opacity, lessThan(base.opacity));
      expect(v.opacity, greaterThan(0));
      // Deterministic: same scene time → same view.
      ed.applySceneTime(400);
      final v2 = ed.evaluatedTransformView(obj);
      expect(v2.x, v.x);
      expect(v2.opacity, v.opacity);

      // After both effects end the object is back to its plain transform.
      ed.applySceneTime(3000);
      final rest = ed.evaluatedTransformView(obj);
      expect(rest.opacity, obj.transform.opacity);
      expect(rest.flash, 0);
    });

    test('flash reaches the paint view (white overlay amount)', () {
      final obj = ed.addText();
      ed.addEffectClip(obj.id, EffectKind.flash, startMs: 100, durationMs: 400);
      ed.applySceneTime(300);
      expect(ed.evaluatedTransformView(obj).flash, greaterThan(0.5));
    });

    test('deleteEffectClip removes the effect and prunes empty tracks', () {
      final obj = ed.addText();
      final fx = ed.addEffectClip(obj.id, EffectKind.zoom, startMs: 0, durationMs: 800);
      expect(ed.timeline.trackOf(obj.id)?.effects, hasLength(1));
      ed.deleteEffectClip(obj.id, fx.id);
      expect(ed.timeline.trackOf(obj.id), isNull, reason: 'empty track must be pruned');
    });
  });
}
