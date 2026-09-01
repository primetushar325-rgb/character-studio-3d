import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'character2d_model.dart';

/// Local persistence for 2D characters: saved variants (customization),
/// favorites and recently-used entries. SharedPreferences only — fully
/// offline and restart-safe.
class Character2DRepository {
  static const _variantsKey = 'cs3d.characters2d.variants';
  static const _recentsKey = 'cs3d.characters2d.recents';
  static const _favoritesKey = 'cs3d.characters2d.favorites';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ---- Variants -----------------------------------------------------------
  Future<List<Character2D>> loadVariants() async {
    final p = await _prefs;
    final raw = p.getString(_variantsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [for (final e in list) Character2D.fromJson(Map<String, dynamic>.from(e as Map))];
    } catch (_) {
      return []; // corrupt data never crashes the app
    }
  }

  Future<void> saveVariant(Character2D variant) async {
    final p = await _prefs;
    final all = await loadVariants()
      ..removeWhere((v) => v.id == variant.id)
      ..add(variant);
    await p.setString(_variantsKey, jsonEncode([for (final v in all) v.toJson()]));
  }

  Future<void> deleteVariant(String id) async {
    final p = await _prefs;
    final all = await loadVariants()..removeWhere((v) => v.id == id);
    await p.setString(_variantsKey, jsonEncode([for (final v in all) v.toJson()]));
    // Also drop it from favorites/recents.
    await removeRecent(id);
    final favs = await loadFavorites()
      ..remove(id);
    await _saveFavorites(p, favs);
  }

  Future<void> renameVariant(String id, String name) async {
    final all = await loadVariants();
    for (final v in all) {
      if (v.id == id) v.name = name;
    }
    final p = await _prefs;
    await p.setString(_variantsKey, jsonEncode([for (final v in all) v.toJson()]));
  }

  // ---- Favorites ----------------------------------------------------------
  Future<Set<String>> loadFavorites() async {
    final p = await _prefs;
    final raw = p.getStringList(_favoritesKey) ?? [];
    return {...raw};
  }

  Future<void> _saveFavorites(SharedPreferences p, Set<String> favs) =>
      p.setStringList(_favoritesKey, favs.toList());

  Future<void> toggleFavorite(String id) async {
    final p = await _prefs;
    final favs = await loadFavorites();
    if (!favs.remove(id)) favs.add(id);
    await _saveFavorites(p, favs);
  }

  // ---- Recents ------------------------------------------------------------
  Future<List<Recent2DEntry>> loadRecents() async {
    final p = await _prefs;
    final raw = p.getString(_recentsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final entries = [for (final e in list) Recent2DEntry.fromJson(Map<String, dynamic>.from(e as Map))];
      entries.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<void> recordUsage(String characterId) async {
    final p = await _prefs;
    final recents = await loadRecents();
    Recent2DEntry? found;
    for (final r in recents) {
      if (r.characterId == characterId) found = r;
    }
    final updated = Recent2DEntry(
      characterId,
      DateTime.now(),
      (found?.usageCount ?? 0) + 1,
    );
    recents
      ..removeWhere((r) => r.characterId == characterId)
      ..insert(0, updated);
    await p.setString(
      _recentsKey,
      jsonEncode([for (final r in recents.take(10)) r.toJson()]),
    );
  }

  Future<void> removeRecent(String characterId) async {
    final p = await _prefs;
    final recents = await loadRecents()..removeWhere((r) => r.characterId == characterId);
    await p.setString(_recentsKey, jsonEncode([for (final r in recents) r.toJson()]));
  }
}
