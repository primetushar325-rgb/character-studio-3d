import 'package:flutter/material.dart';

import '../engine/part2d.dart';
import 'body_kit.dart';
import 'draw_utils.dart';
import 'palettes.dart';

/// CHARACTER 03 — Bangladeshi School Teacher (30–45). Slim formal look:
/// light tucked-in shirt, dark trousers, black rectangular glasses, neat
/// moustache, notebook prop.
List<Part2D> buildTeacherParts(PaletteColors col, Set<String> accessories) {
  final o = col.outline;
  final skin = col.skin;
  final parts = <Part2D>[
    // Far arm: full sleeve.
    BodyKit.limb(bone: 'rightUpperArm', z: 2, len: 44, rTop: 6.6, rBottom: 6.0, color: col.shirt, outline: o),
    BodyKit.limb(bone: 'rightLowerArm', z: 2, len: 40, rTop: 5.6, rBottom: 5.0, color: col.shirt, outline: o),
    BodyKit.hand(bone: 'rightHand', z: 2, skin: skin, outline: o, extraKey: 'handR'),
    // Far leg: trousers + shoe.
    BodyKit.limb(bone: 'rightUpperLeg', z: 3, len: 62, rTop: 7.6, rBottom: 6.8, color: col.bottom, outline: o),
    BodyKit.limb(bone: 'rightLowerLeg', z: 3, len: 58, rTop: 5.6, rBottom: 4.6, color: col.bottom, outline: o),
    BodyKit.shoe(color: col.footwear, outline: o),
    // Near leg.
    BodyKit.limb(bone: 'leftUpperLeg', z: 5, len: 62, rTop: 7.8, rBottom: 7.0, color: col.bottom, outline: o),
    BodyKit.limb(bone: 'leftLowerLeg', z: 5, len: 58, rTop: 5.8, rBottom: 4.8, color: col.bottom, outline: o),
    Part2D(bone: 'leftFoot', z: 5.4, painter: (ctx) => BodyKit.shoe(color: col.footwear, outline: o).painter(ctx)),
    // Pelvis + tucked shirt.
    BodyKit.pelvis(color: col.bottom, outline: o, half: 19, bottom: 22),
    BodyKit.torso(
      z: 7,
      hemY: -40,
      hemHalf: 22,
      shoulderHalf: 26,
      color: col.shirt,
      outline: o,
      buttons: true,
      belt: true,
      beltColor: col.bottom,
      collar: col.shirtPattern,
    ),
    // Neck + head.
    BodyKit.neck(skin: skin, outline: o),
    Part2D(bone: 'head', z: 9, painter: (ctx) => _teacherHead(ctx.canvas, col)),
    Part2D(bone: 'head', z: 10, painter: (ctx) => _teacherHair(ctx.canvas, col)),
    // Near arm.
    BodyKit.limb(bone: 'leftUpperArm', z: 12, len: 44, rTop: 6.8, rBottom: 6.2, color: col.shirt, outline: o),
    BodyKit.limb(bone: 'leftLowerArm', z: 12, len: 40, rTop: 5.8, rBottom: 5.2, color: col.shirt, outline: o),
    BodyKit.hand(bone: 'leftHand', z: 12, skin: skin, outline: o, extraKey: 'handL'),
  ];
  if (accessories.contains('glasses')) {
    parts.add(Part2D(bone: 'head', z: 1, layer: PartLayer.front, painter: (ctx) => _glasses(ctx.canvas, col)));
  }
  if (accessories.contains('book')) {
    parts.add(Part2D(bone: 'leftHand', z: 2, layer: PartLayer.front, painter: (ctx) => _book(ctx.canvas, col)));
  }
  return parts;
}

void _teacherHead(Canvas c, PaletteColors col) {
  final skin = col.skin;
  final o = col.outline;
  // Oval skull + narrow chin.
  c.drawOval(Rect.fromCenter(center: Offset(0, 28), width: 40, height: 46), Draw.fill(o));
  c.drawOval(Rect.fromCenter(center: const Offset(0, 28), width: 38.4, height: 44.4), Draw.fill(skin));
  Draw.ellipse(c, const Offset(0, 8), 10.5, 7.5, skin, outline: o);
  // Ears.
  Draw.ellipse(c, const Offset(-19, 27), 3.4, 5.0, skin, outline: o);
  Draw.ellipse(c, const Offset(19, 27), 3.4, 5.0, skin, outline: o);
  // Straight nose.
  Draw.ellipse(c, const Offset(0, 21), 3.1, 4.0, col.skinShade, outline: o);
  // Neat trimmed moustache.
  final m = Draw.line(col.hair, 3.0);
  Draw.curve(c, const Offset(0, 17), const Offset(-4, 15.4), const Offset(-7.5, 16.6), m);
  Draw.curve(c, const Offset(0, 17), const Offset(4, 15.4), const Offset(7.5, 16.6), m);
}

void _teacherHair(Canvas c, PaletteColors col) {
  final p = Path()
    ..moveTo(-19.5, 38)
    ..quadraticBezierTo(-19, 52, 0, 53)
    ..quadraticBezierTo(19, 52, 19.5, 37)
    // Side-sweep inner edge.
    ..quadraticBezierTo(12, 44, 2, 44.5)
    ..quadraticBezierTo(-9, 45, -13, 40)
    ..quadraticBezierTo(-16, 38.5, -19.5, 38)
    ..close();
  c.drawPath(p, Draw.fill(col.hair));
  // Sideburns.
  Draw.roundRect(c, const Rect.fromLTWH(-21.5, 28, 4, 10, ), 2, col.hair);
  Draw.roundRect(c, const Rect.fromLTWH(17.5, 28, 4, 10), 2, col.hair);
}

void _glasses(Canvas c, PaletteColors col) {
  final g = Draw.line(col.glasses, 1.8);
  const eyeDx = 8.4;
  const eyeY = 29;
  // Rectangular lenses.
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-eyeDx - 6.6, eyeY - 5.2, 13.2, 10.4), const Radius.circular(2.6)),
    g,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(eyeDx - 6.6, eyeY - 5.2, 13.2, 10.4), const Radius.circular(2.6)),
    g,
  );
  // Bridge + temples.
  c.drawLine(const Offset(-eyeDx + 6.6, eyeY - 1.5), const Offset(eyeDx - 6.6, eyeY - 1.5), g);
  c.drawLine(const Offset(-eyeDx - 6.6, eyeY - 1), const Offset(-19, eyeY - 2), g);
  c.drawLine(const Offset(eyeDx + 6.6, eyeY - 1), const Offset(19, eyeY - 2), g);
}

void _book(Canvas c, PaletteColors col) {
  // Open notebook held in the near hand (hand frame: origin wrist, +Y out).
  final o = col.outline;
  c.save();
  c.rotate(0.35);
  Draw.roundRect(c, const Rect.fromLTWH(-9, 2, 18, 13), 2, col.book, outline: o);
  c.drawRect(const Rect.fromLTWH(-7.6, 3.2, 15.2, 10.6), Draw.fill(const Color(0xFFF7F4EC)));
  final l = Draw.line(const Color(0xFFB9B2A4), 0.9);
  for (var i = 0; i < 3; i++) {
    c.drawLine(Offset(-5.5, 5.2 + i * 2.6), Offset(5.5, 5.2 + i * 2.6), l);
  }
  c.restore();
}
