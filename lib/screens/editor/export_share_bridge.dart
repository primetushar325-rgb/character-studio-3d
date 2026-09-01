import 'package:share_plus/share_plus.dart' as sharing;

/// Small bridge so panels/dialogs share exports through one place.
Future<void> shareExportFile(String path, String mime) async {
  await sharing.Share.shareXFiles([sharing.XFile(path, mimeType: mime)]);
}
