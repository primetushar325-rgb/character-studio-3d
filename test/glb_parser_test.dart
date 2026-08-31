import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:character_studio_3d/services/glb_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GLB parser (real sample models)', () {
    test('Fox.glb: animations + skeleton + polygons detected', () async {
      final file = File('assets/characters/Fox.glb');
      expect(file.existsSync(), isTrue, reason: 'Fox.glb asset must exist');

      final data = await GlbParserService().parseFile(file.path);

      // Animations (original identifiers preserved).
      expect(data.animations.map((a) => a.name).toList(),
          containsAll(['Survey', 'Walk', 'Run']));
      final walk = data.animations.firstWhere((a) => a.name == 'Walk');
      expect(walk.durationSeconds, isNotNull);
      expect(walk.durationSeconds! > 0.2, isTrue);

      // Rig.
      expect(data.hasSkeleton, isTrue, reason: 'Fox is a rigged model');
      expect(data.totalBoneCount, greaterThan(10));
      expect(data.skins.first.hierarchyDepth, greaterThanOrEqualTo(2));

      // Scene.
      expect(data.meshCount, greaterThanOrEqualTo(1));
      expect(data.materialCount, greaterThanOrEqualTo(1));
      expect(data.textureCount, greaterThanOrEqualTo(1));
      expect(data.triangleCount, greaterThan(500));
      expect(data.rootNodeCount, greaterThanOrEqualTo(1));
    });

    test('CesiumMan.glb: unnamed clip gets a fallback name', () async {
      final file = File('assets/characters/CesiumMan.glb');
      final data = await GlbParserService().parseFile(file.path);

      expect(data.animations.length, 1);
      expect(data.animations.first.name, 'Animation 1');
      expect(data.hasSkeleton, isTrue);
      expect(data.totalBoneCount, greaterThan(5));
    });

    test('invalid GLB → friendly error, no crash', () async {
      final tmp = File(
          '${Directory.systemTemp.path}/not_a_model_${DateTime.now().millisecondsSinceEpoch}.glb');
      await tmp.writeAsBytes(List.filled(64, 7));

      await expectLater(
        GlbParserService().parseFile(tmp.path),
        throwsA(isA<GlbParseException>().having(
            (e) => e.message, 'message', contains('not a GLB'))),
      );
      await tmp.delete();
    });

    test('truncated GLB → corrupted-file error', () async {
      final src = File('assets/characters/Fox.glb').readAsBytesSync();
      final tmp = File(
          '${Directory.systemTemp.path}/truncated_${DateTime.now().millisecondsSinceEpoch}.glb');
      await tmp.writeAsBytes(src.sublist(0, 1000)); // cut mid-file

      await expectLater(
        GlbParserService().parseFile(tmp.path),
        throwsA(isA<GlbParseException>()),
      );
      await tmp.delete();
    });

    test('missing file → friendly error', () async {
      await expectLater(
        GlbParserService().parseFile('/nonexistent/ghost.glb'),
        throwsA(isA<GlbParseException>()),
      );
    });
  });
}
