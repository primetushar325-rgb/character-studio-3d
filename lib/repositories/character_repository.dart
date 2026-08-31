import 'package:file_picker/file_picker.dart';

import '../core/constants/app_constants.dart';
import '../models/character.dart';
import '../models/recent_entry.dart';
import '../services/character_service.dart';
import '../services/storage_service.dart';
import '../services/thumbnail_service.dart';

/// Owns the character library: discovery, metadata, favorites, recents,
/// staged imports, mapping persistence, duplicate/delete/rename.
/// Business logic lives here, not in widgets.
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
    // Clean up half-staged imports after a crash during review.
    _service.clearPendingImports();
  }

  Future<void> _ensureBundledInstalled() async {
    if (_storage.bundledInstalled) {
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
        _applyMetadata(c, meta);
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

  void _applyMetadata(Character c, Map<String, dynamic> meta) {
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
    // v1.1 fields (old installs simply don't have them yet).
    final mapping = meta['animationMapping'];
    if (mapping is Map<String, dynamic>) {
      c.animationMapping = {
        for (final e in mapping.entries)
          if (e.value is String && (e.value as String).isNotEmpty)
            e.key: e.value as String,
      };
    }
    final bones = meta['boneMapping'];
    if (bones is Map<String, dynamic>) {
      c.boneMapping = {
        for (final e in bones.entries)
          if (e.value is String && (e.value as String).isNotEmpty)
            e.key: e.value as String,
      };
    }
    // A manually-emptied mapping must survive a rescan.
    if (meta.containsKey('animationMapping') &&
        (mapping is Map<String, dynamic>) &&
        mapping.isEmpty) {
      c.animationMapping = {};
    }
  }

  // ---------------------------------------------------------------------
  // Staged import (pick → validate → review → Save Character)
  // ---------------------------------------------------------------------
  Future<Object> stageImport(
    List<String> sourcePaths, {
    void Function(ImportStage stage)? onStage,
  }) {
    return _service.stageImport(sourcePaths, onStage: onStage);
  }

  /// "Save Character": persists the staged model + full metadata.
  Future<Character> commitImport(
    StagedImport staged, {
    String? displayName,
    Map<String, String>? animationMapping,
    Map<String, String>? boneMapping,
  }) async {
    final committed = await _service.commitImport(
      staged,
      displayName: displayName,
      animationMapping: animationMapping,
      boneMapping: boneMapping,
    );
    _metadata[committed.id] = _metaFor(committed);
    await _storage.saveMetadata(_metadata);
    await loadLibrary();
    return byId(committed.id) ?? committed;
  }

  Future<void> discardImport(StagedImport staged) async {
    await _service.discardImport(staged);
  }

  /// Legacy one-shot import kept for compatibility (stage + commit).
  Future<ImportOutcome> importFromPicker(List<PlatformFile> files) async {
    final paths = <String>[
      for (final f in files)
        if (f.path != null && f.path!.isNotEmpty) f.path!
    ];
    final staged = await _service.stageImport(paths);
    if (staged is! StagedImport) {
      return ImportOutcome(errorMessage: (staged as ImportOutcome).errorMessage);
    }
    final committed = await commitImport(staged);
    return ImportOutcome(
      character: committed,
      warnings: staged.warnings,
    );
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
        // v1.1
        'charId': c.charId,
        'source': c.source == CharacterSource.bundled ? 'bundled' : 'imported',
        'originalFileName': c.originalFileName,
        'hasSkeleton': c.hasSkeleton,
        'boneCount': c.boneCount,
        'readiness': c.readiness.name,
        'animationMapping': c.animationMapping,
        'boneMapping': c.boneMapping,
        'humanoidDetected': c.humanoidDetected,
        'updatedAt': (c.updatedAt ?? DateTime.now()).toIso8601String(),
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
    c.updatedAt = DateTime.now();
    await _persistCharacter(c);
  }

  /// Persist the standard-action → clip mapping (manual edits included).
  Future<void> saveAnimationMapping(
      Character c, Map<String, String> mapping) async {
    c.animationMapping = Map<String, String>.from(mapping);
    c.updatedAt = DateTime.now();
    // Readiness reflects the live mapping.
    await _persistCharacter(c);
  }

  /// Persist the humanoid bone mapping (auto-detected + manual overrides).
  Future<void> saveBoneMapping(Character c, Map<String, String> mapping) async {
    c.boneMapping = Map<String, String>.from(mapping);
    c.updatedAt = DateTime.now();
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
    await loadLibrary();
  }

  /// Duplicate → new imported copy in the library.
  Future<Character> duplicate(Character c) async {
    final copy = await _service.duplicate(c);
    _metadata[copy.id] = _metaFor(copy);
    await _storage.saveMetadata(_metadata);
    await loadLibrary();
    return byId(copy.id) ?? copy;
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
