import 'package:flutter/material.dart';

import '../engine/part2d.dart';
import 'draw_utils.dart';

/// Shared humanoid part builders. Every character uses these with different
/// geometry/colors so all three share one art universe yet stay distinct.
class BodyKit {
  BodyKit._();

  /// Limb capsule with joint overlap so rotations never show gaps.
  static Part2D limb({
    required String bone,
    required double z,
    required double len,
    required double rTop,
    required double rBottom,
    required Color color,
    required Color outline,
    double topOverlap = 9,
    double bottomOverlap = 9,
    PartLayer layer = PartLayer.body,
  }) {
    return Part2D(
      bone: bone,
      z: z,
      layer: layer,
      painter: (ctx) {
        final c = ctx.canvas;
        final path = Draw.capsulePath(Offset(0, -topOverlap), Offset(0, len + bottomOverlap), rTop);
        // Tapered limb: draw as stacked capsules from thin to thick.
        c.drawPath(path, Draw.fill(outline));
        final mid = Draw.capsulePath(Offset(0, -topOverlap + 1), Offset(0, len + bottomOverlap - 1), rTop - 0.9);
        c.drawPath(mid, Draw.fill(color));
        if (rBottom != rTop) {
          // Lower half tapers.
          c.save();
          c.clipRect(Rect.fromLTWH(-rTop - 2, len * 0.45, rTop * 2 + 4, len + rTop + 6));
          final lower = Draw.capsulePath(Offset(0, len * 0.35), Offset(0, len + bottomOverlap - 1), rBottom - 0.9);
          c.drawPath(lower, Draw.fill(color));
          c.restore();
        }
      },
    );
  }

  /// Torso shirt drawn on the chest bone (+Y up, hips at y ≈ -38).
  static Part2D torso({
    required double z,
    required double hemY,
    required double hemHalf,
    required double shoulderHalf,
    required Color color,
    required Color outline,
    Color? trim,
    Color? collar,
    bool buttons = false,
    bool belt = false,
    Color? beltColor,
  }) {
    return Part2D(
      bone: 'chest',
      z: z,
      painter: (ctx) {
        final c = ctx.canvas;
        final path = Path()
          ..moveTo(-hemHalf, hemY)
          ..lineTo(-shoulderHalf, 14)
          ..quadraticBezierTo(-shoulderHalf - 3, 20, -shoulderHalf + 5, 21)
          ..lineTo(shoulderHalf - 5, 21)
          ..quadraticBezierTo(shoulderHalf + 3, 20, shoulderHalf, 14)
          ..lineTo(hemHalf, hemY)
          ..quadraticBezierTo(0, hemY - 6, -hemHalf, hemY)
          ..close();
        c.drawPath(path, Draw.fill(outline));
        c.drawPath(path.shift(const Offset(0, 0)), Draw.fill(color)); // slight overlap ok
        if (trim != null) {
          c.save();
          c.clipPath(path);
          c.drawRect(Rect.fromLTRB(-hemHalf - 4, hemY - 1, hemHalf + 4, hemY + 5.5), Draw.fill(trim));
          c.restore();
        }
        if (belt) {
          c.save();
          c.clipPath(path);
          c.drawRect(Rect.fromLTRB(-hemHalf - 4, hemY + 6, hemHalf + 4, hemY + 12), Draw.fill(beltColor ?? outline));
          c.restore();
        }
        // Collar band.
        final col = collar ?? color;
        Draw.curve(c, const Offset(-7, 21), const Offset(0, 15), const Offset(7, 21), Draw.line(outline, 3.2));
        Draw.curve(c, const Offset(-7, 21), const Offset(0, 15.4), const Offset(7, 21), Draw.line(col, 1.9));
        if (buttons) {
          final p = Draw.line(outline, 1.2);
          for (var y = 8.0; y > hemY + 8; y -= 10) {
            c.drawCircle(Offset(0, y), 1.1, Draw.fill(outline));
            c.drawLine(Offset(0, y), Offset(0, y + 0.1), p);
          }
        }
      },
    );
  }

  /// Lungi tube on the hips bone (+Y down, knees at y ≈ 72).
  static Part2D lungi({required Color base, required Color check, required Color outline}) {
    return Part2D(
      bone: 'hips',
      z: 6.5,
      painter: (ctx) {
        final c = ctx.canvas;
        final rect = const Rect.fromLTWH(-22, -8, 44, 52);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
        c.drawRRect(rrect, Draw.fill(outline));
        c.save();
        c.clipRRect(rrect.deflate(0.9));
        Draw.checks(c, rect, base, check, size: 6.5);
        c.restore();
        // Hem shadow.
        c.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-22, 38, 44, 6), const Radius.circular(3)),
          Draw.fill(outline.withOpacity(0.25)),
        );
      },
    );
  }

  /// Pelvis block for trousers/salwar (hips bone).
  static Part2D pelvis({required Color color, required Color outline, double half = 20, double bottom = 26}) {
    return Part2D(
      bone: 'hips',
      z: 6.2,
      painter: (ctx) {
        final c = ctx.canvas;
        Draw.roundRect(c, Rect.fromLTWH(-half, -8, half * 2, bottom + 8), 6, color, outline: outline);
      },
    );
  }

  /// Sandal on the foot bone (+Y down, origin ankle).
  static Part2D sandal({required Color color, required Color outline, required Color skin}) {
    return Part2D(
      bone: 'foot',
      z: 3.4,
      painter: (ctx) {
        final c = ctx.canvas;
        Draw.ellipse(c, const Offset(0, 2.5), 6.2, 4.4, skin, outline: outline);
        Draw.ellipse(c, const Offset(0, 6.5), 9, 4.6, color, outline: outline);
        Draw.curve(c, const Offset(-5.5, 4), const Offset(0, 1.4), const Offset(5.5, 4), Draw.line(color, 2.6));
      },
    );
  }

  /// Closed shoe (teacher).
  static Part2D shoe({required Color color, required Color outline}) {
    return Part2D(
      bone: 'foot',
      z: 3.4,
      painter: (ctx) {
        final c = ctx.canvas;
        Draw.ellipse(c, const Offset(0, 4.5), 8.6, 6, color, outline: outline);
        c.drawRect(const Rect.fromLTWH(-8.6, 6.5, 17.2, 2.6), Draw.fill(outline.withOpacity(0.35)));
      },
    );
  }

  /// Neck skin on the neck bone (+Y up).
  static Part2D neck({required Color skin, required Color outline}) {
    return Part2D(
      bone: 'neck',
      z: 0.5,
      painter: (ctx) {
        Draw.capsule(ctx.canvas, const Offset(0, -9), const Offset(0, 13), 6.2, skin, outline: outline);
      },
    );
  }

  /// Hand with a shape chosen by the animation (extras `handL`/`handR`).
  static Part2D hand({
    required String bone,
    required double z,
    required Color skin,
    required Color outline,
    String extraKey = 'handL',
  }) {
    return Part2D(
      bone: bone,
      z: z,
      painter: (ctx) {
        final code = ctx.extra(extraKey, 0).round();
        String shape;
        switch (code) {
          case 1:
            shape = 'fist';
          case 2:
            shape = 'point';
          case 3:
            shape = 'thumb';
          default:
            shape = 'open';
        }
        HandShapes.draw(ctx.canvas, PaintCtxArgs(skin: skin, outline: outline), shape);
      },
    );
  }
}
