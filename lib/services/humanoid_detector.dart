import 'package:flutter/material.dart';

/// A single humanoid bone match result.
class BoneMatch {
  const BoneMatch({
    required this.standardBone,
    required this.displayName,
    this.nodeName,
    this.confidence = 0,
  });

  final String standardBone; // e.g. "leftUpperArm"
  final String displayName; // e.g. "Left Arm"
  final String? nodeName; // e.g. "upper_arm.L" or "mixamorig:LeftArm"
  final double confidence; // 0..1

  bool get matched => nodeName != null && confidence > 0;
}

/// Result of humanoid-rig detection over a skeleton's bone names.
class HumanoidRig {
  const HumanoidRig({
    required this.matches,
    required this.humanLike,
    required this.score,
  });

  final Map<String, BoneMatch> matches; // standardBone → match
  final bool humanLike;
  final double score; // 0..1 overall confidence

  int get matchedCount => matches.values.where((m) => m.matched).length;
}

/// Detects a standard humanoid bone structure inside any skeleton by fuzzy
/// bone-name matching (mixamo, Blender .L/.R, Unreal _l/_r, glTF standard).
///
/// This powers the Bone Mapping UI and the "human-like character" validation
/// check. It never fabricates data: unmatched bones stay empty.
class HumanoidDetector {
  const HumanoidDetector();

  static const List<(String, String)> standardBones = [
    ('hips', 'Hips'),
    ('spine', 'Spine'),
    ('chest', 'Chest'),
    ('neck', 'Neck'),
    ('head', 'Head'),
    ('leftUpperArm', 'Left Upper Arm'),
    ('leftLowerArm', 'Left Lower Arm'),
    ('leftHand', 'Left Hand'),
    ('rightUpperArm', 'Right Upper Arm'),
    ('rightLowerArm', 'Right Lower Arm'),
    ('rightHand', 'Right Hand'),
    ('leftUpperLeg', 'Left Upper Leg'),
    ('leftLowerLeg', 'Left Lower Leg'),
    ('leftFoot', 'Left Foot'),
    ('rightUpperLeg', 'Right Upper Leg'),
    ('rightLowerLeg', 'Right Lower Leg'),
    ('rightFoot', 'Right Foot'),
  ];

  /// Alias tokens are matched against *normalized* bone names
  /// (lowercase, alphanumeric only, separators & digits stripped).
  static const Map<String, List<String>> _aliases = {
    'hips': ['hips', 'hip', 'pelvis', 'pelvisroot', 'root', 'bip01', 'b_hip'],
    'spine': ['spine', 'spine', 'spines', 'b_spine', 'spinebase'],
    'chest': ['chest', 'upperchest', 'uppertorso', 'spine', 'b_chest'],
    'neck': ['neck', 'b_neck', 'neck'],
    'head': ['head', 'b_head', 'headtop'],
    'leftUpperArm': [
      'leftupperarm', 'upperarml', 'leftarm', 'armleft', 'upperarml',
      'larml', 'leftshoulder'
    ],
    'leftLowerArm': [
      'leftlowerarm', 'lowerarml', 'leftforearm', 'forearml', 'forearml',
      'leftelbow', 'lelbowl'
    ],
    'leftHand': ['lefthand', 'handl', 'leftwrist', 'wristl', 'b_handl'],
    'rightUpperArm': [
      'rightupperarm', 'upperarmr', 'rightarm', 'armright', 'upperarmr',
      'rarml', 'rightshoulder'
    ],
    'rightLowerArm': [
      'rightlowerarm', 'lowerarmr', 'rightforearm', 'forearmr', 'forearmr',
      'rightelbow', 'relbowr'
    ],
    'rightHand': ['righthand', 'handr', 'rightwrist', 'wristr', 'b_handr'],
    'leftUpperLeg': [
      'leftupperleg', 'upperlegl', 'leftthigh', 'thighl', 'leftupleg',
      'uplegl', 'leftupleg', 'legupperl'
    ],
    'leftLowerLeg': [
      'leftlowerleg', 'lowerlegl', 'leftcalf', 'calfl', 'leftshin',
      'shinl', 'leftknee', 'leglowerl'
    ],
    'leftFoot': ['leftfoot', 'footl', 'leftankle', 'anklel', 'b_footl'],
    'rightUpperLeg': [
      'rightupperleg', 'upperlegr', 'rightthigh', 'thighr', 'rightupleg',
      'uplegr', 'legupperr'
    ],
    'rightLowerLeg': [
      'rightlowerleg', 'lowerlegr', 'rightcalf', 'calfr', 'rightshin',
      'shinr', 'rightknee', 'leglowerr'
    ],
    'rightFoot': ['rightfoot', 'footr', 'rightankle', 'ankler', 'b_footr'],
  };

  /// Bones that must be present to consider the rig human-like.
  static const List<String> _coreBones = ['hips', 'head'];

  /// Detect the humanoid mapping over [boneNames].
  HumanoidRig detect(List<String> boneNames) {
    final normalized = <(String, String)>[
      for (final b in boneNames) (b, _normalize(b))
    ];

    final matches = <String, BoneMatch>{};
    var confidenceSum = 0.0;
    var matched = 0;

    for (final (key, _) in standardBones) {
      final match = _bestFor(key, normalized);
      matches[key] = match;
      if (match.matched) {
        matched++;
        confidenceSum += match.confidence;
      }
    }

    final coreOk = _coreBones.every((k) => matches[k]?.matched ?? false);
    final score = matched == 0 ? 0.0 : confidenceSum / matched;
    final humanLike = coreOk && matched >= 6 && score >= 0.6;

    return HumanoidRig(
      matches: matches,
      humanLike: humanLike,
      score: score,
    );
  }

  BoneMatch _bestFor(String standardBone, List<(String, String)> bones) {
    final aliases = _aliases[standardBone] ?? const <String>[];
    BoneMatch? best;

    for (final alias in aliases) {
      for (final (original, normalized) in bones) {
        if (normalized.isEmpty) continue;
        double confidence = 0;
        if (normalized == alias) {
          confidence = 0.95;
        } else if (alias.length >= 7 && normalized.contains(alias)) {
          confidence = 0.85; // e.g. "mixamorig:LeftArm" ⊃ "leftarm"
        } else if (alias.length >= 5 && normalized.contains(alias)) {
          confidence = 0.75; // e.g. "b_Hip_1" ⊃ "hip"
        } else if (alias.length >= 4 &&
            normalized.length <= alias.length + 3 &&
            normalized.contains(alias)) {
          confidence = 0.7;
        }
        if (confidence > 0 && (best == null || confidence > best.confidence)) {
          best = BoneMatch(
            standardBone: standardBone,
            displayName: _labelFor(standardBone),
            nodeName: original,
            confidence: confidence,
          );
        }
      }
    }
    return best ??
        BoneMatch(
          standardBone: standardBone,
          displayName: _labelFor(standardBone),
        );
  }

  static String _labelFor(String key) {
    for (final (k, label) in standardBones) {
      if (k == key) return label;
    }
    return key;
  }

  static String _normalize(String raw) {
    var s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    // Strip mixamo / blender / engine prefixes like "mixamorig" and "b".
    s = s.replaceAll(RegExp(r'^(mixamorig|armature|b|def|org)'), '');
    return s;
  }
}

/// Humanoid bone icons for the mapping UI.
IconData boneIconFor(String standardBone) {
  switch (standardBone) {
    case 'hips':
      return Icons.accessibility_rounded;
    case 'spine':
    case 'chest':
      return Icons.linear_scale_rounded;
    case 'neck':
    case 'head':
      return Icons.face_rounded;
    case 'leftUpperArm':
    case 'rightUpperArm':
    case 'leftLowerArm':
    case 'rightLowerArm':
      return Icons.front_hand_rounded;
    case 'leftHand':
    case 'rightHand':
      return Icons.back_hand_rounded;
    case 'leftUpperLeg':
    case 'rightUpperLeg':
    case 'leftLowerLeg':
    case 'rightLowerLeg':
      return Icons.airline_seat_legroom_extra_rounded;
    case 'leftFoot':
    case 'rightFoot':
      return Icons.directions_walk_rounded;
    default:
      return Icons.accessibility_new_rounded;
  }
}
