import 'package:collection/collection.dart';
import 'package:flutter/material.dart' show Color;

import '../backgrounds/backgrounds.dart';
import '../scene/scene_object.dart';
import '../audio/audio_clip.dart';
import '../timeline/story_timeline.dart';
import '../state/editor_provider.dart'
    show CharacterTransform, EditorProvider;

/// Canvas orientation presets (Phase 1 requirement: exactly three).
class ProjectOrientation {
  static const landscape16x9 = 'landscape16x9'; // 1920 × 1080
  static const portrait9x16 = 'portrait9x16'; // 1080 × 1920
  static const square1x1 = 'square1x1'; // 1080 × 1080

  static const all = [landscape16x9, portrait9x16, square1x1];

  static (int, int) canvasSize(String orientation) {
    switch (orientation) {
      case portrait9x16:
        return (1080, 1920);
      case square1x1:
        return (1080, 1080);
      case landscape16x9:
      default:
        return (1920, 1080);
    }
  }

  static String label(String orientation) {
    switch (orientation) {
      case portrait9x16:
        return 'Portrait 9:16';
      case square1x1:
        return 'Square 1:1';
      case landscape16x9:
      default:
        return 'Landscape 16:9';
    }
  }

  static double aspect(String orientation) {
    final (w, h) = canvasSize(orientation);
    return w / h;
  }
}

/// A real, persistent project document. Phase 1 keeps the editor's current
/// single-character composition as the "scene state"; `scene` and `timeline`
/// are reserved placeholders for the Phase 2 SceneGraph and Phase 3
/// StoryTimeline migrations (never read as required data yet).
class ProjectDocument {
  ProjectDocument({
    required this.id,
    required this.name,
    required this.orientation,
    required this.canvasWidth,
    required this.canvasHeight,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.thumbnailPath,
    this.background,
    this.backgroundVisible = true,
    this.characterId,
    this.characterTransform,
    this.actionId,
    this.expression,
    this.talking,
    this.directionLeft,
    this.layers = const [],
    this.effectsVignette = false,
    this.foregroundHaze = false,
    this.exportFps = 30,
    this.exportQuality = 'High',
    this.scene = const {},
    this.timeline = const {},
    List<Map<String, dynamic>>? audioClips,
  })  : audioClips = audioClips ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String orientation; // ProjectOrientation.*
  int canvasWidth;
  int canvasHeight;
  DateTime createdAt;
  DateTime updatedAt;
  String? thumbnailPath; // relative to the project folder

  // ---- Phase-1 scene state (the editor's current composition) -----------
  Map<String, dynamic>? background; // serialized BgConfig (null = default)
  bool backgroundVisible;
  String? characterId; // legacy Phase-1 field (first character summary)
  Map<String, dynamic>? characterTransform;
  String? actionId; // e.g. 'walk'
  String? expression; // Expr name, e.g. 'happy'
  bool? talking;
  bool? directionLeft;
  List<Map<String, dynamic>> layers; // visibility / lock per layer id
  bool effectsVignette;
  bool foregroundHaze;

  // ---- Export settings ----------------------------------------------------
  int exportFps;
  String exportQuality;

  // ---- Phase 2/3 migration placeholders (kept stable in JSON) ------------
  Map<String, dynamic> scene;
  Map<String, dynamic> timeline;

  // ---- Phase 4: audio clips (missing on old projects → empty list) --------
  List<Map<String, dynamic>> audioClips;

  /// Absolute path of the thumbnail inside [projectDir], if generated.
  FileLike? thumbnailOf(String projectDirPath) => null; // ignored helper

  Map<String, dynamic> toJson() => {
        'format': 1,
        'id': id,
        'name': name,
        'orientation': orientation,
        'canvas': {'width': canvasWidth, 'height': canvasHeight},
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'thumbnailPath': thumbnailPath,
        'background': background,
        'backgroundVisible': backgroundVisible,
        'characterId': characterId,
        'characterTransform': characterTransform,
        'actionId': actionId,
        'expression': expression,
        'talking': talking,
        'directionLeft': directionLeft,
        'layers': layers,
        'effectsVignette': effectsVignette,
        'foregroundHaze': foregroundHaze,
        'export': {'fps': exportFps, 'quality': exportQuality},
        'scene': scene,
        'timeline': timeline,
        'audioClips': audioClips,
      };

  static ProjectDocument fromJson(Map<String, dynamic> json) {
    final canvas = (json['canvas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final export = (json['export'] as Map?)?.cast<String, dynamic>() ?? const {};
    final (w, h) = ProjectOrientation.canvasSize(
        (json['orientation'] as String?) ?? ProjectOrientation.landscape16x9);
    return ProjectDocument(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Untitled',
      orientation: (json['orientation'] as String?) ?? ProjectOrientation.landscape16x9,
      canvasWidth: (canvas['width'] as num?)?.toInt() ?? w,
      canvasHeight: (canvas['height'] as num?)?.toInt() ?? h,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
      thumbnailPath: json['thumbnailPath'] as String?,
      background: (json['background'] as Map?)?.cast<String, dynamic>(),
      backgroundVisible: json['backgroundVisible'] as bool? ?? true,
      characterId: json['characterId'] as String?,
      characterTransform: (json['characterTransform'] as Map?)?.cast<String, dynamic>(),
      actionId: json['actionId'] as String?,
      expression: json['expression'] as String?,
      talking: json['talking'] as bool?,
      directionLeft: json['directionLeft'] as bool?,
      layers: [
        for (final l in (json['layers'] as List? ?? []))
          if (l is Map) l.cast<String, dynamic>(),
      ],
      effectsVignette: json['effectsVignette'] as bool? ?? false,
      foregroundHaze: json['foregroundHaze'] as bool? ?? false,
      exportFps: (export['fps'] as num?)?.toInt() ?? 30,
      exportQuality: (export['quality'] as String?) ?? 'High',
      scene: (json['scene'] as Map?)?.cast<String, dynamic>() ?? const {},
      timeline: (json['timeline'] as Map?)?.cast<String, dynamic>() ?? const {},
      audioClips: (json['audioClips'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

}

/// BgConfig ⇄ JSON (kept here so backgrounds.dart stays untouched).
Map<String, dynamic> bgConfigToJson(BgConfig bg) => {
      'kind': bg.kind.name,
      'builtinId': bg.builtinId,
      'color1': bg.color1.value,
      'color2': bg.color2.value,
      'gradientAngle': bg.gradientAngle,
      'imagePath': bg.imagePath,
      'fit': bg.fit.name,
      'offsetX': bg.offsetX,
      'offsetY': bg.offsetY,
      'scale': bg.scale,
      'brightness': bg.brightness,
      'contrast': bg.contrast,
      'blur': bg.blur,
      'opacity': bg.opacity,
    };

BgConfig bgConfigFromJson(Map<String, dynamic>? j) {
  if (j == null) return BgConfig();
  return BgConfig(
    kind: BgKind.values.byName(j['kind'] as String? ?? 'builtin'),
    builtinId: j['builtinId'] as String? ?? 'studio_dark',
    color1: Color((j['color1'] as num?)?.toInt() ?? 0xFF101828),
    color2: Color((j['color2'] as num?)?.toInt() ?? 0xFF2A1E5C),
    gradientAngle: (j['gradientAngle'] as num?)?.toDouble() ?? 135,
    imagePath: j['imagePath'] as String?,
    fit: BgFit.values.byName(j['fit'] as String? ?? 'cover'),
    offsetX: (j['offsetX'] as num?)?.toDouble() ?? 0,
    offsetY: (j['offsetY'] as num?)?.toDouble() ?? 0,
    scale: (j['scale'] as num?)?.toDouble() ?? 1,
    brightness: (j['brightness'] as num?)?.toDouble() ?? 0,
    contrast: (j['contrast'] as num?)?.toDouble() ?? 0,
    blur: (j['blur'] as num?)?.toDouble() ?? 0,
    opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
  );
}

Map<String, dynamic> characterTransformToJson(CharacterTransform t) => {
      'x': t.x,
      'y': t.y,
      'scale': t.scale,
      'rotation': t.rotation,
      'flipH': t.flipH,
      'flipV': t.flipV,
      'opacity': t.opacity,
    };

void characterTransformFromJson(Map<String, dynamic>? j, CharacterTransform t) {
  if (j == null) return;
  t.x = (j['x'] as num?)?.toDouble() ?? t.x;
  t.y = (j['y'] as num?)?.toDouble() ?? t.y;
  t.scale = (j['scale'] as num?)?.toDouble() ?? t.scale;
  t.rotation = (j['rotation'] as num?)?.toDouble() ?? t.rotation;
  t.flipH = j['flipH'] as bool? ?? t.flipH;
  t.flipV = j['flipV'] as bool? ?? t.flipV;
  t.opacity = (j['opacity'] as num?)?.toDouble() ?? t.opacity;
}

// ---- EditorProvider ⇄ ProjectDocument sync helpers -------------------------

/// Writes the editor's live state INTO the document (mutates + timestamps).
void captureEditorIntoProject(EditorProvider ed, ProjectDocument doc) {
  final firstChar = ed.objectsInPaintOrder.where((o) => o.isCharacter).firstOrNull;
  doc
    ..name = ed.projectName
    ..canvasWidth = ed.canvasWidth
    ..canvasHeight = ed.canvasHeight
    ..background = bgConfigToJson(ed.background)
    ..backgroundVisible = ed.backgroundVisible
    // Scene graph (Phase 2): all objects with transforms/state.
    ..scene = {
        'objects': [for (final o in ed.objects) o.toJson()],
      }
    // Story timeline (Phase 3): duration, tracks, clips, keyframes.
    ..timeline = ed.timeline.toJson()
    // Audio clips (Phase 4): id/name/path/type/start/duration/sourceStart/
    // volume/mute/fades/loop — everything needed to replay identically.
    ..audioClips = [for (final c in ed.audioClips) c.toJson()]
    // Legacy single-character summary kept so Phase-1 builds still open the
    // project with at least the first character.
    ..characterId = firstChar?.characterId
    ..characterTransform = firstChar == null ? null : objectTransformToLegacy(firstChar)
    ..actionId = firstChar?.actionId
    ..expression = firstChar?.expression
    ..talking = firstChar?.talking
    ..directionLeft = firstChar?.directionLeft
    ..layers = [
      for (final l in ed.layers)
        {'id': l.id, 'visible': l.visible, 'locked': l.locked},
    ]
    ..effectsVignette = ed.effectsVignette
    ..foregroundHaze = ed.foregroundHaze
    ..updatedAt = DateTime.now();
}

Map<String, dynamic> objectTransformToLegacy(SceneObject o) => {
      'x': o.transform.x,
      'y': o.transform.y,
      'scale': o.transform.scaleY,
      'rotation': o.transform.rotation,
      'flipH': o.transform.flipH,
      'flipV': false,
      'opacity': o.transform.opacity,
    };

/// Applies the document state ONTO the editor (loading a project).
void applyProjectToEditor(EditorProvider ed, ProjectDocument doc) {
  ed.projectName = doc.name;
  ed.canvasWidth = doc.canvasWidth;
  ed.canvasHeight = doc.canvasHeight;
  ed.background = bgConfigFromJson(doc.background);
  ed.backgroundVisible = doc.backgroundVisible;
  ed.effectsVignette = doc.effectsVignette;
  ed.foregroundHaze = doc.foregroundHaze;
  characterTransformFromJson(doc.characterTransform, ed.transform);
  for (final l in ed.layers) {
    final saved = doc.layers.where((m) => m['id'] == l.id).firstOrNull;
    if (saved != null) {
      l.visible = saved['visible'] as bool? ?? true;
      l.locked = saved['locked'] as bool? ?? false;
    }
  }
}

/// The deferred part of [applyProjectToEditor]: builds the scene graph (with
/// Phase-1 → Phase-2 migration for legacy single-character projects), loads
/// artwork. Safe to call after the library is loaded.
Future<void> applyProjectRuntimeToEditor(EditorProvider ed, ProjectDocument doc) async {
  final graph = SceneGraph.fromJson(doc.scene);

  // ---- MIGRATION: Phase-1 documents have no scene.objects but a legacy
  // characterId → synthesize one character object so old projects keep
  // working (never crashes, never duplicates on re-save).
  if (graph.objects.isEmpty && doc.characterId != null) {
    final legacyT = doc.characterTransform;
    graph.objects.add(characterObject(
      id: 'obj_legacy_${doc.characterId}',
      characterId: doc.characterId!,
      name: 'Character',
      zIndex: 1,
      actionId: doc.actionId ?? 'idle',
    )
      ..expression = doc.expression
      ..talking = doc.talking ?? false
      ..directionLeft = doc.directionLeft ?? false
      ..transform = ObjectTransform(
        x: (legacyT?['x'] as num?)?.toDouble() ?? 0.5,
        y: (legacyT?['y'] as num?)?.toDouble() ?? 0.78,
        scaleX: (legacyT?['scale'] as num?)?.toDouble() ?? 1,
        scaleY: (legacyT?['scale'] as num?)?.toDouble() ?? 1,
        rotation: (legacyT?['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (legacyT?['opacity'] as num?)?.toDouble() ?? 1,
        flipH: legacyT?['flipH'] as bool? ?? false,
      ));
  }

  ed.objects
    ..clear()
    ..addAll(graph.objects);
  ed.selectedId = ed.objects.isEmpty ? null : ed.objects.last.id;

  // Build controllers (character state lives inside each object).
  for (final o in ed.objectsInPaintOrder) {
    if (o.isCharacter) ed.controllerFor(o);
  }
  if (ed.objects.isNotEmpty) {
    characterTransformFromJson(doc.characterTransform, ed.transform);
    ed.syncTransformFromSelected();
  }

  // Background image: resolve project-relative path first.
  if (ed.background.kind == BgKind.image && ed.background.imagePath != null) {
    final abs = ed.resolveAssetPath(ed.background.imagePath!);
    if (abs != null) {
      try {
        await ed.loadBgImage(abs);
      } catch (_) {
        // Missing/unreadable image → keep default background.
      }
    }
  }

  // Warm the image-object cache.
  for (final o in ed.objects) {
    if (o.type == SceneObjectType.image) ed.imageFor(o);
  }

  // Story timeline (Phase 3): restore exactly what was saved; projects saved
  // before Phase 3 (or without timeline content) get a clean 20s default.
  // Tracks pointing at objects that no longer exist are pruned safely.
  ed.timeline = StoryTimeline.fromJson(doc.timeline);
  ed.timeline.pruneTo(ed.objects.map((o) => o.id).toSet());
  ed.clock
    ..durationMs = ed.timeline.durationMs
    ..seek(0);

  // Audio (Phase 4): restore every clip; files that vanished are marked
  // missing and surface as Locate/Remove in the timeline (never a crash).
  ed.audio.clips
    ..clear()
    ..addAll(doc.audioClips.map(AudioClip.fromJson));
  ed.audio.refreshMissing();
  ed.applySceneTime(0);
  ed.refresh();
}

/// Tiny typedef placeholder used by [ProjectDocument.thumbnailOf] so the
/// project model stays free of dart:io imports (testable in pure VM tests).
class FileLike {
  const FileLike(this.path);
  final String path;
}
