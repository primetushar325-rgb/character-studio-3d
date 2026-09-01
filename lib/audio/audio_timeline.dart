import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_clip.dart';

/// Plays one audio clip on demand (platform player or a test fake).
abstract class ClipPlayer {
  Future<void> setFile(String absPath);
  Future<void> setLoop(bool loop);
  Future<void> playFrom(int ms, double volume);
  Future<void> setVolume(double v);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<Duration?> probeDuration(String absPath);
  bool get isPlaying;
  void dispose();
}

/// Real platform playback: audioplayers streams the file natively — the whole
/// file is never decoded into Dart memory (spec §22).
class PlatformClipPlayer implements ClipPlayer {
  PlatformClipPlayer() : _p = AudioPlayer(playerId: 'cs${_seq++}');
  static int _seq = 0;

  final AudioPlayer _p;
  String? _src;
  bool _looped = false;

  @override
  Future<void> setFile(String absPath) async {
    if (_src == absPath) return;
    await _p.setReleaseMode(_looped ? ReleaseMode.loop : ReleaseMode.stop);
    await _p.setSourceDeviceFile(absPath);
    _src = absPath;
  }

  @override
  Future<void> setLoop(bool loop) async {
    _looped = loop;
    await _p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
  }

  @override
  Future<void> playFrom(int ms, double volume) async {
    await _p.seek(Duration(milliseconds: ms));
    await _p.setVolume(volume.clamp(0, 1));
    await _p.resume();
  }

  @override
  Future<void> setVolume(double v) => _p.setVolume(v.clamp(0, 1));

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> resume() => _p.resume();

  @override
  Future<void> stop() => _p.stop();

  @override
  Future<Duration?> probeDuration(String absPath) async {
    await _p.setSourceDeviceFile(absPath);
    return _p.getDuration();
  }

  @override
  bool get isPlaying => _p.state == PlayerState.playing;

  @override
  void dispose() => _p.dispose();
}

/// PHASE 4 — audio preview mixer (spec §10/§11/§12/§17).
///
/// There is NO separate audio clock: the Phase-3 PlaybackClock calls
/// [AudioTimeline.sync] with the current scene time on every tick/seek, and
/// this class positions/starts/stops per-clip players accordingly.
class AudioTimeline {
  AudioTimeline({ClipPlayer Function()? playerFactory})
      : _playerFactory = playerFactory ?? (() => PlatformClipPlayer());

  final ClipPlayer Function() _playerFactory;
  final List<AudioClip> clips = [];
  final Map<String, ClipPlayer> _players = {};
  final Map<String, int> _lastPos = {}; // clipId → ms we last asked for
  final Map<String, bool> _playing = {};

  /// Resolves project-relative → absolute; null when unknown.
  String Function(String rel)? resolvePath;

  /// Marks clips whose file vanished (spec §16) — checked on project open and
  /// before playback. Never throws.
  void refreshMissing() {
    for (final c in clips) {
      final abs = _abs(c);
      c.missing = abs == null || !File(abs).existsSync();
    }
  }

  String? _abs(AudioClip c) =>
      resolvePath == null ? c.filePath : resolvePath!(c.filePath);

  /// THE sync entry: bring every player to the state demanded by timeline
  /// time [tMs] and [isPlaying]. Called on play ticks, pause, seek and stop.
  Future<void> sync(int tMs, bool isPlaying) async {
    for (final c in clips) {
      final player = _players[c.id];
      final wantPlay = isPlaying && c.audibleAt(tMs);
      final pos = c.positionAt(tMs);

      if (!wantPlay) {
        if (player != null && (_playing[c.id] ?? false)) {
          await player.pause();
          _playing[c.id] = false;
        }
        continue;
      }

      // Start/reposition this clip's player.
      final p = player ?? _create(c);
      _players[c.id] = p;
      final abs = _abs(c);
      if (abs == null) continue;
      try {
        await p.setLoop(c.loop); // native gapless loop (spec §21)
        await p.setFile(abs);
        // Re-seek when starting or when the clock jumped (user seek).
        // Drift is measured in CLIP-LOCAL time so a loop wrap (native,
        // gapless) never triggers a redundant re-seek.
        final rel = tMs - c.startMs;
        final lastRel = _lastPos[c.id] ?? -1;
        final wasPlaying = _playing[c.id] ?? false;
        if (!wasPlaying || (rel - lastRel).abs() > 250) {
          await p.playFrom(pos, c.gainAt(tMs));
        } else {
          await p.setVolume(c.gainAt(tMs));
        }
        _lastPos[c.id] = rel;
        _playing[c.id] = true;
      } catch (e) {
        // Missing codec / IO error → mark and keep going (spec §3: no crash).
        debugPrint('audio sync failed for ${c.name}: $e');
        c.missing = true;
        _playing[c.id] = false;
      }
    }
    // Stop players for removed clips.
    final live = clips.map((c) => c.id).toSet();
    final dead = _players.keys.where((k) => !live.contains(k)).toList();
    for (final d in dead) {
      await _players[d]?.stop();
      _players[d]?.dispose();
      _players.remove(d);
      _playing.remove(d);
      _lastPos.remove(d);
    }
  }

  ClipPlayer _create(AudioClip c) => _players[c.id] = _playerFactory();

  Future<void> pauseAll() async {
    for (final p in _players.values) {
      await p.pause();
    }
    _playing.updateAll((_, __) => false);
  }

  Future<void> stopAll() async {
    for (final p in _players.values) {
      await p.stop();
    }
    _playing.updateAll((_, __) => false);
    _lastPos.clear();
  }

  void clear() {
    for (final p in _players.values) {
      p.dispose();
    }
    _players.clear();
    _playing.clear();
    _lastPos.clear();
    clips.clear();
  }

  /// Probes a source file's duration (used at import for trim clamps).
  Future<int> probeDurationMs(String absPath) async {
    final p = _playerFactory();
    try {
      final d = await p.probeDuration(absPath);
      return d?.inMilliseconds ?? 0;
    } catch (_) {
      return 0;
    } finally {
      p.dispose();
    }
  }
}
