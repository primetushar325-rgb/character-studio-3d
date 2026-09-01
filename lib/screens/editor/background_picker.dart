import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/editor_provider.dart';

/// Gallery background import: PNG / JPG / JPEG / WEBP via the system picker.
Future<void> pickGalleryBackground(BuildContext context) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    withData: false,
  );
  final path = res?.files.single.path;
  if (path == null) return;
  if (!context.mounted) return;
  final ed = context.read<EditorProvider>();
  try {
    await ed.loadBgImage(path);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background image could not be loaded.'), backgroundColor: AppColors.dangerSoft),
      );
    }
  }
}
