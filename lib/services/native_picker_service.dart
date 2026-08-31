import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';

/// A file returned by the native ACTION_OPEN_DOCUMENT picker.
class NativePickedFile {
  const NativePickedFile({required this.path, required this.name, required this.size});
  final String path;
  final String name;
  final int size;
}

/// Fallback model picker on the shared native channel.
///
/// Used when the cross-platform file picker cannot return a usable filesystem
/// path (some providers/ROMs). Invokes Android's ACTION_OPEN_DOCUMENT with
/// glTF MIME filtering and copies the result into the app cache.
class NativePickerService {
  static const MethodChannel _channel = MethodChannel(AppConstants.nativeChannel);

  /// Returns the picked file, or null when the user cancelled.
  /// Throws [PlatformException] when the picker itself fails.
  static Future<NativePickedFile?> pickModelFile() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'pickModelFile',
    );
    if (result == null) return null; // cancelled

    final map = Map<String, dynamic>.from(result);
    if (map['error'] == true) {
      throw PlatformException(
        code: 'INVALID_TYPE',
        message: map['message'] as String? ?? 'Invalid file type',
      );
    }
    final path = map['path'] as String?;
    if (path == null || path.isEmpty) return null;
    return NativePickedFile(
      path: path,
      name: map['name'] as String? ?? 'character.glb',
      size: (map['size'] as num?)?.toInt() ?? 0,
    );
  }
}
