import 'package:flutter_test/flutter_test.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/html_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('single-file HTML embeds character JSON, engine and player controls', () {
    for (final spec in CharacterCatalog.builtIn) {
      final html = buildSingleFileHtml(spec, spec.defaultPalette);
      expect(html.startsWith('<!DOCTYPE html>'), isTrue);
      expect(html.contains('</html>'), isTrue);
      // Character payload embedded
      expect(html.contains('"2D_RIGGED_CHARACTER"'), isTrue);
      expect(html.contains('"bones"'), isTrue);
      expect(html.contains('"animations"'), isTrue);
      expect(html.contains(spec.id), isTrue);
      // Player UI + engine present, zero external deps
      // Player buttons are generated from ids at runtime (CSS uppercases).
      expect(html.contains("'idle','walk','run','sit','sleep','talk','jump','wave'"), isTrue);
      expect(html.contains('animButtons'), isTrue);
      expect(html.contains('requestAnimationFrame'), isTrue);
      expect(RegExp(r'src="https?://|href="https?://').hasMatch(html), isFalse,
          reason: 'HTML must be fully self-contained');
    }
  });
}
