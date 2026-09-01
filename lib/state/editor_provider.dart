import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter/painting.dart' show Canvas, Paint, Rect;

import '../backgrounds/backgrounds.dart';
import '../characters2d/character2d_model.dart';
import '../characters2d/engine/face_rig.dart' show Expr;
import '../characters2d/puppet_controller.dart';
import '../project/project_document.dart';
import '../scene/scene_object.dart';
import '../state/library2d_provider.dart';

/// One composition layer entry for the Layers panel (v1 list kept for
/// project-file compatibility; visibility of background/effects/foreground
/// overlays lives here).
class SceneLayer {
  SceneLayer(this.id, this.name, {this.visible = true, this.locked = false});
  final String id;
  final String name;
  bool visible;
  bool locked;
}

/// Legacy single-character transform (kept for Phase-1 project files).
class CharacterTransform {
  CharacterTransform({
    this.x = 0.5,
    this.y = 0.78,
    this.scale = 1,
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.opacity = 1,
  });

  double x; // 0..1 of canvas width
  double y; // 0..1 of canvas height (ground line)
  double scale;
  double rotation; // degrees
  bool flipH;
  bool flipV;
  double opacity; // 0..1
}

/// The multi-object editor state: scene objects (characters/images/text/
/// shapes) + per-character puppet controllers + background + playback.
class EditorProvider extends ChangeNotifier {
  EditorProvider(this._library);

  final Library2DProvider _library;

  // ---- Project context -----------------------------------------------------
  ProjectDocument? project;
  bool get hasProject => project != null;

  /// Absolute path of the open project's folder (for resolving relative
  /// asset paths). Set by ProjectsProvider when a project opens.
  String? projectDirPath;

  // ---- Scene objects ---------------------------------------------------------
  final List<SceneObject> objects = [];
  String? selectedId;
  SceneObject? get selected => selectedId == null ? null : objects.where((o) => o.id == selectedId).firstOrNull;

  /// Objects sorted bottom→top for painting (invisible filtered by renderer).
  List<SceneObject> get objectsInPaintOrder {
    final list = [...objects]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return list.where((o) => o.visible).toList();
  }

  SceneObject? get selectedCharacter => (selected != null && selected!.isCharacter) ? selected : null;

  // ---- Background --------------------------------------------------------------
  BgConfig background = BgConfig();
  ui.Image? bgImage;
  bool backgroundVisible = true;

  // ---- Legacy overlay layers (effects/foreground) -------------------------------
  final List<SceneLayer> layers = [
    SceneLayer('background', 'Background'),
    SceneLayer('shadow', 'Character Shadow'),
    SceneLayer('character', 'Character'),
    SceneLayer('effects', 'Effects (vignette)'),
    SceneLayer('foreground', 'Foreground haze'),
  ];

  String projectName = 'My Animation';
  int canvasWidth = 1920;
  int canvasHeight = 1080;

  bool effectsVignette = false;
  bool foregroundHaze = false;

  // ---- Per-character controllers -------------------------------------------------
  final Map<String, PuppetController> _controllers = {};
  final Map<String, ui.Image> _imageCache = {};

  PuppetController? controllerFor(SceneObject obj) {
    if (!obj.isCharacter || obj.characterId == null) return null;
    var c = _controllers[obj.id];
    if (c != null) return c;
    final character = _library.byId(obj.characterId!);
    if (character == null) return null;
    c = PuppetController(spec: character.spec, palette: character.colors, accessories: {...character.accessories});
    c.setAction(obj.actionId);
    if (obj.expression != null) {
      for (final e in Expr.values) {
        if (e.name == obj.expression) c.setExpression(e);
      }
    }
    c.setTalking(obj.talking);
    c.setDirection(obj.directionLeft ? -1 : 1);
    _controllers[obj.id] = c;
    return c;
  }

  /// Legacy single-controller accessor: the SELECTED character's controller,
  /// else the first character object's (keeps old panels/export working).
  PuppetController? get controller {
    final sc = selectedCharacter;
    if (sc != null) return controllerFor(sc);
    for (final o in objectsInPaintOrder) {
      if (o.isCharacter) return controllerFor(o);
    }
    return null;
  }

  Character2D? get character {
    final c = selectedCharacter ?? objectsInPaintOrder.where((o) => o.isCharacter).firstOrNull;
    final id = c?.characterId;
    return id == null ? null : _library.byId(id);
  }

  /// Legacy transform proxy bound to the selected character object.
  final CharacterTransform transform = CharacterTransform();

  void syncTransformFromSelected() {
    final t = selected?.transform;
    if (t != null) {
      transform.x = t.x;
      transform.y = t.y;
      transform.scale = t.scaleY;
      transform.rotation = t.rotation;
      transform.flipH = t.flipH;
      transform.opacity = t.opacity;
    }
  }

  // ---- Object CRUD -----------------------------------------------------------

  int get _nextZ => objects.fold(0, (m, o) => math.max(m, o.zIndex)) + 1;

  SceneObject addCharacter(String characterId, {bool select = true}) {
    final c = _library.byId(characterId);
    final obj = characterObject(
      id: 'obj_${DateTime.now().millisecondsSinceEpoch}_${objects.length}',
      characterId: characterId,
      name: c?.name ?? 'Character',
      zIndex: _nextZ,
    );
    objects.add(obj);
    controllerFor(obj);
    if (select) selectedId = obj.id;
    _library.recordUsage(characterId);
    notifyListeners();
    return obj;
  }

  Future<SceneObject> addImage(String absolutePath, String relativePath) async {
    final obj = imageObject(
      id: 'obj_${DateTime.now().millisecondsSinceEpoch}_${objects.length}',
      relPath: relativePath,
      name: 'Image ${objects.length + 1}',
      zIndex: _nextZ,
    );
    objects.add(obj);
    selectedId = obj.id;
    await imageFor(obj);
    notifyListeners();
    return obj;
  }

  SceneObject addText() {
    final obj = textObject(id: 'obj_${DateTime.now().millisecondsSinceEpoch}_${objects.length}', zIndex: _nextZ);
    objects.add(obj);
    selectedId = obj.id;
    notifyListeners();
    return obj;
  }

  SceneObject addShape(String kind) {
    final obj = shapeObject(id: 'obj_${DateTime.now().millisecondsSinceEpoch}_${objects.length}', zIndex: _nextZ, kind: kind);
    objects.add(obj);
    selectedId = obj.id;
    notifyListeners();
    return obj;
  }

  void select(String? id) {
    selectedId = id;
    syncTransformFromSelected();
    notifyListeners();
  }

  void updateTransform(String id, void Function(ObjectTransform t) fn) {
    final obj = objects.where((o) => o.id == id).firstOrNull;
    if (obj == null || obj.locked) return;
    fn(obj.transform);
    if (selectedId == id) syncTransformFromSelected();
    notifyListeners();
  }

  /// Updates the selected object's transform (canvas drag / numeric panel).
  void updateSelectedTransform(void Function(ObjectTransform t) fn) {
    final id = selectedId;
    if (id == null) return;
    updateTransform(id, fn);
  }

  void updateObject(String id, void Function(SceneObject o) fn) {
    final obj = objects.where((o) => o.id == id).firstOrNull;
    if (obj == null) return;
    fn(obj);
    notifyListeners();
  }

  void removeObject(String id) {
    objects.removeWhere((o) => o.id == id);
    _controllers.remove(id)?.dispose();
    if (selectedId == id) selectedId = objects.isEmpty ? null : objects.last.id;
    notifyListeners();
  }

  void moveObjectUp(String id) => _reorder(id, 1);
  void moveObjectDown(String id) => _reorder(id, -1);

  void _reorder(String id, int dir) {
    final ordered = [...objects]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final i = ordered.indexWhere((o) => o.id == id);
    final j = i + dir;
    if (i < 0 || j < 0 || j >= ordered.length) return;
    final a = ordered[i];
    final b = ordered[j];
    final az = a.zIndex;
    a.zIndex = b.zIndex;
    b.zIndex = az;
    // De-duplicate z values so future inserts stay ordered.
    var z = 0;
    for (final o in ordered..sort((x, y) => x.zIndex.compareTo(y.zIndex))) {
      o.zIndex = z++;
    }
    notifyListeners();
  }

  void setVisibility(String id, bool v) => updateObject(id, (o) => o.visible = v);
  void toggleLock(String id) => updateObject(id, (o) => o.locked = !o.locked);

  // ---- Image cache ---------------------------------------------------------------

  /// Loads (and caches) the object's artwork from the project folder.
  ui.Image? imageFor(SceneObject obj) {
    if (obj.type != SceneObjectType.image || obj.imagePath == null) return null;
    final abs = resolveAssetPath(obj.imagePath!);
    if (abs == null) return null;
    final cached = _imageCache[abs];
    if (cached != null) return cached;
    _loadImage(abs);
    return null;
  }

  String? resolveAssetPath(String relative) {
    final base = projectDirPath;
    if (base == null) return relative.startsWith('/') ? relative : null;
    return relative.startsWith('/') ? relative : '$base/$relative';
  }

  void _loadImage(String abs) async {
    if (_imageCache.containsKey(abs) || _loading.contains(abs)) return;
    _loading.add(abs);
    try {
      final data = await File(abs).readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      _imageCache[abs] = frame.image;
      notifyListeners();
    } catch (_) {
      _imageCache[abs] = brokenMarker; // mark broken so we don't retry forever
      notifyListeners();
    } finally {
      _loading.remove(abs);
    }
  }

  final Set<String> _loading = {};
  ui.Image? _broken;

  /// 1×1 transparent marker for un-loadable images (never retried).
  ui.Image get brokenMarker => _broken ??= _makeBroken();

  ui.Image _makeBroken() {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = const Color(0x00000000));
    return rec.endRecording().toImageSync(1, 1);
  }

  // ---- Character animation state (selected or by id) ------------------------------

  void setAction(String id) => _withSelectedCharController((o, c) {
        o.actionId = id;
        c.setAction(id);
      });

  void setExpression(Expr e) => _withSelectedCharController((o, c) {
        o.expression = e.name;
        c.setExpression(e);
      });

  void setTalking(bool on) => _withSelectedCharController((o, c) {
        o.talking = on;
        c.setTalking(on);
      });

  void setDirection(bool left) => _withSelectedCharController((o, c) {
        o.directionLeft = left;
        c.setDirection(left ? -1 : 1);
      });

  void _withSelectedCharController(void Function(SceneObject o, PuppetController c) fn) {
    final o = selectedCharacter;
    if (o == null) return;
    final c = controllerFor(o);
    if (c == null) return;
    fn(o, c);
    notifyListeners();
  }

  // ---- Legacy v2.0 API (kept: panels, scrubber, export) ---------------------------

  void setEffects(bool v) {
    effectsVignette = v;
    notifyListeners();
  }

  void setForegroundHaze(bool v) {
    foregroundHaze = v;
    notifyListeners();
  }

  PuppetController? loadCharacter(String characterId) {
    addCharacter(characterId);
    return controller;
  }

  void setTransform(void Function(CharacterTransform t) fn) {
    fn(transform);
    // Proxy the legacy transform onto the selected character object.
    final o = selectedCharacter;
    if (o != null) {
      o.transform
        ..x = transform.x
        ..y = transform.y
        ..scaleX = transform.scale
        ..scaleY = transform.scale
        ..rotation = transform.rotation
        ..flipH = transform.flipH
        ..opacity = transform.opacity;
    } else {
      final any = objectsInPaintOrder.where((e) => e.isCharacter).firstOrNull;
      if (any != null) {
        any.transform
          ..x = transform.x
          ..y = transform.y
          ..scaleX = transform.scale
          ..scaleY = transform.scale
          ..rotation = transform.rotation
          ..flipH = transform.flipH
          ..opacity = transform.opacity;
      }
    }
    notifyListeners();
  }

  void setBackground(BgConfig cfg) {
    background = cfg;
    notifyListeners();
  }

  Future<void> loadBgImage(String path, {String? storeRelative}) async {
    final data = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    bgImage?.dispose();
    bgImage = frame.image;
    background.imagePath = storeRelative ?? path;
    background.kind = BgKind.image;
    notifyListeners();
  }

  // ---- Playback passthrough (bound to the selected character in P2) ---------------
  void play() {
    for (final c in _controllers.values) {
      c.setPlaying(true);
    }
    notifyListeners();
  }

  void pause() {
    for (final c in _controllers.values) {
      c.setPlaying(false);
    }
    notifyListeners();
  }

  void stop() {
    for (final c in _controllers.values) {
      c.setPlaying(false);
      c.setAction(c.actionId);
    }
    notifyListeners();
  }

  void stepFrame(int delta) {
    final c = controller;
    if (c == null) return;
    c.setPlaying(false);
    final fps = 30.0;
    final t = (c.animator.clipTime + delta / fps) % c.animator.clipDuration;
    c.animator.scrub(t);
    notifyListeners();
  }

  void scrub(double t) {
    for (final c in _controllers.values) {
      c.setPlaying(false);
      c.animator.scrub(t % c.animator.clipDuration);
    }
    notifyListeners();
  }

  /// Scrubs EVERY character controller to the same animation time — used by
  /// the export loop so multi-character scenes animate in the exported file.
  void scrubAll(double t) => scrub(t);

  void setSpeed(double s) {
    for (final c in _controllers.values) {
      c.setSpeed(s);
    }
    notifyListeners();
  }

  void setLoop(bool v) {
    for (final c in _controllers.values) {
      c.loop = v;
    }
    notifyListeners();
  }

  void setCanvasSize(int w, int h) {
    canvasWidth = w;
    canvasHeight = h;
    notifyListeners();
  }

  /// Public repaint trigger for external state owners (ProjectsProvider).
  void refresh() => notifyListeners();

  /// Clears the whole scene (used when switching/closing projects).
  void clearScene() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    objects.clear();
    selectedId = null;
    bgImage?.dispose();
    bgImage = null;
    background = BgConfig();
    backgroundVisible = true;
    effectsVignette = false;
    foregroundHaze = false;
    for (final l in layers) {
      l.visible = true;
      l.locked = false;
    }
    transform
      ..x = 0.5
      ..y = 0.78
      ..scale = 1
      ..rotation = 0
      ..flipH = false
      ..flipV = false
      ..opacity = 1;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
}
