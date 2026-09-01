import 'dart:math' as math;

import 'pose2d.dart';

/// Quadruped (side-view) animation library — professional gait mechanics.
///
/// WALK uses the diagonal couplet gait requested by the spec:
///   Front-Left + Back-RIGHT move together, then Front-Right + Back-LEFT.
/// Legs swing fore/aft around shoulder/hip, knees fold only during the lift
/// (passing) phase so paws stay planted and never slide, the body bounces
/// twice per cycle, pitches over the supporting legs, the head counter-nods,
/// ears flop with a small delay and the 4-segment tail flows with per-segment
/// phase delay (classic follow-through).

double _sin(double t) => math.sin(t);
double _lift(double phase) => math.max(0.0, math.sin(phase));

/// Secondary tail flow: each segment follows the previous with a delay.
void _tail(Pose2D p, double t, double baseSway, double amp, [double speed = 1]) {
  const delays = [0.0, 0.55, 1.1, 1.65];
  const amps = [0.55, 0.85, 1.0, 1.0];
  for (var i = 0; i < 4; i++) {
    p.angles['tail${i + 1}'] = baseSway * (i == 0 ? 0.6 : 1) + amp * amps[i] * _sin(t * speed * 2.2 - delays[i]);
  }
}

void _ears(Pose2D p, double t, double amp, double speed) {
  p.angles['earL'] = amp * _sin(t * speed * 3.1);
  p.angles['earR'] = amp * _sin(t * speed * 3.1 + 0.6);
}

/// ---- IDLE: breathing, weight shift, tail sway, ear twitch ---------------
Pose2D quadIdle(double t) {
  final p = Pose2D();
  final breath = _sin(t * 2 * math.pi / 3.6);
  p.dy = 1.2 * breath;
  p.angles['body'] = 0.8 * breath;
  p.angles['neck'] = 2.0 * breath + 1.6 * _sin(t * 2 * math.pi / 5.3);
  p.angles['head'] = -1.5 * breath + 2.2 * _sin(t * 2 * math.pi / 7.1);
  p.angles['flUpper'] = 1.0 * breath;
  p.angles['frUpper'] = 1.0 * breath;
  p.angles['blUpper'] = -0.8 * breath;
  p.angles['brUpper'] = -0.8 * breath;
  _tail(p, t, 3.5, 7, 0.55);
  _ears(p, t, 3.0, 0.5);
  return p;
}

/// ---- WALK: diagonal couplet gait ----------------------------------------
/// phase 0 = FL+BR forward (contact), π = FR+BL forward.
Pose2D quadWalkPose(double phase, double stride, [double t = 0]) {
  final p = Pose2D();
  // Diagonal pairs: (fl, br) at phase; (fr, bl) at phase+π.
  void leg(String pre, double ph, bool front) {
    final swing = _sin(ph);
    final lift = _lift(ph + (front ? 0.0 : math.pi * 0.5)); // back legs lift slightly later
    final liftF = _lift(ph);
    p.angles['${pre}Upper'] = -26 * swing * stride;
    if (front) {
      // Elbow folds only while the paw is in the air.
      p.angles['${pre}Lower'] = 38 * liftF * stride;
      p.angles['${pre}Paw'] = -12 * liftF * stride;
    } else {
      // Hock folds the other way.
      p.angles['${pre}Lower'] = -34 * lift * stride;
      p.angles['${pre}Paw'] = -10 * lift * stride;
    }
  }

  leg('fl', phase, true);
  leg('br', phase, false);
  leg('fr', phase + math.pi, true);
  leg('bl', phase + math.pi, false);

  // Body: two bounces per cycle + pitch over the supporting diagonal.
  final bounce = 0.5 - 0.5 * math.cos(2 * phase);
  p.dy = -2.6 * bounce * stride;
  p.angles['body'] = 1.8 * _sin(phase) * stride;
  p.dx = 1.4 * _sin(phase) * stride;
  // Head stabilization (counter to body pitch) + subtle nod.
  p.angles['neck'] = -1.2 * _sin(phase) * stride + 1.2 * _sin(2 * phase) * stride;
  p.angles['head'] = -1.0 * _sin(phase) * stride - 1.5 * _sin(2 * phase + 0.4) * stride;
  _tail(p, t, -2, 10, 1.35);
  _ears(p, t, 4.5, 1.35);
  return p;
}

/// ---- RUN: gallop — front pair then back pair, strong spine motion -------
Pose2D quadRunPose(double phase, double stride, [double t = 0]) {
  final p = Pose2D();
  // Gallop: both front legs together (small offset), both back together.
  final frontPh = phase;
  final backPh = phase + math.pi * 0.9;

  void legFront(String pre, double off) {
    final ph = frontPh + off;
    final swing = _sin(ph);
    final lift = _lift(ph);
    p.angles['${pre}Upper'] = (-38 * swing - 6) * stride;
    p.angles['${pre}Lower'] = 62 * lift * stride;
    p.angles['${pre}Paw'] = -26 * lift * stride + 10 * swing * stride;
  }

  void legBack(String pre, double off) {
    final ph = backPh + off;
    final swing = _sin(ph);
    final lift = _lift(ph);
    p.angles['${pre}Upper'] = (-40 * swing + 8) * stride;
    p.angles['${pre}Lower'] = -58 * lift * stride;
    p.angles['${pre}Paw'] = -22 * lift * stride;
  }

  legFront('fl', 0);
  legFront('fr', 0.5);
  legBack('bl', 0);
  legBack('br', 0.5);

  // Spine flex + strong bounce + forward lean.
  final bounce = 0.5 - 0.5 * math.cos(2 * phase);
  p.dy = -7.5 * bounce * stride;
  p.angles['body'] = 4.5 * _sin(phase) * stride + 2.5 * stride;
  p.dx = 2.6 * _sin(phase) * stride;
  // Head + neck stretch forward, stabilized.
  p.angles['neck'] = -8 * stride - 3 * _sin(phase) * stride;
  p.angles['head'] = 6 * stride + 2.4 * _sin(phase) * stride;
  _tail(p, t, 6, 16, 2.4);
  _ears(p, t, 8, 2.4);
  return p;
}

/// ---- SIT: tiger sits on haunches ------------------------------------------
Pose2D quadSitPose(double f, [double t = 0]) {
  final p = Pose2D();
  // Body tilts up at the front, rear sinks to the ground.
  p.angles['body'] = 26 * f;
  p.dy = 16 * f;
  p.angles['neck'] = -14 * f;
  p.angles['head'] = -8 * f + 1.2 * _sin(t * 2 * math.pi / 4.2);
  // Front legs straight, planted.
  p.angles['flUpper'] = -26 * f;
  p.angles['flLower'] = 0.0;
  p.angles['frUpper'] = -24 * f;
  p.angles['frLower'] = 0.0;
  p.angles['flPaw'] = -6 * f;
  p.angles['frPaw'] = -6 * f;
  // Back legs fold under.
  p.angles['blUpper'] = 78 * f;
  p.angles['blLower'] = -96 * f;
  p.angles['blPaw'] = 24 * f;
  p.angles['brUpper'] = 82 * f;
  p.angles['brLower'] = -100 * f;
  p.angles['brPaw'] = 26 * f;
  _tail(p, t, -10 * f, 5, 0.5);
  _ears(p, t, 2.5, 0.5);
  return p;
}

/// ---- SLEEP: curled lying ---------------------------------------------------
Pose2D quadSleepPose(double f, [double t = 0]) {
  final p = Pose2D();
  // Body settles to the ground, slight curl.
  p.dy = 38 * f;
  p.angles['body'] = -4 * f;
  p.angles['neck'] = 34 * f;
  p.angles['head'] = 20 * f + 1.5 * _sin(t * 2 * math.pi / 5.5);
  // Legs folded.
  p.angles['flUpper'] = 58 * f;
  p.angles['flLower'] = 52 * f;
  p.angles['flPaw'] = -20 * f;
  p.angles['frUpper'] = 55 * f;
  p.angles['frLower'] = 50 * f;
  p.angles['frPaw'] = -18 * f;
  p.angles['blUpper'] = 74 * f;
  p.angles['blLower'] = -88 * f;
  p.angles['blPaw'] = 20 * f;
  p.angles['brUpper'] = 76 * f;
  p.angles['brLower'] = -92 * f;
  p.angles['brPaw'] = 22 * f;
  // Tail curls around the body.
  p.angles['tail1'] = -70 * f;
  p.angles['tail2'] = -46 * f;
  p.angles['tail3'] = -30 * f + 3 * _sin(t * 0.7);
  p.angles['tail4'] = -18 * f + 3 * _sin(t * 0.7 + 1);
  // Breathing.
  p.dy += 0.9 * _sin(t * 2 * math.pi / 4.6);
  return p;
}

/// ---- JUMP: crouch → launch → airball → land squash ----------------------
Pose2D quadJumpPose(double t) {
  const d = 1.15;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  if (u < 0.22) {
    // Anticipation crouch.
    final k = _ease(u / 0.22);
    p.dy = 12 * k;
    _foldLegs(p, k * 0.8);
    p.angles['neck'] = 8 * k;
    p.angles['body'] = -4 * k;
  } else if (u < 0.62) {
    // Launch + air.
    final k = _ease((u - 0.22) / 0.4);
    p.dy = -12 - 62 * math.sin(k * math.pi);
    _extendLegs(p, 1);
    p.angles['body'] = -10 + 14 * k;
    p.angles['neck'] = -12 * k;
    p.angles['head'] = 8 * k;
    _tail(p, t, 14, 12, 3);
    _ears(p, t, 10, 3);
    return p;
  } else if (u < 0.8) {
    // Landing squash.
    final k = _ease((u - 0.62) / 0.18);
    p.dy = -8 + 24 * k;
    _foldLegs(p, k);
    p.angles['body'] = 6 * k;
    p.angles['neck'] = 10 * k;
  } else {
    // Recover to stand.
    final k = _ease((u - 0.8) / 0.2);
    p.dy = 16 * (1 - k);
    _foldLegs(p, 1 - k);
  }
  _tail(p, t, 2, 8, 1);
  _ears(p, t, 4, 1);
  return p;
}

void _foldLegs(Pose2D p, double k) {
  for (final pre in ['fl', 'fr']) {
    p.angles['${pre}Upper'] = 16 * k;
    p.angles['${pre}Lower'] = 44 * k;
    p.angles['${pre}Paw'] = -14 * k;
  }
  for (final pre in ['bl', 'br']) {
    p.angles['${pre}Upper'] = -14 * k;
    p.angles['${pre}Lower'] = -52 * k;
    p.angles['${pre}Paw'] = -12 * k;
  }
}

void _extendLegs(Pose2D p, double k) {
  for (final pre in ['fl', 'fr']) {
    p.angles['${pre}Upper'] = -38 * k;
    p.angles['${pre}Lower'] = 8 * k;
    p.angles['${pre}Paw'] = -18 * k;
  }
  for (final pre in ['bl', 'br']) {
    p.angles['${pre}Upper'] = 34 * k;
    p.angles['${pre}Lower'] = -10 * k;
    p.angles['${pre}Paw'] = -16 * k;
  }
}

double _ease(double u) => 0.5 - 0.5 * math.cos(math.pi * u.clamp(0.0, 1.0));

/// ---- WAVE: sits up on haunches and waves a front paw --------------------
Pose2D quadWavePose(double t) {
  final p = quadSitPose(1, t);
  final k = _ease((t / 0.4).clamp(0.0, 1.0));
  // Raise the near front leg and wave.
  p.angles['flUpper'] = -70 * k + 6 * _sin(t * 11);
  p.angles['flLower'] = 30 * k + 22 * math.max(0, _sin(t * 11));
  p.angles['flPaw'] = 10 * k;
  p.angles['neck'] = p.angles['neck']! - 6 * k;
  p.angles['head'] = (p.angles['head'] ?? 0) + 6 * k + 2 * _sin(t * 11);
  p.extras['handL'] = 0; // paw stays a paw
  _tail(p, t, -8, 12, 1.6);
  return p;
}

/// ---- FALL: tips over with legs flailing ----------------------------------
Pose2D quadFallPose(double t) {
  const d = 1.3;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  final drop = 38 * u * u;
  p.dy = drop;
  p.angles['body'] = 34 * u;
  p.angles['neck'] = -18 * u + 4 * _sin(t * 9);
  p.angles['head'] = 12 * u;
  final flail = (1 - u) * math.sin(t * 14);
  for (final pre in ['fl', 'fr', 'bl', 'br']) {
    p.angles['${pre}Upper'] = 20 * flail + (pre == 'fl' || pre == 'fr' ? 20 : -14) * u;
    p.angles['${pre}Lower'] = (pre == 'fl' || pre == 'fr' ? 30 : -30) * u * 0.6;
  }
  _tail(p, t, 8, 18, 3);
  _ears(p, t, 12, 3);
  return p;
}

/// ---- ACTION / pounce: stalk → pounce with paws out → land ---------------
Pose2D quadActionPose(double t) {
  const d = 1.5;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  if (u < 0.4) {
    // Stalking crouch (anticipation).
    final k = _ease(u / 0.4);
    p.dy = 14 * k;
    _foldLegs(p, k * 0.7);
    p.angles['neck'] = 14 * k;
    p.angles['head'] = -6 * k;
    p.angles['body'] = -3 * k;
    _tail(p, t, 8, 6, 0.8);
  } else if (u < 0.72) {
    // Pounce!
    final k = _ease((u - 0.4) / 0.32);
    p.dy = 14 - 74 * math.sin(k * math.pi);
    p.dx = 60 * k;
    _extendLegs(p, 1);
    p.angles['body'] = -12 * (1 - k);
    p.angles['neck'] = -16 * k;
    p.angles['head'] = 10 * k;
    _tail(p, t, -12, 14, 3);
    _ears(p, t, 10, 3);
  } else {
    // Land + settle.
    final k = _ease((u - 0.72) / 0.28);
    p.dy = -6 + 22 * k;
    p.dx = 60;
    _foldLegs(p, k);
    p.angles['neck'] = 12 * (1 - k);
    p.angles['body'] = 5 * k;
    _tail(p, t, 4, 8, 1.2);
  }
  _ears(p, t, 5, 1.2);
  return p;
}

/// ---- TALK: head + jaw + brow energy over idle ---------------------------
Pose2D quadTalkPose(double t) {
  final p = quadIdle(t);
  p.angles['head'] = p.angles['head']! + 3.0 * math.sin(t * 2 * math.pi / 2.6) + 2.0 * math.sin(t * 2 * math.pi / 4.3 + 1);
  p.angles['neck'] = p.angles['neck']! + 1.8 * math.sin(t * 2 * math.pi / 3.4 + 0.7);
  p.angles['earL'] = p.angles['earL']! + 2.5 * math.sin(t * 2 * math.pi / 2.2);
  p.angles['earR'] = p.angles['earR']! + 2.5 * math.sin(t * 2 * math.pi / 2.7 + 1);
  _tail(p, t, 5, 9, 1.1);
  return p;
}

/// ---- TURN: little hop with head check ------------------------------------
Pose2D quadTurnPose(double t) {
  const d = 0.8;
  final u = (t / d).clamp(0.0, 1.0);
  final p = Pose2D();
  if (u < 0.5) {
    final k = _ease(u / 0.5);
    p.dy = -26 * math.sin(k * math.pi);
    _foldLegs(p, k * 0.5);
    p.angles['neck'] = 16 * k;
    p.angles['head'] = 10 * k;
  } else {
    final k = _ease((u - 0.5) / 0.5);
    p.dy = -26 * math.sin((1 - k) * math.pi);
    _foldLegs(p, (1 - k) * 0.5);
    p.angles['neck'] = 16 * (1 - k);
    p.angles['head'] = -10 * k;
  }
  _tail(p, t, 0, 14, 2.2);
  _ears(p, t, 9, 2.2);
  return p;
}
