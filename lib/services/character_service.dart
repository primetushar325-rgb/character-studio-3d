import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path/path.dart' as p;

import '../core/constants/app_constants.dart';
import '../models/animation_clip.dart';
import '../models/character.dart';
import 'glb_parser_service.dart';
import 'gltf_converter_service.dart';

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
  })  : _parser = parser ?? GlbParserService(),
        _converter = converter ?? GltfConverterService();

  final GlbParserService _parser;
  final GltfConverterService _converter;

  Directory? _charactersDir;

  /// Called once at app start with the app documents directory.
  void configure(Directory appDocs) {
    _charactersDir = Directory(
        '${appDocs.path}${Platform.pathSeparator}${AppConstants.charactersDirName}');
    if (!_charactersDir!.existsSync()) {
      _charactersDir!.createSync(recursive: true);
    }
  }

  Directory? get charactersDir => _charactersDir;

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
        final stat = file.statSync();
        final clips = <AnimationClip>[
          for (var i = 0; i < data.animations.length; i++)
            AnimationClip.fromGlbName(
              data.animations[i].name,
              duration: data.animations[i].durationSeconds,
              fallbackIndex: i + 1,
            ),
        ];

        final character = Character(
          id: name,
          fileName: name,
          filePath: file.path,
          displayName: _defaultDisplayName(name),
          fileSizeBytes: stat.size,
          animations: clips,
          source:
              bundledIds.contains(name) ? CharacterSource.bundled : CharacterSource.imported,
          createdAt: stat.modified.year < 2000 ? DateTime.now() : stat.modified,
          generator: data.generator,
          nodeCount: data.nodeCount,
          meshCount: data.meshCount,
          materialCount: data.materialCount,
          textureCount: data.textureCount,
          skinCount: data.skinCount,
        );
        _attachSiblingThumbnail(character);
        results.add(ScanOutcome(character: character));
      } on GlbParseException catch (e) {
        // Keep broken files out of the library but still surfaced to the user.
        final character = Character(
          id: name,
          fileName: name,
          filePath: file.path,
          displayName: _defaultDisplayName(name),
          fileSizeBytes: file.lengthSync(),
          animations: [],
          source: CharacterSource.imported,
          createdAt: DateTime.now(),
        );
        results.add(ScanOutcome(character: character, error: e.message));
      }
    }
    return results;
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

  /// The manifest listing method was renamed across Flutter versions
  /// (listAssets → listAssetPaths), so resolve it dynamically to stay
  /// compatible with both.
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

  // ---------------------------------------------------------------------
  // Import pipeline (file picker → validate → convert/copy → parse)
  // ---------------------------------------------------------------------
  Future<ImportOutcome> importPickedFiles(List<PlatformFile> files) async {
    final dir = _charactersDir;
    if (dir == null) {
      return const ImportOutcome(
          errorMessage: 'Local storage is not available yet. Please reopen the app.');
    }
    if (files.isEmpty) {
      return const ImportOutcome(errorMessage: 'No file was selected.');
    }

    // Stage picked files into a temp dir so .gltf can find its siblings.
    final staging = Directory.systemTemp.createTempSync('cs3d_import');
    try {
      final staged = <File>[];
      for (final pf in files) {
        final sourcePath = pf.path;
        if (sourcePath == null || sourcePath.isEmpty) continue;
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
        final target =
            File('${staging.path}${Platform.pathSeparator}${p.basename(source.path)}');
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

      // Copy into the character directory with a collision-safe name.
      final safeBase = _sanitize(p.basename(working.path));
      var finalName = safeBase;
      var counter = 1;
      while (File('${dir.path}${Platform.pathSeparator}$finalName').existsSync()) {
        final dot = safeBase.lastIndexOf('.');
        finalName = dot > 0
            ? '${safeBase.substring(0, dot)} ($counter)${safeBase.substring(dot)}'
            : '$safeBase ($counter)';
        counter++;
      }
      final targetFile = File('${dir.path}${Platform.pathSeparator}$finalName');
      await working.copy(targetFile.path);

      // Sibling thumbnail (e.g. the user picked fox.glb + fox.png together).
      final thumbBase = p.basenameWithoutExtension(working.path);
      for (final ext in ['png', 'jpg', 'jpeg', 'webp']) {
        final sibling = File('${staging.path}${Platform.pathSeparator}$thumbBase.$ext');
        if (await sibling.exists()) {
          await sibling.copy(
              '${dir.path}${Platform.pathSeparator}'
              '${p.basenameWithoutExtension(finalName)}.$ext');
          break;
        }
      }

      // Parse + build the character.
      final GlbModelData data;
      try {
        data = await _parser.parseFile(targetFile.path);
      } on GlbParseException catch (e) {
        try { await targetFile.delete(); } catch (_) {}
        return ImportOutcome(errorMessage: e.message);
      }

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

      final character = Character(
        id: finalName,
        fileName: finalName,
        filePath: targetFile.path,
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
      );
      _attachSiblingThumbnail(character);

      return ImportOutcome(character: character, warnings: warnings);
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
