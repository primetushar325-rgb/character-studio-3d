import 'package:flutter/material.dart';

import '../engine/part2d.dart';
import '../engine/shapes.dart';
import 'body_kit.dart';

/// CHARACTER 03 — Bangladeshi School Teacher (30–45). Slim formal look:
/// light tucked-in shirt, dark trousers, black rectangular glasses, neat
/// moustache, notebook prop.
List<Part2D> buildTeacherParts() {
  return [
    // Far arm: full sleeve.
    BodyKit.limb(bone: 'rightUpperArm', z: 2, len: 44, rTop: 6.6, rBottom: 6.0),
    BodyKit.limb(bone: 'rightLowerArm', z: 2, len: 40, rTop: 5.6, rBottom: 5.0),
    BodyKit.hand(bone: 'rightHand', z: 2, extraKey: 'handR'),
    // Far leg.
    BodyKit.limb(bone: 'rightUpperLeg', z: 3, len: 62, rTop: 7.6, rBottom: 6.8, fillSlot: 'bottom'),
    BodyKit.limb(bone: 'rightLowerLeg', z: 3, len: 58, rTop: 5.6, rBottom: 4.6, fillSlot: 'bottom'),
    Part2D(bone: 'rightFoot', z: 3.4, build: (ctx) => BodyKit.shoeShapes()),
    // Near leg.
    BodyKit.limb(bone: 'leftUpperLeg', z: 5, len: 62, rTop: 7.8, rBottom: 7.0, fillSlot: 'bottom'),
    BodyKit.limb(bone: 'leftLowerLeg', z: 5, len: 58, rTop: 5.8, rBottom: 4.8, fillSlot: 'bottom'),
    Part2D(bone: 'leftFoot', z: 5.4, build: (ctx) => BodyKit.shoeShapes()),
    // Pelvis + tucked shirt.
    BodyKit.pelvis(z: 6.2, half: 19, bottom: 22),
    BodyKit.torso(z: 7, hemY: -40, hemHalf: 22, shoulderHalf: 26, buttons: true, belt: true, collarSlot: 'shirtPattern'),
    // Neck + head.
    BodyKit.neck(z: 0.5),
    Part2D(bone: 'head', z: 9, build: (ctx) => _teacherHead()),
    Part2D(bone: 'head', z: 10, build: (ctx) => _teacherHair()),
    // Glasses (front layer).
    Part2D(bone: 'head', z: 1, layer: PartLayer.front, build: (ctx) => _glasses()),
    // Notebook in the near hand.
    Part2D(bone: 'leftHand', z: 2, layer: PartLayer.front, build: (ctx) => _book()),
    // Near arm.
    BodyKit.limb(bone: 'leftUpperArm', z: 12, len: 44, rTop: 6.8, rBottom: 6.2),
    BodyKit.limb(bone: 'leftLowerArm', z: 12, len: 40, rTop: 5.8, rBottom: 5.2),
    BodyKit.hand(bone: 'leftHand', z: 12),
  ];
}

List<Shape> _teacherHead() {
  final skull = PathBuilder()
    ..move(-14, 22)
    ..quad(-15.5, 4, 0, 4)
    ..quad(15.5, 4, 14, 22)
    ..quad(12.5, 46, 0, 50)
    ..quad(-12.5, 46, -14, 22)
    ..close();
  return [
    skull.build(fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.8),
    Shape(kind: ShapeKind.ellipse, args: [-19, 27, 3.4, 5.0], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.5),
    Shape(kind: ShapeKind.ellipse, args: [19, 27, 3.4, 5.0], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.5),
    Shape(kind: ShapeKind.ellipse, args: [0, 21, 3.1, 4.0], fill: const SolidFillSlot('skinShade'), stroke: 'outline', strokeWidth: 1.5),
    (PathBuilder()
        ..move(0, 17)
        ..quad(-4, 15.4, -7.5, 16.6)).build(fill: const SolidFillSlot('hair'), strokeWidth: 1.5),
    (PathBuilder()
        ..move(0, 17)
        ..quad(4, 15.4, 7.5, 16.6)).build(fill: const SolidFillSlot('hair'), strokeWidth: 1.5),
  ];
}

List<Shape> _teacherHair() {
  final sweep = PathBuilder()
    ..move(-19.5, 38)
    ..quad(-19, 52, 0, 53)
    ..quad(19, 52, 19.5, 37)
    ..quad(12, 44, 2, 44.5)
    ..quad(-9, 45, -13, 40)
    ..quad(-16, 38.5, -19.5, 38)
    ..close();
  return [
    sweep.build(fill: const SolidFillSlot('hair')),
    Shape(kind: ShapeKind.rrect, args: [-21.5, 28, 4, 10, 2], fill: const SolidFillSlot('hair')),
    Shape(kind: ShapeKind.rrect, args: [17.5, 28, 4, 10, 2], fill: const SolidFillSlot('hair')),
  ];
}

List<Shape> _glasses() {
  const eyeDx = 8.4;
  const eyeY = 29;
  final bridge = PathBuilder()
    ..move(-eyeDx + 6.6, eyeY - 1.5)
    ..line(eyeDx - 6.6, eyeY - 1.5);
  return [
    Shape(kind: ShapeKind.rrect, args: [-eyeDx - 6.6, eyeY - 5.2, 13.2, 10.4, 2.6], fill: ConstFill('none', Color(0x00000000)), stroke: 'glasses', strokeWidth: 1.0),
    Shape(kind: ShapeKind.rrect, args: [eyeDx - 6.6, eyeY - 5.2, 13.2, 10.4, 2.6], fill: ConstFill('none', Color(0x00000000)), stroke: 'glasses', strokeWidth: 1.0),
    bridge.build(fill: ConstFill('none', Color(0x00000000)), stroke: 'glasses', strokeWidth: 1.0),
  ];
}

List<Shape> _book() {
  final cover = PathBuilder()
    ..move(-9, 2)
    ..line(9, 2)
    ..line(9, 15)
    ..quad(0, 17.5, -9, 15)
    ..close();
  return [
    cover.build(fill: const SolidFillSlot('book'), stroke: 'outline', strokeWidth: 1.7),
    Shape(kind: ShapeKind.rrect, args: [-7.6, 3.2, 15.2, 10.6, 1.5], fill: ConstFill('paper', Color(0xFFF7F4EC))),
    for (var i = 0; i < 3; i++)
      (PathBuilder()
          ..move(-5.5, 5.2 + i * 2.6)
          ..line(5.5, 5.2 + i * 2.6)).build(fill: ConstFill('line', Color(0xFFB9B2A4)), strokeWidth: 0.5),
  ];
}
