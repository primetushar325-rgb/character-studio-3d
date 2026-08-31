import 'package:flutter_test/flutter_test.dart';
import 'package:character_studio_3d/core/utils/animation_names.dart';
import 'package:character_studio_3d/services/humanoid_detector.dart';
import 'package:character_studio_3d/services/glb_parser_service.dart';
import 'package:character_studio_3d/services/validation_service.dart';
import 'package:character_studio_3d/models/character.dart';

void main() {
  group('Standard action alias detection + confidence', () {
    const matcher = StandardActionMatcher();

    test('"Walk_Cycle" → Walk with ~98% confidence', () {
      final c = matcher.bestClipFor('walk', ['Walk_Cycle']);
      expect(c, isNotNull);
      expect(c!.confidence, greaterThanOrEqualTo(0.9));
    });

    test('"Walk_Cycle_01", "walk-cycle", "Walking" all detect as Walk', () {
      for (final name in ['Walk_Cycle_01', 'walk-cycle', 'Walking']) {
        final c = matcher.candidateForClip(name);
        expect(c, isNotNull, reason: '$name should map to walk');
        expect(c!.action, 'walk');
      }
    });

    test('"Human_Locomotion_02" → Walk at low confidence (71%)', () {
      final c = matcher.candidateForClip('Human_Locomotion_02');
      expect(c, isNotNull);
      expect(c!.action, 'walk');
      expect(c.confidence, closeTo(0.71, 0.01));
    });

    test('stand aliases include idle variants', () {
      for (final name in ['Idle', 'idle_01', 'default_idle', 'Standing']) {
        final c = matcher.candidateForClip(name);
        expect(c, isNotNull, reason: '$name should map to stand');
        expect(c!.action, 'stand');
      }
    });

    test('sit / sleep / talk aliases', () {
      expect(matcher.candidateForClip('Sit_Idle')!.action, 'sit');
      expect(matcher.candidateForClip('sitdown')!.action, 'sit');
      expect(matcher.candidateForClip('Lying')!.action, 'sleep');
      expect(matcher.candidateForClip('mixamo.com') ?? matcher.candidateForClip('lying_down'), isNotNull);
      expect(matcher.candidateForClip('Conversation')!.action, 'talk');
      expect(matcher.candidateForClip('speaking')!.action, 'talk');
      expect(matcher.candidateForClip('Sprint')!.action, 'run');
    });

    test('low-confidence candidates are NOT auto-mapped', () {
      final detection = matcher.detect(['Human_Locomotion_02']);
      expect(detection.mapped.containsKey('walk'), isFalse);
      expect(detection.suggested.containsKey('walk'), isTrue);
    });

    test('high-confidence candidates ARE auto-mapped', () {
      final detection = matcher.detect(['Idle', 'Walk', 'Run_Cycle', 'Sit']);
      expect(detection.mapped['stand']!.clipName, 'Idle');
      expect(detection.mapped['walk']!.clipName, 'Walk');
      expect(detection.mapped['run']!.clipName, 'Run_Cycle');
      expect(detection.mapped['sit']!.clipName, 'Sit');
      expect(detection.mapped.containsKey('sleep'), isFalse);
    });

    test('unknown animations are NOT mapped to any action', () {
      final detection = matcher.detect(['Zombie Roar', 'Sword Slash']);
      expect(detection.mapped, isEmpty);
    });
  });

  group('Humanoid bone detection', () {
    const detector = HumanoidDetector();

    test('mixamo naming is detected', () {
      final rig = detector.detect(const [
        'mixamorig:Hips',
        'mixamorig:Spine',
        'mixamorig:Neck',
        'mixamorig:Head',
        'mixamorig:LeftArm',
        'mixamorig:LeftForeArm',
        'mixamorig:LeftHand',
        'mixamorig:RightArm',
        'mixamorig:RightForeArm',
        'mixamorig:RightHand',
        'mixamorig:LeftUpLeg',
        'mixamorig:LeftLeg',
        'mixamorig:LeftFoot',
        'mixamorig:RightUpLeg',
        'mixamorig:RightLeg',
        'mixamorig:RightFoot',
      ]);
      expect(rig.humanLike, isTrue);
      expect(rig.matchedCount, greaterThanOrEqualTo(14));
      expect(rig.matches['hips']!.nodeName, 'mixamorig:Hips');
      expect(rig.matches['leftUpperArm']!.nodeName, 'mixamorig:LeftArm');
    });

    test('Blender .L/.R naming is detected', () {
      final rig = detector.detect(const [
        'hips',
        'spine',
        'head',
        'upper_arm.L',
        'forearm.L',
        'hand.L',
        'upper_arm.R',
        'forearm.R',
        'hand.R',
        'thigh.L',
        'shin.L',
        'foot.L',
      ]);
      expect(rig.matches['hips']!.matched, isTrue);
      expect(rig.matches['leftUpperArm']!.nodeName, 'upper_arm.L');
      expect(rig.matches['leftLowerArm']!.nodeName, 'forearm.L');
      expect(rig.matches['leftHand']!.nodeName, 'hand.L');
      expect(rig.matches['leftUpperLeg']!.nodeName, 'thigh.L');
    });

    test('non-humanoid rig stays honest', () {
      final rig = detector.detect(const ['b_Root_15', 'b_Hip_1']);
      expect(rig.humanLike, isFalse);
      expect(rig.matchedCount, lessThan(6));
    });
  });

  group('Validation report', () {
    const service = ValidationService();

    GlbModelData fakeData({
      List<String> animNames = const [],
      bool skeleton = true,
      int meshes = 2,
      int materials = 3,
      int textures = 2,
      int bones = 52,
    }) {
      return GlbModelData(
        animations: [
          for (final n in animNames) GlbAnimationData(name: n, durationSeconds: 1.5)
        ],
        nodeCount: 40,
        meshCount: meshes,
        materialCount: materials,
        textureCount: textures,
        skinCount: skeleton ? 1 : 0,
        generator: 'test',
        rootNodeCount: 1,
        cameraCount: 0,
        lightCount: 0,
        triangleCount: 24000,
        vertexCount: 12000,
        hasSkeleton: skeleton,
        totalBoneCount: skeleton ? bones : 0,
        skins: skeleton
            ? [GlbSkinData(name: 'Armature', boneNames: const ['hips', 'head'], hierarchyDepth: 8)]
            : const [],
        boneNames: skeleton ? const ['hips', 'spine', 'head'] : const [],
      );
    }

    test('full rigged character with 6 actions → ready + all found', () {
      final report = service.validate(
        data: fakeData(animNames: ['Idle', 'Walk', 'Run', 'Sit', 'Sleep', 'Talk']),
        fileBytes: 4 * 1024 * 1024,
      );
      expect(report.readiness, CharacterReadiness.ready);
      expect(report.foundActionCount, 6);
      expect(report.actions.every((a) => a.isFound), isTrue);
      expect(report.autoMapping['walk'], 'Walk');
    });

    test('missing actions are reported honestly', () {
      final report = service.validate(
        data: fakeData(animNames: ['Walk', 'Run']),
        fileBytes: 1024,
      );
      final walk = report.actions.firstWhere((a) => a.action == 'walk');
      final sleep = report.actions.firstWhere((a) => a.action == 'sleep');
      expect(walk.isFound, isTrue);
      expect(sleep.isFound, isFalse);
      expect(sleep.state, 'missing');
    });

    test('static model (no skeleton) → partial, no crash', () {
      final report = service.validate(
        data: fakeData(animNames: [], skeleton: false),
        fileBytes: 2048,
      );
      expect(report.readiness, CharacterReadiness.partial);
      expect(report.actions.every((a) => !a.isFound), isTrue);
      final skeletonCheck =
          report.checks.firstWhere((c) => c.id == 'char.skeleton');
      expect(skeletonCheck.status, ValidationStatus.warn);
    });

    test('no mesh → invalid', () {
      final report = service.validate(
        data: fakeData(meshes: 0),
        fileBytes: 1024,
      );
      expect(report.readiness, CharacterReadiness.invalid);
    });

    test('oversized file → fail check', () {
      final report = service.validate(
        data: fakeData(),
        fileBytes: 300 * 1024 * 1024,
      );
      final sizeCheck = report.checks.firstWhere((c) => c.id == 'file.size');
      expect(sizeCheck.status, ValidationStatus.fail);
      expect(report.readiness, CharacterReadiness.invalid);
    });
  });
}
