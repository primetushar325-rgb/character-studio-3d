import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small vector toolbox used by all character artwork. Everything is drawn in
/// rig units and stays crisp at any zoom — no raster assets.
class Draw {
  Draw._();

  static Paint fill(Color c) => Paint()..style = PaintingStyle.fill ..color = c;

  static Paint line(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = c;

  static Path capsulePath(Offset a, Offset b, double r) {
    final p = Path();
    p.addOval(Rect.fromCircle(center: a, radius: r));
    p.addOval(Rect.fromCircle(center: b, radius: r));
    final rect = Rect.fromPoints(
      Offset(math.min(a.dx, b.dx) , math.min(a.dy, b.dy)),
      Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy)),
    );
    // Connecting body: axis-aligned box works because limbs are drawn along
    // the local +Y axis inside their own bone frame.
    p.addRect(Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom));
    return p;
  }

  /// Rounded limb segment from [a] to [b] with optional outline.
  static void capsule(Canvas c, Offset a, Offset b, double r, Color color, {Color? outline, double ow = 1.6}) {
    final path = capsulePath(a, b, r);
    if (outline != null) {
      c.drawPath(path, fill(outline));
    }
    // Slightly inset fill so the outline reads as one stroke.
    final inner = capsulePath(a, b, r > 2 ? r - 0.9 : r);
    c.drawPath(inner, fill(color));
  }

  static void ellipse(Canvas c, Offset center, double rx, double ry, Color color, {Color? outline, double ow = 1.6}) {
    final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
    if (outline != null) c.drawOval(rect, fill(outline));
    c.drawOval(Rect.fromCenter(center: center, width: rx * 2 - 1.8, height: ry * 2 - 1.8), fill(color));
  }

  static void roundRect(Canvas c, Rect rect, double radius, Color color, {Color? outline}) {
    final r = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    if (outline != null) c.drawRRect(r, fill(outline));
    c.drawRRect(r.deflate(0.9), fill(color));
  }

  /// Simple two-tone checked fabric (lungi) inside [rect], drawn clipped.
  static void checks(Canvas c, Rect rect, Color base, Color check, {double size = 7}) {
    c.save();
    c.clipRect(rect);
    c.drawRect(rect, fill(base));
    final p = fill(check);
    for (var x = rect.left; x < rect.right; x += size) {
      for (var y = rect.top; y < rect.bottom; y += size) {
        final cx = ((x - rect.left) / size).floor();
        final cy = ((y - rect.top) / size).floor();
        if ((cx + cy) % 2 == 0) {
          c.drawRect(Rect.fromLTWH(x, y, size, size), p);
        }
      }
    }
    c.restore();
  }

  /// Fills an arbitrary path with a cartoon outline (inset fill).
  static void outlined(Canvas c, Path path, Color fill, Color outline, {double inset = 0.94}) {
    final b = path.getBounds();
    final cx = b.center.dx;
    final cy = b.center.dy;
    c.drawPath(path, Draw.fill(outline));
    c.save();
    c.translate(cx, cy);
    c.scale(inset);
    c.translate(-cx, -cy);
    c.drawPath(path, Draw.fill(fill));
    c.restore();
  }

  /// Quadratic curve helper.
  static void curve(Canvas c, Offset a, Offset cp, Offset b, Paint p) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(cp.dx, cp.dy, b.dx, b.dy);
    c.drawPath(path, p);
  }

  static double deg(double d) => d * math.pi / 180.0;
}

/// Hand shapes for gestures, drawn in the hand bone's local frame
/// (origin = wrist, +Y pointing out through the fingers).
class HandShapes {
  HandShapes._();

  static void draw(Canvas c, PaintCtxArgs a, String shape) {
    final skin = a.skin;
    final outline = a.outline;
    switch (shape) {
      case 'fist':
        Draw.ellipse(c, const Offset(0, 8), 7.5, 8, skin, outline: outline);
        break;
      case 'point':
        Draw.capsule(c, const Offset(0, 2), const Offset(0, 17), 6.5, skin, outline: outline);
        Draw.capsule(c, const Offset(0, 2), const Offset(0, 15), 3.2, skin);
        break;
      case 'thumb':
        Draw.ellipse(c, const Offset(0, 7), 7.5, 8, skin, outline: outline);
        Draw.capsule(c, const Offset(0, 6), const Offset(5, 12), 3.2, skin, outline: outline);
        break;
      case 'open':
      default:
        // Mitten palm + three finger bumps + thumb.
        Draw.ellipse(c, const Offset(0, 7), 8, 9, skin, outline: outline);
        for (var i = -1; i <= 1; i++) {
          Draw.ellipse(c, Offset(i * 4.4, 14 + (1 - i.abs()) * 1.5), 2.9, 4.2, skin, outline: outline);
        }
        Draw.ellipse(c, const Offset(6.5, 6), 3.0, 4.6, skin, outline: outline);
        break;
    }
  }
}

/// Minimal args so [HandShapes] stays decoupled from part painters.
class PaintCtxArgs {
  const PaintCtxArgs({required this.skin, required this.outline});
  final Color skin;
  final Color outline;
}
