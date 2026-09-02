import 'package:flutter/material.dart';

import '../engine/part2d.dart';
import '../engine/shapes.dart';

/// PHASE 5 — CHARACTER 05 — Premium Fox. Anthropomorphic front-facing
/// cartoon fox on the `fox_v1` rig (humanoid_v1 + ears + 3-segment tail):
/// designed bezier head with cheek ruffs / muzzle / blaze, big belly fluff,
/// paw hands & feet, a flowing tail with the signature WHITE TIP, and an
/// optional checked gamcha-style scarf (Bengali touch).
///
/// Every part is bound to a real bone (§1/§23) with a per-part z (§24):
/// tail → far arm → far leg → near leg → hips → torso → scarf → ears →
/// head → near arm.
List<Part2D> buildFoxParts(Set<String> accessories) {
  final scarf = accessories.contains('scarf');
  return [
    // --- Tail (behind everything, curves out beside the legs) -----------
    Part2D(bone: 'tail1', z: 0.6, build: (ctx) => _tailSeg(22, 6.4)),
    Part2D(bone: 'tail2', z: 0.7, build: (ctx) => _tailSeg(19, 5.8)),
    Part2D(bone: 'tail3', z: 0.8, build: (ctx) => _tailTip()),
    // --- Far arm (character-right) --------------------------------------
    Part2D(bone: 'rightUpperArm', z: 2, build: (ctx) => _limb(44, 7.0, 6.2)),
    Part2D(bone: 'rightLowerArm', z: 2, build: (ctx) => _forearm()),
    Part2D(bone: 'rightHand', z: 2.2, build: (ctx) => _pawHand(true)),
    // --- Far leg ---------------------------------------------------------
    Part2D(bone: 'rightUpperLeg', z: 3, build: (ctx) => _limb(62, 9.2, 8.2)),
    Part2D(bone: 'rightLowerLeg', z: 3, build: (ctx) => _limb(58, 5.8, 4.9)),
    Part2D(bone: 'rightFoot', z: 3.4, build: (ctx) => _pawFoot(true)),
    // --- Near leg ---------------------------------------------------------
    Part2D(bone: 'leftUpperLeg', z: 5, build: (ctx) => _limb(62, 9.6, 8.5)),
    Part2D(bone: 'leftLowerLeg', z: 5, build: (ctx) => _limb(58, 6.1, 5.1)),
    Part2D(bone: 'leftFoot', z: 5.4, build: (ctx) => _pawFoot(false)),
    // --- Hips / fluffy shorts ---------------------------------------------
    Part2D(bone: 'hips', z: 4.5, build: (ctx) => _hips()),
    // --- Torso --------------------------------------------------------------
    Part2D(bone: 'spine', z: 7, build: (ctx) => _torso()),
    if (scarf)
      Part2D(bone: 'chest', z: 7.6, build: (ctx) => _scarf(ctx)),
    // --- Neck ----------------------------------------------------------------
    Part2D(bone: 'neck', z: 6.4, build: (ctx) => [
          Shape(kind: ShapeKind.capsule, args: [0, -6, 0, 10, 5.0], fill: const SolidFillSlot('furShade'), stroke: 'outline', strokeWidth: 1.5),
        ]),
    // --- Ears (skull overlaps the base) --------------------------------------
    Part2D(bone: 'earR', z: 8.8, build: (ctx) => _ear()),
    Part2D(bone: 'earL', z: 8.9, build: (ctx) => _ear()),
    // --- Head ------------------------------------------------------------------
    Part2D(bone: 'head', z: 9, build: (ctx) => _head(ctx)),
    // --- Near arm (on top of everything) ----------------------------------------
    Part2D(bone: 'leftUpperArm', z: 12, build: (ctx) => _limb(44, 7.3, 6.4)),
    Part2D(bone: 'leftLowerArm', z: 12, build: (ctx) => _forearm()),
    Part2D(bone: 'leftHand', z: 12.2, build: (ctx) => _pawHand(false)),
  ];
}

// ---------------------------------------------------------------- limbs
/// Tapered two-capsule limb (like the human body kit, in fur).
List<Shape> _limb(double len, double rTop, double rBottom) {
  final mid = len * .45;
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -8, 0, mid, rTop], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.7),
    Shape(kind: ShapeKind.capsule, args: [0, mid - 2, 0, len, rBottom], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.7),
  ];
}

List<Shape> _forearm() {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -8, 0, 40, 5.6], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.6),
    // Fur cuff at the wrist.
    Shape(kind: ShapeKind.ellipse, args: [0, 33, 6.6, 4.4], fill: const SolidFillSlot('furShade'), stroke: 'outline', strokeWidth: 1.4),
  ];
}

/// Paw hand: rounded pad + white palm + little toe strokes.
List<Shape> _pawHand(bool far) {
  return [
    Shape(kind: ShapeKind.ellipse, args: [0, 3, 6.8, 5.6], fill: SolidFillSlot(far ? 'furShade' : 'fur'), stroke: 'outline', strokeWidth: 1.6),
    Shape(kind: ShapeKind.ellipse, args: [1.2, 4.8, 4.5, 3.1], fill: const SolidFillSlot('belly')),
    (PathBuilder()..move(-2.2, 6.8)..line(-1.4, 8.6)).build(fill: const SolidFillSlot('outline'), strokeWidth: 1.1),
    (PathBuilder()..move(2.4, 6.8)..line(1.6, 8.6)).build(fill: const SolidFillSlot('outline'), strokeWidth: 1.1),
  ];
}

/// Paw foot (drawn along the foot bone, +Y = toes forward).
List<Shape> _pawFoot(bool far) {
  return [
    Shape(kind: ShapeKind.ellipse, args: [0, 3.5, 7.4, 5.2], fill: SolidFillSlot(far ? 'furShade' : 'fur'), stroke: 'outline', strokeWidth: 1.6),
    Shape(kind: ShapeKind.ellipse, args: [1.4, 5.2, 4.7, 3.2], fill: const SolidFillSlot('belly')),
    (PathBuilder()..move(-2.4, 6.6)..line(-1.6, 8.2)).build(fill: const SolidFillSlot('outline'), strokeWidth: 1.1),
    (PathBuilder()..move(2.6, 6.6)..line(1.8, 8.2)).build(fill: const SolidFillSlot('outline'), strokeWidth: 1.1),
  ];
}

// ---------------------------------------------------------------- torso
List<Shape> _torso() {
  return [
    // Main chest capsule (spine-local +Y runs UP toward the shoulders).
    Shape(kind: ShapeKind.capsule, args: [0, -42, 0, 20, 23.5], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 2.0),
    // Big cream belly + chest fluff.
    Shape(kind: ShapeKind.capsule, args: [0, -36, 0, 12, 16.5], fill: const SolidFillSlot('belly')),
    Shape(kind: ShapeKind.ellipse, args: [0, 12, 15, 9], fill: const SolidFillSlot('belly')),
    // Shoulder ruffs soften the silhouette.
    Shape(kind: ShapeKind.ellipse, args: [-22, 12, 7, 8.5], fill: const SolidFillSlot('furShade')),
    Shape(kind: ShapeKind.ellipse, args: [22, 12, 7, 8.5], fill: const SolidFillSlot('furShade')),
    // Collar fluff tufts.
    for (final x in [-9.0, 0.0, 9.0])
      Shape(kind: ShapeKind.ellipse, args: [x, 19, 4.6, 5.4], fill: const SolidFillSlot('belly')),
  ];
}

List<Shape> _hips() {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -4, 0, 14, 16.5], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.9),
    // Fluffy haunches either side.
    Shape(kind: ShapeKind.ellipse, args: [-13, 6, 8, 10.5], fill: const SolidFillSlot('fur')),
    Shape(kind: ShapeKind.ellipse, args: [13, 6, 8, 10.5], fill: const SolidFillSlot('fur')),
  ];
}

// ---------------------------------------------------------------- scarf
/// Gamcha-style checked scarf: neck wrap + hanging end with fringe.
List<Shape> _scarf(ShapeCtx ctx) {
  return [
    // Hanging tail of the scarf.
    Shape(kind: ShapeKind.capsule, args: [7.5, 20, 10, 40, 3.8], fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.5),
    // Weave stripes on the hanging end.
    Shape(kind: ShapeKind.capsule, args: [6.5, 26, 11, 27, 2.0], fill: const SolidFillSlot('hair')),
    Shape(kind: ShapeKind.capsule, args: [7.5, 34, 10.5, 35, 1.6], fill: const SolidFillSlot('hair')),
    // Neck wrap band.
    Shape(kind: ShapeKind.capsule, args: [-10, 17.5, 10, 19.5, 5.6], fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.6),
    // Knot.
    Shape(kind: ShapeKind.ellipse, args: [7.5, 20.5, 3.6, 3.0], fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.4),
    // Fringe.
    (PathBuilder()..move(9, 43)..line(8.4, 46.5)).build(fill: const SolidFillSlot('outline'), strokeWidth: 1.2),
    (PathBuilder()..move(11.4, 42.4)..line(11.4, 45.8)).build(fill: const SolidFillSlot('outline'), strokeWidth: 1.2),
  ];
}

// ---------------------------------------------------------------- tail
List<Shape> _tailSeg(double len, double r) {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -6, 0, len, r], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.6),
  ];
}

/// The signature fox tail: white tip on the last segment.
List<Shape> _tailTip() {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -6, 0, 16, 5.2], fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.6),
    Shape(kind: ShapeKind.ellipse, args: [0, 12.5, 5.6, 6.0], fill: const SolidFillSlot('belly'), stroke: 'outline', strokeWidth: 1.5),
  ];
}

// ---------------------------------------------------------------- ear
List<Shape> _ear() {
  final outer = PathBuilder()
    ..move(-6.6, 0)
    ..quad(-4.6, 10, 0, 16.5)
    ..quad(5.2, 10.4, 7.0, -0.6)
    ..quad(0, -3.8, -6.6, 0)
    ..close();
  final inner = PathBuilder()
    ..move(-3.5, 1.4)
    ..quad(-2.1, 7.8, 0, 12)
    ..quad(2.7, 7.6, 3.7, 0.7)
    ..quad(0, -1.0, -3.5, 1.4)
    ..close();
  return [
    outer.build(fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 1.7),
    inner.build(fill: const SolidFillSlot('earInner')),
    // White inner-tip fleck.
    Shape(kind: ShapeKind.ellipse, args: [0, 10.5, 1.7, 2.2], fill: const SolidFillSlot('belly')),
  ];
}

// ---------------------------------------------------------------- head
/// The fox face — designed bezier skull with full cheeks, white muzzle,
/// forehead blaze, two expressive eyes (blink + look), brows, nose and a
/// mouth driven by the shared FaceView (smile / open / talk / tongue).
List<Shape> _head(ShapeCtx ctx) {
  final f = ctx.face;
  final closed = f.blink > 0.55 || f.squint > 0.6;
  final lookX = f.lookX.clamp(-1, 1) * 2.2;
  final lookY = f.lookY.clamp(-1, 1) * 1.8;
  final browTilt = f.browAngle * 0.14;

  // Cheek ruffs (behind the skull silhouette, soft fur fans).
  final ruffL = PathBuilder()
    ..move(-13, 20)
    ..quad(-21, 22, -19, 31)
    ..quad(-17, 38, -10, 40)
    ..close();
  final ruffR = PathBuilder()
    ..move(13, 20)
    ..quad(21, 22, 19, 31)
    ..quad(17, 38, 10, 40)
    ..close();

  // Skull: rounded crown + full cheeks + tapered muzzle line.
  final skull = PathBuilder()
    ..move(-15, 17)
    ..quad(-16.5, 33, -7.5, 41)
    ..quad(0, 47, 7.5, 41)
    ..quad(16.5, 33, 15, 17)
    ..quad(13.5, 2, 0, 1)
    ..quad(-13.5, 2, -15, 17)
    ..close();

  // Forehead blaze.
  final blaze = PathBuilder()
    ..move(-3.4, 2)
    ..quad(0, 0.4, 3.4, 2)
    ..quad(2.6, 12, 0, 16)
    ..quad(-2.6, 12, -3.4, 2)
    ..close();

  final nose = PathBuilder()
    ..move(-3.6, 31.5)
    ..quad(0, 29.6, 3.6, 31.5)
    ..quad(1.7, 35.4, 0, 36)
    ..quad(-1.7, 35.4, -3.6, 31.5)
    ..close();

  return [
    ruffL.build(fill: const SolidFillSlot('fur')),
    ruffR.build(fill: const SolidFillSlot('fur')),
    skull.build(fill: const SolidFillSlot('fur'), stroke: 'outline', strokeWidth: 2.0),
    blaze.build(fill: const SolidFillSlot('belly')),
    // Soft inner-cheek shading.
    Shape(kind: ShapeKind.ellipse, args: [-13.5, 24, 3.6, 6.4], fill: const SolidFillSlot('furShade')),
    Shape(kind: ShapeKind.ellipse, args: [13.5, 24, 3.6, 6.4], fill: const SolidFillSlot('furShade')),
    // White muzzle + jaw.
    Shape(kind: ShapeKind.ellipse, args: [0, 36.5, 12.8, 9.6], fill: const SolidFillSlot('belly'), stroke: 'outline', strokeWidth: 1.6),
    nose.build(fill: const SolidFillSlot('nose'), stroke: 'outline', strokeWidth: 1.3),

    // Eyes: white almond + tracking pupil + glint; blink = curved lash.
    for (final sx in [-1.0, 1.0]) ...[
      if (!closed) ...[
        Shape(kind: ShapeKind.ellipse, args: [8.5 * sx, 24, 5.0, 5.9], fill: ConstFill('white', const Color(0xFFFFFFFF)), stroke: 'outline', strokeWidth: 1.5),
        Shape(kind: ShapeKind.ellipse, args: [8.5 * sx + lookX, 24 + lookY, 2.4 * f.pupil, 3.0 * f.pupil], fill: const SolidFillSlot('outline')),
        Shape(kind: ShapeKind.ellipse, args: [8.5 * sx + lookX + 1.1 * sx, 22.6, 0.9, 1.15], fill: ConstFill('white', const Color(0xFFFFFFFF))),
      ] else
        (PathBuilder()
            ..move(8.5 * sx - 3.6, 24)
            ..quad(8.5 * sx, 21.6, 8.5 * sx + 3.6, 24))
            .build(fill: const SolidFillSlot('outline'), strokeWidth: 1.5),
      // Brow.
      (PathBuilder()
          ..move(8.5 * sx - 3.2 * sx, 33.4 + f.browLift * -0.6 + browTilt * sx)
          ..quad(8.5 * sx, 34.6 + f.browLift * -0.6, 8.5 * sx + 3.2 * sx, 33.4 + f.browLift * -0.6 - browTilt * sx))
          .build(fill: const SolidFillSlot('furShade'), strokeWidth: 1.8),
    ],

    // Mouth: smile creases + open talking mouth with tongue/teeth.
    (PathBuilder()..move(-1.4, 38.5)..quad(-4.2 - f.smile * 1.2, 40.5 + f.smile * 2.0, -5.8, 38.2))
        .build(fill: const SolidFillSlot('outline'), strokeWidth: 1.3),
    (PathBuilder()..move(1.4, 38.5)..quad(4.2 + f.smile * 1.2, 40.5 + f.smile * 2.0, 5.8, 38.2))
        .build(fill: const SolidFillSlot('outline'), strokeWidth: 1.3),
    if (f.mouthOpen > 0.06) ...[
      Shape(kind: ShapeKind.ellipse, args: [0, 42.8, 3.6 + f.mouthW * 2.4, 1.6 + f.mouthOpen * 5.2], fill: const SolidFillSlot('outline'), stroke: 'outline', strokeWidth: 1.2),
      if (f.tongue > 0.05)
        Shape(kind: ShapeKind.ellipse, args: [0, 44.6, 2.4, 1.2 + f.tongue * 1.6], fill: ConstFill('tongue', const Color(0xFFE58A8A))),
      if (f.teeth > 0.2)
        Shape(kind: ShapeKind.rrect, args: [-2.8, 40.6, 5.6, 1.7, 0.8], fill: ConstFill('white', const Color(0xFFFFFFFF))),
    ],

    // Whisker dots.
    Shape(kind: ShapeKind.ellipse, args: [-8.6, 34.5, 0.9, 0.9], fill: const SolidFillSlot('outline')),
    Shape(kind: ShapeKind.ellipse, args: [8.6, 34.5, 0.9, 0.9], fill: const SolidFillSlot('outline')),
    // Blush.
    Shape(kind: ShapeKind.ellipse, args: [-12.2, 30, 3.4, 2.1], fill: const SolidFillSlot('cheek')),
    Shape(kind: ShapeKind.ellipse, args: [12.2, 30, 3.4, 2.1], fill: const SolidFillSlot('cheek')),
  ];
}
