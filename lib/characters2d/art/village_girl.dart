import '../engine/part2d.dart';
import '../engine/shapes.dart';
import 'body_kit.dart';

/// CHARACTER 02 — Bangladeshi Village Girl (12–16). Round head, big eyes,
/// two braids with ribbons, colorful salwar-kameez + dupatta, sandals.
List<Part2D> buildGirlParts() {
  return [
    Part2D(bone: 'head', z: 0, layer: PartLayer.back, build: (ctx) => _girlHairBack()),
    // Far arm.
    BodyKit.limb(bone: 'rightUpperArm', z: 2, len: 44, rTop: 6.2, rBottom: 5.6),
    BodyKit.cuffedForearm(bone: 'rightLowerArm', z: 2, len: 46, r: 5.2, cuffH: 16),
    BodyKit.hand(bone: 'rightHand', z: 2, extraKey: 'handR'),
    // Far leg: salwar + sandal.
    BodyKit.limb(bone: 'rightUpperLeg', z: 3, len: 62, rTop: 7.6, rBottom: 6.8, fillSlot: 'bottom'),
    Part2D(bone: 'rightLowerLeg', z: 3, build: (ctx) => _salwarShin()),
    Part2D(bone: 'rightFoot', z: 3.4, build: (ctx) => BodyKit.sandalShapes()),
    // Near leg.
    BodyKit.limb(bone: 'leftUpperLeg', z: 5, len: 62, rTop: 7.9, rBottom: 7.0, fillSlot: 'bottom'),
    Part2D(bone: 'leftLowerLeg', z: 5, build: (ctx) => _salwarShin()),
    Part2D(bone: 'leftFoot', z: 5.4, build: (ctx) => BodyKit.sandalShapes()),
    // Kameez + dupatta.
    BodyKit.pelvis(z: 6.2, half: 17, bottom: 20),
    BodyKit.torso(z: 7, hemY: -58, hemHalf: 31, shoulderHalf: 22, trimSlot: 'accent', collarSlot: 'accent'),
    // Neck + head + hair.
    BodyKit.neck(z: 0.5),
    Part2D(bone: 'head', z: 9, build: (ctx) => _girlHead()),
    Part2D(bone: 'head', z: 10, build: (ctx) => _girlHairFront()),
    Part2D(bone: 'chest', z: 7.6, build: (ctx) => _dupatta()),
    // Near arm.
    BodyKit.limb(bone: 'leftUpperArm', z: 12, len: 44, rTop: 6.4, rBottom: 5.8),
    BodyKit.cuffedForearm(bone: 'leftLowerArm', z: 12, len: 46, r: 5.4, cuffH: 16),
    BodyKit.hand(bone: 'leftHand', z: 12),
  ];
}

List<Shape> _salwarShin() {
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -9, 0, 44, 6.4], fill: const SolidFillSlot('bottom'), stroke: 'outline', strokeWidth: 1.6),
    Shape(kind: ShapeKind.ellipse, args: [0, 44, 4.6, 4.0], fill: const SolidFillSlot('bottom'), stroke: 'outline', strokeWidth: 1.5),
    Shape(kind: ShapeKind.capsule, args: [0, 46, 0, 53, 3.0], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.5),
  ];
}

List<Shape> _girlHead() {
  final skull = PathBuilder()
    ..move(-14.5, 20)
    ..quad(-16, 2, 0, 2)
    ..quad(16, 2, 14.5, 20)
    ..quad(13.5, 46, 0, 49)
    ..quad(-13.5, 46, -14.5, 20)
    ..close();
  return [
    skull.build(fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.8),
    Shape(kind: ShapeKind.ellipse, args: [-19.5, 27, 3.4, 5.0], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.5),
    Shape(kind: ShapeKind.ellipse, args: [19.5, 27, 3.4, 5.0], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.5),
    Shape(kind: ShapeKind.ellipse, args: [0, 21, 2.9, 3.5], fill: const SolidFillSlot('skinShade'), stroke: 'outline', strokeWidth: 1.4),
    Shape(kind: ShapeKind.ellipse, args: [-13.5, 20, 4.2, 2.8], fill: const SolidFillSlot('cheek')),
    Shape(kind: ShapeKind.ellipse, args: [13.5, 20, 4.2, 2.8], fill: const SolidFillSlot('cheek')),
  ];
}

List<Shape> _girlHairBack() {
  final out = <Shape>[
    Shape(kind: ShapeKind.ellipse, args: [0, 27, 23.5, 25], fill: const SolidFillSlot('hair'), stroke: 'outline', strokeWidth: 1.7),
  ];
  for (final s in [-1, 1]) {
    out.addAll([
      Shape(kind: ShapeKind.capsule, args: [s * 17.0, 20.0, s * 21.5, 4.0, 5.4], fill: const SolidFillSlot('hair'), stroke: 'outline', strokeWidth: 1.5),
      Shape(kind: ShapeKind.capsule, args: [s * 21.5, 4.0, s * 23.5, -9.0, 4.6], fill: const SolidFillSlot('hair'), stroke: 'outline', strokeWidth: 1.5),
      Shape(kind: ShapeKind.ellipse, args: [s * 23.5, -11.5, 4.0, 3.2], fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.4),
      Shape(kind: ShapeKind.ellipse, args: [s * 24.5, -16, 2.6, 3.6], fill: const SolidFillSlot('hair'), stroke: 'outline', strokeWidth: 1.3),
    ]);
  }
  return out;
}

List<Shape> _girlHairFront() {
  final bangs = PathBuilder()
    ..move(-20, 35)
    ..quad(-20, 51, 0, 52.5)
    ..quad(20, 51, 20, 35)
    ..quad(15, 39.5, 12, 36)
    ..quad(8, 42, 4, 37)
    ..quad(0, 43, -4, 37)
    ..quad(-8, 42, -12, 36)
    ..quad(-15, 39.5, -20, 35)
    ..close();
  return [bangs.build(fill: const SolidFillSlot('hair'))];
}

List<Shape> _dupatta() {
  Shape drape(bool left) {
    final b = PathBuilder();
    if (left) {
      b
        ..move(-17, 17)
        ..quad(-19, -12, -6, -50)
        ..line(1, -47)
        ..quad(-10, -14, -10, 16)
        ..close();
    } else {
      b
        ..move(17, 17)
        ..quad(19, -12, 6, -50)
        ..line(-1, -47)
        ..quad(10, -14, 10, 16)
        ..close();
    }
    return b.build(fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.5, opacity: 0.97);
  }
  return [drape(true), drape(false)];
}
