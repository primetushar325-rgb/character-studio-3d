import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// Typed local-storage facade backed by SharedPreferences.
/// 100% on-device — no cloud, no account.
class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- onboarding -------------------------------------------------------
  bool get onboarded => _prefs.getBool(AppConstants.kOnboarded) ?? false;
  Future<void> setOnboarded(bool v) => _prefs.setBool(AppConstants.kOnboarded, v);

  // ---- bundled assets installer flag -------------------------------------
  bool get bundledInstalled => _prefs.getBool(AppConstants.kBundledInstalled) ?? false;
  Future<void> setBundledInstalled(bool v) =>
      _prefs.setBool(AppConstants.kBundledInstalled, v);

  // ---- settings ----------------------------------------------------------
  String get themeMode => _prefs.getString(AppConstants.kThemeMode) ?? 'dark';
  Future<void> setThemeMode(String v) => _prefs.setString(AppConstants.kThemeMode, v);

  double get defaultSpeed => _prefs.getDouble(AppConstants.kDefaultSpeed) ?? 1.0;
  Future<void> setDefaultSpeed(double v) =>
      _prefs.setDouble(AppConstants.kDefaultSpeed, v);

  bool get autoLoop => _prefs.getBool(AppConstants.kAutoLoop) ?? true;
  Future<void> setAutoLoop(bool v) => _prefs.setBool(AppConstants.kAutoLoop, v);

  bool get autoRotateCamera => _prefs.getBool(AppConstants.kAutoRotate) ?? true;
  Future<void> setAutoRotateCamera(bool v) =>
      _prefs.setBool(AppConstants.kAutoRotate, v);

  bool get autoThumbnails => _prefs.getBool(AppConstants.kAutoThumbnails) ?? true;
  Future<void> setAutoThumbnails(bool v) =>
      _prefs.setBool(AppConstants.kAutoThumbnails, v);

  bool get showFileInfo => _prefs.getBool(AppConstants.kShowFileInfo) ?? true;
  Future<void> setShowFileInfo(bool v) => _prefs.setBool(AppConstants.kShowFileInfo, v);

  String get exportResolution => _prefs.getString(AppConstants.kExportResolution) ?? '720p';
  Future<void> setExportResolution(String v) =>
      _prefs.setString(AppConstants.kExportResolution, v);

  int get exportFps => _prefs.getInt(AppConstants.kExportFps) ?? 30;
  Future<void> setExportFps(int v) => _prefs.setInt(AppConstants.kExportFps, v);

  int get exportDuration => _prefs.getInt(AppConstants.kExportDuration) ?? 10;
  Future<void> setExportDuration(int v) =>
      _prefs.setInt(AppConstants.kExportDuration, v);

  String get sortMode => _prefs.getString(AppConstants.kSortMode) ?? 'recent';
  Future<void> setSortMode(String v) => _prefs.setString(AppConstants.kSortMode, v);

  // ---- character metadata --------------------------------------------------
  /// { 'robot.glb': { display, favorite, createdAt, lastUsed, useCount, bundled } }
  Map<String, dynamic> loadMetadata() {
    final raw = _prefs.getString(AppConstants.kMetadata);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveMetadata(Map<String, dynamic> metadata) =>
      _prefs.setString(AppConstants.kMetadata, jsonEncode(metadata));

  // ---- recently used ---------------------------------------------------------
  List<Map<String, dynamic>> loadRecents() {
    final raw = _prefs.getString(AppConstants.kRecents);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecents(List<Map<String, dynamic>> recents) =>
      _prefs.setString(AppConstants.kRecents, jsonEncode(recents));
}
