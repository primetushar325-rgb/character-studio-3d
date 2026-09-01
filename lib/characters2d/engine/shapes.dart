import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'face_rig.dart' show FaceStyle;
import 'palette_resolver.dart';

/// Portable vector shape DSL. Every character part is a list of [Shape]s so
/// the exact same artwork can be painted on Flutter Canvas, emitted as SVG
/// and embedded into the single-file HTML export — one source of truth.
enum ShapeKind { ellipse, capsule, rrect, path, poly, checks, image }

class Shape {
  const Shape({
    required this.kind,
    required this.args,
    this.fill = const SolidFillSlot('outline'),
    this.stroke,
    this.strokeWidth = 2.2,
    this.points = const [],
    this.opacity = 1,
  });

  final ShapeKind kind;

  /// Geometry numbers per kind:
  ///  ellipse: [cx, cy, rx, ry]
  ///  capsule: [ax, ay, bx, by, r]
  ///  rrect:   [left, top, width, height, radius]
  ///  poly:    points
  ///  path:    points + implied ops (see [PathBuilder])
  ///  checks:  [left, top, width, height, cell, baseSlot, checkSlot]
  ///  image:   [left, top, width, height] + [imageSlot] in points
  final List<double> args;
  final List<Offset> points;
  final FillSlot fill;
  final String? stroke;
  final double strokeWidth;
  final double opacity;
}

/// Fill reference: a palette slot resolved at paint time (never baked
/// colors), so customization recolors everything consistently.
abstract class FillSlot {
  const FillSlot(this.slot);
  final String slot;
}

class SolidFillSlot extends FillSlot {
  const SolidFillSlot(super.slot);
}

/// Fixed color fill (used for generic details like eye whites).
class ConstFill extends FillSlot {
  const ConstFill(super.slot, this.value);
  final Color value;
}

/// Dynamic face view handed to shape builders each frame.
class FaceView {
  const FaceView({
    this.blink = 0,
    this.lookX = 0,
    this.lookY = 0,
    this.browAngle = 0,
    this.browLift = 0,
    this.browAsym = 0,
    this.smile = 0,
    this.mouthOpen = 0,
    this.mouthW = 1,
    this.teeth = 0,
    this.tongue = 0,
    this.squint = 0,
    this.pupil = 1,
    this.tears = 0,
    this.sweat = 0,
  });

  final double blink;
  final double lookX;
  final double lookY;
  final double browAngle;
  final double browLift;
  final double browAsym;
  final double smile;
  final double mouthOpen;
  final double mouthW;
  final double teeth;
  final double tongue;
  final double squint;
  final double pupil;
  final double tears;
  final double sweat;
}

/// Builds multi-segment paths (move/line/quad).
class PathBuilder {
  final List<Offset> _pts = [];
  final List<String> _ops = [];

  void move(double x, double y) {
    _ops.add('M');
    _pts.add(Offset(x, y));
  }

  void line(double x, double y) {
    _ops.add('L');
    _pts.add(Offset(x, y));
  }

  void quad(double cx, double cy, double x, double y) {
    _ops.add('Q');
    _pts.add(Offset(cx, cy));
    _pts.add(Offset(x, y));
  }

  void close() => _ops.add('Z');

  DynShape build({FillSlot fill = const SolidFillSlot('outline'), String? stroke, double strokeWidth = 2.2, double opacity = 1}) =>
      DynShape(
        base: Shape(
          kind: ShapeKind.path,
          args: const [],
          points: _pts,
          fill: fill,
          stroke: stroke,
          strokeWidth: strokeWidth,
          opacity: opacity,
        ),
        ops: List.of(_ops),
      );
}

/// Resolves a fill slot to a concrete color.
Color resolveFill(FillSlot fill, PaletteResolver c) {
  if (fill is ConstFill) return fill.value;
  switch (fill.slot) {
    case 'skin':
      return c.get('skin', const Color(0xFF2B2523));
    case 'skinShade':
      return c.get('skinShade', const Color(0xFF2B2523));
    case 'hair':
      return c.get('hair', const Color(0xFF2B2523));
    case 'shirt':
      return c.get('shirt', const Color(0xFF2B2523));
    case 'shirtPattern':
      return c.get('shirtPattern', const Color(0xFF2B2523));
    case 'bottom':
      return c.get('bottom', const Color(0xFF2B2523));
    case 'accent':
      return c.get('accent', const Color(0xFF2B2523));
    case 'footwear':
      return c.get('footwear', const Color(0xFF2B2523));
    case 'outline':
      return c.get('outline', const Color(0xFF2B2523));
    case 'cheek':
      return c.get('cheek', const Color(0xFF2B2523));
    case 'glasses':
      return c.get('glasses', const Color(0xFF2B2523));
    case 'book':
      return c.get('book', const Color(0xFF2B2523));
    case 'white':
      return const Color(0xFFFFFFFF);
    case 'mouth':
      return const Color(0xFF57231F);
    case 'tongue':
      return const Color(0xFFD96A6A);
    case 'tear':
      return const Color(0x996EC9FF);
    default:
      return c.get('outline', const Color(0xFF2B2523));
  }
}

/// Paints one shape on a Flutter canvas (part-local frame, rig units).
void paintShape(Canvas canvas, Shape s, PaletteResolver colors) {
  var fillColor = resolveFill(s.fill, colors);
  if (s.opacity < 1) fillColor = fillColor.withOpacity(fillColor.opacity * s.opacity);
  final strokeColor = s.stroke == null ? null : resolveFill(SolidFillSlot(s.stroke!), colors);
  final strokePaint = strokeColor == null
      ? null
      : (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.strokeWidth * 2
          ..strokeJoin = StrokeJoin.round
          ..color = strokeColor);
  final fillPaint = Paint()..color = fillColor;

  switch (s.kind) {
    case ShapeKind.ellipse:
      final cx = s.args[0], cy = s.args[1], rx = s.args[2], ry = s.args[3];
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
      strokePaint?.let((p) => canvas.drawOval(rect.inflate(s.strokeWidth * 0.5), p));
      canvas.drawOval(rect, fillPaint);
    case ShapeKind.capsule:
      final a = Offset(s.args[0], s.args[1]);
      final b = Offset(s.args[2], s.args[3]);
      final r = s.args[4];
      final path = capsuleGeom(a, b, r);
      strokePaint?.let((p) => canvas.drawPath(path, p));
      canvas.drawPath(path, fillPaint);
    case ShapeKind.rrect:
      final rect = Rect.fromLTWH(s.args[0], s.args[1], s.args[2], s.args[3]);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(s.args[4]));
      strokePaint?.let((p) => canvas.drawRRect(rr.inflate(s.strokeWidth * 0.5), p));
      canvas.drawRRect(rr, fillPaint);
    case ShapeKind.poly:
      final path = Path()..addPolygon(s.points, true);
      strokePaint?.let((p) => canvas.drawPath(path, p));
      canvas.drawPath(path, fillPaint);
    case ShapeKind.path:
      final path = Path();
      var i = 0;
      for (final op in (s as DynShape).ops) {
        switch (op) {
          case 'M':
            path.moveTo(s.points[i].dx, s.points[i].dy);
            i++;
          case 'L':
            path.lineTo(s.points[i].dx, s.points[i].dy);
            i++;
          case 'Q':
            path.quadraticBezierTo(s.points[i].dx, s.points[i].dy, s.points[i + 1].dx, s.points[i + 1].dy);
            i += 2;
          case 'Z':
            path.close();
        }
      }
      strokePaint?.let((p) => canvas.drawPath(path, p));
      canvas.drawPath(path, fillPaint);
    case ShapeKind.checks:
      final rect = Rect.fromLTWH(s.args[0], s.args[1], s.args[2], s.args[3]);
      final base = colors.get('bottom', const Color(0xFF3E5F8A));
      final check = colors.get('shirtPattern', const Color(0xFFDCE4EE));
      canvas.save();
      canvas.clipRect(rect);
      canvas.drawRect(rect, Paint()..color = base);
      final cell = s.args[4];
      final p = Paint()..color = check;
      for (var x = rect.left; x < rect.right; x += cell) {
        for (var y = rect.top; y < rect.bottom; y += cell) {
          final ix = ((x - rect.left) / cell).floor();
          final iy = ((y - rect.top) / cell).floor();
          if ((ix + iy) % 2 == 0) {
            canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), p);
          }
        }
      }
      canvas.restore();
    case ShapeKind.image:
      // Raster layers (imported PNG characters) paint via ui.Image in the
      // scene renderer; SVG/HTML use the data URI directly.
      final image = (s as DynShape).image;
      if (image != null) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(s.args[0], s.args[1], s.args[2], s.args[3]),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
  }
}

/// Convenience: shape with attachable runtime data (path ops / image).
class DynShape extends Shape {
  DynShape({
    required Shape base,
    this.ops = const [],
    this.image,
    this.imageDataUri,
  }) : super(
          kind: base.kind,
          args: base.args,
          points: base.points,
          fill: base.fill,
          stroke: base.stroke,
          strokeWidth: base.strokeWidth,
          opacity: base.opacity,
        );

  final List<String> ops;
  final dynamic image;
  final String? imageDataUri;
}

Path capsuleGeom(Offset a, Offset b, double r) {
  // Capsule as one octagon-ish rounded polygon (works for any angle).
  final d = (b - a);
  final len = d.distance;
  if (len < 0.001) {
    return Path()..addOval(Rect.fromCircle(center: a, radius: r));
  }
  final dir = d / len;
  final n = Offset(-dir.dy, dir.dx);
  final path = Path();
  final c1 = a + n * r;
  final c2 = b + n * r;
  final c3 = b - n * r;
  final c4 = a - n * r;
  path.moveTo(c1.dx, c1.dy);
  path.arcTo(Rect.fromCircle(center: a, radius: r), _angleOf(dir), _swing(n, dir), false);
  path.lineTo(c2.dx, c2.dy);
  path.arcTo(Rect.fromCircle(center: b, radius: r), _angleOf(n), _swing2(n, dir), false);
  path.lineTo(c3.dx, c3.dy);
  path.arcTo(Rect.fromCircle(center: b, radius: r), _angleOf(-dir), _swing(-n, dir), false);
  path.lineTo(c4.dx, c4.dy);
  path.arcTo(Rect.fromCircle(center: a, radius: r), _angleOf(-n), _swing2(-n, -dir), false);
  path.close();
  return path;
}

double _angleOf(Offset v) => math.atan2(v.dy, v.dx);
double _swing(Offset n, Offset dir) {
  final a = _angleOf(dir) - _angleOf(n);
  return _norm(a);
}

double _swing2(Offset n, Offset dir) {
  final a = _angleOf(dir) - _angleOf(n);
  return _norm(a);
}

double _norm(double a) {
  while (a < -math.pi) {
    a += 2 * math.pi;
  }
  while (a > math.pi) {
    a -= 2 * math.pi;
  }
  return a;
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

// ---------------------------------------------------------------------------
// Shared reusable shape groups (limbs, torso, face) — used by every character
// and mirrored 1:1 in the HTML export engine.
// ---------------------------------------------------------------------------

List<Shape> limbShapes({
  required double len,
  required double rTop,
  required double rBottom,
  String fillSlot = 'shirt',
  double topOverlap = 9,
  double bottomOverlap = 9,
}) {
  final midY = len * 0.42;
  return [
    Shape(kind: ShapeKind.capsule, args: [0, -topOverlap, 0, midY, rTop], fill: SolidFillSlot(fillSlot), stroke: 'outline', strokeWidth: 1.6),
    Shape(kind: ShapeKind.capsule, args: [0, midY, 0, len + bottomOverlap, rBottom], fill: SolidFillSlot(fillSlot), stroke: 'outline', strokeWidth: 1.6),
  ];
}

List<Shape> handShapes2(String shapeCode) {
  switch (shapeCode) {
    case 'fist':
      return [Shape(kind: ShapeKind.ellipse, args: [0, 8, 7.5, 8], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.6)];
    case 'point':
      return [
        Shape(kind: ShapeKind.capsule, args: [0, 2, 0, 17, 6.5], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.capsule, args: [0, 2, 0, 15, 3.2], fill: const SolidFillSlot('skin')),
      ];
    case 'thumb':
      return [
        Shape(kind: ShapeKind.ellipse, args: [0, 7, 7.5, 8], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.capsule, args: [0, 6, 5, 12, 3.2], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.4),
      ];
    default: // open
      return [
        Shape(kind: ShapeKind.ellipse, args: [0, 7, 8, 9], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.ellipse, args: [-4.4, 14, 2.9, 4.2], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.3),
        Shape(kind: ShapeKind.ellipse, args: [0, 15.5, 2.9, 4.4], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.3),
        Shape(kind: ShapeKind.ellipse, args: [4.4, 14, 2.9, 4.2], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.3),
        Shape(kind: ShapeKind.ellipse, args: [6.5, 6, 3.0, 4.6], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.3),
      ];
  }
}

/// The complete face as dynamic shapes, in the head-bone local frame
/// (+Y up). Shared by humans AND the tiger-style muzzle faces.
List<Shape> faceShapes(FaceStyle style, FaceView f) {
  final out = <Shape>[];
  final lid = math.max(f.blink, 0.0);
  final closed = f.squint > 0.55 || lid > 0.8;
  final lookX = f.lookX.clamp(-1.0, 1.0);
  final lookY = f.lookY.clamp(-1.0, 1.0);

  for (var side = -1; side <= 1; side += 2) {
    final cx = side * style.eyeDx;
    final cy = style.eyeY;
    if (closed) {
      final happy = f.squint > 0.55;
      final dip = happy ? 3.0 : -2.0;
      final pb = PathBuilder()
        ..move(cx - style.eyeRx, cy - dip * 0.4)
        ..quad(cx, cy - dip, cx + style.eyeRx, cy - dip * 0.4);
      out.add(pb.build(fill: const SolidFillSlot('outline'), strokeWidth: 1.6));
    } else {
      out.add(Shape(kind: ShapeKind.ellipse, args: [cx, cy, style.eyeRx, style.eyeRy], fill: const ConstFill('white', Color(0xFFFFFFFF)), stroke: 'outline', strokeWidth: 1.4));
      out.add(Shape(kind: ShapeKind.ellipse, args: [cx + lookX * style.eyeRx * 0.45, cy - lookY * style.eyeRy * 0.4, 2.6 * f.pupil, 2.6 * f.pupil], fill: const SolidFillSlot('outline')));
      if (lid > 0.02) {
        final h = style.eyeRy * 2 * lid;
        // Lid: skin rect clipped — approximate with a skin ellipse band.
        out.add(DynShape(
          base: Shape(kind: ShapeKind.ellipse, args: [cx, cy - style.eyeRy + h / 2, style.eyeRx + 0.8, h / 2 + 0.6], fill: const SolidFillSlot('skin')),
        ));
        final pb = PathBuilder()
          ..move(cx - style.eyeRx, cy - style.eyeRy + h)
          ..quad(cx, cy - style.eyeRy + h + 1.2, cx + style.eyeRx, cy - style.eyeRy + h);
        out.add(pb.build(fill: const SolidFillSlot('outline'), strokeWidth: 1.1));
      }
    }
    // Brow.
    final lift = f.browLift + (side > 0 ? f.browAsym : 0);
    final y = style.browY + lift;
    final inner = Offset(side * 2.8, y - f.browAngle * 0.16);
    final outer = Offset(side * (style.eyeDx + style.browLen * 0.7), y + 1.0);
    final pb = PathBuilder()
      ..move(inner.dx, inner.dy)
      ..quad((inner.dx + outer.dx) / 2, y + 1.8, outer.dx, outer.dy);
    out.add(pb.build(fill: const SolidFillSlot('hair'), strokeWidth: style.browThick * 0.5));
  }

  // Mouth.
  final mw = style.mouthW * f.mouthW;
  if (f.mouthOpen > 0.04) {
    final rx = mw * (0.85 + f.mouthOpen * 0.35);
    final ry = 1.6 + f.mouthOpen * 7.2;
    out.add(Shape(kind: ShapeKind.ellipse, args: [0, style.mouthY - f.mouthOpen * 1.5, rx, ry], fill: const ConstFill('mouth', Color(0xFF57231F)), stroke: 'outline', strokeWidth: 1.4));
    if (f.teeth > 0.05) {
      out.add(Shape(kind: ShapeKind.ellipse, args: [0, style.mouthY - f.mouthOpen * 1.5 - ry * 0.7, rx * 0.8, ry * 0.5], fill: const ConstFill('white', Color(0xFFFFFFFF))));
    }
    if (f.tongue > 0.05) {
      out.add(Shape(kind: ShapeKind.ellipse, args: [0, style.mouthY - f.mouthOpen * 1.5 + ry * 0.5, rx * 0.55, ry * 0.5], fill: const ConstFill('tongue', Color(0xFFD96A6A))));
    }
  } else {
    final cornerY = style.mouthY - f.smile * 3.6;
    final midY = style.mouthY + f.smile * 2.2 - 0.6;
    final pb = PathBuilder()
      ..move(-mw * 0.8, cornerY)
      ..quad(0, midY, mw * 0.8, cornerY);
    out.add(pb.build(fill: const ConstFill('mouth', Color(0xFF57231F)), strokeWidth: 1.1));
  }

  if (f.tears > 0.05) {
    out.add(Shape(kind: ShapeKind.ellipse, args: [-style.eyeDx - 2.4, style.eyeY - 8, 1.7, 2.6], fill: const ConstFill('tear', Color(0x996EC9FF))));
    out.add(Shape(kind: ShapeKind.ellipse, args: [style.eyeDx + 2.4, style.eyeY - 8, 1.7, 2.6], fill: const ConstFill('tear', Color(0x996EC9FF))));
  }
  if (f.sweat > 0.05) {
    out.add(Shape(kind: ShapeKind.ellipse, args: [style.eyeDx + 8, style.browY - 3, 2.2, 3.2], fill: const ConstFill('tear', Color(0xB36EC9FF))));
  }
  return out;
}
