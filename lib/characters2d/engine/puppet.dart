import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/character_catalog.dart';
import 'clips.dart' show idlePose;
import 'palette_resolver.dart';
import 'animator2d.dart';
import 'face_rig.dart';
import 'part2d.dart';
import '../props.dart';
import 'rig2d.dart';
import 'shapes.dart';

/// Paints one fully assembled puppet from a solved frame. Pure Shape-DSL
/// rendering: identical output to the SVG/HTML export.
class PuppetPainter extends CustomPainter {
  PuppetPainter({
    required this.spec,
    required this.resolver,
    required this.accessories,
    required this.frameGetter,
    this.directionLeft = false,
    this.background,
    this.showGroundShadow = true,
    this.designSpace = const Size(360, 340),
    this.fit = BoxFit.contain,
    this.props = const [],
    super.repaint,
  }) : parts = orderParts([
          ...spec.build(accessories),
          // Props ride the same part pipeline: bound to their bone, z-ordered
          // with the body, mirrored with the rig — animation comes free.
          for (final p in props)
            if (p.visible) propPart(p),
        ]);

  final Character2DSpec spec;
  final PaletteResolver resolver;
  final Set<String> accessories;
  final PuppetFrameData Function() frameGetter;
  final bool directionLeft;
  final Color? background;
  final bool showGroundShadow;

  /// Bone-attached props (§6). See [propPart].
  final List<PropAttachment> props;

  /// Logical design space mapped into the canvas (centered horizontally,
  /// baseline anchored near the bottom).
  final Size designSpace;
  final BoxFit fit;

  final List<Part2D> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frameGetter();

    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background!);
    }

    final s = fit == BoxFit.contain ? math.min(size.width / designSpace.width, size.height / designSpace.height) : size.height / designSpace.height;
    final cx = size.width / 2;
    final groundY = size.height - 14.0;

    canvas.save();
    canvas.translate(cx, groundY);
    canvas.scale(s, s);

    if (showGroundShadow) {
      // Soft contact shadow at the ground line (parts are drawn with feet at
      // y=0, so the shadow belongs just under them — previously it floated
      // at mid-body height, hidden inside the silhouette).
      final lying = frame.pose.bodyTilt.abs() / 84;
      final w = 46 + lying * 52;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(frame.pose.dx, -4), width: w, height: 9),
        Paint()..color = const Color(0x2E000000),
      );
    }

    if (directionLeft) canvas.scale(-1, 1);

    // Rotate FIRST, then translate: the pose's (dx, dy) offsets are defined
    // in the body frame (e.g. sleep's dy=130 slides the lying body along its
    // own axis). Translating before rotating dumped sleeping characters below
    // the ground line, off-canvas.
    if (frame.pose.bodyTilt != 0) {
      canvas.rotate(frame.pose.bodyTilt * math.pi / 180);
    }
    canvas.translate(frame.pose.dx, frame.pose.dy);

    final faceView = FaceView(
      blink: frame.blink,
      lookX: frame.lookX,
      lookY: frame.lookY,
      browAngle: frame.face.browAngle,
      browLift: frame.face.browLift,
      browAsym: frame.face.browAsym,
      smile: frame.face.smile,
      mouthOpen: frame.face.mouthOpen,
      mouthW: frame.face.mouthW,
      teeth: frame.face.teeth,
      tongue: frame.face.tongue,
      squint: frame.face.squint,
      pupil: frame.face.pupil,
      tears: frame.face.tears,
      sweat: frame.face.sweat,
    );
    final ctx = ShapeCtx(colors: resolver, extras: frame.pose.extras, face: faceView);
    final rig = Rig2D.byKind(spec.rigKind);
    final ground = rig.groundY;

    for (final part in parts) {
      final joint = frame.solve.jointOf(part.bone);
      final angle = frame.solve.angleOf(part.bone);
      canvas.save();
      canvas.translate(joint.x, joint.y - ground);
      canvas.rotate(angle);
      for (final shape in part.build(ctx)) {
        paintShape(canvas, shape, resolver);
      }
      canvas.restore();
    }

    // Humanoid face overlay (tiger & PNG characters draw faces in parts).
    if (spec.faceStyle != null) {
      final hj = frame.solve.jointOf('head');
      final ha = frame.solve.angleOf('head');
      canvas.save();
      canvas.translate(hj.x, hj.y - ground);
      canvas.rotate(ha);
      for (final shape in faceShapes(spec.faceStyle!, faceView)) {
        paintShape(canvas, shape, resolver);
      }
      canvas.restore();
    }

    canvas.restore();

    if (frame.sleeping) _drawZzz(canvas, size, frame);
  }

  void _drawZzz(Canvas canvas, Size size, PuppetFrameData frame) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 3; i++) {
      final phase = (frame.time * 0.6 + i * 0.33) % 1.0;
      final a = math.sin(phase * math.pi);
      final fontSize = 10.0 + i * 5;
      tp.text = TextSpan(
        text: 'Z',
        style: TextStyle(color: Colors.white.withOpacity(0.85 * a), fontSize: fontSize, fontWeight: FontWeight.w700),
      );
      tp.layout();
      tp.paint(canvas, Offset(size.width / 2 + 34 + phase * 26, size.height - 205 - phase * 60 - i * 8));
    }
  }

  @override
  bool shouldRepaint(PuppetPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.resolver != resolver || oldDelegate.directionLeft != directionLeft || oldDelegate.background != background;
}

/// A frozen frame for thumbnails / library cards (neutral pose).
class StaticFrameSource {
  StaticFrameSource(this.rig, {this.t = 0.6, this.expr = Expr.neutral});

  final Rig2D rig;
  final double t;
  final Expr expr;

  PuppetFrameData call() {
    final pose = idlePose(t);
    final solve = solveSkeleton(rig, pose.angles);
    return PuppetFrameData(
      pose: pose,
      solve: solve,
      face: Expressions.all[expr]!,
      blink: 0,
      lookX: 0,
      lookY: 0,
      time: t,
      sleeping: false,
      talking: false,
    );
  }
}
