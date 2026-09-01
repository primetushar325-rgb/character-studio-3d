import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/editor_provider.dart';
import '../../state/projects_provider.dart';

/// Copies a picked file into the open project's assets folder and returns
/// (absolutePath, projectRelativePath). Falls back to the original path when
/// no project is open (never throws).
Future<(String, String)> copyIntoProjectAssets(
  ProjectsProvider? projects,
  String srcPath,
  String subfolder,
) async {
  final dir = projects?.current == null ? null : await projects!.repo.projectDir(projects.current!.id);
  if (dir == null) return (srcPath, srcPath);
  final assets = Directory('${dir.path}/assets/$subfolder');
  await assets.create(recursive: true);
  final ext = srcPath.contains('.') ? srcPath.split('.').last.toLowerCase() : 'png';
  final name = '${subfolder}_${DateTime.now().millisecondsSinceEpoch}.$ext';
  final dest = File('${assets.path}/$name');
  await File(srcPath).copy(dest.path);
  return (dest.path, 'assets/$subfolder/$name');
}

/// Gallery background import: PNG / JPG / JPEG / WEBP via the system picker.
/// The image is COPIED into the project folder so it survives app restarts
/// (the picker's cache path does not).
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
  final projects = context.read<ProjectsProvider>();
  try {
    final (abs, rel) = await copyIntoProjectAssets(projects, path, 'bg');
    await ed.loadBgImage(abs, storeRelative: rel);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background image could not be loaded.'), backgroundColor: AppColors.dangerSoft),
      );
    }
  }
}

/// IMAGE OBJECT import (independent movable layer — not the background).
Future<void> pickImageObject(BuildContext context) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    withData: false,
  );
  final path = res?.files.single.path;
  if (path == null) return;
  if (!context.mounted) return;
  final ed = context.read<EditorProvider>();
  final projects = context.read<ProjectsProvider>();
  try {
    final (abs, rel) = await copyIntoProjectAssets(projects, path, 'images');
    await ed.addImage(abs, rel);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image could not be imported.'), backgroundColor: AppColors.dangerSoft),
      );
    }
  }
}
