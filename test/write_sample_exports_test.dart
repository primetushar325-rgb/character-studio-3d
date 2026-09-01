import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/character_json.dart';
import 'package:character_studio_3d/characters2d/html_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Writes sample deliverables (not a real test — a generator kept here so
  // `flutter test` output artifacts stay reproducible).
  test('write sample tiger exports to workspace', () async {
    final tiger = CharacterCatalog.tiger;
    final html = buildSingleFileHtml(tiger, tiger.defaultPalette);
    final json = characterJsonString(tiger, tiger.defaultPalette);
    await File('/home/user/sample_character_export/tiger_character.html').create(recursive: true);
    await File('/home/user/sample_character_export/tiger_character.html').writeAsString(html);
    await File('/home/user/sample_character_export/character.json').writeAsString(json);
    expect(await File('/home/user/sample_character_export/tiger_character.html').length(), greaterThan(5000));
  });
}
