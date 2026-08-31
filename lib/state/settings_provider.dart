import 'package:flutter/material.dart';

import '../services/storage_service.dart';

enum StudioSortMode {
  recent('Recently Used'),
  nameAsc('Name A–Z'),
  nameDesc('Name Z–A'),
  mostAnimations('Most Animations'),
  favorites('Favorites');

  const StudioSortMode(this.label);
  final String label;

  static StudioSortMode fromKey(String key) => StudioSortMode.values
      .firstWhere((m) => m.name == key, orElse: () => StudioSortMode.recent);
}

enum LibraryFilter { all, recent, favorites }

/// App settings with real persistence — every toggle in the Settings screen
/// maps to a field here and immediately affects behavior.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage);

  final StorageService _storage;

  bool _onboarded = false;
  ThemeMode _themeMode = ThemeMode.dark;
  double _defaultSpeed = 1.0;
  bool _autoLoop = true;
  bool _autoRotateCamera = true;
  bool _autoThumbnails = true;
  bool _showFileInfo = true;
  String _exportResolution = '720p';
  int _exportFps = 30;
  int _exportDuration = 10;
  StudioSortMode _sortMode = StudioSortMode.recent;

  bool get onboarded => _onboarded;
  ThemeMode get themeMode => _themeMode;
  double get defaultSpeed => _defaultSpeed;
  bool get autoLoop => _autoLoop;
  bool get autoRotateCamera => _autoRotateCamera;
  bool get autoThumbnails => _autoThumbnails;
  bool get showFileInfo => _showFileInfo;
  String get exportResolution => _exportResolution;
  int get exportFps => _exportFps;
  int get exportDuration => _exportDuration;
  StudioSortMode get sortMode => _sortMode;

  Future<void> load() async {
    _onboarded = _storage.onboarded;
    _themeMode = switch (_storage.themeMode) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    _defaultSpeed = _storage.defaultSpeed;
    _autoLoop = _storage.autoLoop;
    _autoRotateCamera = _storage.autoRotateCamera;
    _autoThumbnails = _storage.autoThumbnails;
    _showFileInfo = _storage.showFileInfo;
    _exportResolution = _storage.exportResolution;
    _exportFps = _storage.exportFps;
    _exportDuration = _storage.exportDuration;
    _sortMode = StudioSortMode.fromKey(_storage.sortMode);
    notifyListeners();
  }

  // ---- onboarding ---------------------------------------------------------
  Future<void> completeOnboarding() async {
    _onboarded = true;
    notifyListeners();
    await _storage.setOnboarded(true);
  }

  // ---- appearance -----------------------------------------------------------
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _storage.setThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    });
  }

  // ---- 3D ---------------------------------------------------------------------
  Future<void> setDefaultSpeed(double v) async {
    _defaultSpeed = v;
    notifyListeners();
    await _storage.setDefaultSpeed(v);
  }

  Future<void> setAutoLoop(bool v) async {
    _autoLoop = v;
    notifyListeners();
    await _storage.setAutoLoop(v);
  }

  Future<void> setAutoRotateCamera(bool v) async {
    _autoRotateCamera = v;
    notifyListeners();
    await _storage.setAutoRotateCamera(v);
  }

  // ---- library -------------------------------------------------------------------
  Future<void> setAutoThumbnails(bool v) async {
    _autoThumbnails = v;
    notifyListeners();
    await _storage.setAutoThumbnails(v);
  }

  Future<void> setShowFileInfo(bool v) async {
    _showFileInfo = v;
    notifyListeners();
    await _storage.setShowFileInfo(v);
  }

  Future<void> setSortMode(StudioSortMode v) async {
    _sortMode = v;
    notifyListeners();
    await _storage.setSortMode(v.name);
  }

  // ---- export --------------------------------------------------------------------
  Future<void> setExportResolution(String v) async {
    _exportResolution = v;
    notifyListeners();
    await _storage.setExportResolution(v);
  }

  Future<void> setExportFps(int v) async {
    _exportFps = v;
    notifyListeners();
    await _storage.setExportFps(v);
  }

  Future<void> setExportDuration(int v) async {
    _exportDuration = v;
    notifyListeners();
    await _storage.setExportDuration(v);
  }
}
