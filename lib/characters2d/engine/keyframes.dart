import 'dart:math' as math;

import 'pose2d.dart';
import 'rig2d.dart';

/// Interpolation modes supported by the keyframe engine (spec §ANIMATION ENGINE).
enum InterpMode { linear, easeIn, easeOut, easeInOut }

double applyInterp(InterpMode mode, double u) {
  switch (mode) {
    case InterpMode.linear:
      return u;
    case InterpMode.easeIn:
      return u * u;
    case InterpMode.easeOut:
      return 1 - (1 - u) * (1 - u);
    case InterpMode.easeInOut:
      return u < 0.5 ? 2 * u * u : 1 - math.pow(-2 * u + 2, 2) / 2;
  }
}

/// One keyframe: normalized time (0..1) + rotation (+ optional x/y/scale).
class Keyframe {
  const Keyframe({required this.time, required this.rotation, this.dx = 0, this.dy = 0, this.scaleX = 1, this.scaleY = 1});
  final double time;
  final double rotation;
  final double dx;
  final double dy;
  final double scaleX;
  final double scaleY;

  Map<String, dynamic> toJson() => {
        'time': time,
        'rotation': rotation,
        if (dx != 0) 'x': dx,
        if (dy != 0) 'y': dy,
        if (scaleX != 1) 'scaleX': scaleX,
        if (scaleY != 1) 'scaleY': scaleY,
      };

  static Keyframe fromJson(Map<String, dynamic> j) => Keyframe(
        time: (j['time'] as num).toDouble(),
        rotation: (j['rotation'] as num? ?? 0).toDouble(),
        dx: (j['x'] as num? ?? 0).toDouble(),
        dy: (j['y'] as num? ?? 0).toDouble(),
        scaleX: (j['scaleX'] as num? ?? 1).toDouble(),
        scaleY: (j['scaleY'] as num? ?? 1).toDouble(),
      );
}

/// Per-bone keyframe track, e.g. LeftUpperLeg: [{0,-25},{0.25,5}...].
class BoneTrack {
  const BoneTrack({required this.bone, required this.keys, this.interp = InterpMode.easeInOut});
  final String bone;
  final List<Keyframe> keys;
  final InterpMode interp;

  Keyframe sample(double t) {
    if (keys.isEmpty) return const Keyframe(time: 0, rotation: 0);
    if (t <= keys.first.time) return keys.first;
    if (t >= keys.last.time) return keys.last;
    for (var i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      if (t >= a.time && t <= b.time) {
        final u = (t - a.time) / (b.time - a.time);
        final e = applyInterp(interp, u);
        return Keyframe(
          time: t,
          rotation: a.rotation + (b.rotation - a.rotation) * e,
          dx: a.dx + (b.dx - a.dx) * e,
          dy: a.dy + (b.dy - a.dy) * e,
          scaleX: a.scaleX + (b.scaleX - a.scaleX) * e,
          scaleY: a.scaleY + (b.scaleY - a.scaleY) * e,
        );
      }
    }
    return keys.last;
  }

  Map<String, dynamic> toJson() => {
        'bone': bone,
        'interp': interp.name,
        'keyframes': [for (final k in keys) k.toJson()],
      };

  static BoneTrack fromJson(Map<String, dynamic> j) => BoneTrack(
        bone: j['bone'] as String,
        interp: InterpMode.values.firstWhere(
          (m) => m.name == (j['interp'] as String?),
          orElse: () => InterpMode.easeInOut,
        ),
        keys: [for (final k in (j['keyframes'] as List)) Keyframe.fromJson(Map<String, dynamic>.from(k as Map))],
      );
}

/// A full keyframed animation clip in the portable character.json format.
class KeyframeClip {
  const KeyframeClip({
    required this.id,
    required this.name,
    required this.duration,
    required this.loop,
    required this.tracks,
  });

  final String id;
  final String name;
  final double duration;
  final bool loop;
  final List<BoneTrack> tracks;

  /// Samples the clip at local time [t] into a pose (deltas from rest).
  Pose2D sample(double t) {
    final clamped = loop ? t % duration : t.clamp(0.0, duration);
    final u = duration <= 0 ? 0.0 : clamped / duration;
    final pose = Pose2D();
    for (final track in tracks) {
      final k = track.sample(u);
      pose.angles[track.bone] = k.rotation;
      // Root motion channels.
      if (track.bone == 'root') {
        pose.dx += k.dx;
        pose.dy += k.dy;
        pose.extras['scaleX'] = k.scaleX - 1;
        pose.extras['scaleY'] = k.scaleY - 1;
      }
    }
    return pose;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'duration': duration,
        'loop': loop,
        'tracks': [for (final t in tracks) t.toJson()],
      };

  static KeyframeClip fromJson(Map<String, dynamic> j) => KeyframeClip(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'],
        duration: (j['duration'] as num? ?? 1).toDouble(),
        loop: j['loop'] as bool? ?? true,
        tracks: [for (final t in (j['tracks'] as List? ?? [])) BoneTrack.fromJson(Map<String, dynamic>.from(t as Map))],
      );
}

/// Bakes a procedural clip into dense keyframes so it becomes portable JSON.
KeyframeClip bakeClip(String id, String name, double duration, bool loop, Rig2D rig,
    Pose2D Function(double t) fn, int fps) {
  final bones = <String>{};
  final samples = <Pose2D>[];
  final frames = math.max(2, (duration * fps).round() + 1);
  for (var i = 0; i < frames; i++) {
    final p = fn(i / fps);
    samples.add(p);
    bones.addAll(p.angles.keys);
  }
  final tracks = <BoneTrack>[];
  for (final b in bones) {
    final keys = <Keyframe>[];
    for (var i = 0; i < frames; i++) {
      keys.add(Keyframe(time: i / (frames - 1), rotation: samples[i].angle(b)));
    }
    tracks.add(BoneTrack(bone: b, keys: keys, interp: InterpMode.linear));
  }
  return KeyframeClip(id: id, name: name, duration: duration, loop: loop, tracks: tracks);
}
