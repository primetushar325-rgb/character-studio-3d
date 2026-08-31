import 'package:file_picker/file_picker.dart';

import '../core/constants/app_constants.dart';
import '../models/character.dart';
import '../models/recent_entry.dart';
import '../services/character_service.dart';
import '../services/storage_service.dart';
import '../services/thumbnail_service.dart';

/// Owns the character library: discovery, metadata, favorites, recents,
/// import/delete/rename. Business logic lives here, not in widgets.
class CharacterRepository {
  CharacterRepository({
    required StorageService storage,
    required CharacterService service,
    required ThumbnailService thumbnails,
  })  : _storage = storage,
        _service = service,
        _thumbnails = thumbnails;

  final StorageService _storage;
  final CharacterService _service;
  final ThumbnailService _thumbnails;

  ThumbnailService get thumbnails => _thumbnails;
  CharacterService get service => _service;

  List<Character> _characters = [];
  List<RecentEntry> _recents = [];
  Map<String, dynamic> _metadata = {};
  Set<String> _bundledIds = {};

  List<Character> get characters => List.unmodifiable(_characters);
  List<RecentEntry> get recents => List.unmodifiable(_recents);
  Set<String> get bundledIds => Set.unmodifiable(_bundledIds);

  Character? byId(String id) {
    for (final c in _characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Bootstrap + discovery
  // ---------------------------------------------------------------------
  Future<void> initialize() async {
    await _ensureBundledInstalled();
  }

  Future<void> _ensureBundledInstalled() async {
    if (_storage.bundledInstalled) {
      // Reinstall anything missing (e.g. app data survived a partial clear).
      _bundledIds = {..._loadBundledMeta()};
      return;
    }
    final copied = await _service.installBundledCharacters();
    _bundledIds = copied.toSet();
    _metadata['app.bundled.ids'] = copied;
    await _storage.setBundledInstalled(true);
    await _storage.saveMetadata(_metadata);
  }

  List<String> _loadBundledMeta() {
    final v = _metadata['app.bundled.ids'];
    if (v is List) return v.whereType<String>().toList();
    return [];
  }

  /// Scans the character directory, merges metadata, resolves recents.
  /// Returns scan warnings for broken files.
  Future<(List<Character>, List<String>)> loadLibrary() async {
    _metadata = _storage.loadMetadata();
    _bundledIds = _loadBundledMeta().toSet();

    final outcomes = await _service.scanDirectory(bundledIds: _bundledIds);
    final warnings = <String>[];
    final loaded = <Character>[];

    for (final o in outcomes) {
      final c = o.character;
      final meta = _metadata[c.id];

      if (meta is Map<String, dynamic>) {
        final storedName = meta['display'] as String?;
        if (storedName != null && storedName.isNotEmpty) {
          c.displayName = storedName;
        }
        c.isFavorite = meta['favorite'] as bool? ?? false;
        c.useCount = (meta['useCount'] as num?)?.toInt() ?? 0;
        final lastUsed = meta['lastUsed'] as String?;
        c.lastUsedAt = lastUsed == null ? null : DateTime.tryParse(lastUsed);
        final createdAt = meta['createdAt'] as String?;
        final parsedCreated =
            createdAt == null ? null : DateTime.tryParse(createdAt);
        if (parsedCreated != null &&
            parsedCreated.isBefore(c.createdAt) &&
            parsedCreated.year > 2000) {
          // Preserve the original install date of bundled samples.
          c.createdAt = parsedCreated;
        }
      }

      c.thumbnailPath ??= _thumbnails.siblingThumbnail(c.fileName)?.path;

      if (o.error != null) {
        warnings.add('${c.displayName}: ${o.error}');
        continue; // broken file → not in library
      }
      loaded.add(c);
    }

    _characters = loaded;
    _recents = _loadRecents();
    return (loaded, warnings);
  }

  // ---------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------
  Future<ImportOutcome> importFromPicker(List<PlatformFile> files) async {
    final outcome = await _service.importPickedFiles(files);
    if (outcome.success && outcome.character != null) {
      final c = outcome.character!;
      _metadata[c.id] = _metaFor(c);
      await _storage.saveMetadata(_metadata);
      await reload();
    }
    return outcome;
  }

  Future<void> reload() async {
    await loadLibrary();
  }

  // ---------------------------------------------------------------------
  // Metadata mutations (persisted; GLB file itself is never touched)
  // ---------------------------------------------------------------------
  Map<String, dynamic> _metaFor(Character c) => {
        'display': c.displayName,
        'favorite': c.isFavorite,
        'createdAt': c.createdAt.toIso8601String(),
        'lastUsed': c.lastUsedAt?.toIso8601String(),
        'useCount': c.useCount,
      };

  Future<void> _persistCharacter(Character c) async {
    _metadata[c.id] = _metaFor(c);
    await _storage.saveMetadata(_metadata);
  }

  Future<void> toggleFavorite(Character c) async {
    c.isFavorite = !c.isFavorite;
    await _persistCharacter(c);
  }

  Future<void> rename(Character c, String newDisplayName) async {
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) return;
    c.displayName = trimmed;
    await _persistCharacter(c);
  }

  Future<void> delete(Character c) async {
    await _service.deleteCharacterFile(c);
    _metadata.remove(c.id);
    if (_bundledIds.contains(c.id)) {
      _bundledIds.remove(c.id);
      _metadata['app.bundled.ids'] = _bundledIds.toList();
    }
    await _storage.saveMetadata(_metadata);
    _recents.removeWhere((r) => r.characterId == c.id);
    await _persistRecents();
    await reload();
  }

  Future<void> updateThumbnail(String characterId, String? thumbnailPath) async {
    final c = byId(characterId);
    if (c == null) return;
    c.thumbnailPath = thumbnailPath ?? _thumbnails.siblingThumbnail(c.fileName)?.path;
  }

  // ---------------------------------------------------------------------
  // Recently used
  // ---------------------------------------------------------------------
  List<RecentEntry> _loadRecents() {
    final raw = _storage.loadRecents();
    final entries = raw.map(RecentEntry.fromJson).toList();
    // Drop entries whose character no longer exists (e.g. deleted files).
    entries.removeWhere((r) => byId(r.characterId) == null);
    return entries;
  }

  Future<void> _persistRecents() async {
    final data = _recents.map((r) => r.toJson()).toList();
    await _storage.saveRecents(data.cast<Map<String, dynamic>>());
  }

  /// Records usage; moves existing entry to the top, no duplicates.
  Future<void> recordUsage(Character c, String? animationName) async {
    final clip = animationName != null ? c.clipByName(animationName) : null;
    final entry = RecentEntry(
      characterId: c.id,
      animationName: clip?.name ?? animationName ?? '',
      animationDisplay: clip?.displayName ?? (animationName ?? '3D Preview'),
      timestamp: DateTime.now(),
    );

    _recents.removeWhere((r) => r.key == entry.key);
    _recents.insert(0, entry);
    if (_recents.length > AppConstants.maxRecentEntries) {
      _recents = _recents.sublist(0, AppConstants.maxRecentEntries);
    }

    c.lastUsedAt = DateTime.now();
    c.useCount += 1;

    await _persistRecents();
    await _persistCharacter(c);
  }

  Future<void> clearRecents() async {
    _recents = [];
    await _persistRecents();
  }

  /// Recents resolved against the current library (drops missing characters).
  List<ResolvedRecent> resolvedRecents({int limit = 20}) {
    final out = <ResolvedRecent>[];
    for (final entry in _recents) {
      final character = byId(entry.characterId);
      if (character == null) continue;
      out.add(ResolvedRecent(entry: entry, character: character));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// The last animation used with a character (for quick play), if any.
  RecentEntry? lastUsageOf(String characterId) {
    for (final r in _recents) {
      if (r.characterId == characterId && r.animationName.isNotEmpty) return r;
    }
    return null;
  }
}

class ResolvedRecent {
  const ResolvedRecent({required this.entry, required this.character});
  final RecentEntry entry;
  final Character character;
}
