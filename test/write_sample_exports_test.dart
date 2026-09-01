import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/character_json.dart';
import 'package:character_studio_3d/characters2d/html_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Writes sample deliverables (not a real test — a generator kept here so
  // `flutter test` output artifacts stay reproducible).
  test('write sample tiger exports to temp dir', () async {
    final tiger = CharacterCatalog.tiger;
    final html = buildSingleFileHtml(tiger, tiger.defaultPalette);
    final json = characterJsonString(tiger, tiger.defaultPalette);
    // Writable everywhere (CI runners have no /home/user).
    final dir = await Directory.systemTemp.createTemp('cs_sample_exports');
    await File('${dir.path}/tiger_character.html').writeAsString(html);
    await File('${dir.path}/character.json').writeAsString(json);
    expect(await File('${dir.path}/tiger_character.html').length(), greaterThan(5000));
  });
}
