import 'dart:math' as math;

/// A single bone of the universal 2D humanoid rig (`humanoid_v1`).
///
/// The bone's local frame has its origin at the joint pivot and +Y pointing
/// along the bone segment. [restAngle] is the orientation (degrees, clockwise
/// positive on screen) relative to the parent bone's orientation at rest.
class Bone2D {
  const Bone2D({
    required this.name,
    required this.parent,
    required this.attach,
    required this.restAngle,
    required this.length,
  });

  final String name;
  final String parent;

  /// Attachment point inside the PARENT bone's local frame
  /// (origin = parent joint, +Y = along the parent bone).
  final math.Point<double> attach;

  /// Rest orientation relative to the parent, degrees.
  final double restAngle;

  /// Bone length in rig units (design height ~= 330u).
  final double length;
}

/// Universal 2D humanoid rig shared by every 2D character.
///
/// Naming is identical for all characters so animations can be reused:
/// root, hips, spine, chest, neck, head,
/// {left,right}{Shoulder,UpperArm,LowerArm,Hand},
/// {left,right}{UpperLeg,LowerLeg,Foot}.
class Rig2D {
  Rig2D(this.bones) : byName = {for (final b in bones) b.name: b};

  final List<Bone2D> bones;
  final Map<String, Bone2D> byName;

  /// Design-space ground line (distance below the hips origin).
  static const double groundY = 148;

  /// Bones considered "upper body" for the upper-body animation layer.
  static const Set<String> upperBodyBones = {
    'spine', 'chest', 'neck', 'head',
    'leftShoulder', 'leftUpperArm', 'leftLowerArm', 'leftHand',
    'rightShoulder', 'rightUpperArm', 'rightLowerArm', 'rightHand',
  };

  /// Bones owned by the base (locomotion) layer.
  static const Set<String> baseBodyBones = {
    'hips', 'leftUpperLeg', 'leftLowerLeg', 'leftFoot',
    'rightUpperLeg', 'rightLowerLeg', 'rightFoot',
  };

  factory Rig2D.humanoidV1() {
    const List<Bone2D> list = [
      // Pelvis chain (origin = hip centre).
      Bone2D(name: 'root', parent: '', attach: math.Point(0, 0), restAngle: 0, length: 0),
      Bone2D(name: 'hips', parent: 'root', attach: math.Point(0, 0), restAngle: 0, length: 14),
      Bone2D(name: 'spine', parent: 'hips', attach: math.Point(0, -6), restAngle: 180, length: 32),
      Bone2D(name: 'chest', parent: 'spine', attach: math.Point(0, 32), restAngle: 0, length: 24),
      Bone2D(name: 'neck', parent: 'chest', attach: math.Point(0, 24), restAngle: 0, length: 9),
      Bone2D(name: 'head', parent: 'neck', attach: math.Point(0, 9), restAngle: 0, length: 50),
      // Arms. Character-left appears on screen +X for a viewer-facing puppet.
      Bone2D(name: 'leftShoulder', parent: 'chest', attach: math.Point(20, -12), restAngle: -90, length: 9),
      Bone2D(name: 'leftUpperArm', parent: 'leftShoulder', attach: math.Point(0, 9), restAngle: 90, length: 44),
      Bone2D(name: 'leftLowerArm', parent: 'leftUpperArm', attach: math.Point(0, 44), restAngle: 0, length: 40),
      Bone2D(name: 'leftHand', parent: 'leftLowerArm', attach: math.Point(0, 40), restAngle: 0, length: 15),
      Bone2D(name: 'rightShoulder', parent: 'chest', attach: math.Point(-20, -12), restAngle: 90, length: 9),
      Bone2D(name: 'rightUpperArm', parent: 'rightShoulder', attach: math.Point(0, 9), restAngle: -90, length: 44),
      Bone2D(name: 'rightLowerArm', parent: 'rightUpperArm', attach: math.Point(0, 44), restAngle: 0, length: 40),
      Bone2D(name: 'rightHand', parent: 'rightLowerArm', attach: math.Point(0, 40), restAngle: 0, length: 15),
      // Legs.
      Bone2D(name: 'leftUpperLeg', parent: 'hips', attach: math.Point(12, 10), restAngle: 0, length: 62),
      Bone2D(name: 'leftLowerLeg', parent: 'leftUpperLeg', attach: math.Point(0, 62), restAngle: 0, length: 58),
      Bone2D(name: 'leftFoot', parent: 'leftLowerLeg', attach: math.Point(0, 58), restAngle: 0, length: 12),
      Bone2D(name: 'rightUpperLeg', parent: 'hips', attach: math.Point(-12, 10), restAngle: 0, length: 62),
      Bone2D(name: 'rightLowerLeg', parent: 'rightUpperLeg', attach: math.Point(0, 62), restAngle: 0, length: 58),
      Bone2D(name: 'rightFoot', parent: 'rightLowerLeg', attach: math.Point(0, 58), restAngle: 0, length: 12),
    ];
    return Rig2D(list);
  }

  bool get isValid {
    final names = bones.map((b) => b.name).toSet();
    if (names.length != bones.length) return false;
    for (final b in bones) {
      if (b.name == 'root') continue;
      if (!names.contains(b.parent)) return false;
    }
    // No cycles: every chain must reach root.
    for (final b in bones) {
      var cur = b;
      var guard = 0;
      while (cur.name != 'root') {
        final p = byName[cur.parent];
        if (p == null) return false;
        cur = p;
        if (++guard > bones.length) return false;
      }
    }
    return true;
  }

  Iterable<String> get boneNames => byName.keys;
}

/// Result of a forward-kinematics solve: world angle + joint position per bone.
class SkeletonSolve {
  SkeletonSolve(this.angles, this.joints);

  /// World orientation per bone, radians (0 = pointing down).
  final Map<String, double> angles;

  /// World position of each bone's joint pivot, rig units.
  final Map<String, math.Point<double>> joints;

  double angleOf(String bone) => angles[bone] ?? 0;
  math.Point<double> jointOf(String bone) => joints[bone] ?? const math.Point(0, 0);
}

math.Point<double> _rotate(math.Point<double> p, double radians) {
  final c = math.cos(radians);
  final s = math.sin(radians);
  return math.Point(p.x * c - p.y * s, p.x * s + p.y * c);
}

/// Forward kinematics: applies pose deltas (degrees) on top of rest angles.
SkeletonSolve solveSkeleton(Rig2D rig, Map<String, double> poseAngles) {
  final angles = <String, double>{};
  final joints = <String, math.Point<double>>{};
  final deg = math.pi / 180.0;

  void solve(Bone2D bone, math.Point<double> parentJoint, double parentWorldRad) {
    final worldDeg = parentWorldRad / deg + bone.restAngle + (poseAngles[bone.name] ?? 0);
    final worldRad = worldDeg * deg;
    angles[bone.name] = worldRad;
    joints[bone.name] = parentJoint;
    for (final child in rig.bones) {
      if (child.parent == bone.name) {
        final local = _rotate(child.attach, worldRad);
        solve(child, parentJoint + local, worldRad);
      }
    }
  }

  final root = rig.byName['root']!;
  solve(root, const math.Point(0, 0), 0);
  return SkeletonSolve(angles, joints);
}
