import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../characters2d/character_json.dart';
import '../../characters2d/html_export.dart';
import '../../core/theme/app_colors.dart';
import '../../state/editor_provider.dart';
import 'export_share_bridge.dart';

/// EXPORT CHARACTER → one self-contained HTML file (character + rig +
/// animations + engine + controls) and the portable character.json.
Future<void> exportCharacterHtml(BuildContext context, EditorProvider ed) async {
  final character = ed.character;
  final controller = ed.controller;
  if (character == null || controller == null) return;
  try {
    final html = buildSingleFileHtml(controller.spec, controller.palette);
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/2DStudio_exports');
    await dir.create(recursive: true);
    final safe = controller.spec.id.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final f = File('${dir.path}/${safe}_character.html');
    await f.writeAsString(html);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('HTML exported (${(html.length / 1024).toStringAsFixed(0)} KB) — opens in any browser.'), backgroundColor: AppColors.surfaceAlt),
      );
      await shareExportFile(f.path, 'text/html');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('HTML export failed: $e'), backgroundColor: AppColors.dangerSoft),
      );
    }
  }
}

Future<void> exportCharacterJson(BuildContext context, EditorProvider ed) async {
  final controller = ed.controller;
  if (controller == null) return;
  try {
    final json = characterJsonString(controller.spec, controller.palette);
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/2DStudio_exports');
    await dir.create(recursive: true);
    final f = File('${dir.path}/character.json');
    await f.writeAsString(json);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('character.json exported — portable rig + animations.'), backgroundColor: AppColors.surfaceAlt),
      );
      await shareExportFile(f.path, 'application/json');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON export failed: $e'), backgroundColor: AppColors.dangerSoft),
      );
    }
  }
}
