import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../characters2d/art/character_catalog.dart';
import '../characters2d/character2d_model.dart';
import '../characters2d/character2d_repository.dart';
import '../characters2d/png_character.dart';

/// App-wide 2D character library state: the three built-in characters plus
/// saved customization variants, favorites and recently-used tracking.
class Library2DProvider extends ChangeNotifier {
  Library2DProvider({Character2DRepository? repo}) : repo = repo ?? Character2DRepository();

  final Character2DRepository repo;

  final List<Character2D> _builtIns = [for (final s in CharacterCatalog.builtIn) Character2D.builtIn(s)];
  List<Character2D> _variants = [];
  Set<String> _favorites = {};
  List<Recent2DEntry> _recents = [];

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    _variants = await repo.loadVariants();
    _favorites = await repo.loadFavorites();
    _recents = await repo.loadRecents();
    await rehydratePngCharacters();
    // Apply persisted usage info to built-ins (variants carry their own).
    for (final r in _recents) {
      for (final c in _builtIns) {
        if (c.id == r.characterId) {
          c.lastUsedAt = r.lastUsedAt;
          c.usageCount = r.usageCount;
        }
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Built-in three, always in catalog order.
  List<Character2D> get builtIns => List.unmodifiable(_builtIns);

  /// All usable characters (built-ins + variants).
  List<Character2D> get all => [..._builtIns, ..._variants];

  Character2D? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Character2D> variantsOf(String specId) => [for (final v in _variants) if (v.specId == specId) v];

  bool isFavorite(String id) => _favorites.contains(id);

  Future<void> toggleFavorite(String id) async {
    await repo.toggleFavorite(id);
    _favorites = await repo.loadFavorites();
    notifyListeners();
  }

  /// Saves a customization variant (never touches the original).
  Future<Character2D> saveVariant({
    required String baseId,
    required String name,
    required Map<String, Color> palette,
    required Set<String> accessories,
  }) async {
    final base = byId(baseId);
    final specId = base?.specId ?? baseId;
    final now = DateTime.now();
    final variant = Character2D(
      id: 'char2d_${now.millisecondsSinceEpoch}',
      specId: specId,
      name: name,
      palette: Map.of(palette),
      accessories: accessories,
      isVariant: true,
      createdAt: now,
      updatedAt: now,
    );
    await repo.saveVariant(variant);
    _variants = await repo.loadVariants();
    notifyListeners();
    return variant;
  }

  /// Saves a fully-formed character (PNG cutouts, prompt-generated).
  Future<void> saveVariantFull(Character2D character) async {
    await repo.saveVariant(character);
    _variants = await repo.loadVariants();
    notifyListeners();
  }

  /// Re-registers imported PNG character specs after restart so saved
  /// variants resolve to their real artwork + rig (not the fallback farmer).
  Future<void> rehydratePngCharacters() async {
    for (final v in _variants) {
      final path = v.imagePath;
      if (path == null) continue;
      if (CharacterCatalog.byId(v.specId) != null) continue; // already live
      try {
        final art = await loadPngArt(path);
        if (art == null) continue; // artwork file missing → skip safely
        CharacterCatalog.register(pngSpecFromArt(
          id: v.specId,
          name: v.name,
          art: art,
          rigKind: v.rigKind ?? 'humanoid_v1',
        ));
      } catch (_) {
        // One bad import never blocks the library from loading.
      }
    }
  }

  /// Updates an existing variant in place (customization edits).
  Future<void> updateVariant(Character2D variant) async {
    variant.updatedAt = DateTime.now();
    await repo.saveVariant(variant);
    _variants = await repo.loadVariants();
    notifyListeners();
  }

  Future<void> deleteVariant(String id) async {
    await repo.deleteVariant(id);
    _variants = await repo.loadVariants();
    _favorites = await repo.loadFavorites();
    _recents = await repo.loadRecents();
    notifyListeners();
  }

  Future<void> renameVariant(String id, String name) async {
    await repo.renameVariant(id, name);
    _variants = await repo.loadVariants();
    notifyListeners();
  }

  /// Records usage (characterId, lastUsedAt, usageCount) and refreshes the
  /// Recently Used order (most recent first).
  Future<void> recordUsage(String id) async {
    await repo.recordUsage(id);
    _recents = await repo.loadRecents();
    for (final c in all) {
      for (final r in _recents) {
        if (c.id == r.characterId) {
          c.lastUsedAt = r.lastUsedAt;
          c.usageCount = r.usageCount;
        }
      }
    }
    notifyListeners();
  }

  /// Recently used characters, most recent first (missing ids skipped).
  List<Character2D> get recentCharacters {
    final out = <Character2D>[];
    for (final r in _recents) {
      final c = byId(r.characterId);
      if (c != null) out.add(c);
    }
    return out;
  }
}
