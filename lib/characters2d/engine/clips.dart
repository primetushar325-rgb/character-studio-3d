import 'dart:math' as math;

import 'pose2d.dart';
import 'quadruped_clips.dart' as q;

/// One keyframe: time (s) + value.
class K {
  const K(this.t, this.v);
  final double t;
  final double v;
}

double _smooth(double u) => 0.5 - 0.5 * math.cos(math.pi * u.clamp(0.0, 1.0));

double _sampleTrack(List<K> keys, double t) {
  if (keys.isEmpty) return 0;
  if (t <= keys.first.t) return keys.first.v;
  if (t >= keys.last.t) return keys.last.v;
  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i];
    final b = keys[i + 1];
    if (t >= a.t && t <= b.t) {
      final u = (t - a.t) / (b.t - a.t);
      return a.v + (b.v - a.v) * _smooth(u);
    }
  }
  return keys.last.v;
}

/// Builds a pose from keyframe tracks. Special track names:
/// `_dx`, `_dy`, `_tilt`, `handL`, `handR`, `_lookX`, `_lookY`.
Pose2D keyPose(Map<String, List<K>> tracks, double t) {
  final pose = Pose2D();
  for (final e in tracks.entries) {
    final v = _sampleTrack(e.value, t);
    switch (e.key) {
      case '_dx':
        pose.dx = v;
      case '_dy':
        pose.dy = v;
      case '_tilt':
        pose.bodyTilt = v;
      default:
        pose.angles[e.key] = v;
    }
  }
  return pose;
}

/// A reusable animation clip. [fn] receives local time in seconds and returns
/// a pose (absolute deltas from the rest pose).
class Clip2D {
  const Clip2D({required this.id, required this.duration, required this.loop, required this.fn});

  final String id;

  /// Duration in seconds at speed 1x.
  final double duration;
  final bool loop;
  final Pose2D Function(double t) fn;

  Pose2D sample(double t) => fn(t.clamp(0.0, duration));
}

double _lift(double phase) => math.max(0.0, math.sin(phase));

/// Shared idle breathing / micro-motion.
Pose2D idlePose(double t) {
  final p = Pose2D();
  final breath = math.sin(t * 2 * math.pi / 3.8);
  final sway = math.sin(t * 2 * math.pi / 11.3);
  p.angles['spine'] = 1.1 * breath + 0.4 * sway;
  p.angles['chest'] = 0.8 * breath;
  p.angles['neck'] = -0.5 * breath;
  p.angles['head'] = -0.4 * breath + 1.1 * math.sin(t * 2 * math.pi / 7.7);
  p.angles['leftShoulder'] = 0.9 * breath;
  p.angles['rightShoulder'] = -0.9 * breath;
  p.angles['leftUpperArm'] = 2.2 * breath + 1.4 * sway;
  p.angles['rightUpperArm'] = 2.2 * breath - 1.4 * sway;
  p.angles['leftLowerArm'] = 4 + 1.5 * breath;
  p.angles['rightLowerArm'] = -4 - 1.5 * breath;
  p.dy = 0.7 * breath;
  p.dx = 1.2 * sway;
  return p;
}

/// Front-view cartoon walk cycle. [phase] in radians, [stride] 0..1 amplitude.
Pose2D walkPose(double phase, double stride, [double t = 0]) {
  final p = Pose2D();
  final liftL = _lift(phase);
  final liftR = _lift(phase + math.pi);
  final swing = math.sin(phase);
  final breathe = t == 0 ? 0 : math.sin(t * 2 * math.pi / 3.8);

  // Legs: alternate knee lifts with folded shins + tucked feet.
  p.angles['leftUpperLeg'] = (-5 * liftL + 2 * liftR) * stride;
  p.angles['leftLowerLeg'] = 16 * liftL * stride;
  p.angles['leftFoot'] = -14 * liftL * stride;
  p.angles['rightUpperLeg'] = (-5 * liftR + 2 * liftL) * stride;
  p.angles['rightLowerLeg'] = 16 * liftR * stride;
  p.angles['rightFoot'] = -14 * liftR * stride;

  // Hips: sway + rotation + double-bounce per cycle.
  p.angles['hips'] = 1.8 * swing * stride;
  p.dx = 2.4 * swing * stride;
  p.dy = -2.4 * (0.5 - 0.5 * math.cos(2 * phase)) * stride;

  // Torso counter-rotation, stabilized head.
  p.angles['spine'] = -1.6 * swing * stride + 0.8 * breathe;
  p.angles['chest'] = 1.3 * swing * stride;
  p.angles['neck'] = -0.6 * swing * stride;
  p.angles['head'] = -0.7 * swing * stride + 0.9 * breathe;

  // Arms: opposite to legs, slight elbow bend, more when swinging in.
  final inL = math.max(0.0, -swing);
  final inR = math.max(0.0, swing);
  p.angles['leftUpperArm'] = (16 * inL - 10 * math.max(0.0, swing)) * stride + 1.2 * breathe;
  p.angles['rightUpperArm'] = (-16 * inR + 10 * math.max(0.0, -swing)) * stride - 1.2 * breathe;
  p.angles['leftLowerArm'] = 10 + 9 * inL * stride;
  p.angles['rightLowerArm'] = -10 - 9 * inR * stride;
  p.angles['leftShoulder'] = 2.5 * swing * stride;
  p.angles['rightShoulder'] = -2.5 * swing * stride;
  return p;
}

/// Front-view cartoon run cycle: bigger lifts, strong arm pump, forward lean.
Pose2D runPose(double phase, double stride, [double t = 0]) {
  final p = Pose2D();
  final liftL = _lift(phase);
  final liftR = _lift(phase + math.pi);
  final swing = math.sin(phase);

  p.angles['leftUpperLeg'] = (-9 * liftL + 3 * liftR) * stride;
  p.angles['leftLowerLeg'] = 38 * liftL * stride;
  p.angles['leftFoot'] = -22 * liftL * stride;
  p.angles['rightUpperLeg'] = (-9 * liftR + 3 * liftL) * stride;
  p.angles['rightLowerLeg'] = 38 * liftR * stride;
  p.angles['rightFoot'] = -22 * liftR * stride;

  p.angles['hips'] = 2.6 * swing * stride;
  p.dx = 3.2 * swing * stride;
  p.dy = -4.6 * (0.5 - 0.5 * math.cos(2 * phase)) * stride;

  // Forward lean (hunch) + stabilized head.
  p.angles['spine'] = 7 * stride - 2 * swing * stride;
  p.angles['chest'] = 5 * stride + 1.6 * swing * stride;
  p.angles['neck'] = -4 * stride;
  p.angles['head'] = -4.5 * stride - 1.2 * swing * stride;

  final inL = math.max(0.0, -swing);
  final inR = math.max(0.0, swing);
  p.angles['leftUpperArm'] = (38 * inL - 26 * math.max(0.0, swing)) * stride;
  p.angles['rightUpperArm'] = (-38 * inR + 26 * math.max(0.0, -swing)) * stride;
  p.angles['leftLowerArm'] = 24 + 18 * inL * stride;
  p.angles['rightLowerArm'] = -24 - 18 * inR * stride;
  p.angles['leftShoulder'] = 4 * swing * stride + 2 * stride;
  p.angles['rightShoulder'] = -4 * swing * stride - 2 * stride;
  return p;
}

/// Seated (cross-legged) base pose. [f] 0..1 sit depth.
Pose2D sitPose(double f) {
  final p = Pose2D();
  p.dy = 46 * f;
  p.dx = -2 * f;
  p.angles['hips'] = 0;
  p.angles['leftUpperLeg'] = 46 * f;
  p.angles['rightUpperLeg'] = -46 * f;
  p.angles['leftLowerLeg'] = -84 * f;
  p.angles['rightLowerLeg'] = 84 * f;
  p.angles['leftFoot'] = -30 * f;
  p.angles['rightFoot'] = 30 * f;
  p.angles['spine'] = 5 * f;
  p.angles['chest'] = 3 * f;
  p.angles['head'] = -3 * f;
  p.angles['leftUpperArm'] = 22 * f;
  p.angles['rightUpperArm'] = -22 * f;
  p.angles['leftLowerArm'] = 34 * f;
  p.angles['rightLowerArm'] = -34 * f;
  return p;
}

/// Lying-down sleep pose. [f] 0..1.
Pose2D sleepPose(double f) {
  final p = Pose2D();
  p.bodyTilt = -84 * f;
  p.dy = 130 * f;
  p.dx = 8 * f;
  p.angles['spine'] = 4 * f;
  p.angles['neck'] = 6 * f;
  p.angles['head'] = 10 * f;
  p.angles['leftUpperLeg'] = 8 * f;
  p.angles['leftLowerLeg'] = 12 * f;
  p.angles['rightUpperLeg'] = -6 * f;
  p.angles['rightLowerLeg'] = -8 * f;
  // Near arm folded up under the head, far arm resting along the body.
  p.angles['leftUpperArm'] = -58 * f;
  p.angles['leftLowerArm'] = -78 * f;
  p.extras['handL'] = 1 * f; // fist (pillow)
  p.angles['rightUpperArm'] = 14 * f;
  p.angles['rightLowerArm'] = 10 * f;
  return p;
}


// ---- v2.0 extra humanoid clips -------------------------------------------
double _ez(double u) => 0.5 - 0.5 * math.cos(math.pi * u.clamp(0.0, 1.0));

/// JUMP: anticipation crouch → launch with arm swing → land squash.
Pose2D jumpPose(double t) {
  const d = 1.15;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  if (u < 0.25) {
    final k = _ez(u / 0.25);
    p.dy = 12 * k;
    p.angles['leftUpperLeg'] = 26 * k;
    p.angles['leftLowerLeg'] = -42 * k;
    p.angles['rightUpperLeg'] = -26 * k;
    p.angles['rightLowerLeg'] = 42 * k;
    p.angles['spine'] = 8 * k;
    p.angles['leftUpperArm'] = -30 * k;
    p.angles['rightUpperArm'] = 30 * k;
  } else if (u < 0.7) {
    final k = _ez((u - 0.25) / 0.45);
    p.dy = -10 - 58 * math.sin(k * math.pi);
    p.angles['leftUpperLeg'] = 26 - 40 * k;
    p.angles['leftLowerLeg'] = -42 + 30 * k;
    p.angles['rightUpperLeg'] = -26 + 34 * k;
    p.angles['rightLowerLeg'] = 42 - 26 * k;
    p.angles['leftUpperArm'] = -30 - 60 * k;
    p.angles['rightUpperArm'] = 30 + 60 * k;
    p.angles['spine'] = 4;
    p.angles['head'] = -4;
  } else if (u < 0.85) {
    final k = _ez((u - 0.7) / 0.15);
    p.dy = -6 + 22 * k;
    p.angles['leftUpperLeg'] = 22 * k;
    p.angles['leftLowerLeg'] = -36 * k;
    p.angles['rightUpperLeg'] = -22 * k;
    p.angles['rightLowerLeg'] = 36 * k;
    p.angles['spine'] = 9 * k;
    p.angles['leftUpperArm'] = 26 * k;
    p.angles['rightUpperArm'] = -26 * k;
  } else {
    final k = _ez((u - 0.85) / 0.15);
    p.dy = 16 * (1 - k);
    p.angles['leftUpperLeg'] = 22 * (1 - k);
    p.angles['leftLowerLeg'] = -36 * (1 - k);
    p.angles['rightUpperLeg'] = -22 * (1 - k);
    p.angles['rightLowerLeg'] = 36 * (1 - k);
    p.angles['spine'] = 9 * (1 - k);
    p.angles['leftUpperArm'] = 26 * (1 - k);
    p.angles['rightUpperArm'] = -26 * (1 - k);
  }
  return p;
}

/// FALL: staggers backward and tips over with flailing limbs.
Pose2D fallPose(double t) {
  const d = 1.4;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  p.bodyTilt = -74 * u * u;
  p.dy = 96 * u * u;
  p.dx = -18 * u;
  p.angles['spine'] = -6 * u;
  final flail = (1 - u) * math.sin(t * 13);
  p.angles['leftUpperArm'] = -80 * u + 24 * flail;
  p.angles['rightUpperArm'] = 70 * u - 20 * flail;
  p.angles['leftUpperLeg'] = 30 * u + 10 * flail;
  p.angles['rightUpperLeg'] = -24 * u - 8 * flail;
  p.angles['head'] = -14 * u;
  return p;
}

/// TURN: pivot hop (direction flip is handled by the controller).
Pose2D turnPose(double t) {
  const d = 0.8;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  final arc = u < 0.5 ? _ez(u / 0.5) : 1 - _ez((u - 0.5) / 0.5);
  p.dy = -20 * math.sin(arc * math.pi / 2);
  p.angles['hips'] = 10 * arc;
  p.angles['spine'] = -8 * arc;
  p.angles['head'] = 14 * arc;
  p.angles['leftUpperArm'] = -30 * arc;
  p.angles['rightUpperArm'] = 30 * arc;
  p.angles['leftUpperLeg'] = 18 * arc;
  p.angles['rightUpperLeg'] = -18 * arc;
  return p;
}

/// ACTION / attack: wind-up → lunge with pointed hand → recover.
Pose2D actionPose(double t) {
  const d = 1.3;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  if (u < 0.35) {
    final k = _ez(u / 0.35);
    p.angles['spine'] = -10 * k;
    p.angles['hips'] = -6 * k;
    p.angles['rightUpperArm'] = 52 * k;
    p.angles['rightLowerArm'] = -70 * k;
    p.angles['leftUpperArm'] = -18 * k;
    p.angles['leftUpperLeg'] = 10 * k;
    p.angles['rightUpperLeg'] = -12 * k;
    p.angles['leftLowerLeg'] = -16 * k;
    p.angles['head'] = -6 * k;
  } else if (u < 0.6) {
    final k = _ez((u - 0.35) / 0.25);
    p.dx = 30 * k;
    p.angles['spine'] = -10 + 22 * k;
    p.angles['rightUpperArm'] = 52 - 150 * k;
    p.angles['rightLowerArm'] = -70 + 66 * k;
    p.angles['leftUpperArm'] = -18 + 30 * k;
    p.angles['leftUpperLeg'] = 10 - 34 * k;
    p.angles['rightUpperLeg'] = -12 + 26 * k;
    p.angles['head'] = -6 + 10 * k;
    p.extras['handR'] = 2; // point
  } else {
    final k = _ez((u - 0.6) / 0.4);
    p.dx = 30 * (1 - k);
    p.angles['spine'] = 12 * (1 - k);
    p.angles['rightUpperArm'] = -98 * (1 - k);
    p.angles['rightLowerArm'] = -4 * (1 - k);
    p.angles['leftUpperArm'] = 12 * (1 - k);
    p.angles['leftUpperLeg'] = -24 * (1 - k);
    p.angles['rightUpperLeg'] = 14 * (1 - k);
    p.extras['handR'] = 2 * (1 - k);
  }
  return p;
}

/// HAPPY body one-shot: little bounce + arms up.
Pose2D happyPose(double t) {
  const d = 1.2;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  final bounce = math.sin(u * math.pi * 2).abs();
  p.dy = -10 * bounce * (1 - u * 0.4);
  p.angles['leftUpperArm'] = -120 * _ez(u / 0.3) * (1 - _ez((u - 0.7) / 0.3).clamp(0.0, 1.0));
  p.angles['rightUpperArm'] = 120 * _ez(u / 0.3) * (1 - _ez((u - 0.7) / 0.3).clamp(0.0, 1.0));
  p.angles['head'] = 6 * math.sin(u * math.pi * 2);
  p.extras['handL'] = 0;
  p.extras['handR'] = 0;
  return p;
}

/// SAD body one-shot: droop + slow sway.
Pose2D sadPose(double t) {
  const d = 2.4;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  final k = _ez(u / 0.4);
  p.angles['spine'] = 12 * k;
  p.angles['neck'] = 8 * k;
  p.angles['head'] = 14 * k + 2 * math.sin(t * 2 * math.pi / 2.0);
  p.angles['leftUpperArm'] = 8 * k;
  p.angles['rightUpperArm'] = -8 * k;
  p.dy = 4 * k;
  return p;
}

/// THINK body one-shot: hand to chin + look up.
Pose2D thinkPose(double t) {
  const d = 2.4;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  final k = _ez(u / 0.35);
  p.angles['spine'] = 5 * k;
  p.angles['head'] = -12 * k + 2.5 * math.sin(t * 2 * math.pi / 3.0);
  p.angles['leftUpperArm'] = -20 * k;
  p.angles['leftLowerArm'] = -118 * k;
  p.extras['handL'] = 1;
  p.extras['_lookY'] = 0.5 * k;
  p.extras['_lookX'] = 0.4 * k;
  return p;
}

/// The clip catalog — every clip id used by the state machine and UI.
class ClipLibrary {
  ClipLibrary._();

  static const walkCycle = 0.95;
  static const runCycle = 0.62;

  static Pose2D _walkLoop(double t) => walkPose(t * 2 * math.pi / walkCycle, 1, t);
  static Pose2D _runLoop(double t) => runPose(t * 2 * math.pi / runCycle, 1, t);

  static Pose2D _walkStart(double t) {
    const d = 0.5;
    final u = (t / d).clamp(0.0, 1.0);
    final e = _smooth(u);
    final target = walkPose(e * math.pi * 0.75, e, t);
    return Pose2D.lerp(idlePose(t), target, e);
  }

  static Pose2D _walkStop(double t) {
    const d = 0.55;
    final u = (t / d).clamp(0.0, 1.0);
    final e = _smooth(u);
    final from = walkPose(math.pi * 0.75 + e * math.pi * 0.4, 1 - e, t);
    final settle = idlePose(t + d);
    settle.dy -= 1.6 * (1 - e) * (1 - e); // small weight settle
    return Pose2D.lerp(from, settle, e);
  }

  static Pose2D _runStart(double t) {
    const d = 0.42;
    final u = (t / d).clamp(0.0, 1.0);
    final e = _smooth(u);
    final target = runPose(e * math.pi * 0.7, e, t);
    return Pose2D.lerp(idlePose(t), target, e);
  }

  static Pose2D _runStop(double t) {
    const d = 0.55;
    final u = (t / d).clamp(0.0, 1.0);
    final e = _smooth(u);
    final from = runPose(math.pi * 0.7 + e * math.pi * 0.3, 1 - e, t);
    final settle = idlePose(t + d);
    settle.dy -= 2.2 * (1 - e) * (1 - e); // landing dip
    return Pose2D.lerp(from, settle, e);
  }

  static Pose2D _standToSit(double t) => keyPose({
        '_dy': [K(0, 0), K(0.45, -6), K(0.8, 30), K(1.1, 46)],
        'leftUpperLeg': [K(0, 0), K(0.45, -8), K(1.1, 46)],
        'rightUpperLeg': [K(0, 0), K(0.45, 8), K(1.1, -46)],
        'leftLowerLeg': [K(0, 0), K(0.45, 4), K(1.1, -84)],
        'rightLowerLeg': [K(0, 0), K(0.45, -4), K(1.1, 84)],
        'leftFoot': [K(0, 0), K(1.1, -30)],
        'rightFoot': [K(0, 0), K(1.1, 30)],
        'spine': [K(0, 0), K(0.5, 9), K(1.1, 5)],
        'chest': [K(0, 0), K(0.5, 6), K(1.1, 3)],
        'head': [K(0, 0), K(0.5, -5), K(1.1, -3)],
        'leftUpperArm': [K(0, 0), K(0.5, 34), K(1.1, 22)],
        'rightUpperArm': [K(0, 0), K(0.5, -34), K(1.1, -22)],
        'leftLowerArm': [K(0, 0), K(0.5, 20), K(1.1, 34)],
        'rightLowerArm': [K(0, 0), K(0.5, -20), K(1.1, -34)],
      }, t);

  static Pose2D _sitToStand(double t) => _standToSit((1.1 - t).clamp(0.0, 1.1));

  static Pose2D _sitIdle(double t) {
    final base = sitPose(1);
    final breath = math.sin(t * 2 * math.pi / 4.2);
    base.angles['spine'] = base.angle('spine') + 1.2 * breath;
    base.angles['chest'] = base.angle('chest') + 0.9 * breath;
    base.angles['head'] = base.angle('head') - 0.6 * breath + 1.2 * math.sin(t * 2 * math.pi / 9.1);
    base.angles['leftUpperArm'] = base.angle('leftUpperArm') + 1.5 * breath;
    base.angles['rightUpperArm'] = base.angle('rightUpperArm') - 1.5 * breath;
    base.dy = base.dy + 0.6 * breath;
    return base;
  }

  static Pose2D _toSleep(double t) {
    const d = 1.7;
    final u = (t / d).clamp(0.0, 1.0);
    final e = _smooth(u);
    final target = sleepPose(1);
    final from = idlePose(t);
    return Pose2D.lerp(from, target, e);
  }

  static Pose2D _sleepLoop(double t) {
    final base = sleepPose(1);
    final breath = math.sin(t * 2 * math.pi / 4.6);
    base.angles['chest'] = base.angle('chest') + 1.4 * breath;
    base.angles['spine'] = base.angle('spine') + 1.0 * breath;
    base.dy = base.dy + 1.1 * breath;
    base.angles['head'] = base.angle('head') + 1.6 * math.sin(t * 2 * math.pi / 7.3);
    return base;
  }

  static Pose2D _wakeUp(double t) {
    const d = 1.8;
    if (t < d * 0.62) {
      final u = (t / (d * 0.62)).clamp(0.0, 1.0);
      final wake = sitPose(u * 0.55);
      return Pose2D.lerp(sleepPose(1), wake, _smooth(u));
    }
    final u = ((t - d * 0.62) / (d * 0.38)).clamp(0.0, 1.0);
    final rub = idlePose(t);
    rub.angles['leftUpperArm'] = -38;
    rub.angles['leftLowerArm'] = -88;
    rub.extras['handL'] = 1;
    return Pose2D.lerp(sitPose(0.55), rub, _smooth(u));
  }

  /// Upper-body talk layer: mixed prime-period sines so it never repeats
  /// robotically. Gestures ride on top of this.
  static Pose2D _talkLoop(double t) {
    final p = Pose2D();
    p.angles['chest'] = 1.3 * math.sin(t * 2 * math.pi / 2.4);
    p.angles['spine'] = 0.8 * math.sin(t * 2 * math.pi / 3.3 + 0.5);
    p.angles['neck'] = 1.0 * math.sin(t * 2 * math.pi / 3.7 + 1.2);
    p.angles['head'] = 2.2 * math.sin(t * 2 * math.pi / 3.1) + 1.5 * math.sin(t * 2 * math.pi / 4.7) + 1.1 * math.sin(t * 2 * math.pi / 6.1);
    p.angles['leftShoulder'] = 1.6 * math.sin(t * 2 * math.pi / 2.9);
    p.angles['rightShoulder'] = -1.6 * math.sin(t * 2 * math.pi / 2.9 + 0.8);
    p.angles['leftUpperArm'] = 3.0 * math.sin(t * 2 * math.pi / 5.3);
    p.angles['rightUpperArm'] = -3.0 * math.sin(t * 2 * math.pi / 4.1 + 1.4);
    p.angles['leftLowerArm'] = 4.0 * math.sin(t * 2 * math.pi / 2.6 + 0.3);
    p.angles['rightLowerArm'] = -4.0 * math.sin(t * 2 * math.pi / 3.9 + 2.1);
    return p;
  }

  // ---- Gestures (upper-body one-shots) ---------------------------------
  static Pose2D _wave(double t) => keyPose({
        'leftUpperArm': const [K(0, 0), K(0.3, -142), K(1.1, -148), K(1.5, 0)],
        'leftLowerArm': const [K(0, 0), K(0.3, 26), K(0.45, 44), K(0.6, 8), K(0.75, 44), K(0.9, 8), K(1.05, 30), K(1.5, 0)],
        'head': const [K(0, 0), K(0.4, 6), K(1.1, 6), K(1.5, 0)],
        'handL': const [K(0, 0), K(0.28, 0), K(1.15, 0)],
      }, t);

  static Pose2D _greet(double t) => keyPose({
        'leftUpperArm': const [K(0, 0), K(0.35, -26), K(1.0, -26), K(1.6, 0)],
        'rightUpperArm': const [K(0, 0), K(0.35, 26), K(1.0, 26), K(1.6, 0)],
        'leftLowerArm': const [K(0, 0), K(0.35, 84), K(1.0, 84), K(1.6, 0)],
        'rightLowerArm': const [K(0, 0), K(0.35, -84), K(1.0, -84), K(1.6, 0)],
        'neck': const [K(0, 0), K(0.5, 8), K(1.0, 8), K(1.6, 0)],
        'spine': const [K(0, 0), K(0.5, 5), K(1.0, 5), K(1.6, 0)],
        'handL': const [K(0, 0), K(0.33, 0), K(1.05, 0)],
        'handR': const [K(0, 0), K(0.33, 0), K(1.05, 0)],
      }, t);

  static Pose2D _pointR(double t) => keyPose({
        'leftUpperArm': const [K(0, 0), K(0.25, -95), K(0.95, -95), K(1.2, 0)],
        'leftLowerArm': const [K(0, 0), K(0.25, 6), K(0.95, 6), K(1.2, 0)],
        'head': const [K(0, 0), K(0.3, 4), K(0.95, 4), K(1.2, 0)],
        'handL': const [K(0, 0), K(0.23, 2), K(0.97, 2)],
      }, t);

  static Pose2D _pointL(double t) => keyPose({
        'rightUpperArm': const [K(0, 0), K(0.25, 95), K(0.95, 95), K(1.2, 0)],
        'rightLowerArm': const [K(0, 0), K(0.25, -6), K(0.95, -6), K(1.2, 0)],
        'head': const [K(0, 0), K(0.3, -4), K(0.95, -4), K(1.2, 0)],
        'handR': const [K(0, 0), K(0.23, 2), K(0.97, 2)],
      }, t);

  static Pose2D _pointF(double t) => keyPose({
        'leftUpperArm': const [K(0, 0), K(0.28, -70), K(1.0, -70), K(1.4, 0)],
        'leftLowerArm': const [K(0, 0), K(0.28, -52), K(1.0, -52), K(1.4, 0)],
        'spine': const [K(0, 0), K(0.35, -3), K(1.0, -3), K(1.4, 0)],
        'handL': const [K(0, 0), K(0.26, 0), K(1.05, 0)],
      }, t);

  static Pose2D _palm(double t) => keyPose({
        'leftUpperArm': const [K(0, 0), K(0.35, -74), K(1.0, -74), K(1.5, 0)],
        'rightUpperArm': const [K(0, 0), K(0.35, 74), K(1.0, 74), K(1.5, 0)],
        'leftLowerArm': const [K(0, 0), K(0.35, -12), K(1.0, -12), K(1.5, 0)],
        'rightLowerArm': const [K(0, 0), K(0.35, 12), K(1.0, 12), K(1.5, 0)],
        'leftShoulder': const [K(0, 0), K(0.35, -3), K(1.0, -3), K(1.5, 0)],
        'rightShoulder': const [K(0, 0), K(0.35, 3), K(1.0, 3), K(1.5, 0)],
        'handL': const [K(0, 0), K(0.33, 0), K(1.05, 0)],
        'handR': const [K(0, 0), K(0.33, 0), K(1.05, 0)],
      }, t);

  static Pose2D _thumbsUp(double t) => keyPose({
        'leftUpperArm': const [K(0, 0), K(0.3, -34), K(1.0, -34), K(1.4, 0)],
        'leftLowerArm': const [K(0, 0), K(0.3, -96), K(1.0, -96), K(1.4, 0)],
        'head': const [K(0, 0), K(0.4, 5), K(1.0, 5), K(1.4, 0)],
        'handL': const [K(0, 0), K(0.28, 3), K(1.05, 3)],
      }, t);

  static Pose2D _explain(double t) {
    // Alternating forearm offers.
    final alt = math.sin(t * 2 * math.pi / 1.2);
    final fade = math.sin((t / 2.4).clamp(0.0, 1.0) * math.pi);
    final p = Pose2D();
    p.angles['leftUpperArm'] = -20 * fade;
    p.angles['rightUpperArm'] = 20 * fade;
    p.angles['leftLowerArm'] = (62 + 16 * alt) * fade;
    p.angles['rightLowerArm'] = (-62 + 16 * alt) * fade;
    p.angles['head'] = 3 * alt * fade;
    p.angles['spine'] = -2 * fade;
    p.extras['handL'] = 0;
    p.extras['handR'] = 0;
    return p;
  }

  static Pose2D _thinking(double t) => keyPose({
        'leftUpperArm': const [K(0, 0), K(0.4, -18), K(1.7, -18), K(2.2, 0)],
        'leftLowerArm': const [K(0, 0), K(0.4, -106), K(1.7, -106), K(2.2, 0)],
        'head': const [K(0, 0), K(0.5, 9), K(1.7, 9), K(2.2, 0)],
        'handL': const [K(0, 0), K(0.38, 1), K(1.75, 1)],
        '_lookX': const [K(0, 0), K(0.5, 0.55), K(1.7, 0.55), K(2.2, 0)],
        '_lookY': const [K(0, 0), K(0.5, 0.6), K(1.7, 0.6), K(2.2, 0)],
      }, t);

  static Pose2D _angryGesture(double t) => keyPose({
        'rightUpperArm': const [K(0, 0), K(0.2, 40), K(0.35, 52), K(0.5, 38), K(0.65, 52), K(0.8, 40), K(1.6, 0)],
        'rightLowerArm': const [K(0, 0), K(0.2, -92), K(1.1, -92), K(1.6, 0)],
        'spine': const [K(0, 0), K(0.3, -4), K(1.1, -4), K(1.6, 0)],
        'handR': const [K(0, 0), K(0.18, 1), K(1.15, 1)],
      }, t);

  // ---- Head movements (head layer one-shots) ---------------------------
  static Pose2D _nod(double t) => keyPose({
        'head': const [K(0, 0), K(0.22, 9), K(0.44, -5), K(0.66, 7), K(0.9, 0)],
        'neck': const [K(0, 0), K(0.22, 4), K(0.44, -2), K(0.66, 3), K(0.9, 0)],
      }, t);

  static Pose2D _shake(double t) => keyPose({
        'head': const [K(0, 0), K(0.18, 5), K(0.36, -5), K(0.54, 5), K(0.72, -5), K(0.9, 0)],
        '_lookX': const [K(0, 0), K(0.18, -0.8), K(0.36, 0.8), K(0.54, -0.8), K(0.72, 0.8), K(0.9, 0)],
      }, t);

  static Pose2D _tiltL(double t) => keyPose({
        'head': const [K(0, 0), K(0.35, 14), K(0.8, 14), K(1.0, 0)],
      }, t);

  static Pose2D _tiltR(double t) => keyPose({
        'head': const [K(0, 0), K(0.35, -14), K(0.8, -14), K(1.0, 0)],
      }, t);

  static Pose2D _lookL(double t) => keyPose({
        '_lookX': const [K(0, 0), K(0.3, -0.9), K(0.8, -0.9), K(1.1, 0)],
        'head': const [K(0, 0), K(0.3, 3), K(0.8, 3), K(1.1, 0)],
      }, t);

  static Pose2D _lookR(double t) => keyPose({
        '_lookX': const [K(0, 0), K(0.3, 0.9), K(0.8, 0.9), K(1.1, 0)],
        'head': const [K(0, 0), K(0.3, -3), K(0.8, -3), K(1.1, 0)],
      }, t);

  static final Map<String, Clip2D> all = {
    'idle': Clip2D(id: 'idle', duration: 4.2, loop: true, fn: idlePose),
    'walk': Clip2D(id: 'walk', duration: walkCycle, loop: true, fn: _walkLoop),
    'walk_start': Clip2D(id: 'walk_start', duration: 0.5, loop: false, fn: _walkStart),
    'walk_stop': Clip2D(id: 'walk_stop', duration: 0.55, loop: false, fn: _walkStop),
    'run': Clip2D(id: 'run', duration: runCycle, loop: true, fn: _runLoop),
    'run_start': Clip2D(id: 'run_start', duration: 0.42, loop: false, fn: _runStart),
    'run_stop': Clip2D(id: 'run_stop', duration: 0.55, loop: false, fn: _runStop),
    'stand_to_sit': Clip2D(id: 'stand_to_sit', duration: 1.1, loop: false, fn: _standToSit),
    'sit_idle': Clip2D(id: 'sit_idle', duration: 4.2, loop: true, fn: _sitIdle),
    'sit_to_stand': Clip2D(id: 'sit_to_stand', duration: 1.1, loop: false, fn: _sitToStand),
    'to_sleep': Clip2D(id: 'to_sleep', duration: 1.7, loop: false, fn: _toSleep),
    'sleep_loop': Clip2D(id: 'sleep_loop', duration: 4.6, loop: true, fn: _sleepLoop),
    'wake_up': Clip2D(id: 'wake_up', duration: 1.8, loop: false, fn: _wakeUp),
    'talk': Clip2D(id: 'talk', duration: 7.7, loop: true, fn: _talkLoop),
    // Gestures.
    'wave': Clip2D(id: 'wave', duration: 1.5, loop: false, fn: _wave),
    'greet': Clip2D(id: 'greet', duration: 1.6, loop: false, fn: _greet),
    'point_right': Clip2D(id: 'point_right', duration: 1.2, loop: false, fn: _pointR),
    'point_left': Clip2D(id: 'point_left', duration: 1.2, loop: false, fn: _pointL),
    'point_forward': Clip2D(id: 'point_forward', duration: 1.4, loop: false, fn: _pointF),
    'open_palm': Clip2D(id: 'open_palm', duration: 1.5, loop: false, fn: _palm),
    'thumbs_up': Clip2D(id: 'thumbs_up', duration: 1.4, loop: false, fn: _thumbsUp),
    'explain': Clip2D(id: 'explain', duration: 2.4, loop: false, fn: _explain),
    'thinking': Clip2D(id: 'thinking', duration: 2.2, loop: false, fn: _thinking),
    'angry_gesture': Clip2D(id: 'angry_gesture', duration: 1.6, loop: false, fn: _angryGesture),
    // Head movements.
    'nod': Clip2D(id: 'nod', duration: 0.9, loop: false, fn: _nod),
    'shake': Clip2D(id: 'shake', duration: 0.9, loop: false, fn: _shake),
    'tilt_left': Clip2D(id: 'tilt_left', duration: 1.0, loop: false, fn: _tiltL),
    'tilt_right': Clip2D(id: 'tilt_right', duration: 1.0, loop: false, fn: _tiltR),
    'look_left': Clip2D(id: 'look_left', duration: 1.1, loop: false, fn: _lookL),
    'look_right': Clip2D(id: 'look_right', duration: 1.1, loop: false, fn: _lookR),
    // v2.0 full-body one-shots.
    'jump': Clip2D(id: 'jump', duration: 1.15, loop: false, fn: jumpPose),
    'fall': Clip2D(id: 'fall', duration: 1.4, loop: false, fn: fallPose),
    'turn': Clip2D(id: 'turn', duration: 0.8, loop: false, fn: turnPose),
    'action': Clip2D(id: 'action', duration: 1.3, loop: false, fn: actionPose),
    'happy': Clip2D(id: 'happy', duration: 1.2, loop: false, fn: happyPose),
    'sad': Clip2D(id: 'sad', duration: 2.4, loop: false, fn: sadPose),
    'think': Clip2D(id: 'think', duration: 2.4, loop: false, fn: thinkPose),
  };

  /// The 14 standard animations every character must support (§ANIMATION
  /// LIBRARY). ids are shared by humanoids and quadrupeds.
  static const Set<String> standardAnimationIds = {
    'idle', 'walk', 'run', 'sit', 'sleep', 'talk',
    'jump', 'wave', 'action', 'happy', 'sad', 'think', 'turn', 'fall',
  };

  static Clip2D get(String id) => all[id] ?? all['idle']!;

  /// Quadruped clip table (rig quadruped_v1).
  static final Map<String, Clip2D> quadruped = {
    'idle': Clip2D(id: 'idle', duration: 4.4, loop: true, fn: q.quadIdle),
    'walk': Clip2D(id: 'walk', duration: 1.05, loop: true, fn: (t) => q.quadWalkPose(t * 2 * math.pi / 1.05, 1, t)),
    'run': Clip2D(id: 'run', duration: 0.55, loop: true, fn: (t) => q.quadRunPose(t * 2 * math.pi / 0.55, 1, t)),
    'sit': Clip2D(id: 'sit', duration: 1.2, loop: false, fn: (t) => q.quadSitPose(_ez01(t / 1.2), t)),
    'sit_idle': Clip2D(id: 'sit_idle', duration: 4.4, loop: true, fn: (t) => q.quadSitPose(1, t)),
    'stand_to_sit': Clip2D(id: 'stand_to_sit', duration: 1.2, loop: false, fn: (t) => q.quadSitPose(_ez01(t / 1.2), t)),
    'sit_to_stand': Clip2D(id: 'sit_to_stand', duration: 1.2, loop: false, fn: (t) => q.quadSitPose(1 - _ez01(t / 1.2), t)),
    'to_sleep': Clip2D(id: 'to_sleep', duration: 1.8, loop: false, fn: (t) => q.quadSleepPose(_ez01(t / 1.8), t)),
    'sleep_loop': Clip2D(id: 'sleep_loop', duration: 4.6, loop: true, fn: (t) => q.quadSleepPose(1, t)),
    'wake_up': Clip2D(id: 'wake_up', duration: 1.8, loop: false, fn: (t) => q.quadSleepPose(1 - _ez01(t / 1.8), t)),
    'talk': Clip2D(id: 'talk', duration: 7.3, loop: true, fn: q.quadTalkPose),
    'jump': Clip2D(id: 'jump', duration: 1.15, loop: false, fn: q.quadJumpPose),
    'wave': Clip2D(id: 'wave', duration: 2.0, loop: false, fn: q.quadWavePose),
    'action': Clip2D(id: 'action', duration: 1.5, loop: false, fn: q.quadActionPose),
    'fall': Clip2D(id: 'fall', duration: 1.3, loop: false, fn: q.quadFallPose),
    'turn': Clip2D(id: 'turn', duration: 0.8, loop: false, fn: q.quadTurnPose),
    'happy': Clip2D(id: 'happy', duration: 1.6, loop: false, fn: (t) => _quadHappy(t)),
    'sad': Clip2D(id: 'sad', duration: 2.4, loop: false, fn: (t) => _quadSad(t)),
    'think': Clip2D(id: 'think', duration: 2.4, loop: false, fn: (t) => _quadThink(t)),
    'walk_start': Clip2D(id: 'walk_start', duration: 0.5, loop: false, fn: (t) => Pose2D.lerp(q.quadIdle(t), q.quadWalkPose(_ez01(t / 0.5) * math.pi * 0.75, _ez01(t / 0.5), t), _ez01(t / 0.5))),
    'walk_stop': Clip2D(id: 'walk_stop', duration: 0.55, loop: false, fn: (t) => Pose2D.lerp(q.quadWalkPose(math.pi * 0.75 + _ez01(t / 0.55) * math.pi * 0.4, 1 - _ez01(t / 0.55), t), q.quadIdle(t), _ez01(t / 0.55))),
    'run_start': Clip2D(id: 'run_start', duration: 0.45, loop: false, fn: (t) => Pose2D.lerp(q.quadIdle(t), q.quadRunPose(_ez01(t / 0.45) * math.pi * 0.7, _ez01(t / 0.45), t), _ez01(t / 0.45))),
    'run_stop': Clip2D(id: 'run_stop', duration: 0.55, loop: false, fn: (t) => Pose2D.lerp(q.quadRunPose(math.pi * 0.7 + _ez01(t / 0.55) * math.pi * 0.3, 1 - _ez01(t / 0.55), t), q.quadIdle(t), _ez01(t / 0.55))),
  };

  static double _ez01(double u) => 0.5 - 0.5 * math.cos(math.pi * u.clamp(0.0, 1.0));

  static Pose2D _quadHappy(double t) {
    final p = q.quadIdle(t);
    final k = _ez01(t / 1.6);
    final bounce = (1 - k).abs() * (0.5 - 0.5 * math.cos(t * 2 * math.pi / 0.4));
    p.dy -= 12 * bounce;
    p.angles['head'] = (p.angles['head'] ?? 0) - 8 * (1 - k);
    p.angles['neck'] = (p.angles['neck'] ?? 0) - 6 * (1 - k);
    return p;
  }

  static Pose2D _quadSad(double t) {
    final p = q.quadIdle(t);
    final k = _ez01(t / 1.0);
    p.angles['neck'] = (p.angles['neck'] ?? 0) + 16 * k;
    p.angles['head'] = (p.angles['head'] ?? 0) + 14 * k;
    p.dy += 4 * k;
    return p;
  }

  static Pose2D _quadThink(double t) {
    final p = q.quadIdle(t);
    final k = _ez01(t / 0.8);
    p.angles['head'] = (p.angles['head'] ?? 0) - 10 * k + 2 * math.sin(t * 2);
    p.angles['earL'] = (p.angles['earL'] ?? 0) + 8 * k;
    return p;
  }

  /// Clip table for a rig kind.
  static Map<String, Clip2D> forRig(String rigKind) => rigKind == 'quadruped_v1' ? quadruped : all;

  static const Set<String> gestureIds = {
    'wave', 'greet', 'point_right', 'point_left', 'point_forward', 'open_palm',
    'thumbs_up', 'explain', 'thinking', 'angry_gesture',
  };

  static const Set<String> headMoveIds = {'nod', 'shake', 'tilt_left', 'tilt_right', 'look_left', 'look_right'};
}
