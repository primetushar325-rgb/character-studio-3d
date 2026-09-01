import 'package:flutter/foundation.dart';

import 'art/character_catalog.dart';
import 'art/palettes.dart';
import 'engine/animator2d.dart';
import 'engine/clips.dart' show idlePose;
import 'engine/face_rig.dart';
import 'engine/palette_resolver.dart';
import 'engine/rig2d.dart';
import 'engine/state_machine2d.dart';

/// UI-facing controller for one live 2D puppet: base animation state, face,
/// gestures, playback and customization. Pure logic — widgets only call this.
class PuppetController extends ChangeNotifier {
  PuppetController({required this.spec, PaletteColors? palette, Set<String>? accessories, int seed = 11})
      : animator = PuppetAnimator(rig: Rig2D.byKind(spec.rigKind), seed: seed),
        accessories = {...(accessories ?? spec.defaultAccessories)},
        _palette = palette ?? spec.defaultPalette;

  final Character2DSpec spec;
  final PuppetAnimator animator;

  PaletteColors _palette;
  PaletteColors get palette => _palette;
  PaletteResolver get resolver => _palette.toResolver();
  Set<String> accessories;

  bool directionLeft = false;
  bool talkOverlay = false;
  bool loop = true;
  String actionId = 'idle';

  PuppetFrameData? _frame;
  double _cycleT = 0;

  /// When set, [frame] returns this instead of the internal frame — used by
  /// the timeline evaluator to compose deterministic blended poses.
  PuppetFrameData? frameOverride;
  void clearFrameOverride() => frameOverride = null;

  static const Map<String, double> _cycleLengths = {
    'idle': 4.2, 'walk': 1.05, 'run': 0.62, 'sit': 1.2, 'sleep': 4.6,
    'talk': 7.7, 'jump': 1.15, 'wave': 1.5, 'action': 1.3, 'happy': 1.2,
    'sad': 2.4, 'think': 2.4, 'turn': 0.8, 'fall': 1.4,
  };

  static const List<String> actionOrder = [
    'idle', 'walk', 'run', 'sit', 'sleep', 'talk',
    'jump', 'wave', 'action', 'happy', 'sad', 'think', 'turn', 'fall',
  ];

  double get speed => animator.speed;

  /// Source length of an action's clip, in seconds (timeline default spans).
  static double cycleLengthSeconds(String id) => _cycleLengths[id] ?? 4.2;

  PuppetFrameData get frame =>
      frameOverride ??
      _frame ??
      PuppetFrameData(
        pose: idlePose(0.35),
        solve: solveSkeleton(animator.rig, idlePose(0.35).angles),
        face: Expressions.all[Expr.neutral]!,
        blink: 0,
        lookX: 0,
        lookY: 0,
        time: 0,
        sleeping: false,
        talking: false,
      );

  void tick(double dt) {
    if (!animator.playing) {
      _frame = animator.update(0);
      notifyListeners();
      return;
    }
    _cycleT += dt * animator.speed;
    if (!loop && _cycleT >= (_cycleLengths[actionId] ?? 4.2)) {
      animator.playing = false;
    }
    _frame = animator.update(dt);
    notifyListeners();
  }

  void replay() {
    _cycleT = 0;
    animator.playing = true;
    animator.play(animator.clipId, fade: 0.12);
    notifyListeners();
  }

  // ---- Animations ----------------------------------------------------------
  void setAction(String id) {
    if (!actionOrder.contains(id)) return;
    actionId = id;
    _cycleT = 0;
    switch (id) {
      case 'idle':
        animator.setTalking(talkOverlay);
        animator.requestState(CharState.idle);
      case 'walk':
        animator.setTalking(talkOverlay);
        animator.requestState(CharState.walk);
      case 'run':
        animator.setTalking(false);
        animator.requestState(CharState.run);
      case 'sit':
        animator.setTalking(talkOverlay);
        animator.requestState(CharState.sit);
      case 'sleep':
        animator.setTalking(false);
        animator.requestState(CharState.sleep);
      case 'talk':
        talkOverlay = true;
        animator.setTalking(true);
        animator.requestState(CharState.talk);
      default:
        // Full-body one-shots: play directly on the base layer, keep state.
        animator.setTalking(false);
        animator.play(id, fade: 0.18, loopAfter: '');
    }
    notifyListeners();
  }

  // ---- Face / gestures ------------------------------------------------------
  void setExpression(Expr e) => animator.setExpression(e);

  void setTalking(bool on) {
    talkOverlay = on;
    animator.setTalking(on);
    notifyListeners();
  }

  void setLook(double x, double y) => animator.setLook(x, y);

  void gesture(String id) => animator.triggerGesture(id);

  void headMove(String id) => animator.triggerHeadMove(id);

  // ---- Playback ---------------------------------------------------------------
  void setSpeed(double s) {
    animator.speed = s;
    notifyListeners();
  }

  void setPlaying(bool p) {
    if (p && !loop) {
      replay();
      return;
    }
    animator.playing = p;
    notifyListeners();
  }

  bool get playing => animator.playing;

  void setDirection(int dir) {
    directionLeft = dir < 0;
    notifyListeners();
  }

  // ---- Customization -----------------------------------------------------------
  void setPalette(PaletteColors p) {
    _palette = p;
    notifyListeners();
  }

  void setAccessory(String key, bool on) {
    if (on) {
      accessories.add(key);
    } else {
      accessories.remove(key);
    }
    notifyListeners();
  }

}
