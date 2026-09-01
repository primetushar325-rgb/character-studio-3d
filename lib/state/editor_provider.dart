import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter/painting.dart' show Canvas, Paint, Rect;

import '../backgrounds/backgrounds.dart';
import '../characters2d/character2d_model.dart';
import '../characters2d/engine/animator2d.dart' show PuppetFrameData;
import '../characters2d/engine/face_rig.dart' show Expr;
import '../characters2d/engine/pose2d.dart' show Pose2D;
import '../characters2d/engine/rig2d.dart' show solveSkeleton;
import '../characters2d/puppet_controller.dart';
import '../project/project_document.dart';
import '../scene/scene_object.dart';
import '../state/library2d_provider.dart';
import '../timeline/playback_clock.dart';
import '../timeline/story_timeline.dart';

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
  EditorProvider(this._library) {
    clock.addListener(_onClock);
  }

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

  // ---- PHASE 3: story timeline + one scene clock ---------------------------------
  StoryTimeline timeline = StoryTimeline.empty();
  final PlaybackClock clock = PlaybackClock();

  /// Runtime (evaluated) state — only non-empty when the timeline has content
  /// or playback/scrub happened. Renderer reads through [transformFor] /
  /// [runtimeHidden] so preview == export by construction.
  final Map<String, EvaluatedTransform> _runtimeTransforms = {};
  final Set<String> _runtimeHidden = {};

  bool autoKey = false; // AUTO KEY on/off (spec §13)

  bool get timelineActive =>
      timeline.tracks.values.any((t) =>
          t.clips.isNotEmpty ||
          t.visClips.isNotEmpty ||
          t.keyframes.isNotEmpty);

  int get playheadMs => clock.currentTimeMs;
  int get durationMs => clock.durationMs;

  /// Transform actually used for painting: timeline-evaluated when active,
  /// otherwise the static object transform.
  EvaluatedTransform transformFor(SceneObject obj) =>
      _runtimeTransforms[obj.id] ?? EvaluatedTransform.of(obj.transform);

  bool runtimeHidden(String id) => _runtimeHidden.contains(id);

  /// Live paint transform for [obj]: timeline-evaluated values merged onto
  /// the static transform (flips follow the object, not keyframes).
  ObjectTransform evaluatedTransformView(SceneObject obj) {
    final rt = _runtimeTransforms[obj.id];
    if (rt == null) return obj.transform;
    return ObjectTransform(
      x: rt.x,
      y: rt.y,
      scaleX: rt.scaleX,
      scaleY: rt.scaleY,
      rotation: rt.rotation,
      opacity: rt.opacity.clamp(0, 1),
      flipH: obj.transform.flipH,
    );
  }

  void _onClock() {
    // Any clock change (play tick, seek, stop) re-evaluates the scene.
    applySceneTime(clock.currentTimeMs);
  }

  /// Deterministic seek used by the export loop (spec §22): pauses the clock
  /// and evaluates the whole scene at [ms]. Preview and export share this.
  void scrubSceneTo(int ms) {
    clock.pause();
    clock.seek(ms.clamp(0, clock.durationMs)); // → applySceneTime via listener
  }

  /// Re-applies the current playhead time to the live scene (call after any
  /// structural edit: object added/removed, transform changed, track edited).
  void refreshRuntime() {
    if (timelineActive || _runtimeTransforms.isNotEmpty) {
      applySceneTime(clock.currentTimeMs);
    }
  }

  /// THE evaluation entry (spec §20/§21): computes the complete scene state
  /// at scene time [tMs] — transforms, visibility, character animation — from
  /// the timeline data. Deterministic: same project + same tMs → same state.
  void applySceneTime(int tMs) {
    final t = tMs.clamp(0, clock.durationMs);
    _runtimeTransforms.clear();
    _runtimeHidden.clear();

    final bgTrack = timeline.trackOf(kBackgroundTrackId);
    if (bgTrack != null &&
        !bgTrack.visibleAt(t, baseVisible: backgroundVisible)) {
      _runtimeHidden.add(kBackgroundTrackId);
    }

    for (final obj in objects) {
      final track = timeline.trackOf(obj.id);
      if (track != null && !track.visibleAt(t, baseVisible: obj.visible)) {
        _runtimeHidden.add(obj.id);
        continue;
      }
      if (track != null && track.keyframes.isNotEmpty) {
        _runtimeTransforms[obj.id] = evalTransform(obj, track, t);
      }
      if (obj.isCharacter) _applyCharacterTrack(obj, track, t);
    }
    notifyListeners();
  }

  /// Deterministic character evaluation: active clip → local time → force
  /// the base clip on the (paused) animator → scrub → re-solve. Deterministic
  /// pose crossfade at clip boundaries (blend-in/out, spec §17).
  void _applyCharacterTrack(SceneObject obj, TimelineTrack? track, int tMs) {
    final c = controllerFor(obj);
    if (c == null) return;
    c.setPlaying(false);
    c.clearFrameOverride();
    final sceneSec = tMs / 1000.0;

    final clip = track?.animAt(tMs);
    final talkOn =
        clip == null ? obj.talking : (clip.animId == 'talk' || obj.talking);
    if (c.animator.talking != talkOn) c.setTalking(talkOn);

    // Outside any clip: the object's chosen static action, loop-sampled at
    // scene time (continuous idle breathing, fully deterministic).
    final animId = clip?.animId ?? obj.actionId;
    _forceClip(c, animId);
    final srcDurMs = (c.animator.clipDuration * 1000).round();
    final localSec = clip == null
        ? sceneSec % math.max(c.animator.clipDuration, 0.001)
        : (clip.localMs(tMs, srcDurMs) / 1000.0)
            .clamp(0.0, c.animator.clipDuration);
    c.animator.scrub(localSec, faceTime: sceneSec);
    c.animator.speech.seekTo(sceneSec);
    c.tick(0); // re-solve the frame from the scrubbed time
    if (clip == null || track == null) return;

    // ---- Boundary blends (Walk → Wave must not hard-cut) -----------------
    Pose2D? other; // the pose we blend towards/away from
    var wCur = 1.0; // weight of the CURRENT clip's pose
    if (clip.blendInMs > 0 && tMs - clip.startMs < clip.blendInMs) {
      final prev = track.neighborOf(clip, after: false);
      if (prev != null) {
        wCur = (tMs - clip.startMs) / clip.blendInMs;
        other = _sampleClipPose(c, prev, prev.endMs, sceneSec);
      }
    } else if (clip.blendOutMs > 0 && clip.endMs - tMs < clip.blendOutMs) {
      final next = track.neighborOf(clip, after: true);
      if (next != null) {
        wCur = (clip.endMs - tMs) / clip.blendOutMs;
        other = _sampleClipPose(c, next, next.startMs, sceneSec);
      }
    }
    if (other != null) {
      // Re-force + re-sample the current clip (sampling `other` above left
      // the animator on the neighbor clip).
      final curPose = _sampleClipPose(c, clip, tMs, sceneSec);
      c.tick(0);
      _overrideWithBlend(c, from: other, to: curPose, w: wCur,
          sceneSec: sceneSec);
    }
  }

  /// Samples a clip's pose at scene time [tMs]; callers re-force their own
  /// clip afterwards (this leaves the animator on the sampled clip).
  Pose2D _sampleClipPose(
      PuppetController c, AnimClip clip, int tMs, double sceneSec) {
    _forceClip(c, clip.animId);
    final srcDurMs = (c.animator.clipDuration * 1000).round();
    final localSec = (clip.localMs(tMs, srcDurMs) / 1000.0)
        .clamp(0.0, c.animator.clipDuration);
    c.animator.scrub(localSec, faceTime: sceneSec);
    c.animator.speech.seekTo(sceneSec);
    c.tick(0);
    return c.frame.pose;
  }

  void _overrideWithBlend(PuppetController c,
      {required Pose2D from,
      required Pose2D to,
      required double w,
      required double sceneSec}) {
    final cl = w.clamp(0.0, 1.0);
    final blended = Pose2D.lerp(from, to, cl);
    final f = c.frame;
    c.frameOverride = PuppetFrameData(
      pose: blended,
      solve: solveSkeleton(c.animator.rig, blended.angles),
      face: f.face,
      blink: f.blink,
      lookX: f.lookX,
      lookY: f.lookY,
      time: sceneSec,
      sleeping: f.sleeping,
      talking: f.talking,
    );
  }

  /// Forces [animId] as the animator's base clip deterministically (no fade,
  /// no state-machine queue): state actions map to their canonical loop clip.
  void _forceClip(PuppetController c, String animId) {
    if (c.actionId != animId) c.setAction(animId);
    final base = _baseClipFor(animId);
    if (c.animator.clipId != base) c.animator.play(base, fade: 0);
  }

  static String _baseClipFor(String actionId) => switch (actionId) {
        'sit' => 'sit_idle',
        'sleep' => 'sleep_loop',
        'talk' => 'idle', // talk body = idle + deterministic talk overlay
        _ => actionId,
      };

  // ---- PHASE 3: timeline editing (all undoable, spec §18) ----------------------
  final List<_TimelineSnapshot> _undoStack = [];
  final List<_TimelineSnapshot> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Push one undo checkpoint (call BEFORE mutating; drag flows push once at
  /// drag start, then mutate directly).
  void beginTimelineEdit() {
    _undoStack.add(_TimelineSnapshot.capture(this));
    if (_undoStack.length > 80) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undoTimelineEdit() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_TimelineSnapshot.capture(this));
    _undoStack.removeLast().restore(this);
    refreshRuntime();
    notifyListeners();
  }

  void redoTimelineEdit() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_TimelineSnapshot.capture(this));
    _redoStack.removeLast().restore(this);
    refreshRuntime();
    notifyListeners();
  }

  /// Safe duration change: clamps playhead + any out-of-range clip ends stay
  /// (they simply extend past the visible timeline).
  void setDurationMs(int ms) {
    beginTimelineEdit();
    timeline.durationMs = ms.clamp(1000, 600000);
    clock.durationMs = timeline.durationMs;
    clock.seek(clock.currentTimeMs);
    refreshRuntime();
    notifyListeners();
  }

  AnimClip addAnimClip(String objectId, String animId,
      {required int startMs, required int endMs, bool loop = true}) {
    beginTimelineEdit();
    final track = timeline.ensureTrack(objectId);
    final clip = AnimClip(
        id: newTimelineId('clip_'),
        animId: animId,
        startMs: startMs.clamp(0, timeline.durationMs),
        endMs: endMs.clamp(0, timeline.durationMs));
    track.clips.add(clip);
    track.sortAll();
    refreshRuntime();
    notifyListeners();
    return clip;
  }

  void deleteAnimClip(String objectId, String clipId) {
    final track = timeline.trackOf(objectId);
    if (track == null) return;
    beginTimelineEdit();
    track.clips.removeWhere((c) => c.id == clipId);
    if (track.clips.isEmpty &&
        track.keyframes.isEmpty &&
        track.visClips.isEmpty) {
      timeline.tracks.remove(objectId);
    }
    refreshRuntime();
    notifyListeners();
  }

  /// Duplicates [clipId] and places the copy right after the original
  /// (clamped to the scene end).
  AnimClip? duplicateAnimClip(String objectId, String clipId) {
    final track = timeline.trackOf(objectId);
    final src = track?.clips.where((c) => c.id == clipId).firstOrNull;
    if (track == null || src == null) return null;
    beginTimelineEdit();
    final len = src.durationMs;
    final start = src.endMs >= timeline.durationMs
        ? math.max(0, timeline.durationMs - len)
        : src.endMs;
    final copy = AnimClip(
        id: newTimelineId('clip_'),
        animId: src.animId,
        startMs: start,
        endMs: math.min(timeline.durationMs, start + len),
        speed: src.speed,
        loop: src.loop,
        blendInMs: src.blendInMs,
        blendOutMs: src.blendOutMs);
    track.clips.add(copy);
    track.sortAll();
    refreshRuntime();
    notifyListeners();
    return copy;
  }

  /// Upserts a transform keyframe at [atMs] (default: the playhead). With no
  /// explicit [props] the object's CURRENT evaluated transform is captured.
  TransformKeyframe upsertKeyframe(String objectId,
      {int? atMs, Map<String, double>? props}) {
    beginTimelineEdit();
    final track = timeline.ensureTrack(objectId);
    final t = (atMs ?? clock.currentTimeMs).clamp(0, timeline.durationMs);
    final obj = objects.where((o) => o.id == objectId).firstOrNull;
    // Capture the object's CURRENT static transform (post-edit values when
    // called from AUTO KEY, base values for the manual add button).
    final v = obj?.transform;
    final values = props ??
        (v == null
            ? <String, double>{}
            : {
                'x': v.x,
                'y': v.y,
                'scaleX': v.scaleX,
                'scaleY': v.scaleY,
                'rotation': v.rotation,
                'opacity': v.opacity,
              });
    var kf = track.keyframes.firstWhereOrNull((k) => k.timeMs == t);
    if (kf == null) {
      kf = TransformKeyframe(id: newTimelineId('kf_'), timeMs: t, props: values);
      track.keyframes.add(kf);
    } else {
      kf.props
        ..clear()
        ..addAll(values);
    }
    track.sortAll();
    refreshRuntime();
    notifyListeners();
    return kf;
  }

  void deleteKeyframe(String objectId, String kfId) {
    final track = timeline.trackOf(objectId);
    if (track == null) return;
    beginTimelineEdit();
    track.keyframes.removeWhere((k) => k.id == kfId);
    if (track.clips.isEmpty &&
        track.keyframes.isEmpty &&
        track.visClips.isEmpty) {
      timeline.tracks.remove(objectId);
    }
    refreshRuntime();
    notifyListeners();
  }

  void setVisibilityClips(String objectId, List<VisibilityClip> clips) {
    beginTimelineEdit();
    final track = timeline.ensureTrack(objectId);
    track.visClips
      ..clear()
      ..addAll(clips);
    track.sortAll();
    refreshRuntime();
    notifyListeners();
  }

  /// Drops the whole track (clips + keyframes + visibility ranges).
  void clearTrack(String objectId) {
    if (!timeline.tracks.containsKey(objectId)) return;
    beginTimelineEdit();
    timeline.tracks.remove(objectId);
    refreshRuntime();
    notifyListeners();
  }

  /// AUTO KEY hook (spec §12/§13): after a user transform edit (drag, scale,
  /// rotate, panel slider):
  ///  * AUTO KEY on → upsert a keyframe at the playhead with the new values.
  ///  * AUTO KEY off → if a keyframe exists exactly at the playhead, update
  ///    its stored properties (so editing AT a keyframe changes the keyframe).
  void onUserTransformEdit(String objectId) {
    final track = timeline.trackOf(objectId);
    final t = clock.currentTimeMs;
    if (autoKey) {
      upsertKeyframe(objectId, atMs: t);
      return;
    }
    if (track == null) return;
    final kf = track.keyframes.firstWhereOrNull((k) => k.timeMs == t);
    if (kf == null) return;
    final obj = objects.where((o) => o.id == objectId).firstOrNull;
    if (obj == null) return;
    final v = obj.transform;
    kf.props
      ..clear()
      ..addAll({
        'x': v.x, 'y': v.y, 'scaleX': v.scaleX,
        'scaleY': v.scaleY, 'rotation': v.rotation, 'opacity': v.opacity,
      });
    refreshRuntime();
    notifyListeners();
  }

  /// Prunes tracks for deleted objects (kept unless empty).
  void _pruneTimeline() {
    timeline
        .pruneTo(objects.map((o) => o.id).toSet());
    _runtimeTransforms.removeWhere((k, _) => !timeline.tracks.containsKey(k));
    refreshRuntime();
  }


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
    onUserTransformEdit(id); // AUTO KEY / keyframe-at-playhead update
    refreshRuntime(); // re-evaluate so runtime overrides stay in sync
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
    timeline.tracks.remove(id);
    _runtimeTransforms.remove(id);
    _runtimeHidden.remove(id);
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
    timeline = StoryTimeline.empty();
    clock.pause();
    clock.durationMs = timeline.durationMs;
    clock.seek(0);
    _runtimeTransforms.clear();
    _runtimeHidden.clear();
    _undoStack.clear();
    _redoStack.clear();
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
    clock.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
}


/// Undo checkpoint: full timeline + every object's transform.
class _TimelineSnapshot {
  _TimelineSnapshot.capture(EditorProvider ed)
      : timelineJson = ed.timeline.toJson(),
        transforms = {
          for (final o in ed.objects) o.id: o.transform.toJson(),
        },
        playheadMs = ed.clock.currentTimeMs;

  final Map<String, dynamic> timelineJson;
  final Map<String, Map<String, dynamic>> transforms;
  final int playheadMs;

  void restore(EditorProvider ed) {
    ed.timeline = StoryTimeline.fromJson(timelineJson);
    ed.clock.durationMs = ed.timeline.durationMs;
    ed.clock.seek(playheadMs.clamp(0, ed.timeline.durationMs));
    for (final o in ed.objects) {
      final j = transforms[o.id];
      if (j != null) o.transform = ObjectTransform.fromJson(j);
    }
  }
}
