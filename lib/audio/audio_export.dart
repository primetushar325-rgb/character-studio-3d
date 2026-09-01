import 'dart:io';

import 'audio_clip.dart';

/// PHASE 4 — deterministic export audio mix (spec §18/§19).
///
/// Builds the ffmpeg arguments that turn the project's [AudioClip]s into one
/// mixed track, muxed with the rendered PNG frames into the final MP4.
/// Everything (positions, trims, volumes, mutes, fades, project duration) is
/// computed from project data only — never from live playback timing.
///
/// Pure function → unit-testable without ffmpeg.

class AudioMixPlan {
  AudioMixPlan({required this.clips, required this.totalMs});
  final List<AudioClip> clips; // playable clips (exists, not muted)
  final int totalMs; // project duration bound (spec §20)

  bool get hasAudio => clips.isNotEmpty;
}

/// Filters to playable clips (file present, not muted) clipped to project
/// duration. Deterministic: sorts by startMs for stable input order.
AudioMixPlan planAudioMix(
    List<AudioClip> allClips, int projectDurationMs, String projectDir,
    {bool Function(String absPath)? fileExists}) {
  final exists = fileExists ?? (p) => File(p).existsSync();
  final playable = <AudioClip>[];
  for (final c in allClips) {
    if (c.muted || c.missing) continue;
    if (c.startMs >= projectDurationMs) continue;
    final abs = '$projectDir/${c.filePath}';
    if (!exists(abs)) continue;
    playable.add(c);
  }
  playable.sort((a, b) => a.startMs.compareTo(b.startMs));
  return AudioMixPlan(clips: playable, totalMs: projectDurationMs);
}

/// Full ffmpeg args: frames + per-clip audio inputs → per-clip filters →
/// amix → H.264 + AAC MP4.
List<String> buildExportArgs({
  required String framesPattern, // e.g. /tmp/frames/frame_%04d.png
  required int fps,
  required AudioMixPlan plan,
  required String outPath,
  required String videoBitrate, // e.g. '6M'
  required String projectDir,
}) {
  final totalSec = (plan.totalMs / 1000.0).toStringAsFixed(3);

  final args = <String>[
    '-y',
    '-framerate', '$fps',
    '-i', framesPattern,
  ];

  // One audio input per clip: input-side seek/limit = streaming trim, never
  // a full-file decode (spec §22). Loop short sources with -stream_loop.
  for (final c in plan.clips) {
    final srcLen = c.sourceDurationMs - c.sourceStartMs;
    if (c.loop && srcLen > 0 && c.durationMs > srcLen) {
      args.addAll(['-stream_loop', '-1']);
    }
    args.addAll([
      '-ss', _sec(c.sourceStartMs),
      '-t', _sec(c.durationMs),
      '-i', '$projectDir/${c.filePath}',
    ]);
  }

  final n = plan.clips.length;
  if (n == 0) {
    // No audio: exactly the previous video-only pipeline (spec §24).
    args.addAll([
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-b:v', videoBitrate,
      '-t', totalSec, outPath,
    ]);
    return args;
  }

  // Per-clip chain: volume → fade in → fade out → adelay(startMs).
  final chains = <String>[];
  for (var i = 0; i < n; i++) {
    final c = plan.clips[i];
    final parts = <String>[
      'volume=${c.volume.clamp(0.0, 1.5).toStringAsFixed(3)}'
    ];
    if (c.fadeInMs > 0) {
      parts.add('afade=t=in:st=0:d=${_sec(c.fadeInMs)}');
    }
    if (c.fadeOutMs > 0) {
      final st = (c.durationMs - c.fadeOutMs) / 1000.0;
      if (st > 0) {
        parts.add(
            'afade=t=out:st=${st.toStringAsFixed(3)}:d=${_sec(c.fadeOutMs)}');
      }
    }
    parts.add('adelay=delays=${c.startMs.clamp(0, plan.totalMs)}ms:all=1');
    chains.add('[${i + 1}:a]${parts.join(',')}[a$i]');
  }

  // amix keeps all clips at their own loudness (normalize=0 → no ducking).
  var filter = chains.join(';');
  var audioMap = '[a0]';
  if (n > 1) {
    final inputs = [for (var i = 0; i < n; i++) '[a$i]'].join();
    filter += ';$inputs amix=inputs=$n:normalize=0[mix]';
    audioMap = '[mix]';
  }

  args.addAll([
    '-filter_complex', filter,
    '-map', '0:v',
    '-map', audioMap,
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-b:v', videoBitrate,
    '-c:a', 'aac', '-b:a', '192k',
    '-t', totalSec,
    outPath,
  ]);
  return args;
}

String _sec(int ms) => (ms / 1000.0).toStringAsFixed(3);
