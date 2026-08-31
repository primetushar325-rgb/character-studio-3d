import 'package:flutter/foundation.dart';

import '../models/character.dart';
import '../models/recent_entry.dart';
import '../repositories/character_repository.dart';
import '../services/animation_service.dart';
import 'settings_provider.dart';

/// Library UI-state + statistics, backed by [CharacterRepository].
/// Search/filter/sort all happen here so widgets stay declarative.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider({
    required CharacterRepository repository,
    required SettingsProvider settings,
  })  : _repo = repository,
        _settings = settings;

  final CharacterRepository _repo;
  final SettingsProvider _settings;
  final AnimationService _animations = const AnimationService();

  bool _loading = false;
  String? _error;
  List<String> _scanWarnings = const [];

  String _query = '';
  LibraryFilter _filter = LibraryFilter.all;

  List<Character> _characters = const [];
  List<ResolvedRecent> _recents = const [];

  // ---- getters -----------------------------------------------------------
  bool get loading => _loading;
  String? get error => _error;
  List<String> get scanWarnings => _scanWarnings;
  String get query => _query;
  LibraryFilter get filter => _filter;
  List<Character> get characters => _characters;
  List<ResolvedRecent> get recents => _recents;
  CharacterRepository get repository => _repo;
  SettingsProvider get settings => _settings;

  Character? byId(String id) => _repo.byId(id);

  // ---- dynamic statistics -------------------------------------------------
  int get characterCount => _characters.length;
  int get favoriteCount => _characters.where((c) => c.isFavorite).toList().length;
  int get recentCount => _recents.length;

  /// Distinct animation actions across the whole library.
  int get animationCount {
    final names = <String>{};
    for (final c in _characters) {
      for (final clip in c.animations) {
        names.add(clip.normalizedName);
      }
    }
    return names.length;
  }

  List<AnimationSummary> get allAnimations =>
      _animations.distinctAcrossLibrary(_characters);

  AnimationService get animationService => _animations;

  List<Character> get favorites => _characters.where((c) => c.isFavorite).toList();

  Character? get featured {
    if (_characters.isEmpty) return null;
    Character? best;
    for (final c in _characters) {
      if (best == null) {
        best = c;
        continue;
      }
      final bTime = best.lastUsedAt ?? DateTime(2000);
      final cTime = c.lastUsedAt ?? DateTime(2000);
      if (cTime.isAfter(bTime)) best = c;
    }
    return best;
  }

  // ---- lifecycle ------------------------------------------------------------
  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final (loaded, warnings) = await _repo.loadLibrary();
      _characters = loaded;
      _scanWarnings = warnings;
      _recents = _repo.resolvedRecents(limit: 20);
      _error = null;
    } catch (e) {
      _error = 'The character library could not be loaded. '
          '${kDebugMode ? e.toString() : 'Please try again.'}';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---- search / filter --------------------------------------------------------
  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  void setFilter(LibraryFilter f) {
    _filter = f;
    notifyListeners();
  }

  /// Instant local search: matches display name, file name AND animation names.
  List<Character> get visibleCharacters {
    var list = List<Character>.from(_characters);

    switch (_filter) {
      case LibraryFilter.favorites:
        list = list.where((c) => c.isFavorite).toList();
        break;
      case LibraryFilter.recent:
        list.sort((a, b) => (b.lastUsedAt ?? DateTime(2000))
            .compareTo(a.lastUsedAt ?? DateTime(2000)));
        list = list.where((c) => c.lastUsedAt != null).toList();
        break;
      case LibraryFilter.all:
        break;
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        if (c.displayName.toLowerCase().contains(q)) return true;
        if (c.fileName.toLowerCase().contains(q)) return true;
        for (final clip in c.animations) {
          if (clip.displayName.toLowerCase().contains(q)) return true;
          if (clip.name.toLowerCase().contains(q)) return true;
          if (clip.normalizedName.contains(q)) return true;
        }
        return false;
      }).toList();
    }

    switch (_settings.sortMode) {
      case StudioSortMode.recent:
        list.sort((a, b) => (b.lastUsedAt ?? DateTime(2000))
            .compareTo(a.lastUsedAt ?? DateTime(2000)));
      case StudioSortMode.nameAsc:
        list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      case StudioSortMode.nameDesc:
        list.sort((a, b) => b.displayName.toLowerCase().compareTo(a.displayName.toLowerCase()));
      case StudioSortMode.mostAnimations:
        list.sort((a, b) => b.animationCount.compareTo(a.animationCount));
      case StudioSortMode.favorites:
        list.sort((a, b) {
          final fav = (b.isFavorite ? 1 : 0) - (a.isFavorite ? 1 : 0);
          if (fav != 0) return fav;
          return (b.lastUsedAt ?? DateTime(2000)).compareTo(a.lastUsedAt ?? DateTime(2000));
        });
    }
    return list;
  }

  // ---- actions ------------------------------------------------------------
  Future<void> toggleFavorite(Character c) async {
    await _repo.toggleFavorite(c);
    notifyListeners();
  }

  Future<void> rename(Character c, String name) async {
    await _repo.rename(c, name);
    notifyListeners();
  }

  Future<void> delete(Character c) async {
    await _repo.delete(c);
    _recents = _repo.resolvedRecents(limit: 20);
    notifyListeners();
  }

  Future<void> recordUsage(Character c, String? animationName) async {
    await _repo.recordUsage(c, animationName);
    _recents = _repo.resolvedRecents(limit: 20);
    notifyListeners();
  }

  Future<void> clearRecents() async {
    await _repo.clearRecents();
    _recents = [];
    notifyListeners();
  }

  Future<void> reloadAfterImport() async {
    await refresh();
  }

  Future<void> updateThumbnail(String characterId, String? path) async {
    await _repo.updateThumbnail(characterId, path);
    notifyListeners();
  }

  RecentEntry? lastUsageOf(String characterId) => _repo.lastUsageOf(characterId);
}
