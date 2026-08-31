import 'package:flutter/material.dart';

import '../engine/part2d.dart';
import 'body_kit.dart';
import 'draw_utils.dart';
import 'palettes.dart';

/// CHARACTER 02 — Bangladeshi Village Girl (12–16). Round head, big eyes,
/// two braids with ribbons, colorful salwar-kameez + dupatta, sandals.
List<Part2D> buildGirlParts(PaletteColors col, Set<String> accessories) {
  final o = col.outline;
  final skin = col.skin;
  final parts = <Part2D>[
    // Hair back + braids (behind everything).
    Part2D(bone: 'head', z: 0, layer: PartLayer.back, painter: (ctx) => _girlHairBack(ctx.canvas, col)),
    // Far arm: 3/4 sleeve — upper shirt, lower skin with cuff.
    BodyKit.limb(bone: 'rightUpperArm', z: 2, len: 44, rTop: 6.2, rBottom: 5.6, color: col.shirt, outline: o),
    Part2D(
      bone: 'rightLowerArm',
      z: 2,
      painter: (ctx) {
        final c = ctx.canvas;
        Draw.capsule(c, const Offset(0, -8), const Offset(0, 46), 5.2, skin, outline: o);
        Draw.roundRect(c, const Rect.fromLTWH(-6, -8, 12, 16), 4, col.shirt, outline: o);
      },
    ),
    BodyKit.hand(bone: 'rightHand', z: 2, skin: skin, outline: o, extraKey: 'handR'),
    // Far leg: salwar + sandal.
    BodyKit.limb(bone: 'rightUpperLeg', z: 3, len: 62, rTop: 7.6, rBottom: 6.8, color: col.bottom, outline: o),
    Part2D(
      bone: 'rightLowerLeg',
      z: 3,
      painter: (ctx) => _salwarShin(ctx.canvas, col),
    ),
    BodyKit.sandal(color: col.footwear, outline: o, skin: skin),
    // Near leg.
    BodyKit.limb(bone: 'leftUpperLeg', z: 5, len: 62, rTop: 7.9, rBottom: 7.0, color: col.bottom, outline: o),
    Part2D(bone: 'leftLowerLeg', z: 5, painter: (ctx) => _salwarShin(ctx.canvas, col)),
    Part2D(bone: 'leftFoot', z: 5.4, painter: (ctx) => BodyKit.sandal(color: col.footwear, outline: o, skin: skin).painter(ctx)),
    // Kameez + dupatta.
    BodyKit.pelvis(color: col.bottom, outline: o, half: 17, bottom: 20),
    BodyKit.torso(
      z: 7,
      hemY: -58,
      hemHalf: 31,
      shoulderHalf: 22,
      color: col.shirt,
      outline: o,
      trim: col.accent,
      collar: col.accent,
    ),
    // Neck + head.
    BodyKit.neck(skin: skin, outline: o),
    Part2D(bone: 'head', z: 9, painter: (ctx) => _girlHead(ctx.canvas, col)),
    Part2D(bone: 'head', z: 10, painter: (ctx) => _girlHairFront(ctx.canvas, col)),
    // Near arm.
    BodyKit.limb(bone: 'leftUpperArm', z: 12, len: 44, rTop: 6.4, rBottom: 5.8, color: col.shirt, outline: o),
    Part2D(
      bone: 'leftLowerArm',
      z: 12,
      painter: (ctx) {
        final c = ctx.canvas;
        Draw.capsule(c, const Offset(0, -8), const Offset(0, 46), 5.4, skin, outline: o);
        Draw.roundRect(c, const Rect.fromLTWH(-6.2, -8, 12.4, 16), 4, col.shirt, outline: o);
      },
    ),
    BodyKit.hand(bone: 'leftHand', z: 12, skin: skin, outline: o, extraKey: 'handL'),
  ];
  if (accessories.contains('dupatta')) {
    parts.add(Part2D(bone: 'chest', z: 7.6, painter: (ctx) => _dupatta(ctx.canvas, col)));
  }
  return parts;
}

void _salwarShin(Canvas c, PaletteColors col) {
  // Baggy salwar shin: wide top, gathered cuff near the ankle.
  Draw.capsule(c, const Offset(0, -9), const Offset(0, 44), 6.4, col.bottom, outline: col.outline);
  Draw.ellipse(c, const Offset(0, 44), 4.6, 4.0, col.bottom, outline: col.outline);
  Draw.capsule(c, const Offset(0, 47), const Offset(0, 53), 3.0, col.skin, outline: col.outline);
}

void _girlHead(Canvas c, PaletteColors col) {
  final skin = col.skin;
  final o = col.outline;
  // Round skull + soft chin.
  c.drawOval(Rect.fromCenter(center: Offset(0, 28), width: 41, height: 45), Draw.fill(o));
  c.drawOval(Rect.fromCenter(center: const Offset(0, 27), width: 39.4, height: 43.4), Draw.fill(skin));
  Draw.ellipse(c, const Offset(0, 8), 12.5, 8.5, skin, outline: o);
  // Ears.
  Draw.ellipse(c, const Offset(-19.5, 27), 3.4, 5.0, skin, outline: o);
  Draw.ellipse(c, const Offset(19.5, 27), 3.4, 5.0, skin, outline: o);
  // Small nose.
  Draw.ellipse(c, const Offset(0, 21), 2.9, 3.5, col.skinShade, outline: o);
  // Blush.
  Draw.ellipse(c, const Offset(-13.5, 20), 4.2, 2.8, col.cheek);
  Draw.ellipse(c, const Offset(13.5, 20), 4.2, 2.8, col.cheek);
}

void _girlHairBack(Canvas c, PaletteColors col) {
  final hair = col.hair;
  final o = col.outline;
  Draw.ellipse(c, const Offset(0, 27), 23.5, 25, hair, outline: o);
  // Two braids falling over the shoulders.
  for (final s in [-1, 1]) {
    final a = Offset(s * 17.0, 20.0);
    final b = Offset(s * 21.5, 4.0);
    final d = Offset(s * 23.5, -9.0);
    Draw.capsule(c, a, b, 5.4, hair, outline: o);
    Draw.capsule(c, b, d, 4.6, hair, outline: o);
    // Braid segment ties.
    final seg = Draw.line(o, 1.3);
    c.drawLine(Offset(s * 17.6, 13), Offset(s * 22.4, 10.5), seg);
    c.drawLine(Offset(s * 21.0, -2), Offset(s * 25.6, -0.5), seg);
    // Ribbon + tuft.
    Draw.ellipse(c, Offset(s * 23.5, -11.5), 4.0, 3.2, col.accent, outline: o);
    Draw.ellipse(c, Offset(s * 24.5, -16), 2.6, 3.6, hair, outline: o);
  }
}

void _girlHairFront(Canvas c, PaletteColors col) {
  final p = Path()
    ..moveTo(-20, 35)
    ..quadraticBezierTo(-20, 51, 0, 52.5)
    ..quadraticBezierTo(20, 51, 20, 35)
    // Scalloped bangs.
    ..quadraticBezierTo(15, 39.5, 12, 36)
    ..quadraticBezierTo(8, 42, 4, 37)
    ..quadraticBezierTo(0, 43, -4, 37)
    ..quadraticBezierTo(-8, 42, -12, 36)
    ..quadraticBezierTo(-15, 39.5, -20, 35)
    ..close();
  c.drawPath(p, Draw.fill(col.hair));
  // Center part line.
  final part = Draw.line(const Color(0x66000000), 1.2);
  c.drawLine(const Offset(0, 52), const Offset(0, 43), part);
}

void _dupatta(Canvas c, PaletteColors col) {
  final o = col.outline;
  final paint = col.accent.withOpacity(0.96);
  // U-drape over the kameez (chest frame, +Y up).
  final left = Path()
    ..moveTo(-17, 17)
    ..quadraticBezierTo(-19, -12, -6, -50)
    ..lineTo(1, -47)
    ..quadraticBezierTo(-10, -14, -10, 16)
    ..close();
  final right = Path()
    ..moveTo(17, 17)
    ..quadraticBezierTo(19, -12, 6, -50)
    ..lineTo(-1, -47)
    ..quadraticBezierTo(10, -14, 10, 16)
    ..close();
  Draw.outlined(c, left, paint, o, inset: 0.93);
  Draw.outlined(c, right, paint, o, inset: 0.93);
}
