import '../engine/part2d.dart';
import '../engine/shapes.dart';
import 'body_kit.dart';

/// CHARACTER 01 — BD Farmer Male (35–45). Broad build, off-white shirt with
/// rolled sleeves, checked lungi, gamcha sash, moustache, close-cropped hair.
List<Part2D> buildFarmerParts() {
  return [
    // Far arm (character-right).
    BodyKit.limb(bone: 'rightUpperArm', z: 2, len: 44, rTop: 7.2, rBottom: 6.4),
    BodyKit.cuffedForearm(bone: 'rightLowerArm', z: 2, len: 46, r: 5.8),
    BodyKit.hand(bone: 'rightHand', z: 2, extraKey: 'handR'),
    // Far leg.
    BodyKit.limb(bone: 'rightUpperLeg', z: 3, len: 62, rTop: 9.0, rBottom: 8.2, fillSlot: 'bottom'),
    BodyKit.limb(bone: 'rightLowerLeg', z: 3, len: 58, rTop: 6.0, rBottom: 4.8, fillSlot: 'skin'),
    Part2D(bone: 'rightFoot', z: 3.4, build: (ctx) => BodyKit.sandalShapes()),
    // Near leg.
    BodyKit.limb(bone: 'leftUpperLeg', z: 5, len: 62, rTop: 9.4, rBottom: 8.4, fillSlot: 'bottom'),
    BodyKit.limb(bone: 'leftLowerLeg', z: 5, len: 58, rTop: 6.2, rBottom: 5.0, fillSlot: 'skin'),
    Part2D(bone: 'leftFoot', z: 5.4, build: (ctx) => BodyKit.sandalShapes()),
    // Lungi + torso.
    BodyKit.lungi(),
    BodyKit.torso(z: 7, hemY: -46, hemHalf: 25, shoulderHalf: 29, collarSlot: 'shirtPattern'),
    // Neck + head + hair.
    BodyKit.neck(z: 0.5),
    Part2D(bone: 'head', z: 9, build: (ctx) => _farmerHead()),
    Part2D(bone: 'head', z: 10, build: (ctx) => _farmerHair()),
    // Gamcha sash on chest.
    Part2D(bone: 'chest', z: 7.5, build: (ctx) => _gamcha()),
    // Near arm.
    BodyKit.limb(bone: 'leftUpperArm', z: 12, len: 44, rTop: 7.4, rBottom: 6.6),
    BodyKit.cuffedForearm(bone: 'leftLowerArm', z: 12, len: 46, r: 6.0),
    BodyKit.hand(bone: 'leftHand', z: 12),
  ];
}

List<Shape> _farmerHead() {
  final skull = PathBuilder()
    ..move(-14, 21)
    ..quad(-15.5, 3, 0, 3)
    ..quad(15.5, 3, 14, 21)
    ..quad(13, 44, 0, 51)
    ..quad(-13, 44, -14, 21)
    ..close();
  final out = <Shape>[
    skull.build(fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.8),
    Shape(kind: ShapeKind.ellipse, args: [-20.5, 28, 3.6, 5.2], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.5),
    Shape(kind: ShapeKind.ellipse, args: [20.5, 28, 3.6, 5.2], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.5),
    // Bulbous nose.
    Shape(kind: ShapeKind.ellipse, args: [0, 21, 3.8, 4.6], fill: const SolidFillSlot('skinShade'), stroke: 'outline', strokeWidth: 1.5),
    // Friendly moustache.
    (PathBuilder()
        ..move(0, 17)
        ..quad(-5, 14.6, -9.5, 16.4)).build(fill: const SolidFillSlot('hair'), strokeWidth: 1.7),
    (PathBuilder()
        ..move(0, 17)
        ..quad(5, 14.6, 9.5, 16.4)).build(fill: const SolidFillSlot('hair'), strokeWidth: 1.7),
    Shape(kind: ShapeKind.ellipse, args: [-14, 21, 3.6, 2.4], fill: const SolidFillSlot('cheek')),
    Shape(kind: ShapeKind.ellipse, args: [14, 21, 3.6, 2.4], fill: const SolidFillSlot('cheek')),
  ];
  return out;
}

List<Shape> _farmerHair() {
  final fringe = PathBuilder()
    ..move(-20, 36)
    ..quad(-19, 52, 0, 53.5)
    ..quad(19, 52, 20, 36)
    ..quad(14, 41, 10, 37.5)
    ..quad(5, 43, 0, 39)
    ..quad(-5, 43, -10, 37.5)
    ..quad(-14, 41, -20, 36)
    ..close();
  return [
    fringe.build(fill: const SolidFillSlot('hair')),
    Shape(kind: ShapeKind.rrect, args: [-22, 28, 4.4, 11, 2], fill: const SolidFillSlot('hair')),
    Shape(kind: ShapeKind.rrect, args: [17.6, 28, 4.4, 11, 2], fill: const SolidFillSlot('hair')),
  ];
}

List<Shape> _gamcha() {
  final band = PathBuilder()
    ..move(15, 18)
    ..line(22, 15)
    ..line(-10, -42)
    ..line(-17, -38)
    ..close();
  final tail = PathBuilder()
    ..move(-17, -38)
    ..line(-10, -42)
    ..line(-14, -58)
    ..quad(-13, -62, -8, -61)
    ..line(-13, -44)
    ..close();
  return [
    band.build(fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.7),
    tail.build(fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.6),
  ];
}
