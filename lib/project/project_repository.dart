import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'project_document.dart';

/// File-backed project storage:
///
///   <appDocuments>/projects/<projectId>/
///     project.json   — the serialized ProjectDocument
///     assets/        — project-local assets (future phases)
///     thumb.png      — rendered composition thumbnail
///
/// Survives app close, restart and Android process death. SharedPreferences
/// stays reserved for character favorites/recents only.
class ProjectRepository {
  ProjectRepository({Directory? baseDir}) : _baseDirOverride = baseDir;

  final Directory? _baseDirOverride;
  Directory? _cachedBase;

  Future<Directory> baseDir() async {
    if (_baseDirOverride != null) return _baseDirOverride;
    if (_cachedBase != null) return _cachedBase!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/projects');
    await dir.create(recursive: true);
    _cachedBase = dir;
    return dir;
  }

  Future<Directory> projectDir(String projectId) async {
    final dir = Directory('${(await baseDir()).path}/$projectId');
    await dir.create(recursive: true);
    return dir;
  }

  /// Creates the on-disk folder for a new document.
  Future<ProjectDocument> create(ProjectDocument doc) async {
    await projectDir(doc.id);
    await save(doc);
    return doc;
  }

  /// Atomic JSON save (write temp + rename) — a crash mid-save never
  /// corrupts the previous version.
  Future<void> save(ProjectDocument doc) async {
    final dir = await projectDir(doc.id);
    final json = const JsonEncoder.withIndent('  ').convert(doc.toJson());
    final tmp = File('${dir.path}/project.json.tmp');
    final dest = File('${dir.path}/project.json');
    await tmp.writeAsString(json);
    await tmp.rename(dest.path);
  }

  Future<ProjectDocument?> load(String projectId) async {
    final f = File('${(await baseDir()).path}/$projectId/project.json');
    if (!await f.exists()) return null;
    try {
      final map = jsonDecode(await f.readAsString());
      if (map is! Map<String, dynamic>) return null;
      final doc = ProjectDocument.fromJson(map);
      // Thumbnail path is derived from presence of the file.
      final thumb = File('${(await baseDir()).path}/$projectId/thumb.png');
      doc.thumbnailPath = await thumb.exists() ? thumb.path : null;
      return doc;
    } catch (_) {
      return null; // unreadable project → skipped, never crashes the app
    }
  }

  /// All projects, newest-updated first.
  Future<List<ProjectDocument>> list() async {
    final dir = await baseDir();
    final docs = <ProjectDocument>[];
    await for (final e in dir.list()) {
      if (e is! Directory) continue;
      // Directory.uri ends with '/', so pathSegments.last would be '' —
      // take the real folder name from the path instead.
      final name = e.path.split(Platform.pathSeparator).last;
      final doc = await load(name);
      if (doc != null) docs.add(doc);
    }
    docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return docs;
  }

  Future<void> rename(ProjectDocument doc, String newName) async {
    doc.name = newName.trim().isEmpty ? doc.name : newName.trim();
    doc.updatedAt = DateTime.now();
    await save(doc);
  }

  /// Duplicates a project under a new unique id (original untouched).
  Future<ProjectDocument?> duplicate(ProjectDocument doc) async {
    final sourceDir = await projectDir(doc.id);
    final newId = 'prj_${DateTime.now().millisecondsSinceEpoch}';
    final json = doc.toJson();
    json['id'] = newId;
    json['name'] = '${doc.name} Copy';
    final copy = ProjectDocument.fromJson(json);
    await create(copy);
    // Copy thumbnail + assets folder contents if present.
    try {
      final thumb = File('${sourceDir.path}/thumb.png');
      if (await thumb.exists()) {
        await thumb.copy('${(await projectDir(newId)).path}/thumb.png');
      }
      final assets = Directory('${sourceDir.path}/assets');
      if (await assets.exists()) {
        final destAssets = Directory('${(await projectDir(newId)).path}/assets');
        await destAssets.create(recursive: true);
        await for (final f in assets.list()) {
          if (f is File) await f.copy('${destAssets.path}/${f.uri.pathSegments.last}');
        }
      }
    } catch (_) {
      // thumbnail/asset copy is best-effort; project.json is the source of truth
    }
    return copy;
  }

  Future<void> delete(String projectId) async {
    final dir = Directory('${(await baseDir()).path}/$projectId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Writes a rendered PNG thumbnail for the project.
  Future<void> saveThumbnail(String projectId, List<int> pngBytes) async {
    final dir = await projectDir(projectId);
    await File('${dir.path}/thumb.png').writeAsBytes(pngBytes, flush: true);
  }
}
