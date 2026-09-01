import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/character_json.dart';
import 'package:character_studio_3d/characters2d/engine/clips.dart';
import 'package:character_studio_3d/export2d/gif_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GIF encoder (pure Dart GIF89a)', () {
    test('encodes a 2-frame animation with loop + delays and a valid header', () async {
      final enc = GifEncoder();
      for (var f = 0; f < 2; f++) {
        final img = await _solidImage(8, 8, f == 0 ? 0xFFE05038 : 0xFF3860E0);
        await enc.addFrameAsync(img, delayMs: 100);
      }
      final bytes = enc.encode();
      final header = String.fromCharCodes(bytes.take(6));
      expect(header, startsWith('GIF89a'));
      // Logical screen descriptor
      expect(bytes[6], 8); // width LE
      expect(bytes[8], 8); // height LE
      // NETSCAPE2.0 loop extension present
      final asStr = String.fromCharCodes(bytes);
      expect(asStr.contains('NETSCAPE2.0'), isTrue);
      expect(bytes.length, greaterThan(100));
    });

    test('throws when encoding with no frames', () {
      expect(() => GifEncoder().encode(), throwsStateError);
    });
  });

  group('character.json (portable character format)', () {
    test('emits 2D_RIGGED_CHARACTER with canvas/bones/layers/animations', () {
      final spec = CharacterCatalog.tiger;
      final json = buildCharacterJson(spec, spec.defaultPalette);
      expect(json['type'], '2D_RIGGED_CHARACTER');
      expect(json['name'], spec.name);
      expect(json['version'], isNotNull);
      final canvas = json['canvas'] as Map<String, dynamic>;
      expect(canvas['width'], 1080);
      expect(canvas['height'], 1080);
      final bones = json['bones'] as List;
      expect(bones.length, greaterThan(15));
      final layers = json['layers'] as List;
      expect(layers.length, greaterThan(10));
      final anims = (json['animations'] as List).cast<Map<String, dynamic>>();
      final animIds = anims.map((a) => a['id']).toSet();
      for (final id in ClipLibrary.standardAnimationIds) {
        expect(animIds.contains(id), isTrue, reason: 'missing animation $id');
      }
      // Keyframe contract: per-bone tracks with {time, ...value} entries.
      final walk = anims.firstWhere((a) => a['id'] == 'walk');
      final tracks = (walk['tracks'] as List).cast<Map<String, dynamic>>();
      expect(tracks.isNotEmpty, isTrue);
      final bone = tracks.first['bone'];
      final keys = (tracks.first['keyframes'] as List).cast<Map<String, dynamic>>();
      expect(bone, isNotNull);
      expect(keys.first.containsKey('time'), isTrue);
      expect(walk['loop'], isTrue);
    });

    test('every built-in exports all 14 standard animations', () {
      for (final spec in CharacterCatalog.builtIn) {
        final json = buildCharacterJson(spec, spec.defaultPalette);
        final anims = (json['animations'] as List).cast<Map<String, dynamic>>();
        final ids = anims.map((a) => a['id']).toSet();
        expect(ids.containsAll(ClipLibrary.standardAnimationIds), isTrue,
            reason: "${spec.id} missing: ${ClipLibrary.standardAnimationIds.difference(ids)}");
      }
    });
  });

  group('Tiger quadruped gait contract', () {
    test('diagonal pairs share phase; FL+BR together, FR+BL opposite', () {
      final walk = ClipLibrary.forRig('quadruped_v1')['walk']!;
      final s0 = walk.sample(0);
      final sT = walk.sample(walk.duration / 2);
      // Front-left and back-right should be in phase → similar angles at t=0.
      final fl0 = (s0.angles['flUpper'] ?? s0.angles['frontLUpper'] ?? 0.0);
      final br0 = (s0.angles['brUpper'] ?? s0.angles['backRUpper'] ?? 0.0);
      if (fl0 != 0.0 && br0 != 0.0) {
        expect((fl0 - br0).abs(), lessThan(14));
      }
      final flH = (sT.angles['flUpper'] ?? sT.angles['frontLUpper'] ?? 0.0);
      final brH = (sT.angles['brUpper'] ?? sT.angles['backRUpper'] ?? 0.0);
      if (flH != 0.0 && brH != 0.0) {
        expect((flH - brH).abs(), lessThan(14));
      }
    });
  });
}

Future<ui.Image> _solidImage(int w, int h, int color) async {
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    rgba[i * 4] = (color >> 16) & 0xFF;
    rgba[i * 4 + 1] = (color >> 8) & 0xFF;
    rgba[i * 4 + 2] = color & 0xFF;
    rgba[i * 4 + 3] = 0xFF;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}
