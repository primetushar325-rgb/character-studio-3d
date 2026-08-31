import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/draw_utils.dart';

/// Continuous face parameters — every expression/viseme is a point in this
/// space, so any two can be blended (expression ⇄ expression, viseme ⇄ viseme).
class FaceParams {
  const FaceParams({
    this.browAngle = 0,
    this.browLift = 0,
    this.browAsym = 0,
    this.lid = 0,
    this.squint = 0,
    this.mouthOpen = 0,
    this.mouthW = 1,
    this.smile = 0,
    this.teeth = 0,
    this.tongue = 0,
    this.tears = 0,
    this.sweat = 0,
    this.pupil = 1,
    this.lookBiasX = 0,
    this.lookBiasY = 0,
  });

  /// Brow tilt in degrees; + = inner ends down (angry), - = inner ends up (sad).
  final double browAngle;

  /// Brow vertical offset (+ = raised).
  final double browLift;

  /// Extra lift for the left brow only (confused / thinking).
  final double browAsym;

  /// Eyelid closure 0..1 (blink overrides this).
  final double lid;

  /// Happy squint amount 0..1 (smiling closed-curve eyes).
  final double squint;

  /// Mouth openness 0..1.
  final double mouthOpen;

  /// Mouth width multiplier.
  final double mouthW;

  /// Smile curvature -1 (frown) .. +1 (smile).
  final double smile;

  /// Upper teeth visibility 0..1.
  final double teeth;

  /// Tongue visibility 0..1.
  final double tongue;

  /// Tear level 0..1.
  final double tears;

  /// Sweat drop 0..1.
  final double sweat;

  /// Pupil scale (surprise/shrink when scared).
  final double pupil;

  /// Pupil bias from the face itself (thinking looks up, etc.).
  final double lookBiasX;
  final double lookBiasY;

  static FaceParams lerp(FaceParams a, FaceParams b, double t) => FaceParams(
        browAngle: _l(a.browAngle, b.browAngle, t),
        browLift: _l(a.browLift, b.browLift, t),
        browAsym: _l(a.browAsym, b.browAsym, t),
        lid: _l(a.lid, b.lid, t),
        squint: _l(a.squint, b.squint, t),
        mouthOpen: _l(a.mouthOpen, b.mouthOpen, t),
        mouthW: _l(a.mouthW, b.mouthW, t),
        smile: _l(a.smile, b.smile, t),
        teeth: _l(a.teeth, b.teeth, t),
        tongue: _l(a.tongue, b.tongue, t),
        tears: _l(a.tears, b.tears, t),
        sweat: _l(a.sweat, b.sweat, t),
        pupil: _l(a.pupil, b.pupil, t),
        lookBiasX: _l(a.lookBiasX, b.lookBiasX, t),
        lookBiasY: _l(a.lookBiasY, b.lookBiasY, t),
      );

  static double _l(double a, double b, double t) => a + (b - a) * t;
}

/// Mouth shape ids required by the spec (all share the same anchor point on
/// the face so visemes align while talking).
class MouthShapes {
  MouthShapes._();

  static const neutral = FaceParams();
  static const smile = FaceParams(smile: 0.75, mouthW: 1.06);
  static const open = FaceParams(mouthOpen: 0.85);
  static const A = FaceParams(mouthOpen: 0.95, mouthW: 1.0);
  static const E = FaceParams(mouthOpen: 0.55, mouthW: 1.18, teeth: 0.7);
  static const I = FaceParams(mouthOpen: 0.32, mouthW: 1.22, teeth: 0.8);
  static const O = FaceParams(mouthOpen: 0.8, mouthW: 0.74);
  static const U = FaceParams(mouthOpen: 0.34, mouthW: 0.7);
  static const mbp = FaceParams(mouthOpen: 0.0, mouthW: 0.96);
  static const fv = FaceParams(mouthOpen: 0.22, mouthW: 1.06, teeth: 1.0);
  static const L = FaceParams(mouthOpen: 0.42, mouthW: 1.0, tongue: 0.8);
  static const S = FaceParams(mouthOpen: 0.16, mouthW: 1.06, teeth: 0.9);
  static const sh = FaceParams(mouthOpen: 0.5, mouthW: 0.82);
  static const th = FaceParams(mouthOpen: 0.38, mouthW: 1.0, tongue: 0.6, teeth: 0.4);
  static const surprised = FaceParams(mouthOpen: 0.8, mouthW: 0.72);
  static const angry = FaceParams(mouthOpen: 0.24, mouthW: 0.92, smile: -0.7);
  static const laugh = FaceParams(mouthOpen: 1.0, mouthW: 1.14, smile: 0.9, tongue: 0.9);

  static const Map<String, FaceParams> all = {
    'neutral': neutral, 'smile': smile, 'open': open, 'A': A, 'E': E, 'I': I,
    'O': O, 'U': U, 'MBP': mbp, 'FV': fv, 'L': L, 'S': S, 'SH': sh, 'TH': th,
    'surprised': surprised, 'angry': angry, 'laugh': laugh,
  };
}

/// The ten independently-controllable expressions.
enum Expr { neutral, happy, sad, angry, surprised, scared, confused, thinking, laughing, crying }

class Expressions {
  Expressions._();

  static const Map<Expr, FaceParams> all = {
    Expr.neutral: FaceParams(),
    Expr.happy: FaceParams(browAngle: -6, browLift: 1.5, squint: 0.25, smile: 0.85, mouthW: 1.08),
    Expr.sad: FaceParams(browAngle: -16, browLift: -1, smile: -0.7, lid: 0.28, mouthW: 0.94),
    Expr.angry: FaceParams(browAngle: 16, browLift: -2.5, smile: -0.6, mouthOpen: 0.2, lid: 0.22, pupil: 1.1),
    Expr.surprised: FaceParams(browLift: 5.5, mouthOpen: 0.78, mouthW: 0.74, pupil: 0.72),
    Expr.scared: FaceParams(browAngle: -8, browLift: 4.5, mouthOpen: 0.4, mouthW: 0.85, pupil: 0.6, sweat: 1),
    Expr.confused: FaceParams(browAsym: 4.5, browLift: 2, mouthOpen: 0.3, mouthW: 1.12, lookBiasX: -0.5, lookBiasY: 0.5),
    Expr.thinking: FaceParams(browAsym: 3.5, browLift: 1.5, mouthW: 0.9, lookBiasX: 0.55, lookBiasY: 0.6, smile: -0.1),
    Expr.laughing: FaceParams(browAngle: -8, browLift: 2.5, squint: 1.0, mouthOpen: 1.0, smile: 0.95, mouthW: 1.12, tongue: 0.8),
    Expr.crying: FaceParams(browAngle: -18, browLift: -1.5, smile: -0.8, lid: 0.85, tears: 1, mouthOpen: 0.3),
  };

  static String label(Expr e) {
    switch (e) {
      case Expr.neutral: return 'Neutral';
      case Expr.happy: return 'Happy';
      case Expr.sad: return 'Sad';
      case Expr.angry: return 'Angry';
      case Expr.surprised: return 'Surprised';
      case Expr.scared: return 'Scared';
      case Expr.confused: return 'Confused';
      case Expr.thinking: return 'Thinking';
      case Expr.laughing: return 'Laughing';
      case Expr.crying: return 'Crying';
    }
  }

  static String emoji(Expr e) {
    switch (e) {
      case Expr.neutral: return '🙂';
      case Expr.happy: return '😊';
      case Expr.sad: return '😔';
      case Expr.angry: return '😠';
      case Expr.surprised: return '😮';
      case Expr.scared: return '😨';
      case Expr.confused: return '😕';
      case Expr.thinking: return '🤔';
      case Expr.laughing: return '😄';
      case Expr.crying: return '😢';
    }
  }
}

/// Per-character face geometry (where eyes/brows/mouth sit, sizes, styles).
class FaceStyle {
  const FaceStyle({
    this.eyeDx = 9.2,
    this.eyeY = 30,
    this.eyeRx = 5.4,
    this.eyeRy = 6.2,
    this.browY = 41,
    this.browLen = 9,
    this.browThick = 2.4,
    this.mouthY = 13,
    this.mouthW = 8.5,
    this.noseY = 21,
    this.noseLen = 4.5,
    this.lash = false,
    this.glasses = false,
  });

  final double eyeDx;
  final double eyeY;
  final double eyeRx;
  final double eyeRy;
  final double browY;
  final double browLen;
  final double browThick;
  final double mouthY;
  final double mouthW;
  final double noseY;
  final double noseLen;
  final bool lash;
  final bool glasses;
}

/// Everything the face renderer needs for one frame.
class FaceRenderInput {
  const FaceRenderInput({
    required this.params,
    required this.blink,
    required this.lookX,
    required this.lookY,
    required this.talkWeight,
    required this.time,
  });

  final FaceParams params;

  /// 0 = eyes open, 1 = fully closed (overrides expression lids).
  final double blink;

  /// Eye look direction -1..1 (added to expression look bias).
  final double lookX;
  final double lookY;

  /// 0..1 — how much the procedural/viseme mouth drives the lips.
  final double talkWeight;

  /// Seconds, for tear/sweat motion.
  final double time;
}

/// Renders eyes, brows, mouth and expression marks in the head bone frame
/// (origin = head joint at neck top, +Y = up-screen, +X = character's left).
void drawFace(Canvas c, FaceStyle style, FaceRenderInput face, PaletteColorSet colors) {
  final p = face.params;
  final lid = math.max(p.lid, face.blink);
  final lookX = (face.lookX + p.lookBiasX).clamp(-1.0, 1.0);
  final lookY = (face.lookY + p.lookBiasY).clamp(-1.0, 1.0);

  // --- Eyes -------------------------------------------------------------
  for (var s = -1; s <= 1; s += 2) {
    final cx = s * style.eyeDx;
    final cy = style.eyeY;
    if (p.squint > 0.55 || lid > 0.8) {
      // Closed / happy-arc eye.
      final happy = p.squint > 0.55 && lid < 0.8;
      final paint = Draw.line(colors.outline, 2.2);
      final curve = happy ? -3.2 : 2.2;
      Draw.curve(
        c,
        Offset(cx - style.eyeRx, cy + curve * 0.4),
        Offset(cx, cy + curve),
        Offset(cx + style.eyeRx, cy + curve * 0.4),
        paint,
      );
    } else {
      Draw.ellipse(c, Offset(cx, cy), style.eyeRx, style.eyeRy, const Color(0xFFFFFFFF), outline: colors.outline);
      final px = cx + lookX * style.eyeRx * 0.45;
      final py = cy - lookY * style.eyeRy * 0.4;
      final pr = 2.6 * p.pupil;
      Draw.ellipse(c, Offset(px, py), pr, pr, colors.outline);
      if (lid > 0.02) {
        // Upper lid slides down.
        final h = style.eyeRy * 2 * lid;
        c.save();
        c.clipRect(Rect.fromLTWH(cx - style.eyeRx - 1, cy - style.eyeRy - 1, style.eyeRx * 2 + 2, h + 1));
        Draw.ellipse(c, Offset(cx, cy), style.eyeRx + 1, style.eyeRy + 1, colors.skin);
        c.restore();
        Draw.curve(c, Offset(cx - style.eyeRx, cy - style.eyeRy + h), Offset(cx, cy - style.eyeRy + h + 1.2),
            Offset(cx + style.eyeRx, cy - style.eyeRy + h), Draw.line(colors.outline, 1.4));
      }
    }
    if (style.lash && p.squint < 0.55 && lid < 0.8) {
      final l = Draw.line(colors.outline, 1.4);
      c.drawLine(Offset(cx + s * (style.eyeRx - 0.5), cy - style.eyeRy + 1),
          Offset(cx + s * (style.eyeRx + 1.8), cy - style.eyeRy - 1.6), l);
    }
  }

  // --- Brows ------------------------------------------------------------
  for (var s = -1; s <= 1; s += 2) {
    final lift = p.browLift + (s > 0 ? p.browAsym : 0);
    final y = style.browY + lift; // +Y is up in the head frame
    // browAngle > 0 (angry): inner end drops.  < 0 (sad): inner end rises.
    final inner = Offset(s * 2.8, y - p.browAngle * 0.16);
    final outer = Offset(s * (style.eyeDx + style.browLen * 0.7), y + 1.0);
    final cp = Offset((inner.dx + outer.dx) / 2, y + 1.8);
    Draw.curve(c, inner, cp, outer, Draw.line(colors.hair, style.browThick));
  }

  // --- Mouth ------------------------------------------------------------
  final mw = style.mouthW * p.mouthW;
  final mo = p.mouthOpen;
  final my = style.mouthY;
  if (mo > 0.04) {
    final rx = mw * (0.85 + mo * 0.35);
    final ry = 1.6 + mo * 7.2;
    Draw.ellipse(c, Offset(0, my - mo * 1.5), rx, ry, const Color(0xFF57231F), outline: colors.outline);
    if (p.teeth > 0.05) {
      c.save();
      c.clipRect(Rect.fromCenter(center: Offset(0, my - mo * 1.5 - ry * 0.55), width: rx * 1.9, height: ry * 1.1));
      Draw.ellipse(c, Offset(0, my - mo * 1.5 - ry * 0.7), rx, ry * 0.8, const Color(0xFFFFFFFF));
      c.restore();
    }
    if (p.tongue > 0.05) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCenter(center: Offset(0, my - mo * 1.5), width: rx * 1.9, height: ry * 1.9)));
      Draw.ellipse(c, Offset(0, my - mo * 1.5 + ry * 0.55), rx * 0.6, ry * 0.6, const Color(0xFFD96A6A));
      c.restore();
    }
  } else {
    final cornerY = my - p.smile * 3.6;
    final midY = my + p.smile * 2.2 - 0.6;
    Draw.curve(
      c,
      Offset(-mw * 0.8, cornerY),
      Offset(0, midY),
      Offset(mw * 0.8, cornerY),
      Draw.line(const Color(0xFF57231F), 2.0),
    );
  }

  // --- Marks: tears & sweat ---------------------------------------------
  if (p.tears > 0.05) {
    final drop = (face.time * 26) % 22;
    final paint = Draw.fill(const Color(0x996EC9FF));
    for (var s = -1; s <= 1; s += 2) {
      c.drawOval(Rect.fromCenter(center: Offset(s * (style.eyeDx + 2.4), style.eyeY - drop), width: 3.2, height: 5), paint);
    }
  }
  if (p.sweat > 0.05) {
    final drop = (face.time * 14) % 14;
    final paint = Draw.fill(const Color(0xB36EC9FF));
    c.drawOval(Rect.fromCenter(center: Offset(style.eyeDx + 8, style.browY - drop * 0.5), width: 4.2, height: 6), paint);
  }
}

/// Color bundle the face needs (kept tiny so art files own the real palette).
class PaletteColorSet {
  const PaletteColorSet({required this.skin, required this.outline, required this.hair});
  final Color skin;
  final Color outline;
  final Color hair;
}
