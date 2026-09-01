import 'package:flutter/material.dart';

import '../engine/part2d.dart';
import '../engine/shapes.dart';

/// CHARACTER 04 — Cartoon Tiger (default 2D test character). Side-view
/// quadruped: body, head with muzzle/eyes/ears/jaw, 4 legs with paws,
/// 4-segment tail with follow-through, stripes + fur details.
List<Part2D> buildTigerParts() {
  return [
    // --- Far side legs ------------------------------------------------------
    Part2D(bone: 'brUpper', z: 1, build: (ctx) => _thigh(10.5, 34)),
    Part2D(bone: 'brLower', z: 1, build: (ctx) => _shin(5.2)),
    Part2D(bone: 'brPaw', z: 1.2, build: (ctx) => _paw(true)),
    Part2D(bone: 'frUpper', z: 2, build: (ctx) => _frontUpper(7.8)),
    Part2D(bone: 'frLower', z: 2, build: (ctx) => _shin(5.0)),
    Part2D(bone: 'frPaw', z: 2.2, build: (ctx) => _paw(true)),
    // --- Tail (above the back silhouette) -----------------------------------
    Part2D(bone: 'tail1', z: 4.2, build: (ctx) => _tailSeg(16, 5.6, false)),
    Part2D(bone: 'tail2', z: 4.4, build: (ctx) => _tailSeg(15, 5.2, true)),
    Part2D(bone: 'tail3', z: 4.6, build: (ctx) => _tailSeg(14, 4.8, true)),
    Part2D(bone: 'tail4', z: 4.8, build: (ctx) => _tailTip()),
    // --- Body ----------------------------------------------------------------
    Part2D(bone: 'body', z: 5, build: (ctx) => _body()),
    // --- Near side legs --------------------------------------------------------
    Part2D(bone: 'blUpper', z: 8, build: (ctx) => _thigh(11, 36)),
    Part2D(bone: 'blLower', z: 8, build: (ctx) => _shin(5.6)),
    Part2D(bone: 'blPaw', z: 8.2, build: (ctx) => _paw(false)),
    Part2D(bone: 'flUpper', z: 9, build: (ctx) => _frontUpper(8.4)),
    Part2D(bone: 'flLower', z: 9, build: (ctx) => _shin(5.4)),
    Part2D(bone: 'flPaw', z: 9.2, build: (ctx) => _paw(false)),
    // --- Neck + head ------------------------------------------------------------
    Part2D(
      bone: 'neck',
      z: 7,
      build: (ctx) => [
        Shape(kind: ShapeKind.capsule, args: [0, -12, 0, 30, 14], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.8),
        Shape(kind: ShapeKind.ellipse, args: [-5, 20, 9, 8], fill: const SolidFillSlot('belly')),
      ],
    ),
    Part2D(bone: 'earR', z: 8.5, build: (ctx) => _ear()),
    Part2D(
      bone: 'jaw',
      z: 9.4,
      build: (ctx) => [
        Shape(kind: ShapeKind.capsule, args: [0, -4, 0, 17, 6.4], fill: const SolidFillSlot('furShade'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.ellipse, args: [0, 14, 6.5, 4.6], fill: const SolidFillSlot('belly')),
      ],
    ),
    Part2D(bone: 'head', z: 10, build: (ctx) => _head(ctx)),
    Part2D(bone: 'earL', z: 11, build: (ctx) => _ear()),
  ];
}

List<Shape> _body() {
  return [
    // Main torso capsule (origin = body centre, +Y forward).
    Shape(kind: ShapeKind.capsule, args: [0, -44, 0, 46, 26], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 2.0),
    // Belly + chest fluff (local -X side = world down).
    Shape(kind: ShapeKind.capsule, args: [-6, -28, -6, 38, 15], fill: const SolidFillSlot('belly')),
    Shape(kind: ShapeKind.ellipse, args: [-4, 42, 20, 20], fill: const SolidFillSlot('belly')),
    // Haunch (back thigh mass).
    Shape(kind: ShapeKind.ellipse, args: [3, -34, 17, 19], fill: const SolidFillSlot('fur')),
    // Back stripes (local +X side = world up).
    for (final p in [-30.0, -16.0, -2.0, 12.0, 26.0])
      Shape(kind: ShapeKind.capsule, args: [24, p, 1, p + 3, 4.6], fill: const SolidFillSlot('stripe')),
    Shape(kind: ShapeKind.capsule, args: [22, 40, 2, 42, 4.2], fill: const SolidFillSlot('stripe')),
  ];
}

List<Shape> _thigh(double r, double len) {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -10, 0, len, r], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.8),
    Shape(kind: ShapeKind.capsule, args: [-r + 2, -2, -2, 10, 3.6], fill: const SolidFillSlot('stripe')),
  ];
}

List<Shape> _frontUpper(double r) {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -10, 0, 36, r], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.7),
  ];
}

List<Shape> _shin(double r) {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -8, 0, 30, r], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.6),
  ];
}

List<Shape> _paw(bool far) {
  return [
    Shape(kind: ShapeKind.ellipse, args: [0, 3, 7, 5.4], fill: SolidFillSlot(far ? 'furShade' : 'fur'), stroke: 'outline', strokeWidth: 1.6),
    Shape(kind: ShapeKind.ellipse, args: [2, 5.5, 4.6, 3.2], fill: const SolidFillSlot('belly')),
  ];
}

List<Shape> _tailSeg(double len, double r, bool stripe) {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -7, 0, len + 5, r], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.5),
    if (stripe) Shape(kind: ShapeKind.ellipse, args: [0, len * 0.55, r * 0.55, 2.6], fill: const SolidFillSlot('stripe')),
  ];
}

List<Shape> _tailTip() {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -7, 0, 15, 4.4], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.5),
    Shape(kind: ShapeKind.ellipse, args: [0, 11, 4.6, 5.2], fill: const SolidFillSlot('stripe'), stroke: 'outline', strokeWidth: 1.4),
  ];
}

List<Shape> _ear() {
  final outer = PathBuilder()
    ..move(-6.5, -2)
    ..quad(-4, 10, 0, 14)
    ..quad(5, 9, 7, -1)
    ..quad(0, -5, -6.5, -2)
    ..close();
  final inner = PathBuilder()
    ..move(-3.4, 0)
    ..quad(-1.5, 7, 0, 9.5)
    ..quad(2.6, 6, 3.8, 0.2)
    ..quad(0, -1.6, -3.4, 0)
    ..close();
  return [
    outer.build(fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.6),
    inner.build(fill: const SolidFillSlot('earInner')),
  ];
}

List<Shape> _head(ShapeCtx ctx) {
  final f = ctx.face;
  final closed = f.blink > 0.55 || f.squint > 0.6;
  final eyeX = 6 + f.lookX.clamp(-1, 1) * 2.2;
  final browTilt = f.browAngle * 0.14;

  final skull = PathBuilder()
    ..move(-16, 8)
    ..quad(-18, 26, -6, 33)
    ..quad(4, 40, 16, 33)
    ..quad(24, 26, 22, 14)
    ..quad(20, -4, 4, -6)
    ..quad(-12, -6, -16, 8)
    ..close();

  final brow = PathBuilder()
    ..move(-1, 26 + browTilt)
    ..quad(6, 29 + f.browLift * 0.6, 13, 24 - browTilt);

  final mouthCrease = PathBuilder()
    ..move(6, 36)
    ..quad(11, 36 + f.smile * 2.2, 15, 34);

  final nosePath = PathBuilder()
    ..move(1, 34.5)
    ..line(7, 35.8)
    ..line(5, 31)
    ..close();

  return [
    // Cheek ruff behind the muzzle.
    Shape(kind: ShapeKind.ellipse, args: [2, 26, 17, 15], fill: const SolidFillSlot('fur')),
    skull.build(fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 2.0),
    // Forehead stripes.
    Shape(kind: ShapeKind.capsule, args: [-2, -4, 1, 9, 2.8], fill: const SolidFillSlot('stripe')),
    Shape(kind: ShapeKind.capsule, args: [-9, -1, -6, 10, 2.4], fill: const SolidFillSlot('stripe')),
    Shape(kind: ShapeKind.capsule, args: [6, -2, 8, 9, 2.4], fill: const SolidFillSlot('stripe')),
    // Muzzle.
    Shape(kind: ShapeKind.ellipse, args: [6, 27, 14.5, 10.5], fill: const SolidFillSlot('belly'), stroke: 'outline', strokeWidth: 1.6),
    nosePath.build(fill: const SolidFillSlot('nose'), stroke: 'outline', strokeWidth: 1.3),
    // Eye (blinks + pupils track the face look direction).
    if (!closed) ...[
      Shape(kind: ShapeKind.ellipse, args: [6, 18, 5.4, 6.0], fill: ConstFill('white', Color(0xFFFFFFFF)), stroke: 'outline', strokeWidth: 1.5),
      Shape(kind: ShapeKind.ellipse, args: [eyeX, 18, 2.6 * f.pupil, 3.0 * f.pupil], fill: const SolidFillSlot('outline')),
      Shape(kind: ShapeKind.ellipse, args: [eyeX + 1.2, 16.4, 0.9, 1.1], fill: ConstFill('white', Color(0xFFFFFFFF))),
    ] else
      (PathBuilder()
          ..move(0.5, 18)
          ..quad(6, 15.4, 11.5, 18)).build(fill: const SolidFillSlot('outline'), strokeWidth: 1.4),
    // Brow.
    brow.build(fill: const SolidFillSlot('stripe'), strokeWidth: 1.6),
    // Whisker dots + smile crease.
    Shape(kind: ShapeKind.ellipse, args: [13, 26, 1.0, 1.0], fill: const SolidFillSlot('outline')),
    Shape(kind: ShapeKind.ellipse, args: [16.5, 28, 1.0, 1.0], fill: const SolidFillSlot('outline')),
    mouthCrease.build(fill: const SolidFillSlot('outline'), strokeWidth: 1.2),
  ];
}
