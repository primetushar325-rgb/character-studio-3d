/// Global constants for Character Studio 3D.
class AppConstants {
  AppConstants._();

  static const String appName = 'Character Studio 3D';
  static const String appTagline = 'Create. Animate. Preview.';
  static const String appVersion = '1.0.0';

  // Native method channel
  static const String nativeChannel = 'app.characterstudio/native';

  // Local folders
  static const String charactersDirName = 'characters';

  // Library limits
  static const int maxRecentEntries = 40;
  static const int maxImportBytes = 250 * 1024 * 1024; // 250 MB hard limit
  static const int largeModelBytes = 80 * 1024 * 1024; // warn above this

  // SharedPreferences keys
  static const String kOnboarded = 'app.onboarded';
  static const String kBundledInstalled = 'app.bundled.installed.v1';
  static const String kThemeMode = 'settings.themeMode';
  static const String kDefaultSpeed = 'settings.defaultSpeed';
  static const String kAutoLoop = 'settings.autoLoop';
  static const String kAutoRotate = 'settings.autoRotateCamera';
  static const String kAutoThumbnails = 'settings.autoThumbnails';
  static const String kShowFileInfo = 'settings.showFileInfo';
  static const String kExportResolution = 'settings.exportResolution';
  static const String kExportFps = 'settings.exportFps';
  static const String kExportDuration = 'settings.exportDuration';
  static const String kSortMode = 'library.sortMode';
  static const String kMetadata = 'library.metadata.v1';
  static const String kRecents = 'library.recents.v1';

  // Viewer
  static const Duration viewerLoadTimeout = Duration(seconds: 45);
}
