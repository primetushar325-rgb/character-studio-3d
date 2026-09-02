import 'dart:math' as math;

/// PHASE 5 — IK "where safe" (§ spec).
///
/// Analytic two-bone IK (upper+lower arm / thigh+shin): given a reach target
/// relative to the chain's root joint, returns absolute bone angles in the
/// engine's convention (0° = bone points along +Y / down the chain; angles
/// follow the rig's rotate() so FK reproduces the reach exactly).
///
/// Deterministic pure math — preview and export share the same result. It is
/// intentionally NOT wired into editor bone dragging (that would risk the
/// existing StoryTimeline + Auto Key model, which must not break); it is the
/// safe, programmatic building block for aimed reaches.
class TwoBoneIkSolution {
  const TwoBoneIkSolution({
    required this.rootAngleDeg,
    required this.midAngleDeg,
    required this.reachable,
  });

  /// Absolute world angle of the first (root) bone, degrees.
  final double rootAngleDeg;

  /// Absolute world angle of the second bone, degrees.
  final double midAngleDeg;

  /// False when the target was out of reach (angles straighten toward it).
  final bool reachable;
}

class TwoBoneIk {
  TwoBoneIk._();

  /// [l1], [l2] bone lengths; [target] reach point in the chain-root frame;
  /// [pole] +1/-1 picks the elbow/knee bend side.
  static TwoBoneIkSolution solve({
    required double l1,
    required double l2,
    required math.Point<double> target,
    int pole = 1,
  }) {
    final dist = math.sqrt(target.x * target.x + target.y * target.y);
    final d = dist.clamp((l1 - l2).abs() + 1e-9, l1 + l2 - 1e-9);
    final reachable = dist <= l1 + l2 + 1e-6 && dist >= (l1 - l2).abs() - 1e-6;

    // Law of cosines: interior bend at the middle joint + offset at root.
    final cosMid = ((l1 * l1) + (l2 * l2) - (d * d)) / (2 * l1 * l2);
    final bend = math.pi - math.acos(cosMid.clamp(-1.0, 1.0));
    final cosRoot = ((l1 * l1) + (d * d) - (l2 * l2)) / (2 * l1 * d);
    final rootInterior = math.acos(cosRoot.clamp(-1.0, 1.0));

    // Engine convention: bone direction at angle a (radians) is
    // rotate((0,1), a) = (-sin a, cos a). Inverting for the target bearing:
    final bearing = math.atan2(-target.x, target.y);

    final a1 = bearing - pole * rootInterior;
    final a2 = a1 + pole * bend;
    final deg = 180.0 / math.pi;
    return TwoBoneIkSolution(
      rootAngleDeg: a1 * deg,
      midAngleDeg: a2 * deg,
      reachable: reachable,
    );
  }

}
