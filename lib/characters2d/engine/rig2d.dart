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
  Rig2D(this.bones, {this.groundY = 148, this.kind = 'humanoid_v1'}) : byName = {for (final b in bones) b.name: b};

  /// 'humanoid_v1' or 'quadruped_v1'.
  final String kind;

  final List<Bone2D> bones;
  final Map<String, Bone2D> byName;

  /// Design-space ground line (distance below the root origin).
  final double groundY;

  static Rig2D byKind(String kind) =>
      kind == 'quadruped_v1' ? Rig2D.quadrupedV1() : Rig2D.humanoidV1();

  /// Bones considered "upper body" for the upper-body animation layer.
  static const Set<String> upperBodyBones = {
    'spine', 'chest', 'neck', 'head',
    'leftShoulder', 'leftUpperArm', 'leftLowerArm', 'leftHand',
    'rightShoulder', 'rightUpperArm', 'rightLowerArm', 'rightHand',
  };

  /// Quadruped bones driven by the tail/ear secondary motion.
  static const Set<String> quadrupedTailBones = {'tail1', 'tail2', 'tail3', 'tail4'};
  static const Set<String> quadrupedEarBones = {'earL', 'earR'};

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
    return Rig2D(list, groundY: 148, kind: 'humanoid_v1');
  }

  /// Side-view quadruped rig (tiger & other four-legged characters).
  /// Facing +X (character looks to the RIGHT); root sits at ground level.
  factory Rig2D.quadrupedV1() {
    const List<Bone2D> q = [
      Bone2D(name: 'root', parent: '', attach: math.Point(0, 0), restAngle: 0, length: 0),
      Bone2D(name: 'body', parent: 'root', attach: math.Point(0, -60), restAngle: -90, length: 92),
      Bone2D(name: 'neck', parent: 'body', attach: math.Point(0, 44), restAngle: -40, length: 26),
      Bone2D(name: 'head', parent: 'neck', attach: math.Point(0, 26), restAngle: 42, length: 34),
      Bone2D(name: 'earL', parent: 'head', attach: math.Point(-6, 24), restAngle: -80, length: 13),
      Bone2D(name: 'earR', parent: 'head', attach: math.Point(6, 22), restAngle: -70, length: 13),
      Bone2D(name: 'jaw', parent: 'head', attach: math.Point(-3, 10), restAngle: 22, length: 15),
      Bone2D(name: 'tail1', parent: 'body', attach: math.Point(0, -44), restAngle: -118, length: 16),
      Bone2D(name: 'tail2', parent: 'tail1', attach: math.Point(0, 16), restAngle: -22, length: 15),
      Bone2D(name: 'tail3', parent: 'tail2', attach: math.Point(0, 15), restAngle: -18, length: 14),
      Bone2D(name: 'tail4', parent: 'tail3', attach: math.Point(0, 14), restAngle: -16, length: 13),
      // Front legs (near chest end of body).
      Bone2D(name: 'flUpper', parent: 'body', attach: math.Point(0, 38), restAngle: 90, length: 30),
      Bone2D(name: 'flLower', parent: 'flUpper', attach: math.Point(0, 30), restAngle: 0, length: 26),
      Bone2D(name: 'flPaw', parent: 'flLower', attach: math.Point(0, 26), restAngle: -80, length: 10),
      Bone2D(name: 'frUpper', parent: 'body', attach: math.Point(-3, 36), restAngle: 90, length: 30),
      Bone2D(name: 'frLower', parent: 'frUpper', attach: math.Point(0, 30), restAngle: 0, length: 26),
      Bone2D(name: 'frPaw', parent: 'frLower', attach: math.Point(0, 26), restAngle: -80, length: 10),
      // Back legs (near haunch end).
      Bone2D(name: 'blUpper', parent: 'body', attach: math.Point(0, -38), restAngle: 90, length: 32),
      Bone2D(name: 'blLower', parent: 'blUpper', attach: math.Point(0, 32), restAngle: 4, length: 26),
      Bone2D(name: 'blPaw', parent: 'blLower', attach: math.Point(0, 26), restAngle: -84, length: 10),
      Bone2D(name: 'brUpper', parent: 'body', attach: math.Point(3, -36), restAngle: 90, length: 32),
      Bone2D(name: 'brLower', parent: 'brUpper', attach: math.Point(0, 32), restAngle: 4, length: 26),
      Bone2D(name: 'brPaw', parent: 'brLower', attach: math.Point(0, 26), restAngle: -84, length: 10),
    ];
    return Rig2D(q, groundY: 0, kind: 'quadruped_v1');
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
