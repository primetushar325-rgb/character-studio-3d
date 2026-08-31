import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/character_catalog.dart';
import '../art/palettes.dart';
import 'animator2d.dart';
import 'clips.dart' show idlePose;
import 'face_rig.dart';
import 'part2d.dart';
import 'rig2d.dart';

/// Paints one fully assembled puppet from a solved frame.
///
/// Everything is vector geometry, so the same painter serves live animation,
/// static thumbnails and library cards — always in sync with customization.
class PuppetPainter extends CustomPainter {
  PuppetPainter({
    required this.spec,
    required this.palette,
    required this.accessories,
    required this.frameGetter,
    required this.directionLeft,
    this.background,
    this.showGroundShadow = true,
    super.repaint,
  });

  final Character2DSpec spec;
  final PaletteColors palette;
  final Set<String> accessories;
  final PuppetFrameData Function() frameGetter;
  final bool directionLeft;
  final Color? background;
  final bool showGroundShadow;

  /// Parts are rebuilt only when colors/accessories actually change.
  List<Part2D>? _parts;
  PaletteColors? _partsPalette;
  Set<String>? _partsAccessories;

  static const double designHeight = 340;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frameGetter();

    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background!);
    }

    final s1 = size.shortestSide / designHeight;
    final s2 = (size.height - 30) / 300;
    final scale = math.min(s1, s2) * spec.scale;
    final cx = size.width / 2;
    final groundY = size.height - 14.0;

    canvas.save();
    canvas.translate(cx, groundY);
    canvas.scale(scale, scale);

    // Ground shadow.
    if (showGroundShadow) {
      final lying = frame.pose.bodyTilt.abs() / 84;
      final w = 42 + lying * 46;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(frame.pose.dx, Rig2D.groundY + 5), width: w, height: 9),
        Paint()..color = const Color(0x2E000000),
      );
    }

    // Mirror for direction = left.
    if (directionLeft) canvas.scale(-1, 1);

    canvas.translate(frame.pose.dx, frame.pose.dy);
    if (frame.pose.bodyTilt != 0) {
      canvas.rotate(frame.pose.bodyTilt * math.pi / 180);
    }

    final colors = palette;
    if (_parts == null || _partsPalette != palette || _partsAccessories!.length != accessories.length || !_partsAccessories!.containsAll(accessories)) {
      _parts = orderParts(spec.build(colors, accessories));
      _partsPalette = palette;
      _partsAccessories = {...accessories};
    }
    final pctx = PaintCtx(canvas: canvas, colors: colors, extras: frame.pose.extras, time: frame.time);

    for (final part in _parts!) {
      final joint = frame.solve.jointOf(part.bone);
      final angle = frame.solve.angleOf(part.bone);
      canvas.save();
      canvas.translate(joint.x, joint.y - Rig2D.groundY);
      canvas.rotate(angle);
      part.painter(pctx);
      canvas.restore();
    }

    // Face (in head frame).
    final hj = frame.solve.jointOf('head');
    final ha = frame.solve.angleOf('head');
    canvas.save();
    canvas.translate(hj.x, hj.y - Rig2D.groundY);
    canvas.rotate(ha);
    drawFace(
      canvas,
      spec.face,
      FaceRenderInput(
        params: frame.face,
        blink: frame.blink,
        lookX: frame.lookX,
        lookY: frame.lookY,
        talkWeight: frame.talking ? 1 : 0,
        time: frame.time,
      ),
      PaletteColorSet(skin: colors.skin, outline: colors.outline, hair: colors.hair),
    );
    canvas.restore();
    canvas.restore();

    // Sleep Zzz overlay (screen-space, unaffected by mirroring).
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
        style: TextStyle(
          color: Colors.white.withOpacity(0.85 * a),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(size.width / 2 + 34 + phase * 26, size.height - 205 - phase * 60 - i * 8));
    }
  }

  @override
  bool shouldRepaint(PuppetPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.palette != palette || oldDelegate.directionLeft != directionLeft || oldDelegate.background != background;
}

/// A frozen frame for thumbnails / library cards (neutral pose, soft idle).
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
