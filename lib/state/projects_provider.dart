import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../project/project_document.dart';
import '../project/project_repository.dart';
import '../scene/scene_renderer.dart';
import 'editor_provider.dart';

/// Owns the project list + the currently-open project, debounced autosave
/// and thumbnail refresh. The editor stays the live composition; this
/// provider projects it into persistent ProjectDocuments.
class ProjectsProvider extends ChangeNotifier {
  ProjectsProvider({ProjectRepository? repo})
      : repo = repo ?? ProjectRepository() {
    _attachAutosave();
  }

  final ProjectRepository repo;

  List<ProjectDocument> projects = [];
  ProjectDocument? current;
  bool loaded = false;

  /// Set when listing failed — the UI shows a retry affordance instead of a
  /// spinner that never ends. Null once a load succeeds.
  String? loadError;

  EditorProvider? _editor;
  Timer? _debounce;
  bool _saving = false;
  Future<void>? _loadInFlight;

  /// Loads the project list exactly once per session (idempotent + guarded
  /// against concurrent calls — everyone awaits the SAME in-flight load, so
  /// Home init / shortcuts / retry can never race). Never throws: failures
  /// land in [loadError].
  Future<void> load() {
    if (loaded) return Future.value();
    return _loadInFlight ??= _load().whenComplete(() => _loadInFlight = null);
  }

  Future<void> _load() async {
    loadError = null;
    try {
      projects = await repo.list();
      loaded = true;
    } catch (e) {
      // Storage unavailable (first run, IO error…): keep the UI usable.
      loaded = false;
      loadError = 'Could not read projects: $e';
      debugPrint('ProjectsProvider.load failed: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Public refresh of the project list (used after editor closes). A failure
  // keeps the previous list and is logged — never breaks the Home screen.
  Future<void> reloadList() async {
    try {
      projects = await repo.list();
      loadError = null;
    } catch (e) {
      debugPrint('ProjectsProvider.reloadList failed: $e');
    }
    notifyListeners();
  }

  void _attachAutosave() {
    // Autosave is driven by EditorProvider notifications — these fire on real
    // state changes (action, transform, background…), NOT on animation
    // playback frames, so writes stay cheap and bounded.
  }

  /// Binds the editor provider once (from the widget tree) and starts
  /// listening for debounced autosaves.
  void bindEditor(EditorProvider editor) {
    if (_editor == null) {
      _editor = editor;
      editor.addListener(_onEditorChanged);
    }
  }

  void _onEditorChanged() {
    if (current == null) return;
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () => saveCurrent());
  }

  /// CREATES a new empty project (no forced character — the user adds
  /// background/character themselves) and opens it in the editor.
  Future<ProjectDocument> createProject({
    required String name,
    required String orientation,
  }) async {
    final id = 'prj_${DateTime.now().millisecondsSinceEpoch}';
    final (w, h) = ProjectOrientation.canvasSize(orientation);
    final doc = ProjectDocument(
      id: id,
      name: name.trim().isEmpty ? 'Untitled Story' : name.trim(),
      orientation: orientation,
      canvasWidth: w,
      canvasHeight: h,
    );
    await repo.create(doc);
    projects = [doc, ...projects];
    await _openInEditor(doc);
    notifyListeners();
    return doc;
  }

  /// Opens an existing project: applies its state to the editor.
  Future<void> openProject(String projectId) async {
    ProjectDocument? doc;
    try {
      doc = await repo.load(projectId);
    } catch (e) {
      debugPrint('openProject($projectId) load failed: $e');
      return;
    }
    if (doc == null) {
      debugPrint('openProject($projectId): missing or unreadable project.json');
      return;
    }
    await _openInEditor(doc);
    notifyListeners();
  }

  Future<void> _openInEditor(ProjectDocument doc) async {
    final ed = _editor;
    if (ed == null) {
      // Must never happen: main.dart binds the editor at startup. If it
      // ever does, fail loudly instead of silently doing nothing.
      debugPrint('openProject: editor is NOT bound — call bindEditor()');
      return;
    }
    // Stop playback + clear the previous project's scene before switching.
    ed.pause();
    ed.clearScene();
    ed.project = doc;
    ed.projectDirPath = (await repo.projectDir(doc.id)).path;
    applyProjectToEditor(ed, doc);
    await applyProjectRuntimeToEditor(ed, doc);
    current = doc;
    ed.refresh();
    await saveCurrent();
  }

  /// Writes the live editor state into the current project document (called
  /// by the debounced autosave, on editor close and on lifecycle pause).
  Future<void> saveCurrent() async {
    final doc = current;
    final ed = _editor;
    if (doc == null || ed == null || _saving) return;
    _saving = true;
    try {
      captureEditorIntoProject(ed, doc);
      await repo.save(doc);
      final i = projects.indexWhere((p) => p.id == doc.id);
      if (i >= 0) projects[i] = doc;
      notifyListeners();
    } catch (e) {
      debugPrint('project save failed: $e'); // friendly: never crash on IO
    } finally {
      _saving = false;
    }
  }

  /// Leaves the editor: final save + thumbnail, then clears current.
  Future<void> closeCurrent({bool withThumbnail = true}) async {
    final doc = current;
    final ed = _editor;
    if (doc == null) return;
    _debounce?.cancel();
    if (ed != null) {
      ed.pause();
      captureEditorIntoProject(ed, doc);
      await repo.save(doc);
      if (withThumbnail) await _refreshThumbnail(doc, ed);
    }
    current = null;
    if (ed != null) {
      ed.project = null;
      ed.projectDirPath = null;
      ed.refresh();
    }
    notifyListeners();
  }

  /// Renders the current composition through the SAME scene renderer used by
  /// preview and export, and stores it as the project thumbnail.
  /// Failures fall back to leaving the old thumbnail (the home card then
  /// shows a composition-colored placeholder, never a fake image).
  Future<void> _refreshThumbnail(ProjectDocument doc, EditorProvider ed) async {
    try {
      const w = 480;
      final h = (w * doc.canvasHeight / doc.canvasWidth).round();
      final image = await renderSceneFrame(ed, w, h);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data != null) {
        await repo.saveThumbnail(doc.id, data.buffer.asUint8List());
        doc.thumbnailPath = '${(await repo.projectDir(doc.id)).path}/thumb.png';
      }
    } catch (_) {
      // Keep previous thumbnail; documented as best-effort.
    }
  }

  Future<void> renameProject(ProjectDocument doc, String newName) async {
    await repo.rename(doc, newName);
    await _reloadList();
  }

  Future<void> duplicateProject(ProjectDocument doc) async {
    final copy = await repo.duplicate(doc);
    if (copy != null) await _reloadList();
  }

  Future<void> deleteProject(String projectId) async {
    if (current?.id == projectId) {
      await closeCurrent(withThumbnail: false);
    }
    await repo.delete(projectId);
    await _reloadList();
  }

  Future<void> _reloadList() async {
    projects = await repo.list();
    notifyListeners();
  }

  /// Lifecycle pause hook: flush any pending save immediately.
  Future<void> onAppPaused() async {
    _debounce?.cancel();
    await saveCurrent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Re-exported so UI code has one import for project types.
typedef ProjectCardData = ({String id, String name, String orientation, String? thumbnailPath});
