import 'dart:math' as math;

import 'face_rig.dart';
import 'clips.dart';
import 'pose2d.dart';
import 'rig2d.dart';
import 'speech.dart';
import 'state_machine2d.dart';

/// Fully-assembled frame handed to the painter every tick.
class PuppetFrameData {
  PuppetFrameData({
    required this.pose,
    required this.solve,
    required this.face,
    required this.blink,
    required this.lookX,
    required this.lookY,
    required this.time,
    required this.sleeping,
    required this.talking,
  });

  final Pose2D pose;
  final SkeletonSolve solve;
  final FaceParams face;
  final double blink;
  final double lookX;
  final double lookY;
  final double time;
  final bool sleeping;
  final bool talking;
}

/// The layered animator.
///
/// BASE layer: idle / walk / run / sit / sleep (+ start/stop transitions).
/// UPPER-BODY layer: talk + one-shot gestures (mask: arms, spine, head).
/// FACE layer: expression (blendable) + blink + eye look + speech mouth.
///
/// Layers combine additively except gestures, which smoothly override the
/// arm/spine/head tracks while active — so Walk + Wave + Happy + Blink all
/// work simultaneously without per-combination clips.
class PuppetAnimator {
  PuppetAnimator({required this.rig, int seed = 11}) : sm = StateMachine2D();

  final Rig2D rig;
  final StateMachine2D sm;

  // --- Base layer --------------------------------------------------------
  String _clipId = 'idle';
  String? _prevClipId;
  double _t = 0;
  double _prevT = 0;
  double _fade = 0; // remaining crossfade seconds
  double _fadeTotal = 0.22;
  String _loopAfter = ''; // e.g. walk_stop -> walk loop? '' = stay
  final List<_PendingPlay> _queue = [];

  // --- Upper layer -------------------------------------------------------
  String? _gestureId;
  double _gestureT = 0;
  double _gestureW = 0;
  String? _headMoveId;
  double _headMoveT = 0;
  double _headMoveW = 0;

  // --- Face layer --------------------------------------------------------
  Expr _expr = Expr.neutral;
  Expr _prevExpr = Expr.neutral;
  double _exprBlend = 1;
  double _lookX = 0;
  double _lookY = 0;
  double _lookTX = 0;
  double _lookTY = 0;

  final SpeechDriver speech = SpeechDriver();
  final BlinkScheduler blinker = BlinkScheduler();
  bool _talking = false;

  // --- Playback ----------------------------------------------------------
  double speed = 1;
  bool playing = true;
  bool eyesForcedClosed = false;
  double _clock = 0;

  String get clipId => _clipId;
  Expr get expression => _expr;
  bool get talking => _talking;
  CharState get state => sm.state;
  double get clock => _clock;

  /// Plays a clip with a crossfade; optionally queues the loop clip to start
  /// when this one-shot finishes.
  void play(String id, {double fade = 0.22, String loopAfter = ''}) {
    _prevClipId = _clipId;
    _prevT = _t;
    _clipId = id;
    _t = 0;
    _fade = fade;
    _fadeTotal = fade <= 0 ? 0.001 : fade;
    _loopAfter = loopAfter;
  }

  void _finishPending() {
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _applyHop(next);
    }
  }

  void _applyHop(_PendingPlay hop) {
    sm.state = hop.state;
    play(hop.clip, fade: hop.fade, loopAfter: hop.loopAfter);
    if (hop.state == CharState.sleep) {
      eyesForcedClosed = false; // closed during to_sleep by blend, then held
    }
  }

  /// Requests a state change following legal transitions (auto-routing).
  void requestState(CharState to) {
    final path = sm.route(to);
    if (path.isEmpty) {
      if (sm.state == to) return;
      return; // unreachable — never jump illegally
    }
    _queue.clear();
    CharState from = sm.state;
    for (final hop in path) {
      final exit = _exitClipFor(from);
      if (exit != null) {
        _queue.add(_PendingPlay(state: from, clip: exit, fade: 0.2, loopAfter: ''));
      }
      _queue.add(_PendingPlay(state: hop, clip: _enterClipFor(hop), fade: 0.24, loopAfter: _loopClipFor(hop)));
      from = hop;
    }
    // Kick immediately if idle.
    _finishPending();
  }

  static String _loopClipFor(CharState s) {
    switch (s) {
      case CharState.idle:
        return 'idle';
      case CharState.walk:
        return 'walk';
      case CharState.run:
        return 'run';
      case CharState.sit:
        return 'sit_idle';
      case CharState.sleep:
        return 'sleep_loop';
      case CharState.talk:
        return 'idle'; // talk body = idle + talk overlay
    }
  }

  static String _enterClipFor(CharState s) {
    switch (s) {
      case CharState.walk:
        return 'walk_start';
      case CharState.run:
        return 'run_start';
      case CharState.sit:
        return 'stand_to_sit';
      case CharState.sleep:
        return 'to_sleep';
      case CharState.talk:
        return 'idle';
      case CharState.idle:
        return 'idle';
    }
  }

  static String? _exitClipFor(CharState s) {
    switch (s) {
      case CharState.walk:
        return 'walk_stop';
      case CharState.run:
        return 'run_stop';
      case CharState.sit:
        return 'sit_to_stand';
      case CharState.sleep:
        return 'wake_up';
      default:
        return null;
    }
  }

  /// Talk overlay (works on top of idle/walk/sit).
  void setTalking(bool on) {
    if (_talking == on) return;
    _talking = on;
    if (on) {
      speech.start();
      blinker.rateBoost = 0.8;
    } else {
      speech.stop();
      blinker.rateBoost = 0;
    }
  }

  void setExpression(Expr e) {
    if (e == _expr) return;
    _prevExpr = _expr;
    _expr = e;
    _exprBlend = 0;
  }

  void setLook(double x, double y) {
    _lookTX = x.clamp(-1.0, 1.0);
    _lookTY = y.clamp(-1.0, 1.0);
  }

  /// Fire a one-shot gesture (upper-body layer). New gestures replace the
  /// active one with a short crossfade.
  void triggerGesture(String id) {
    if (!ClipLibrary.gestureIds.contains(id)) return;
    _gestureId = id;
    _gestureT = 0;
    _gestureW = math.min(1, _gestureW + 0.35); // resume fading in
  }

  void triggerHeadMove(String id) {
    if (!ClipLibrary.headMoveIds.contains(id)) return;
    _headMoveId = id;
    _headMoveT = 0;
    _headMoveW = math.min(1, _headMoveW + 0.35);
  }

  /// Future lip-sync entry point: external viseme/timing data goes here.
  void feedVisemeTimeline(List<Syllable> timeline) => speech.setVisemeTimeline(timeline);

  PuppetFrameData update(double dt) {
    _clock += dt;
    final sdt = dt * (playing ? speed : 0);

    // --- Base clip timing -------------------------------------------------
    final clip = ClipLibrary.get(_clipId);
    _t += sdt;
    if (_fade > 0) {
      _fade = math.max(0, _fade - dt);
      _prevT += sdt;
    }
    if (!clip.loop && _t >= clip.duration) {
      if (_queue.isNotEmpty) {
        _finishPending();
      } else if (_loopAfter.isNotEmpty) {
        play(_loopAfter, fade: 0.2);
      } else {
        _t = clip.duration;
      }
    }

    // --- Solve base pose --------------------------------------------------
    var pose = clip.sample(_t);
    if (_fade > 0 && _prevClipId != null) {
      final prev = ClipLibrary.get(_prevClipId!);
      final w = 1 - (_fade / _fadeTotal);
      pose = Pose2D.lerp(prev.sample(_prevT), pose, w);
    }

    // --- Upper-body layer: talk ------------------------------------------
    final talkBase = Pose2D();
    if (_talking) {
      final tl = ClipLibrary.get('talk').sample(_clock % ClipLibrary.get('talk').duration);
      tl.onto(talkBase);
    }

    // --- Upper-body layer: gesture one-shot ------------------------------
    var gesture = Pose2D();
    if (_gestureId != null) {
      final g = ClipLibrary.get(_gestureId!);
      _gestureT += dt;
      final fadeIn = (_gestureT / 0.16).clamp(0.0, 1.0);
      final remain = g.duration - _gestureT;
      final fadeOut = (remain / 0.2).clamp(0.0, 1.0);
      _gestureW = math.min(fadeIn, fadeOut);
      if (_gestureT >= g.duration) {
        _gestureId = null;
        _gestureW = 0;
      } else {
        gesture = g.sample(_gestureT);
      }
    }

    // --- Head-move one-shot ----------------------------------------------
    var headMove = Pose2D();
    if (_headMoveId != null) {
      final h = ClipLibrary.get(_headMoveId!);
      _headMoveT += dt;
      final fadeIn = (_headMoveT / 0.14).clamp(0.0, 1.0);
      final remain = h.duration - _headMoveT;
      final fadeOut = (remain / 0.18).clamp(0.0, 1.0);
      _headMoveW = math.min(fadeIn, fadeOut);
      if (_headMoveT >= h.duration) {
        _headMoveId = null;
        _headMoveW = 0;
      } else {
        headMove = h.sample(_headMoveT);
      }
    }

    // --- Compose layers ----------------------------------------------------
    // Start from the base pose, add talk, then weighted-override with the
    // gesture/head-move tracks.
    final combined = pose.copy();
    talkBase.onto(combined);

    if (_gestureId != null && _gestureW > 0) {
      final w = _gestureW;
      for (final b in Rig2D.upperBodyBones) {
        final g = gesture.angle(b, double.nan);
        if (!g.isNaN) {
          final base = combined.angle(b);
          combined.angles[b] = base + (g - base) * w;
        }
      }
      for (final e in gesture.extras.keys) {
        final base = combined.extra(e);
        combined.extras[e] = base + (gesture.extra(e) - base) * w;
      }
    }

    if (_headMoveId != null && _headMoveW > 0) {
      final w = _headMoveW;
      for (final b in const ['head', 'neck']) {
        final hmv = headMove.angle(b, double.nan);
        if (!hmv.isNaN) {
          final base = combined.angle(b);
          combined.angles[b] = base + (hmv - base) * w;
        }
      }
      combined.extras['_lookX'] = combined.extra('_lookX') + headMove.extra('_lookX') * w;
      combined.extras['_lookY'] = combined.extra('_lookY') + headMove.extra('_lookY') * w;
    }

    // --- Face layer --------------------------------------------------------
    _exprBlend = (_exprBlend + dt / 0.28).clamp(0.0, 1.0);
    final from = Expressions.all[_prevExpr]!;
    final to = Expressions.all[_expr]!;
    var face = FaceParams.lerp(from, to, _exprBlend);

    speech.update(dt);
    if (_talking) {
      final m = speech.mouth;
      final talkBlend = 1.0;
      face = FaceParams.lerp(
        face,
        FaceParams(
          browAngle: face.browAngle + speech.accent * 4,
          browLift: face.browLift + speech.accent * 2.5,
          mouthOpen: m.mouthOpen,
          mouthW: m.mouthW,
          smile: face.smile * 0.2 + m.smile,
          teeth: m.teeth,
          tongue: m.tongue,
        ),
        talkBlend,
      );
      final suggestion = speech.takeGestureSuggestion();
      if (suggestion != null && _gestureId == null) triggerGesture(suggestion);
    }

    // Eye look smoothing + extras.
    _lookX += (_lookTX - _lookX) * math.min(1, dt * 8);
    _lookY += (_lookTY - _lookY) * math.min(1, dt * 8);
    final lookX = (_lookX + combined.extra('_lookX')).clamp(-1.0, 1.0);
    final lookY = (_lookY + combined.extra('_lookY')).clamp(-1.0, 1.0);

    blinker.update(dt, suppressed: eyesForcedClosed || _expr == Expr.crying);
    var blink = blinker.value;
    final sleepingNow = _clipId == 'sleep_loop' || _clipId == 'to_sleep';
    if (sleepingNow) blink = 1;
    if (eyesForcedClosed) blink = 1;

    final solve = solveSkeleton(rig, combined.angles);
    return PuppetFrameData(
      pose: combined,
      solve: solve,
      face: face,
      blink: blink,
      lookX: lookX,
      lookY: lookY,
      time: _clock,
      sleeping: sleepingNow,
      talking: _talking,
    );
  }
}

class _PendingPlay {
  _PendingPlay({required this.state, required this.clip, required this.fade, required this.loopAfter});
  final CharState state;
  final String clip;
  final double fade;
  final String loopAfter;
}
