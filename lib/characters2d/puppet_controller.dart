import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'art/character_catalog.dart';
import 'art/palettes.dart';
import 'engine/animator2d.dart';
import 'engine/face_rig.dart';
import 'engine/clips.dart' show idlePose;
import 'engine/rig2d.dart';
import 'engine/state_machine2d.dart';

/// UI-facing controller: one live puppet. Widgets call the setters, the
/// stage widget pumps [tick] every frame (only place that notifies).
class PuppetController extends ChangeNotifier {
  PuppetController({required this.spec, PaletteColors? palette, Set<String>? accessories, int seed = 11})
      : animator = PuppetAnimator(rig: sharedRig, seed: seed),
        accessories = {...(accessories ?? spec.defaultAccessories)},
        _palette = palette ?? spec.defaultPalette;

  /// Shared universal rig instance (immutable data, reused by every puppet).
  static final Rig2D sharedRig = Rig2D.humanoidV1();

  final Character2DSpec spec;
  final PuppetAnimator animator;

  PaletteColors _palette;
  PaletteColors get palette => _palette;
  Set<String> accessories;

  bool directionLeft = false;
  bool talkOverlay = false;
  bool loop = true;
  String actionId = 'stand';

  PuppetFrameData? _frame;
  double _cycleT = 0;

  static const Map<String, double> _cycleLengths = {
    'stand': 4.2,
    'walk': 0.95,
    'run': 0.62,
    'sit': 4.2,
    'sleep': 4.6,
    'talk': 7.7,
  };

  PuppetFrameData get frame =>
      _frame ??
      PuppetFrameData(
        pose: idlePose(0.35),
        solve: solveSkeleton(sharedRig, idlePose(0.35).angles),
        face: Expressions.all[Expr.neutral]!,
        blink: 0,
        lookX: 0,
        lookY: 0,
        time: 0,
        sleeping: false,
        talking: false,
      );

  double get speed => animator.speed;

  /// Pumped by the stage's ticker — the only notifyListeners() call site.
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

  /// Restarts the current action from the beginning (used with Loop OFF).
  void replay() {
    _cycleT = 0;
    animator.playing = true;
    animator.play(animator.clipId, fade: 0.12);
    notifyListeners();
  }

  // ---- Actions -------------------------------------------------------------
  static const actionIds = ['stand', 'walk', 'run', 'sit', 'sleep', 'talk'];

  void setAction(String id) {
    if (!actionIds.contains(id)) return;
    actionId = id;
    _cycleT = 0;
    switch (id) {
      case 'stand':
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
    }
    notifyListeners();
  }

  // ---- Face / talk / gestures ----------------------------------------------
  void setExpression(Expr e) => animator.setExpression(e);

  void setTalking(bool on) {
    talkOverlay = on;
    animator.setTalking(on);
    notifyListeners();
  }

  void setLook(double x, double y) => animator.setLook(x, y);

  void gesture(String id) => animator.triggerGesture(id);

  void headMove(String id) => animator.triggerHeadMove(id);

  // ---- Playback --------------------------------------------------------------
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

  // ---- Customization ---------------------------------------------------------
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

