import 'dart:math' as math;

import '../scene/scene_object.dart';

/// PHASE 3 — real story timeline: data model + deterministic evaluator math.
///
/// Everything here is PURE (no Flutter imports): the editor preview, the
/// playback clock and the exporter all evaluate through these functions, so
/// preview and export can never drift apart.

// ---------------------------------------------------------------------------
// Easing
// ---------------------------------------------------------------------------

/// Easing modes attached to the *destination* keyframe of a segment
/// ("how you arrive at this keyframe").
enum KfEase { linear, easeIn, easeOut, easeInOut }

extension KfEaseX on KfEase {
  double apply(double t) {
    switch (this) {
      case KfEase.linear:
        return t;
      case KfEase.easeIn:
        return t * t;
      case KfEase.easeOut:
        return 1 - (1 - t) * (1 - t);
      case KfEase.easeInOut:
        return t < .5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
    }
  }

  String get label => switch (this) {
        KfEase.linear => 'Linear',
        KfEase.easeIn => 'Ease In',
        KfEase.easeOut => 'Ease Out',
        KfEase.easeInOut => 'Ease In-Out',
      };

  static KfEase fromLabel(String s) => KfEase.values.firstWhere(
      (e) => e.label.toLowerCase() == s.trim().toLowerCase(),
      orElse: () => KfEase.linear);

  String get json => name;
  static KfEase fromJson(String? s) =>
      KfEase.values.firstWhere((e) => e.name == s, orElse: () => KfEase.linear);
}

// ---------------------------------------------------------------------------
// Clips
// ---------------------------------------------------------------------------

/// An animation clip on a character track: plays [animId] from [startMs] to
/// [endMs] (scene time), at [speed], optionally [loop]ing the source clip.
class AnimClip {
  AnimClip({
    required this.id,
    required this.animId,
    required this.startMs,
    required this.endMs,
    this.speed = 1.0,
    this.loop = true,
    this.blendInMs = 250,
    this.blendOutMs = 250,
  })  : assert(speed > 0, 'clip speed must be > 0'),
        assert(endMs > startMs, 'clip end must be after start');

  final String id;
  String animId;
  int startMs;
  int endMs;
  double speed; // 0.25 – 3
  bool loop;
  int blendInMs;
  int blendOutMs;

  int get durationMs => endMs - startMs;

  bool activeAt(int tMs) => startMs <= tMs && tMs < endMs;

  /// Local (animation-source) time for scene time [tMs] given the source clip
  /// length [sourceDurMs]. Looping wraps; one-shots clamp (hold first/last
  /// frame) — never negative, never past the source duration.
  int localMs(int tMs, int sourceDurMs) {
    final raw = ((tMs - startMs) * speed).round();
    if (sourceDurMs <= 0) return 0;
    if (!loop) return raw.clamp(0, sourceDurMs);
    return raw % sourceDurMs;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'animId': animId,
        'startMs': startMs,
        'endMs': endMs,
        'speed': speed,
        'loop': loop,
        'blendInMs': blendInMs,
        'blendOutMs': blendOutMs,
      };

  static AnimClip fromJson(Map<String, dynamic> j) => AnimClip(
        id: j['id'] as String? ?? 'clip',
        animId: j['animId'] as String? ?? 'idle',
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        endMs: (j['endMs'] as num?)?.toInt() ?? 1000,
        speed: (j['speed'] as num?)?.toDouble() ?? 1.0,
        loop: j['loop'] as bool? ?? true,
        blendInMs: (j['blendInMs'] as num?)?.toInt() ?? 250,
        blendOutMs: (j['blendOutMs'] as num?)?.toInt() ?? 250,
      ).._clampSpeed();

  void _clampSpeed() => speed = speed.clamp(0.25, 3.0);
}

/// A visibility range: the object renders only while at least one visibility
/// clip is active (empty list = visible for the whole scene).
class VisibilityClip {
  VisibilityClip({required this.startMs, required this.endMs})
      : assert(endMs > startMs, 'visibility end must be after start');

  int startMs;
  int endMs;

  int get durationMs => endMs - startMs;

  bool activeAt(int tMs) => startMs <= tMs && tMs < endMs;

  Map<String, dynamic> toJson() => {'startMs': startMs, 'endMs': endMs};

  static VisibilityClip fromJson(Map<String, dynamic> j) => VisibilityClip(
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        endMs: (j['endMs'] as num?)?.toInt() ?? 1000,
      );
}

// ---------------------------------------------------------------------------
// Keyframes
// ---------------------------------------------------------------------------

/// Animatable object properties (canvas-relative space, same units as
/// SceneTransform).
const kTransformProps = ['x', 'y', 'scaleX', 'scaleY', 'rotation', 'opacity'];

/// One transform keyframe. Stores ONLY the properties intentionally changed
/// (missing properties fall through to the base object transform).
class TransformKeyframe {
  TransformKeyframe({
    required this.id,
    required this.timeMs,
    Map<String, double>? props,
    this.ease = KfEase.linear,
  }) : props = {...?props} {
    this.props.removeWhere((k, v) => !kTransformProps.contains(k));
  }

  final String id;
  int timeMs;
  final Map<String, double> props; // subset of kTransformProps
  KfEase ease; // ease of the segment ARRIVING at this keyframe

  Map<String, dynamic> toJson() => {
        'id': id,
        'timeMs': timeMs,
        'props': props,
        'ease': ease.json,
      };

  static TransformKeyframe fromJson(Map<String, dynamic> j) => TransformKeyframe(
        id: j['id'] as String? ?? 'kf',
        timeMs: (j['timeMs'] as num?)?.toInt() ?? 0,
        props: (j['props'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        ease: KfEaseX.fromJson(j['ease'] as String?),
      );
}

// ---------------------------------------------------------------------------
// Track + timeline
// ---------------------------------------------------------------------------

class TimelineTrack {
  TimelineTrack({
    required this.objectId,
    List<AnimClip>? clips,
    List<VisibilityClip>? visClips,
    List<TransformKeyframe>? keyframes,
  })  : clips = [...?clips]..sort((a, b) => a.startMs.compareTo(b.startMs)),
        visClips = [...?visClips]..sort((a, b) => a.startMs.compareTo(b.startMs)),
        keyframes = [...?keyframes]..sort((a, b) => a.timeMs.compareTo(b.timeMs));

  final String objectId; // SceneObject.id, or kBackgroundTrackId
  final List<AnimClip> clips;
  final List<VisibilityClip> visClips;
  final List<TransformKeyframe> keyframes;

  void sortAll() {
    clips.sort((a, b) => a.startMs.compareTo(b.startMs));
    visClips.sort((a, b) => a.startMs.compareTo(b.startMs));
    keyframes.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  }

  /// Animation clip active at scene time [tMs] (latest-starting wins on
  /// overlap), or null.
  AnimClip? animAt(int tMs) {
    AnimClip? found;
    for (final c in clips) {
      if (c.activeAt(tMs) && (found == null || c.startMs >= found.startMs)) {
        found = c;
      }
    }
    return found;
  }

  /// Clip that ended most recently before/around [tMs] (for blend-out), or
  /// the clip that starts soonest after [tMs] when blending into a future
  /// clip. Returns null when there is nothing to blend with.
  AnimClip? neighborOf(AnimClip clip, {required bool after}) {
    final others = clips.where((c) => c.id != clip.id).toList();
    if (after) {
      others.sort((a, b) => a.startMs.compareTo(b.startMs));
      return others.where((c) => c.startMs >= clip.endMs).isEmpty
          ? null
          : others.where((c) => c.startMs >= clip.endMs).first;
    }
    others.sort((a, b) => b.endMs.compareTo(a.endMs));
    return others.where((c) => c.endMs <= clip.startMs).isEmpty
        ? null
        : others.where((c) => c.endMs <= clip.startMs).first;
  }

  /// Static visibility (no track) OR visibility-clip evaluation.
  bool visibleAt(int tMs, {required bool baseVisible}) {
    if (!baseVisible) return false;
    if (visClips.isEmpty) return true;
    return visClips.any((v) => v.activeAt(tMs));
  }

  Map<String, dynamic> toJson() => {
        'objectId': objectId,
        'clips': clips.map((c) => c.toJson()).toList(),
        'visClips': visClips.map((c) => c.toJson()).toList(),
        'keyframes': keyframes.map((k) => k.toJson()).toList(),
      };

  static TimelineTrack fromJson(Map<String, dynamic> j) => TimelineTrack(
        objectId: j['objectId'] as String? ?? '',
        clips: (j['clips'] as List?)
            ?.map((e) => AnimClip.fromJson(e as Map<String, dynamic>))
            .toList(),
        visClips: (j['visClips'] as List?)
            ?.map((e) => VisibilityClip.fromJson(e as Map<String, dynamic>))
            .toList(),
        keyframes: (j['keyframes'] as List?)
            ?.map((e) => TransformKeyframe.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Pseudo track id for the project background (not a SceneObject).
const kBackgroundTrackId = '__background__';

class StoryTimeline {
  StoryTimeline({this.durationMs = 20000, Map<String, TimelineTrack>? tracks})
      : tracks = tracks ?? {};

  int durationMs; // default 20s; presets 10/15/20/30/60s
  final Map<String, TimelineTrack> tracks; // by objectId

  static StoryTimeline empty() => StoryTimeline();

  TimelineTrack? trackOf(String objectId) => tracks[objectId];

  /// Get-or-create the track for [objectId].
  TimelineTrack ensureTrack(String objectId) =>
      tracks[objectId] ??= TimelineTrack(objectId: objectId);

  /// Remove tracks whose object no longer exists (except the background).
  void pruneTo(Set<String> liveObjectIds) => tracks.removeWhere(
      (id, _) => id != kBackgroundTrackId && !liveObjectIds.contains(id));

  Map<String, dynamic> toJson() => {
        'durationMs': durationMs,
        'tracks': tracks.map((k, v) => MapEntry(k, v.toJson())),
      };

  static StoryTimeline fromJson(Map<String, dynamic>? j) {
    if (j == null) return StoryTimeline.empty();
    final t = StoryTimeline(
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 20000);
    final raw = j['tracks'] as Map<String, dynamic>? ?? {};
    for (final e in raw.entries) {
      if (e.value is Map<String, dynamic>) {
        final tr = TimelineTrack.fromJson(e.value as Map<String, dynamic>);
        t.tracks[tr.objectId.isNotEmpty ? tr.objectId : e.key] = tr;
      }
    }
    return t;
  }

  StoryTimeline clone() => StoryTimeline.fromJson(toJson());
}

// ---------------------------------------------------------------------------
// Evaluator (pure math half; character-pose half lives in EditorProvider,
// which owns the live controllers)
// ---------------------------------------------------------------------------

/// Result of evaluating one object's transform at a scene time.
class EvaluatedTransform {
  const EvaluatedTransform({
    required this.x,
    required this.y,
    required this.scaleX,
    required this.scaleY,
    required this.rotation,
    required this.opacity,
  });

  final double x;
  final double y;
  final double scaleX;
  final double scaleY;
  final double rotation;
  final double opacity;

  static EvaluatedTransform of(ObjectTransform t) => EvaluatedTransform(
        x: t.x,
        y: t.y,
        scaleX: t.scaleX,
        scaleY: t.scaleY,
        rotation: t.rotation,
        opacity: t.opacity,
      );
}

/// Interpolated property value at [tMs].
///
/// * No keyframe holds the property → base value.
/// * Exactly one → that constant value (holds).
/// * t before first / after last → first / last value.
/// * Otherwise → eased lerp between the bracketing keyframes using the
///   destination keyframe's ease.
double evalProp(
    TimelineTrack? track, String prop, int tMs, double baseValue) {
  if (track == null) return baseValue;
  final kfs = track.keyframes.where((k) => k.props.containsKey(prop)).toList()
    ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
  if (kfs.isEmpty) return baseValue;
  if (kfs.length == 1) return kfs.first.props[prop]!;
  if (tMs <= kfs.first.timeMs) return kfs.first.props[prop]!;
  if (tMs >= kfs.last.timeMs) return kfs.last.props[prop]!;
  TransformKeyframe a = kfs.first, b = kfs.last;
  for (var i = 0; i < kfs.length - 1; i++) {
    if (tMs >= kfs[i].timeMs && tMs <= kfs[i + 1].timeMs) {
      a = kfs[i];
      b = kfs[i + 1];
      break;
    }
  }
  final span = (b.timeMs - a.timeMs).clamp(1, 1 << 30);
  final u = (tMs - a.timeMs) / span;
  final e = b.ease.apply(u.clamp(0.0, 1.0));
  return a.props[prop]! + (b.props[prop]! - a.props[prop]!) * e;
}

/// Full transform evaluation for an object at scene time [tMs].
EvaluatedTransform evalTransform(
    SceneObject obj, TimelineTrack? track, int tMs) {
  final base = obj.transform;
  if (track == null || track.keyframes.isEmpty) {
    return EvaluatedTransform.of(base);
  }
  return EvaluatedTransform(
    x: evalProp(track, 'x', tMs, base.x),
    y: evalProp(track, 'y', tMs, base.y),
    scaleX: evalProp(track, 'scaleX', tMs, base.scaleX),
    scaleY: evalProp(track, 'scaleY', tMs, base.scaleY),
    rotation: evalProp(track, 'rotation', tMs, base.rotation),
    opacity: evalProp(track, 'opacity', tMs, base.opacity),
  );
}

// ---------------------------------------------------------------------------
// Snapping
// ---------------------------------------------------------------------------

/// Snap [proposedMs] to the nearest snap target within [thresholdMs].
/// Targets: 0, scene end, half-second grid, and every other clip/keyframe
/// edge in the timeline (except [exceptIds]).
int snapMs(
  int proposedMs, {
  required StoryTimeline timeline,
  int thresholdMs = 80,
  Set<String> exceptIds = const {},
}) {
  final t = proposedMs;
  var best = t;
  var bestDist = thresholdMs;
  void consider(int cand) {
    final d = (cand - t).abs();
    if (d < bestDist || (d == bestDist && cand < best)) {
      bestDist = d;
      best = cand;
    }
  }

  consider(0);
  consider(timeline.durationMs);
  // 0.5s grid.
  final grid = 500;
  consider(((t / grid).round()) * grid);
  for (final tr in timeline.tracks.values) {
    for (final c in tr.clips) {
      if (!exceptIds.contains(c.id)) {
        consider(c.startMs);
        consider(c.endMs);
      }
    }
    for (final k in tr.keyframes) {
      if (!exceptIds.contains(k.id)) consider(k.timeMs);
    }
  }
  return best.clamp(0, timeline.durationMs);
}

/// Unique id for timeline entities.
String newTimelineId(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch}';
