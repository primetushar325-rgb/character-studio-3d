import 'dart:math' as math;

/// PHASE 6 — data-driven per-object timeline effects.
///
/// Effects are ordinary timeline data (like keyframes and anim clips): they
/// persist with the project, evaluate deterministically from (effect, scene
/// time) alone — no randomness — and apply through the same
/// [EvaluatedTransform] used by BOTH the live preview and the frame-rendered
/// export, so preview == export by construction.
enum EffectKind { fadeIn, fadeOut, shake, zoom, pulse, flash }

String effectLabel(EffectKind k) => switch (k) {
      EffectKind.fadeIn => 'Fade In',
      EffectKind.fadeOut => 'Fade Out',
      EffectKind.shake => 'Shake',
      EffectKind.zoom => 'Zoom',
      EffectKind.pulse => 'Pulse',
      EffectKind.flash => 'Flash',
    };

/// One effect clip on one object's track.
class EffectClip {
  EffectClip({
    required this.id,
    required this.kind,
    required this.startMs,
    required this.durationMs,
    this.intensity = 1,
    this.seed = 0,
  });

  final String id;
  final EffectKind kind;
  int startMs;
  int durationMs;
  double intensity; // 0..2 scale of the effect
  int seed; // deterministic phase source for shake

  int get endMs => startMs + durationMs;

  bool activeAt(int tMs) => tMs >= startMs && tMs < endMs && durationMs > 0;

  /// Linear progress through the clip at [tMs] (clamped 0..1).
  double progressAt(int tMs) =>
      durationMs <= 0 ? 0 : ((tMs - startMs) / durationMs).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'startMs': startMs,
        'durationMs': durationMs,
        'intensity': intensity,
        'seed': seed,
      };

  static EffectClip fromJson(Map<String, dynamic> j) => EffectClip(
        id: j['id'] as String? ?? '',
        kind: EffectKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => EffectKind.fadeIn,
        ),
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 800,
        intensity: (j['intensity'] as num?)?.toDouble() ?? 1,
        seed: (j['seed'] as num?)?.toInt() ?? 0,
      );
}

/// Deterministic smooth ease for fades (S-curve, no pop at the ends).
double _smooth(double u) => u * u * (3 - 2 * u);

/// Derives a stable phase (radians) from an integer seed.
double _seedPhase(int seed) {
  var h = (seed & 0xFFFF) * 2654435761 % 1000003;
  return (h / 1000003) * 2 * math.pi;
}

/// Result of evaluating all active effects for one object at one time.
class EffectValue {
  const EffectValue({this.opacityMul = 1, this.dx = 0, this.dy = 0, this.scaleMul = 1, this.flash = 0});

  /// Multiplier for the object's opacity (fades).
  final double opacityMul;

  /// Additive offset in fraction-of-canvas units (shake).
  final double dx;
  final double dy;

  /// Multiplier for the object's scale (zoom / pulse).
  final double scaleMul;

  /// 0..1 white-flash amount painted over the object's layer.
  final double flash;

  static const EffectValue none = EffectValue();
}

/// Pure evaluation of the active effects at scene time [tMs].
EffectValue evaluateEffects(List<EffectClip> effects, int tMs) {
  var v = EffectValue.none;
  for (final e in effects) {
    if (!e.activeAt(tMs)) continue;
    final u = e.progressAt(tMs);
    final k = e.intensity.clamp(0.0, 2.0);
    switch (e.kind) {
      case EffectKind.fadeIn:
        v = EffectValue(
          opacityMul: v.opacityMul * _smooth(u).clamp(0.0, 1.0),
          dx: v.dx,
          dy: v.dy,
          scaleMul: v.scaleMul,
          flash: v.flash,
        );
      case EffectKind.fadeOut:
        v = EffectValue(
          opacityMul: v.opacityMul * _smooth(1 - u).clamp(0.0, 1.0),
          dx: v.dx,
          dy: v.dy,
          scaleMul: v.scaleMul,
          flash: v.flash,
        );
      case EffectKind.shake:
        // Two incommensurate sines from the seed: looks organic, is pure math.
        final p = _seedPhase(e.seed);
        final tt = tMs / 1000.0;
        final amp = 0.006 * k; // fraction of canvas per notch
        v = EffectValue(
          opacityMul: v.opacityMul,
          dx: v.dx + math.sin(tt * 21.7 + p) * amp,
          dy: v.dy + math.sin(tt * 27.3 + p * 2.1) * amp * 0.7,
          scaleMul: v.scaleMul,
          flash: v.flash,
        );
      case EffectKind.zoom:
        // Ease in-out around 1x → (1 + 0.35·intensity)x.
        final s = 1 + 0.35 * k * _smooth(u);
        v = EffectValue(
          opacityMul: v.opacityMul,
          dx: v.dx,
          dy: v.dy,
          scaleMul: v.scaleMul * s,
          flash: v.flash,
        );
      case EffectKind.pulse:
        // 3 heart-beat cycles over the clip, symmetric (grows and shrinks).
        final s = 1 + 0.16 * k * math.sin(u * 3 * 2 * math.pi).abs();
        v = EffectValue(
          opacityMul: v.opacityMul,
          dx: v.dx,
          dy: v.dy,
          scaleMul: v.scaleMul * s,
          flash: v.flash,
        );
      case EffectKind.flash:
        v = EffectValue(
          opacityMul: v.opacityMul,
          dx: v.dx,
          dy: v.dy,
          scaleMul: v.scaleMul,
          flash: (v.flash + (1 - (2 * u - 1).abs()) * k).clamp(0.0, 1.0),
        );
    }
  }
  return v;
}
