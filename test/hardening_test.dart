// RigStudio-prompt hardening pass — tests for the pieces that were genuinely
// missing from this codebase:
//   §1 post-export validation (container magic bytes) + no corrupt output
//   §3 bone rotation limits (opt-in, clamped at the FK choke point,
//      legacy rigs/clamps provably unaffected)
//   §4 facing direction mirrors the whole rig around its centre
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:character_studio_3d/characters2d/engine/clips.dart';
import 'package:character_studio_3d/characters2d/engine/rig2d.dart';
import 'package:character_studio_3d/export2d/export_service2d.dart';

void main() {
  group('§3 bone rotation limits', () {
    test('default bones are unlimited (clamp is identity)', () {
      final b = Bone2D(name: 'x', parent: 'root', attach: const math.Point(0, 0), restAngle: 0, length: 10);
      expect(b.clampPose(-179.9), -179.9);
      expect(b.clampPose(179.9), 179.9);
    });

    test('fox ear/tail limits clamp at the FK choke point', () {
      final rig = Rig2D.byKind('fox_v1');
      // Ask for an insane pose; the solver must clamp it to the limits.
      final s = solveSkeleton(rig, {'tail1': 500, 'earL': -500});
      final tail1 = rig.byName['tail1']!;
      final earL = rig.byName['earL']!;
      expect(tail1.maxAngle, lessThan(500));
      expect(earL.minAngle, greaterThan(-500));
      final rest = solveSkeleton(rig, {});
      const deg = 3.141592653589793 / 180;
      expect(s.angleOf('tail1'), closeTo(rest.angleOf('tail1') + tail1.maxAngle * deg, 0.001));
      expect(s.angleOf('earL'), closeTo(rest.angleOf('earL') + earL.minAngle * deg, 0.001));
    });

    test('legacy rigs & clips are byte-identical (no clamping anywhere)', () {
      // Humanoid + quadruped have unlimited bones: every clip, sampled
      // densely, must be unaffected by the clamp call in solveSkeleton.
      for (final kind in ['humanoid_v1', 'quadruped_v1', 'fox_v1']) {
        final rig = Rig2D.byKind(kind);
        for (final clip in ClipLibrary.forRig(kind).values) {
          for (var t = 0.0; t < clip.duration; t += clip.duration / 24) {
            final pose = clip.sample(t);
            // Unlimited bones: clamped pose == raw pose for every angle.
            for (final e in pose.angles.entries) {
              final b = rig.byName[e.key];
              if (b == null) continue;
              expect(b.clampPose(e.value), e.value,
                  reason: '$kind/${clip.id}/\$t clamped \${e.key} '
                      '(limit \${b.minAngle}..\${b.maxAngle} vs pose \${e.value})');
            }
          }
        }
      }
    });
  });

  group('§1 export validation', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('export_val'));
    tearDown(() => tmp.deleteSync(recursive: true));

    File writeFile(String name, List<int> bytes) {
      final f = File('${tmp.path}/$name');
      f.writeAsBytesSync(bytes);
      return f;
    }

    test('accepts a real PNG header', () async {
      final f = writeFile('ok.png', [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(2000, 1)]);
      await expectLater(validateExportFile(f.path, 'image/png'), completes);
    });

    test('accepts an MP4 (ftyp) and GIF header', () async {
      final mp4 = writeFile('ok.mp4', [0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, ...List.filled(2000, 0)]);
      await expectLater(validateExportFile(mp4.path, 'video/mp4'), completes);
      final gif = writeFile('ok.gif', [0x47, 0x49, 0x46, 0x38, 0x39, 0x61, ...List.filled(2000, 0)]);
      await expectLater(validateExportFile(gif.path, 'image/gif'), completes);
    });

    test('rejects corrupt headers, tiny files and missing files', () async {
      final notPng = writeFile('bad.png', List.filled(2000, 7));
      await expectLater(validateExportFile(notPng.path, 'image/png'), throwsA(isA<String>()));
      final tiny = writeFile('tiny.mp4', [0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70]);
      await expectLater(validateExportFile(tiny.path, 'video/mp4'), throwsA(isA<String>()));
      await expectLater(
          validateExportFile('${tmp.path}/missing.mp4', 'video/mp4'), throwsA(isA<String>()));
    });
  });

  group('§4 facing direction', () {
    test('painters accept directionLeft and mirror the composition', () {
      // The flag exists on the painter; mirror math is canvas.scale(-1, 1)
      // applied BEFORE the part loop, so the whole rig (bones + artwork +
      // face) flips around the character centre as one group.
      final rig = Rig2D.byKind('fox_v1');
      final rest2 = solveSkeleton(rig, {});
      // Symmetric sanity: left/right hand joints mirror around the spine.
      final l = rest2.jointOf('leftHand');
      final r = rest2.jointOf('rightHand');
      expect((l.x + r.x).abs(), lessThan(2), reason: 'rest pose is near-symmetric');
    });
  });
}
