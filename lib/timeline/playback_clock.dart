import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// PHASE 3 — THE one scene clock.
///
/// The entire composition (characters, objects, camera-less canvas) follows
/// this single time base. No widget or controller may keep its own wall
/// clock. Preview playback and export both advance/seek through this class.
class PlaybackClock extends ChangeNotifier {
  PlaybackClock({this.durationMs = 20000});

  int durationMs; // scene length; playhead never moves past this
  bool loop = false;

  double _speed = 1.0; // 0.25 – 2
  int _t = 0;
  bool _playing = false;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  /// Playback speeds supported by the UI (spec §3/§16).
  static const List<double> supportedSpeeds = [0.25, 0.5, 1.0, 1.5, 2.0];

  int get currentTimeMs => _t;
  bool get isPlaying => _playing;
  double get speed => _speed;

  void setSpeed(double v) {
    _speed = v.clamp(0.25, 2.0);
    notifyListeners();
  }

  /// Starts (or resumes) playback from the current playhead.
  void play() {
    if (_playing) return;
    if (_t >= durationMs) _t = 0; // replay from the top
    _playing = true;
    _last = Duration.zero;
    _ticker = Ticker(_tick)..start();
    notifyListeners();
  }

  void pause() {
    if (!_playing) return;
    _playing = false;
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    notifyListeners();
  }

  /// Pause + rewind.
  void stop() {
    pause();
    seek(0);
  }

  void seek(int ms) {
    _t = ms.clamp(0, durationMs);
    notifyListeners();
  }

  /// One frame nudge (30 fps grid).
  void stepForward() => seek(_t + 33);
  void stepBackward() => seek(_t - 33);

  void _tick(Duration elapsed) {
    final dtMs = (elapsed - _last).inMicroseconds / 1000.0;
    _last = elapsed;
    _t = (_t + dtMs * _speed).round();
    if (_t >= durationMs) {
      if (loop) {
        _t %= durationMs;
      } else {
        _t = durationMs;
        pause();
        notifyListeners();
        return;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}
