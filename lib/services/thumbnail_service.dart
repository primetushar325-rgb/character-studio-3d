import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/character.dart';

/// Thumbnail resolution & persistence.
///
/// Priority per character:
///   1. An existing image beside the GLB (robot.glb → robot.png)
///   2. A captured frame from the live 3D viewer (model-viewer `toDataURL`)
///   3. The deterministic generated placeholder (see CharacterAvatar widget)
class ThumbnailService {
  ThumbnailService(this._charactersDir);
  final Directory _charactersDir;

  File? siblingThumbnail(String fileName) {
    final base = fileName.toLowerCase().endsWith('.glb')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    for (final ext in ['png', 'jpg', 'jpeg', 'webp']) {
      final f = File('${_charactersDir.path}${p.separator}$base.$ext');
      if (f.existsSync()) return f;
    }
    return null;
  }

  /// Persist a PNG data-URL captured from the live viewer next to the GLB.
  /// Returns the saved file, or null when the data is invalid.
  Future<File?> saveDataUrlFor(String dataUrl, String glbFileName) async {
    try {
      final comma = dataUrl.indexOf(',');
      if (!dataUrl.startsWith('data:image') || comma < 0) return null;
      final bytes = base64.decode(dataUrl.substring(comma + 1));
      if (bytes.isEmpty) return null;

      final base = glbFileName.toLowerCase().endsWith('.glb')
          ? glbFileName.substring(0, glbFileName.length - 4)
          : glbFileName;
      final file = File('${_charactersDir.path}${p.separator}$base.png');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Remove cached thumbnails (Settings → Clear Cache).
  int clearGeneratedThumbnails() {
    var removed = 0;
    try {
      for (final f in _charactersDir.listSync().whereType<File>()) {
        final lower = p.basename(f.path).toLowerCase();
        if (lower.endsWith('.png') || lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
          f.deleteSync();
          removed++;
        }
      }
    } catch (_) {}
    return removed;
  }

  /// Best-known thumbnail path for a character (may be null → placeholder).
  static String? resolve(Character c) => c.thumbnailPath;
}
