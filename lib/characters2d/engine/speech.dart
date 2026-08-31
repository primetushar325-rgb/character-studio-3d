import 'dart:math' as math;

import 'face_rig.dart';

/// One syllable: viseme id + timing + whether it carries an accent.
class Syllable {
  const Syllable(this.viseme, this.start, this.duration, this.accent);
  final String viseme;
  final double start;
  final double duration;
  double get end => start + duration;
  final bool accent;
}

/// Procedural speech synthesizer.
///
/// Generates natural, randomized talking (varied syllable counts, lengths,
/// accents, phrase pauses — never a mechanical open/close loop). Designed so a
/// future voice/lip-sync system can simply push real viseme/timing data
/// through [setVisemeTimeline] and everything downstream keeps working.
class SpeechDriver {
  SpeechDriver({int seed = 7}) : _rng = math.Random(seed);

  final math.Random _rng;

  bool active = false;
  double _t = 0;
  double _wall = 0;
  List<Syllable> _timeline = const [];
  double _phraseEnd = 0;

  /// 0..1 accent pulse — drives brow/head emphasis.
  double accent = 0;

  /// Last viseme the driver wants (already smoothed between syllables).
  FaceParams mouth = MouthShapes.neutral;

  double _lastGestureAt = -99;
  String? _pendingGesture;

  static const _vowels = ['A', 'E', 'I', 'O', 'U'];
  static const _consonants = ['S', 'SH', 'TH', 'FV', 'L', 'MBP'];

  /// Future lip-sync hook: replaces procedural generation with real data.
  void setVisemeTimeline(List<Syllable> timeline) {
    _timeline = timeline;
    _phraseEnd = timeline.isEmpty ? 0 : timeline.last.end + 0.2;
  }

  void start() {
    active = true;
    _t = 0;
    _buildPhrase();
  }

  void stop() {
    active = false;
    mouth = MouthShapes.neutral;
    accent = 0;
    _pendingGesture = null;
  }

  /// Occasionally suggests a co-speech gesture (with cooldown). UI decides.
  String? takeGestureSuggestion() {
    final g = _pendingGesture;
    _pendingGesture = null;
    return g;
  }

  void update(double dt) {
    if (!active) return;
    _wall += dt;
    _t += dt;
    if (_t >= _phraseEnd) _buildPhrase();
    _sample();
  }

  void _buildPhrase() {
    // Phrase: 3–9 syllables with varied durations, MBP start, then a pause.
    final count = 3 + _rng.nextInt(7);
    final syllables = <Syllable>[];
    var t = 0.02;
    for (var i = 0; i < count; i++) {
      final String viseme;
      if (i == 0 && _rng.nextBool()) {
        viseme = 'MBP';
      } else if (_rng.nextDouble() < 0.58) {
        viseme = _vowels[_rng.nextInt(_vowels.length)];
      } else {
        viseme = _consonants[_rng.nextInt(_consonants.length)];
      }
      final dur = 0.09 + _rng.nextDouble() * 0.13;
      final accentHere = _rng.nextDouble() < 0.28 && i > 0;
      syllables.add(Syllable(viseme, t, dur, accentHere));
      t += dur;
      if (_rng.nextDouble() < 0.14) t += 0.05 + _rng.nextDouble() * 0.07; // micro pause
    }
    final pause = 0.35 + _rng.nextDouble() * 0.85;
    _timeline = syllables;
    _phraseEnd = t + pause;
    _t = 0;
    if (_wall - _lastGestureAt > 3.5 && _rng.nextDouble() < 0.35) {
      _lastGestureAt = _wall;
      const pool = ['wave', 'explain', 'open_palm', 'point_right', 'point_left'];
      _pendingGesture = pool[_rng.nextInt(pool.length)];
    }
  }

  void _sample() {
    if (_timeline.isEmpty) {
      mouth = MouthShapes.neutral;
      accent = 0;
      return;
    }
    if (_t >= _timeline.last.end) {
      mouth = MouthShapes.neutral; // between phrases
      accent = 0;
      return;
    }
    Syllable? cur;
    Syllable? next;
    for (var i = 0; i < _timeline.length; i++) {
      final s = _timeline[i];
      if (_t >= s.start && _t < s.end) {
        cur = s;
        next = i + 1 < _timeline.length ? _timeline[i + 1] : null;
        break;
      }
    }
    if (cur == null) {
      mouth = MouthShapes.neutral;
      accent = 0;
      return;
    }
    final a = MouthShapes.all[cur.viseme] ?? MouthShapes.neutral;
    // Co-articulation: blend toward the next viseme near the syllable end.
    final u = (_t - cur.start) / cur.duration;
    FaceParams out = a;
    if (u > 0.65 && next != null) {
      final b = MouthShapes.all[next.viseme] ?? MouthShapes.neutral;
      out = FaceParams.lerp(a, b, (u - 0.65) / 0.35);
    }
    // Tiny jitter so identical visemes never look identical twice.
    final jitter = (_rng.nextDouble() - 0.5).abs() * 0.06;
    mouth = FaceParams.lerp(out, MouthShapes.open, jitter);
    accent = cur.accent ? math.max(0, 1 - (_t - cur.start) / 0.28) : accent * 0.9;
  }
}

/// Automatic blink scheduler: 2–6 s interval, occasional double blink.
class BlinkScheduler {
  BlinkScheduler({int seed = 3}) : _rng = math.Random(seed);

  final math.Random _rng;
  double _nextAt = 2.2;
  double _t = 0;
  double _phase = -1; // <0 = idle, else 0..1 over the blink duration
  bool _secondPending = false;

  /// Extra blinks per minute boost (e.g. while talking).
  double rateBoost = 0;

  /// Current blink amount 0..1.
  double get value {
    if (_phase < 0) return 0;
    final t = _phase;
    // fast close, slower open
    return t < 0.45 ? (t / 0.45) : (1 - (t - 0.45) / 0.55);
  }

  void forceBlink() {
    if (_phase < 0) _phase = 0;
  }

  void update(double dt, {bool suppressed = false}) {
    if (suppressed) {
      _phase = -1;
      return;
    }
    if (_phase >= 0) {
      _phase += dt / 0.22;
      if (_phase >= 1) {
        if (_secondPending) {
          _secondPending = false;
          _phase = 0;
        } else {
          _phase = -1;
          _schedule();
        }
      }
      return;
    }
    _t += dt;
    if (_t >= _nextAt) {
      _t = 0;
      _phase = 0;
      if (_rng.nextDouble() < 0.18) _secondPending = true;
    }
  }

  void _schedule() {
    final base = 2.0 + _rng.nextDouble() * 3.6;
    _nextAt = base / (1 + rateBoost.clamp(0.0, 2.0));
  }
}
