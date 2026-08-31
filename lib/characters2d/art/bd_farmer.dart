import 'package:flutter/material.dart';

import '../engine/part2d.dart';
import 'body_kit.dart';
import 'draw_utils.dart';
import 'palettes.dart';

/// CHARACTER 01 — BD Farmer Male (35–45). Broad build, off-white shirt with
/// rolled sleeves, checked lungi, gamcha sash, moustache, close-cropped hair.
List<Part2D> buildFarmerParts(PaletteColors col, Set<String> accessories) {
  final o = col.outline;
  final skin = col.skin;
  final parts = <Part2D>[
    // Far arm (character-right).
    BodyKit.limb(bone: 'rightUpperArm', z: 2, len: 44, rTop: 7.2, rBottom: 6.4, color: col.shirt, outline: o),
    Part2D(
      bone: 'rightLowerArm',
      z: 2,
      painter: (ctx) {
        final c = ctx.canvas;
        Draw.capsule(c, const Offset(0, -8), const Offset(0, 46), 5.8, skin, outline: o);
        Draw.roundRect(c, const Rect.fromLTWH(-6.4, -8, 12.8, 12), 4, col.shirt, outline: o); // rolled cuff
      },
    ),
    BodyKit.hand(bone: 'rightHand', z: 2, skin: skin, outline: o, extraKey: 'handR'),
    // Far leg (lungi-coloured thigh + skin shin + sandal).
    BodyKit.limb(bone: 'rightUpperLeg', z: 3, len: 62, rTop: 9.0, rBottom: 8.2, color: col.bottom, outline: o),
    BodyKit.limb(bone: 'rightLowerLeg', z: 3, len: 58, rTop: 6.0, rBottom: 4.8, color: skin, outline: o),
    BodyKit.sandal(color: col.footwear, outline: o, skin: skin),
    // Near leg.
    BodyKit.limb(bone: 'leftUpperLeg', z: 5, len: 62, rTop: 9.4, rBottom: 8.4, color: col.bottom, outline: o),
    BodyKit.limb(bone: 'leftLowerLeg', z: 5, len: 58, rTop: 6.2, rBottom: 5.0, color: skin, outline: o),
    Part2D(
      bone: 'leftFoot',
      z: 5.4,
      painter: (ctx) => BodyKit.sandal(color: col.footwear, outline: o, skin: skin).painter(ctx),
    ),
    // Lungi + torso.
    BodyKit.lungi(base: col.bottom, check: col.shirtPattern, outline: o),
    BodyKit.torso(
      z: 7,
      hemY: -46,
      hemHalf: 25,
      shoulderHalf: 29,
      color: col.shirt,
      outline: o,
      collar: col.shirtPattern,
    ),
    // Neck + head.
    BodyKit.neck(skin: skin, outline: o),
    Part2D(
      bone: 'head',
      z: 9,
      painter: (ctx) => _farmerHead(ctx.canvas, col),
    ),
    Part2D(bone: 'head', z: 10, painter: (ctx) => _farmerHair(ctx.canvas, col)),
    // Near arm.
    BodyKit.limb(bone: 'leftUpperArm', z: 12, len: 44, rTop: 7.4, rBottom: 6.6, color: col.shirt, outline: o),
    Part2D(
      bone: 'leftLowerArm',
      z: 12,
      painter: (ctx) {
        final c = ctx.canvas;
        Draw.capsule(c, const Offset(0, -8), const Offset(0, 46), 6.0, skin, outline: o);
        Draw.roundRect(c, const Rect.fromLTWH(-6.6, -8, 13.2, 12), 4, col.shirt, outline: o);
      },
    ),
    BodyKit.hand(bone: 'leftHand', z: 12, skin: skin, outline: o, extraKey: 'handL'),
  ];
  if (accessories.contains('gamcha')) {
    parts.add(Part2D(bone: 'chest', z: 7.5, painter: (ctx) => _gamcha(ctx.canvas, col)));
  }
  return parts;
}

void _farmerHead(Canvas c, PaletteColors col) {
  final skin = col.skin;
  final o = col.outline;
  // Squarish skull + wide jaw.
  c.drawOval(Rect.fromCenter(center: Offset(0, 29), width: 43, height: 47), Draw.fill(o));
  Draw.roundRect(c, const Rect.fromLTWH(-14, 3, 28, 18), 8, o);
  c.drawOval(Rect.fromCenter(center: const Offset(0, 29), width: 41.2, height: 45.2), Draw.fill(skin));
  Draw.roundRect(c, const Rect.fromLTWH(-13, 4, 26, 16), 7, skin);
  // Ears.
  Draw.ellipse(c, const Offset(-20.5, 28), 3.6, 5.2, skin, outline: o);
  Draw.ellipse(c, const Offset(20.5, 28), 3.6, 5.2, skin, outline: o);
  // Bulbous nose.
  Draw.ellipse(c, const Offset(0, 21), 3.8, 4.6, col.skinShade, outline: o);
  // Friendly moustache.
  final m = Draw.line(col.hair, 3.4);
  Draw.curve(c, const Offset(0, 17), const Offset(-5, 14.6), const Offset(-9.5, 16.4), m);
  Draw.curve(c, const Offset(0, 17), const Offset(5, 14.6), const Offset(9.5, 16.4), m);
  // Cheek shade.
  Draw.ellipse(c, const Offset(-14, 21), 3.6, 2.4, col.cheek);
  Draw.ellipse(c, const Offset(14, 21), 3.6, 2.4, col.cheek);
}

void _farmerHair(Canvas c, PaletteColors col) {
  final p = Path()
    ..moveTo(-20, 36)
    ..quadraticBezierTo(-19, 52, 0, 53.5)
    ..quadraticBezierTo(19, 52, 20, 36)
    // Wavy fringe back to start.
    ..quadraticBezierTo(14, 41, 10, 37.5)
    ..quadraticBezierTo(5, 43, 0, 39)
    ..quadraticBezierTo(-5, 43, -10, 37.5)
    ..quadraticBezierTo(-14, 41, -20, 36)
    ..close();
  c.drawPath(p, Draw.fill(col.hair));
  // Sideburns.
  Draw.roundRect(c, const Rect.fromLTWH(-22, 28, 4.4, 11), 2, col.hair);
  Draw.roundRect(c, const Rect.fromLTWH(17.6, 28, 4.4, 11), 2, col.hair);
}

void _gamcha(Canvas c, PaletteColors col) {
  final o = col.outline;
  // Sash across the chest (chest frame, +Y up, hips ≈ y -38).
  final band = Path()
    ..moveTo(15, 18)
    ..lineTo(22, 15)
    ..lineTo(-10, -42)
    ..lineTo(-17, -38)
    ..close();
  Draw.outlined(c, band, col.accent, o, inset: 0.9);
  // Hanging tail over the hip.
  final tail = Path()
    ..moveTo(-17, -38)
    ..lineTo(-10, -42)
    ..lineTo(-14, -58)
    ..quadraticBezierTo(-13, -62, -8, -61)
    ..lineTo(-13, -44)
    ..close();
  Draw.outlined(c, tail, col.accent, o, inset: 0.88);
  // Fringe ticks.
  final f = Draw.line(o, 1.4);
  for (var i = 0; i < 4; i++) {
    c.drawLine(Offset(-13 + i * 2.2, -56), Offset(-13.6 + i * 2.2, -61), f);
  }
}
