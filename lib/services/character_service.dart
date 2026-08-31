import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path/path.dart' as p;

import '../core/constants/app_constants.dart';
import '../models/animation_clip.dart';
import '../models/character.dart';
import '../services/humanoid_detector.dart';
import '../services/validation_service.dart';
import 'glb_parser_service.dart';
import 'gltf_converter_service.dart';

/// Progress stages reported by the import pipeline to the UI.
enum ImportStage {
  reading('Reading file'),
  loading('Loading 3D model'),
  skeleton('Checking skeleton'),
  animations('Checking animations'),
  preview('Preparing preview');

  const ImportStage(this.label);
  final String label;

  String get labelWithArrow => '$label →';
}

/// A staged import awaiting review / "Save Character".
class StagedImport {
  StagedImport({
    required this.character,
    required this.report,
    required this.pendingFile,
    required this.warnings,
    this.boneNames = const [],
  });

  final Character character; // isPending = true
  final ValidationReport report;
  final File pendingFile;
  final List<String> warnings;

  /// All bone names parsed from the model's skins (for the mapping UI).
  final List<String> boneNames;
}

/// Result of an import operation (success or friendly failure).
class ImportOutcome {
  const ImportOutcome({
    this.character,
    this.errorMessage,
    this.warnings = const [],
  });
  final Character? character;
  final String? errorMessage;
  final List<String> warnings;
  bool get success => character != null;
}

/// Outcome of scanning one character file.
class ScanOutcome {
  const ScanOutcome({required this.character, this.error});
  final Character character;
  final String? error;
}

/// Discovers, validates and imports characters — with zero character-specific
/// logic. Any valid GLB dropped into the app's character directory (or
/// imported through the file picker) becomes a first-class character.
class CharacterService {
  CharacterService({
    GlbParserService? parser,
    GltfConverterService? converter,
    ValidationService? validation,
  })  : _parser = parser ?? GlbParserService(),
        _converter = converter ?? GltfConverterService(),
        _validation = validation ?? const ValidationService();

  final GlbParserService _parser;
  final GltfConverterService _converter;
  final ValidationService _validation;

  static const pendingDirName = 'characters_pending';

  Directory? _charactersDir;
  Directory? _pendingDir;

  /// Called once at app start with the app documents directory.
  void configure(Directory appDocs) {
    _charactersDir = Directory(
        '${appDocs.path}${Platform.pathSeparator}${AppConstants.charactersDirName}');
    _pendingDir = Directory(
        '${appDocs.path}${Platform.pathSeparator}$pendingDirName');
    if (!_charactersDir!.existsSync()) {
      _charactersDir!.createSync(recursive: true);
    }
    if (!_pendingDir!.existsSync()) {
      _pendingDir!.createSync(recursive: true);
    }
  }

  Directory? get charactersDir => _charactersDir;
  Directory? get pendingDir => _pendingDir;

  // ---------------------------------------------------------------------
  // Bundled sample characters → copied into the live character directory
  // (once per install). New samples can be added to assets/characters/
  // without touching Dart code — the asset manifest is scanned dynamically.
  // ---------------------------------------------------------------------
  Future<List<String>> installBundledCharacters() async {
    final dir = _charactersDir;
    if (dir == null) return [];

    final copied = <String>[];
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetPaths = _listManifestPaths(manifest);
    final glbPaths = assetPaths
        .where((path) =>
            path.startsWith('assets/characters/') &&
            path.toLowerCase().endsWith('.glb'))
        .toList();

    for (final assetPath in glbPaths) {
      final fileName = p.basename(assetPath);
      final target = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (await target.exists()) continue;
      try {
        final data = await rootBundle.load(assetPath);
        await target.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        // Sibling thumbnail if one is bundled (fox.glb → fox.png).
        final pngPath = '${assetPath.substring(0, assetPath.length - 4)}.png';
        if (assetPaths.contains(pngPath)) {
          final pngData = await rootBundle.load(pngPath);
          await File(
                  '${dir.path}${Platform.pathSeparator}${p.basename(pngPath)}')
              .writeAsBytes(
            pngData.buffer.asUint8List(pngData.offsetInBytes, pngData.lengthInBytes),
            flush: true,
          );
        }
        copied.add(fileName);
      } catch (_) {
        // A broken bundled asset must never block startup.
      }
    }
    return copied;
  }

  List<String> _listManifestPaths(dynamic manifest) {
    try {
      return (manifest.listAssets() as List).whereType<String>().toList();
    } catch (_) {
      try {
        return (manifest.listAssetPaths() as List).whereType<String>().toList();
      } catch (_) {
        return const [];
      }
    }
  }

  // ---------------------------------------------------------------------
  // Directory scan (bundled + imported, merged, de-duplicated by file name)
  // ---------------------------------------------------------------------
  Future<List<ScanOutcome>> scanDirectory({required Set<String> bundledIds}) async {
    final dir = _charactersDir;
    if (dir == null) return const [];

    final results = <ScanOutcome>[];
    final seen = <String>{};

    final entities = dir.listSync(followLinks: false).whereType<File>().toList()
      ..sort((a, b) =>
          p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));

    for (final file in entities) {
      final name = p.basename(file.path);
      if (!name.toLowerCase().endsWith('.glb')) continue;
      if (seen.contains(name)) continue; // duplicate safety
      seen.add(name);

      try {
        final data = await _parser.parseFile(file.path);
        final character = _buildCharacter(
          data: data,
          file: file,
          fileName: name,
          source:
              bundledIds.contains(name) ? CharacterSource.bundled : CharacterSource.imported,
        );
        results.add(ScanOutcome(character: character));
      } on GlbParseException catch (e) {
        // Keep broken files out of the library but still surfaced to the user.
        results.add(ScanOutcome(
          character: Character(
            id: name,
            fileName: name,
            filePath: file.path,
            displayName: _defaultDisplayName(name),
            fileSizeBytes: file.lengthSync(),
            animations: [],
            source: CharacterSource.imported,
            createdAt: DateTime.now(),
            readiness: CharacterReadiness.invalid,
          ),
          error: e.message,
        ));
      }
    }
    return results;
  }

  Character _buildCharacter({
    required GlbModelData data,
    required File file,
    required String fileName,
    required CharacterSource source,
  }) {
    final stat = file.statSync();
    final report = _validation.validate(data: data, fileBytes: stat.size);

    final clips = <AnimationClip>[
      for (var i = 0; i < data.animations.length; i++)
        AnimationClip.fromGlbName(
          data.animations[i].name,
          duration: data.animations[i].durationSeconds,
          fallbackIndex: i + 1,
        ),
    ];

    final character = Character(
      id: fileName,
      fileName: fileName,
      filePath: file.path,
      displayName: _defaultDisplayName(fileName),
      fileSizeBytes: stat.size,
      animations: clips,
      source: source,
      createdAt: stat.modified.year < 2000 ? DateTime.now() : stat.modified,
      generator: data.generator,
      nodeCount: data.nodeCount,
      meshCount: data.meshCount,
      materialCount: data.materialCount,
      textureCount: data.textureCount,
      skinCount: data.skinCount,
      hasSkeleton: data.hasSkeleton,
      boneCount: data.totalBoneCount,
      triangleCount: data.triangleCount,
      readiness: report.readiness,
      animationMapping: Map<String, String>.from(report.autoMapping),
      boneMapping: {
        for (final e in (report.humanoidRig?.matches ?? const <String, BoneMatch>{})
            .entries)
          if (e.value.matched) e.key: e.value.nodeName!,
      },
      humanoidDetected: report.humanoidRig?.humanLike ?? false,
    );
    _attachSiblingThumbnail(character);
    return character;
  }

  void _attachSiblingThumbnail(Character c) {
    final base = c.fileName.substring(0, c.fileName.length - 4);
    final dir = p.dirname(c.filePath);
    for (final ext in ['png', 'jpg', 'jpeg', 'webp']) {
      final f = File('$dir${Platform.pathSeparator}$base.$ext');
      if (f.existsSync()) {
        c.thumbnailPath = f.path;
        return;
      }
    }
  }

  String _defaultDisplayName(String fileName) {
    final base = fileName.toLowerCase().endsWith('.glb')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    return base
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  // =====================================================================
  // IMPORT PIPELINE (v1.1 — staged: pending → review → Save Character)
  //
  //   1. stageImport()      copy + parse + validate into characters_pending/
  //   2. (user reviews mapping / preview in the UI)
  //   3. commitImport()     "Save Character" → move into characters/
  //      discardImport()    remove all temporary files
  // =====================================================================
  Future<Object> stageImport(
    List<String> sourcePaths, {
    void Function(ImportStage stage)? onStage,
  }) async {
    final pending = _pendingDir;
    if (pending == null) {
      return const ImportOutcome(
          errorMessage: 'Local storage is not available yet. Please reopen the app.');
    }
    if (sourcePaths.isEmpty) {
      return const ImportOutcome(errorMessage: 'No file was selected.');
    }

    _stageReport(onStage, ImportStage.reading);

    // Stage picked files into a temp dir so .gltf can find its siblings.
    final staging = Directory.systemTemp.createTempSync('cs3d_import');
    try {
      final staged = <File>[];
      String? originalName;
      for (final sourcePath in sourcePaths) {
        final source = File(sourcePath);
        if (!await source.exists()) continue;
        final size = await source.length();
        if (size > AppConstants.maxImportBytes) {
          return ImportOutcome(
            errorMessage:
                'This model is too large (${(size / 1024 / 1024).toStringAsFixed(0)} MB). '
                'The maximum supported size is 250 MB.',
          );
        }
        final base = p.basename(sourcePath);
        if (originalName == null &&
            (base.toLowerCase().endsWith('.glb') || base.toLowerCase().endsWith('.gltf'))) {
          originalName = base;
        }
        final target = File('${staging.path}${Platform.pathSeparator}$base');
        await source.copy(target.path);
        staged.add(target);
      }

      final glbFiles =
          staged.where((f) => f.path.toLowerCase().endsWith('.glb')).toList();
      final gltfFiles =
          staged.where((f) => f.path.toLowerCase().endsWith('.gltf')).toList();

      if (glbFiles.isEmpty && gltfFiles.isEmpty) {
        return const ImportOutcome(
            errorMessage:
                'No .glb or .gltf file found. Please pick a 3D character file.');
      }

      // Prefer a .glb; otherwise convert the first .gltf (with staged siblings).
      var working = glbFiles.isNotEmpty ? glbFiles.first : gltfFiles.first;
      var warnings = <String>[];

      _stageReport(onStage, ImportStage.loading);

      if (working.path.toLowerCase().endsWith('.gltf')) {
        try {
          working = await _converter.convertToGlb(
            gltfFile: working,
            outputFileName: p.basenameWithoutExtension(working.path),
            outputDirectory: staging,
          );
        } on GlbParseException catch (e) {
          return ImportOutcome(errorMessage: e.message);
        }
      }

      final size = await working.length();
      if (size > AppConstants.maxImportBytes) {
        return const ImportOutcome(
            errorMessage: 'The converted model exceeds the 250 MB limit.');
      }
      if (size > AppConstants.largeModelBytes) {
        warnings = [
          'This model is very large (${(size / 1024 / 1024).toStringAsFixed(0)} MB) '
              'and may play slowly on this device.'
        ];
      }

      // Copy into the PENDING directory (not the library yet).
      final safeBase = _sanitize(p.basename(working.path));
      var finalName = safeBase;
      var counter = 1;
      while (File('${pending.path}${Platform.pathSeparator}$finalName')
          .existsSync()) {
        final dot = safeBase.lastIndexOf('.');
        finalName = dot > 0
            ? '${safeBase.substring(0, dot)} ($counter)${safeBase.substring(dot)}'
            : '$safeBase ($counter)';
        counter++;
      }
      final pendingFile = File('${pending.path}${Platform.pathSeparator}$finalName');
      await working.copy(pendingFile.path);

      // Parse (model + skeleton + animations) with staged progress.
      final GlbModelData data;
      try {
        _stageReport(onStage, ImportStage.skeleton);
        data = await _parser.parseFile(pendingFile.path);
      } on GlbParseException catch (e) {
        await pendingFile.delete();
        return ImportOutcome(errorMessage: e.message);
      }

      _stageReport(onStage, ImportStage.animations);
      final report =
          _validation.validate(data: data, fileBytes: pendingFile.lengthSync());

      final clips = <AnimationClip>[
        for (var i = 0; i < data.animations.length; i++)
          AnimationClip.fromGlbName(
            data.animations[i].name,
            duration: data.animations[i].durationSeconds,
            fallbackIndex: i + 1,
          ),
      ];

      if (clips.isEmpty) {
        warnings = [
          ...warnings,
          'No animation clips were found in this model — it can still be viewed in 3D.'
        ];
      }

      _stageReport(onStage, ImportStage.preview);

      final character = Character(
        id: finalName,
        fileName: finalName,
        filePath: pendingFile.path,
        displayName: _defaultDisplayName(finalName),
        fileSizeBytes: size,
        animations: clips,
        source: CharacterSource.imported,
        createdAt: DateTime.now(),
        generator: data.generator,
        nodeCount: data.nodeCount,
        meshCount: data.meshCount,
        materialCount: data.materialCount,
        textureCount: data.textureCount,
        skinCount: data.skinCount,
        hasSkeleton: data.hasSkeleton,
        boneCount: data.totalBoneCount,
        triangleCount: data.triangleCount,
        readiness: report.readiness,
        animationMapping: Map<String, String>.from(report.autoMapping),
        boneMapping: {
          for (final e in (report.humanoidRig?.matches ?? const <String, BoneMatch>{})
              .entries)
            if (e.value.matched) e.key: e.value.nodeName!,
        },
        humanoidDetected: report.humanoidRig?.humanLike ?? false,
        originalFileName: originalName ?? finalName,
        isPending: true,
      );

      // Sibling thumbnail staged with the model (user picked fox.glb + fox.png).
      final thumbBase = p.basenameWithoutExtension(working.path);
      for (final ext in ['png', 'jpg', 'jpeg', 'webp']) {
        final sibling = File('${staging.path}${Platform.pathSeparator}$thumbBase.$ext');
        if (await sibling.exists()) {
          final thumb = File(
              '${pending.path}${Platform.pathSeparator}'
              '${p.basenameWithoutExtension(finalName)}.$ext');
          await sibling.copy(thumb.path);
          character.thumbnailPath = thumb.path;
          break;
        }
      }

      return StagedImport(
        character: character,
        report: report,
        pendingFile: pendingFile,
        warnings: warnings,
        boneNames: data.boneNames,
      );
    } on GlbParseException catch (e) {
      return ImportOutcome(errorMessage: e.message);
    } catch (_) {
      return const ImportOutcome(
          errorMessage: 'This character could not be imported. '
              'The file may be corrupted or use an unsupported feature.');
    } finally {
      try {
        staging.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  void _stageReport(void Function(ImportStage)? onStage, ImportStage stage) {
    if (onStage != null) onStage(stage);
  }

  /// "Save Character" — move the staged model into the library.
  Future<Character> commitImport(
    StagedImport staged, {
    String? displayName,
    Map<String, String>? animationMapping,
    Map<String, String>? boneMapping,
  }) async {
    final dir = _charactersDir!;
    final pending = _pendingDir!;

    var finalName = staged.character.fileName;
    var counter = 1;
    while (File('${dir.path}${Platform.pathSeparator}$finalName').existsSync()) {
      final dot = staged.character.fileName.lastIndexOf('.');
      finalName = dot > 0
          ? '${staged.character.fileName.substring(0, dot)} ($counter)'
              '${staged.character.fileName.substring(dot)}'
          : '${staged.character.fileName} ($counter)';
      counter++;
    }

    final targetFile = File('${dir.path}${Platform.pathSeparator}$finalName');
    await staged.pendingFile.rename(targetFile.path);

    // Move sibling thumbnail too.
    String? thumbPath;
    final base = p.basenameWithoutExtension(staged.character.fileName);
    for (final ext in ['png', 'jpg', 'jpeg', 'webp']) {
      final f = File('${pending.path}${Platform.pathSeparator}$base.$ext');
      if (await f.exists()) {
        final moved = File(
            '${dir.path}${Platform.pathSeparator}'
            '${p.basenameWithoutExtension(finalName)}.$ext');
        await f.rename(moved.path);
        thumbPath = moved.path;
        break;
      }
    }

    staged.character.displayName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : staged.character.displayName;
    if (animationMapping != null) {
      staged.character.animationMapping = animationMapping;
    }
    if (boneMapping != null) {
      staged.character.boneMapping = boneMapping;
    }

    final committed = Character(
      id: finalName,
      fileName: finalName,
      filePath: targetFile.path,
      displayName: staged.character.displayName,
      fileSizeBytes: staged.character.fileSizeBytes,
      animations: staged.character.animations,
      source: CharacterSource.imported,
      createdAt: DateTime.now(),
      generator: staged.character.generator,
      thumbnailPath: thumbPath ?? staged.character.thumbnailPath,
      nodeCount: staged.character.nodeCount,
      meshCount: staged.character.meshCount,
      materialCount: staged.character.materialCount,
      textureCount: staged.character.textureCount,
      skinCount: staged.character.skinCount,
      hasSkeleton: staged.character.hasSkeleton,
      boneCount: staged.character.boneCount,
      triangleCount: staged.character.triangleCount,
      readiness: staged.character.readiness,
      animationMapping: staged.character.animationMapping,
      boneMapping: staged.character.boneMapping,
      humanoidDetected: staged.character.humanoidDetected,
      originalFileName: staged.character.originalFileName,
      charId: 'char_${DateTime.now().millisecondsSinceEpoch}',
    );
    return committed;
  }

  /// Discard a staged import — removes every temporary file.
  Future<void> discardImport(StagedImport staged) async {
    final pending = _pendingDir;
    try {
      if (await staged.pendingFile.exists()) {
        await staged.pendingFile.delete();
      }
      final base = p.basenameWithoutExtension(staged.character.fileName);
      if (pending != null) {
        for (final ext in ['png', 'jpg', 'jpeg', 'webp']) {
          final f = File('${pending.path}${Platform.pathSeparator}$base.$ext');
          if (await f.exists()) await f.delete();
        }
      }
    } catch (_) {}
  }

  /// Duplicate an existing character (copy file + thumbnail, fresh metadata).
  Future<Character> duplicate(Character source) async {
    final dir = _charactersDir!;
    final base = p.basenameWithoutExtension(source.fileName);
    final ext = p.extension(source.fileName).toLowerCase();

    var newFileName = '$base (copy)$ext';
    var counter = 2;
    while (File('${dir.path}${Platform.pathSeparator}$newFileName').existsSync()) {
      newFileName = '$base (copy $counter)$ext';
      counter++;
    }

    final target = File('${dir.path}${Platform.pathSeparator}$newFileName');
    await File(source.filePath).copy(target.path);

    String? thumb;
    for (final e in ['png', 'jpg', 'jpeg', 'webp']) {
      final f = File(
          '${p.dirname(source.filePath)}${Platform.pathSeparator}$base.$e');
      if (await f.exists()) {
        thumb = File(
            '${dir.path}${Platform.pathSeparator}'
            '${p.basenameWithoutExtension(newFileName)}.$e').path;
        await f.copy(thumb);
        break;
      }
    }

    return Character(
      id: newFileName,
      fileName: newFileName,
      filePath: target.path,
      displayName: '${source.displayName} (copy)',
      fileSizeBytes: source.fileSizeBytes,
      animations: source.animations,
      source: CharacterSource.imported,
      createdAt: DateTime.now(),
      generator: source.generator,
      thumbnailPath: thumb,
      nodeCount: source.nodeCount,
      meshCount: source.meshCount,
      materialCount: source.materialCount,
      textureCount: source.textureCount,
      skinCount: source.skinCount,
      hasSkeleton: source.hasSkeleton,
      boneCount: source.boneCount,
      triangleCount: source.triangleCount,
      readiness: source.readiness,
      animationMapping: Map<String, String>.from(source.animationMapping),
      boneMapping: Map<String, String>.from(source.boneMapping),
      humanoidDetected: source.humanoidDetected,
      originalFileName: source.originalFileName ?? source.fileName,
      charId: 'char_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  String _sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^\w\-. ()\[\]]'), '_');
    return cleaned.isEmpty ? 'character.glb' : cleaned;
  }

  // ---------------------------------------------------------------------
  // File management
  // ---------------------------------------------------------------------
  Future<void> deleteCharacterFile(Character c) async {
    final file = File(c.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    final base = p.basenameWithoutExtension(c.fileName);
    final dir = p.dirname(c.filePath);
    for (final ext in ['png', 'jpg', 'jpeg', 'webp']) {
      final f = File('$dir${Platform.pathSeparator}$base.$ext');
      if (await f.exists()) await f.delete();
    }
  }

  /// Remove every staged/pending file (Settings → Clear Cache, or startup
  /// hygiene after a crash during review).
  int clearPendingImports() {
    final pending = _pendingDir;
    if (pending == null || !pending.existsSync()) return 0;
    var removed = 0;
    try {
      for (final f in pending.listSync().whereType<File>()) {
        f.deleteSync();
        removed++;
      }
    } catch (_) {}
    return removed;
  }

  int directoryUsageBytes() {
    final dir = _charactersDir;
    if (dir == null || !dir.existsSync()) return 0;
    try {
      return dir
          .listSync()
          .whereType<File>()
          .fold<int>(0, (sum, f) => sum + f.lengthSync());
    } catch (_) {
      return 0;
    }
  }

  int get fileCount {
    final dir = _charactersDir;
    if (dir == null || !dir.existsSync()) return 0;
    return dir.listSync().whereType<File>().length;
  }
}

/// Legacy convenience wrapper kept for compatibility with older call sites.
typedef PlatformImportFiles = List<PlatformFile>;
