import 'dart:math' as math;

import 'rig2d.dart';

/// A full-body 2D pose: per-bone angle deltas (degrees) + root offsets and a
/// whole-body tilt used for lying down (sleep).
class Pose2D {
  Pose2D({Map<String, double>? angles, this.dx = 0, this.dy = 0, this.bodyTilt = 0, Map<String, double>? extras})
      : angles = angles ?? {},
        extras = extras ?? {};

  /// Bone name -> angle delta in degrees (0 = rest pose).
  final Map<String, double> angles;

  /// Root translation in rig units (screen space, +Y down).
  double dx;
  double dy;

  /// Whole-body rotation around the hips, degrees. -90 = lying down.
  double bodyTilt;

  /// Extra per-part parameters (hand shapes, prop angles, ...).
  final Map<String, double> extras;

  static Pose2D get neutral => Pose2D();

  double angle(String bone, [double fallback = 0]) => angles[bone] ?? fallback;
  double extra(String key, [double fallback = 0]) => extras[key] ?? fallback;

  Pose2D copy() => Pose2D(
        angles: Map.of(angles),
        dx: dx,
        dy: dy,
        bodyTilt: bodyTilt,
        extras: Map.of(extras),
      );

  /// Writes this pose's values on top of [into] (missing keys treated as 0).
  void onto(Pose2D into) {
    into.dx += dx;
    into.dy += dy;
    into.bodyTilt += bodyTilt;
    for (final e in angles.entries) {
      into.angles[e.key] = (into.angles[e.key] ?? 0) + e.value;
    }
    for (final e in extras.entries) {
      into.extras[e.key] = (into.extras[e.key] ?? 0) + e.value;
    }
  }

  /// Linear interpolation between two poses (missing bones = 0).
  static Pose2D lerp(Pose2D a, Pose2D b, double t) {
    final keys = <String>{...a.angles.keys, ...b.angles.keys};
    final exKeys = <String>{...a.extras.keys, ...b.extras.keys};
    return Pose2D(
      angles: {for (final k in keys) k: _l(a.angle(k), b.angle(k), t)},
      dx: _l(a.dx, b.dx, t),
      dy: _l(a.dy, b.dy, t),
      bodyTilt: _l(a.bodyTilt, b.bodyTilt, t),
      extras: {for (final k in exKeys) k: _l(a.extra(k), b.extra(k), t)},
    );
  }

  /// Max absolute difference between two poses for any bone (used to prove
  /// that animation actually moves limbs).
  static double maxDiff(Pose2D a, Pose2D b) {
    var m = (a.dx - b.dx).abs();
    m = math.max(m, (a.dy - b.dy).abs());
    m = math.max(m, (a.bodyTilt - b.bodyTilt).abs());
    final keys = <String>{...a.angles.keys, ...b.angles.keys};
    for (final k in keys) {
      m = math.max(m, (a.angle(k) - b.angle(k)).abs());
    }
    return m;
  }

  static double _l(double a, double b, double t) => a + (b - a) * t;
}

/// Reads only the given bone set from a pose (layer masking).
Pose2D maskPose(Pose2D pose, Set<String> bones) {
  final out = Pose2D();
  for (final b in bones) {
    if (pose.angles.containsKey(b)) out.angles[b] = pose.angle(b);
  }
  out.dx = pose.dx;
  out.dy = pose.dy;
  return out;
}

/// Holds a solved frame ready for painting: pose + solved skeleton.
class PuppetFrame {
  PuppetFrame({required this.pose, required this.solve, required this.time});

  final Pose2D pose;
  final SkeletonSolve solve;
  final double time;

  factory PuppetFrame.of(Pose2D pose, Rig2D rig, [double time = 0]) =>
      PuppetFrame(pose: pose, solve: solveSkeleton(rig, pose.angles), time: time);
}
