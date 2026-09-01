import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Background configuration for the 16:9 composition.
enum BgKind { builtin, solid, gradient, transparent, image }

enum BgFit { cover, contain, fill }

class BgConfig {
  BgConfig({
    this.kind = BgKind.builtin,
    this.builtinId = 'studio_dark',
    this.color1 = const Color(0xFF101828),
    this.color2 = const Color(0xFF2A1E5C),
    this.gradientAngle = 135,
    this.imagePath,
    this.fit = BgFit.cover,
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1,
    this.brightness = 0,
    this.contrast = 0,
    this.blur = 0,
    this.opacity = 1,
  });

  BgKind kind;
  String builtinId;
  Color color1;
  Color color2;
  double gradientAngle;
  String? imagePath;
  BgFit fit;
  double offsetX; // -1..1
  double offsetY; // -1..1
  double scale;
  double brightness; // -0.5..0.5
  double contrast; // -0.5..0.5
  double blur; // 0..20
  double opacity; // 0..1

  BgConfig clone() => BgConfig(
        kind: kind,
        builtinId: builtinId,
        color1: color1,
        color2: color2,
        gradientAngle: gradientAngle,
        imagePath: imagePath,
        fit: fit,
        offsetX: offsetX,
        offsetY: offsetY,
        scale: scale,
        brightness: brightness,
        contrast: contrast,
        blur: blur,
        opacity: opacity,
      );
}

/// One built-in procedural background.
class BgSpec {
  const BgSpec(this.id, this.name, this.category, this.painter);
  final String id;
  final String name;
  final String category;
  final void Function(Canvas c, Size size) painter;
}

class Backgrounds {
  Backgrounds._();

  static const categories = [
    'Nature', 'Village', 'City', 'Room', 'Office', 'Street', 'Forest',
    'Farm', 'School', 'Studio', 'Night', 'Day', 'Fantasy', 'Custom',
  ];

  static Paint _p(Color c) => Paint()..color = c;

  static void _sky(Canvas c, Size s, Color top, Color bottom) {
    final rect = Rect.fromLTWH(0, 0, s.width, s.height);
    c.drawRect(rect, Paint()..shader = LinearGradient(colors: [top, bottom]).createShader(rect));
  }

  static void _ground(Canvas c, Size s, Color col, [double h = 0.22]) {
    c.drawRect(Rect.fromLTWH(0, s.height * (1 - h), s.width, s.height * h), _p(col));
  }

  static void _sun(Canvas c, Size s, Offset rel, double r, Color col) {
    c.drawCircle(Offset(s.width * rel.dx, s.height * rel.dy), r * s.height / 1080 * 4, _p(col));
  }

  static void _cloud(Canvas c, Offset center, double w, Color col) {
    final p = _p(col);
    c.drawCircle(center.translate(-w * 0.5, 0), w * 0.32, p);
    c.drawCircle(center, w * 0.42, p);
    c.drawCircle(center.translate(w * 0.52, w * 0.05), w * 0.3, p);
    c.drawRect(Rect.fromLTRB(center.dx - w * 0.75, center.dy, center.dx + w * 0.78, center.dy + w * 0.34), p);
  }

  static void _tree(Canvas c, Offset base, double h, Color trunk, Color leaf) {
    c.drawRect(Rect.fromLTWH(base.dx - h * 0.035, base.dy - h * 0.42, h * 0.07, h * 0.42), _p(trunk));
    c.drawCircle(base.translate(0, -h * 0.58), h * 0.24, _p(leaf));
    c.drawCircle(base.translate(-h * 0.16, -h * 0.46), h * 0.17, _p(leaf));
    c.drawCircle(base.translate(h * 0.16, -h * 0.47), h * 0.18, _p(leaf));
  }

  static void _hut(Canvas c, Offset base, double w, Color wall, Color roof, Color door) {
    final h = w * 0.62;
    c.drawRect(Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h), _p(wall));
    final roofPath = Path()
      ..moveTo(base.dx - w * 0.62, base.dy - h)
      ..lineTo(base.dx, base.dy - h - w * 0.34)
      ..lineTo(base.dx + w * 0.62, base.dy - h)
      ..close();
    c.drawPath(roofPath, _p(roof));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(base.dx - w * 0.12, base.dy - h * 0.55, w * 0.24, h * 0.55), const Radius.circular(3)), _p(door));
  }

  static void _building(Canvas c, Offset base, double w, double h, Color col, Color win, {int cols = 4, int rows = 6}) {
    c.drawRect(Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h), _p(col));
    for (var r = 0; r < rows; r++) {
      for (var ci = 0; ci < cols; ci++) {
        final colC = Color.lerp(col, const Color(0xFF20262E), ci / cols)!;
        final lit = (r * 7 + ci * 13) % 3 == 0;
        c.drawRect(
          Rect.fromLTWH(base.dx - w / 2 + w * (0.12 + ci * 0.8 / cols), base.dy - h + h * (0.08 + r * 0.86 / rows), w * 0.55 / cols, h * 0.6 / rows),
          _p(lit ? win : Color.lerp(colC, col, 0.45)!),
        );
      }
    }
  }

  static void _desk(Canvas c, Size s, Color wood, double y) {
    c.drawRect(Rect.fromLTWH(0, s.height * y, s.width, s.height * 0.035), _p(wood));
    c.drawRect(Rect.fromLTWH(s.width * 0.06, s.height * y + s.height * 0.035, s.width * 0.02, s.height * 0.2), _p(wood));
    c.drawRect(Rect.fromLTWH(s.width * 0.92, s.height * y + s.height * 0.035, s.width * 0.02, s.height * 0.2), _p(wood));
  }

  static void _stars(Canvas c, Size s, int n, int seed) {
    final rng = math.Random(seed);
    final p = _p(const Color(0xCCFFFFFF));
    for (var i = 0; i < n; i++) {
      final x = rng.nextDouble() * s.width;
      final y = rng.nextDouble() * s.height * 0.6;
      final r = 1 + rng.nextDouble() * 2.2;
      c.drawCircle(Offset(x, y), r, p);
    }
  }

  static void _hills(Canvas c, Size s, Color col, double h, int seed) {
    final rng = math.Random(seed);
    final path = Path()..moveTo(0, s.height);
    var x = 0.0;
    while (x < s.width) {
      final peak = s.height * (1 - h) - rng.nextDouble() * s.height * h * 0.6;
      path.quadraticBezierTo(x + s.width * 0.08, peak, x + s.width * 0.16, s.height * (1 - h * 0.6));
      x += s.width * 0.16;
    }
    path.lineTo(s.width, s.height);
    path.close();
    c.drawPath(path, _p(col));
  }

  static final List<BgSpec> builtIns = [
    // --- Nature ---
    BgSpec('meadow', 'Meadow', 'Nature', (c, s) {
      _sky(c, s, const Color(0xFF8FD3F4), const Color(0xFFD9F2D0));
      _sun(c, s, const Offset(0.82, 0.16), 46, const Color(0xFFFFE9A8));
      _cloud(c, Offset(s.width * 0.2, s.height * 0.16), s.width * 0.09, Colors.white.withOpacity(0.9));
      _cloud(c, Offset(s.width * 0.62, s.height * 0.1), s.width * 0.07, Colors.white.withOpacity(0.8));
      _hills(c, s, const Color(0xFF9CD39B), 0.16, 4);
      _ground(c, s, const Color(0xFF7ABD6F), 0.24);
    }),
    BgSpec('lake', 'Lake', 'Nature', (c, s) {
      _sky(c, s, const Color(0xFF6FC6E8), const Color(0xFFBFE8F5));
      _sun(c, s, const Offset(0.2, 0.18), 40, const Color(0xFFFFF3C4));
      _hills(c, s, const Color(0xFF6FA86F), 0.2, 7);
      _ground(c, s, const Color(0xFF3E7FA8), 0.3);
      final p = _p(const Color(0x33FFFFFF));
      for (var i = 0; i < 5; i++) {
        c.drawRect(Rect.fromLTWH(s.width * (0.08 + i * 0.18), s.height * (0.78 + (i % 2) * 0.06), s.width * 0.1, 3), p);
      }
    }),
    // --- Village ---
    BgSpec('village', 'Village Homes', 'Village', (c, s) {
      _sky(c, s, const Color(0xFFFFC98A), const Color(0xFFFFE8C7));
      _sun(c, s, const Offset(0.75, 0.2), 44, const Color(0xFFFFB95C));
      _hut(c, Offset(s.width * 0.18, s.height * 0.8), s.width * 0.2, const Color(0xFFE8D4B0), const Color(0xFFB4543B), const Color(0xFF7A4A2B));
      _hut(c, Offset(s.width * 0.52, s.height * 0.78), s.width * 0.16, const Color(0xFFDFC9A4), const Color(0xFF9C4A38), const Color(0xFF6B4127));
      _hut(c, Offset(s.width * 0.84, s.height * 0.82), s.width * 0.22, const Color(0xFFE8D4B0), const Color(0xFFA8563F), const Color(0xFF7A4A2B));
      _tree(c, Offset(s.width * 0.36, s.height * 0.82), s.height * 0.42, const Color(0xFF7A5638), const Color(0xFF5E9C55));
      _ground(c, s, const Color(0xFFC7A96F), 0.2);
    }),
    BgSpec('farm', 'Farm Field', 'Farm', (c, s) {
      _sky(c, s, const Color(0xFF9AD7F2), const Color(0xFFE8F7D9));
      _cloud(c, Offset(s.width * 0.3, s.height * 0.12), s.width * 0.08, Colors.white);
      _hut(c, Offset(s.width * 0.85, s.height * 0.72), s.width * 0.14, const Color(0xFFDECAA6), const Color(0xFF9C4A38), const Color(0xFF6B4127));
      _ground(c, s, const Color(0xFF8FBF62), 0.3);
      final rows = _p(const Color(0xFF6EA34C));
      for (var i = 0; i < 6; i++) {
        final y = s.height * (0.74 + i * 0.045);
        c.drawRect(Rect.fromLTWH(0, y, s.width, 5), rows);
      }
    }),
    // --- City / Street ---
    BgSpec('city', 'City Skyline', 'City', (c, s) {
      _sky(c, s, const Color(0xFF3E4A6B), const Color(0xFF8A6E9E));
      _sun(c, s, const Offset(0.15, 0.22), 36, const Color(0xFFFFD9A0));
      _building(c, Offset(s.width * 0.12, s.height * 0.85), s.width * 0.14, s.height * 0.5, const Color(0xFF2C3350), const Color(0xFFFFD98A));
      _building(c, Offset(s.width * 0.32, s.height * 0.85), s.width * 0.12, s.height * 0.62, const Color(0xFF262C47), const Color(0xFFCAF0FF));
      _building(c, Offset(s.width * 0.55, s.height * 0.85), s.width * 0.16, s.height * 0.55, const Color(0xFF2C3350), const Color(0xFFFFE2A8));
      _building(c, Offset(s.width * 0.8, s.height * 0.85), s.width * 0.13, s.height * 0.68, const Color(0xFF232943), const Color(0xFFCAF0FF));
      _ground(c, s, const Color(0xFF1D2236), 0.15);
    }),
    BgSpec('street', 'Street', 'Street', (c, s) {
      _sky(c, s, const Color(0xFFB8DDEB), const Color(0xFFE9F4F7));
      _building(c, Offset(s.width * 0.2, s.height * 0.78), s.width * 0.24, s.height * 0.42, const Color(0xFFD9C6A8), const Color(0xFF9CC3D8), cols: 5, rows: 4);
      _building(c, Offset(s.width * 0.66, s.height * 0.78), s.width * 0.28, s.height * 0.5, const Color(0xFFCFBBA0), const Color(0xFF8FB4CC), cols: 6, rows: 5);
      _ground(c, s, const Color(0xFF6E6E78), 0.26);
      final line = _p(Colors.white.withOpacity(0.7));
      for (var i = 0; i < 5; i++) {
        c.drawRect(Rect.fromLTWH(s.width * (0.04 + i * 0.2), s.height * 0.9, s.width * 0.09, 6), line);
      }
    }),
    // --- Room / School / Office ---
    BgSpec('room', 'Room', 'Room', (c, s) {
      c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), _p(const Color(0xFFE8D8C2)));
      c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height * 0.62), _p(const Color(0xFFDFC9AC)));
      c.drawRect(Rect.fromLTWH(s.width * 0.1, s.height * 0.18, s.width * 0.2, s.height * 0.26), _p(const Color(0xFF9CC3D8)));
      c.drawRect(Rect.fromLTWH(s.width * 0.68, s.height * 0.2, s.width * 0.2, s.height * 0.22), _p(const Color(0xFFB5D9E8)));
      _desk(c, s, const Color(0xFF9A6B45), 0.74);
      _ground(c, s, const Color(0xFFC7A17A), 0.2);
    }),
    BgSpec('school', 'Classroom', 'School', (c, s) {
      c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), _p(const Color(0xFFDDE8CF)));
      c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height * 0.6), _p(const Color(0xFFCFE0BC)));
      // Blackboard.
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.28, s.height * 0.12, s.width * 0.44, s.height * 0.3), const Radius.circular(8)), _p(const Color(0xFF2E4A3B)));
      c.drawRect(Rect.fromLTWH(s.width * 0.28, s.height * 0.44, s.width * 0.44, s.height * 0.02), _p(const Color(0xFF9A6B45)));
      _desk(c, s, const Color(0xFFA8764E), 0.72);
      _ground(c, s, const Color(0xFFB58F6A), 0.22);
    }),
    BgSpec('office', 'Office', 'Office', (c, s) {
      c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), _p(const Color(0xFFE4E9F0)));
      c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height * 0.58), _p(const Color(0xFFD3DCE8)));
      for (var i = 0; i < 4; i++) {
        c.drawRect(Rect.fromLTWH(s.width * (0.06 + i * 0.23), s.height * 0.14, s.width * 0.16, s.height * 0.26), _p(const Color(0xFF9FC4DC)));
        c.drawRect(Rect.fromLTWH(s.width * (0.06 + i * 0.23), s.height * 0.14, s.width * 0.16, s.height * 0.03), _p(const Color(0xFF77879A)));
      }
      _desk(c, s, const Color(0xFF8A6248), 0.72);
      _ground(c, s, const Color(0xFF9AA5B5), 0.2);
    }),
    // --- Forest ---
    BgSpec('forest', 'Forest', 'Forest', (c, s) {
      _sky(c, s, const Color(0xFFBFE8D4), const Color(0xFFE4F5D9));
      _tree(c, Offset(s.width * 0.1, s.height * 0.86), s.height * 0.72, const Color(0xFF6B4A2F), const Color(0xFF3E7A4C));
      _tree(c, Offset(s.width * 0.3, s.height * 0.9), s.height * 0.85, const Color(0xFF5E4028), const Color(0xFF356B42));
      _tree(c, Offset(s.width * 0.62, s.height * 0.88), s.height * 0.78, const Color(0xFF6B4A2F), const Color(0xFF3E7A4C));
      _tree(c, Offset(s.width * 0.9, s.height * 0.92), s.height * 0.9, const Color(0xFF5E4028), const Color(0xFF356B42));
      _ground(c, s, const Color(0xFF4E8A52), 0.22);
    }),
    // --- Studio ---
    BgSpec('studio_dark', 'Studio Dark', 'Studio', (c, s) {
      final rect = Rect.fromLTWH(0, 0, s.width, s.height);
      c.drawRect(rect, Paint()..shader = const LinearGradient(colors: [Color(0xFF171B26), Color(0xFF232A3D)]).createShader(rect));
      final glow = Paint()..shader = RadialGradient(colors: [const Color(0x337B9BFF), Colors.transparent]).createShader(rect);
      c.drawRect(rect, glow);
    }),
    BgSpec('stage_lights', 'Stage', 'Studio', (c, s) {
      final rect = Rect.fromLTWH(0, 0, s.width, s.height);
      c.drawRect(rect, Paint()..shader = const LinearGradient(colors: [Color(0xFF2A1E5C), Color(0xFF101828)]).createShader(rect));
      for (final x in [0.25, 0.5, 0.75]) {
        final beam = Paint()..shader = LinearGradient(colors: [const Color(0x66FFD98A), Colors.transparent]).createShader(Rect.fromLTWH(s.width * x - s.width * 0.06, 0, s.width * 0.12, s.height * 0.7));
        c.drawRect(Rect.fromLTWH(s.width * x - s.width * 0.06, 0, s.width * 0.12, s.height * 0.7), beam);
      }
      _ground(c, s, const Color(0xFF1D2236), 0.16);
    }),
    // --- Night / Day ---
    BgSpec('night', 'Starry Night', 'Night', (c, s) {
      _sky(c, s, const Color(0xFF0E1230), const Color(0xFF27325E));
      _stars(c, s, 120, 11);
      c.drawCircle(Offset(s.width * 0.8, s.height * 0.2), s.height * 0.06, _p(const Color(0xFFFFF3C4)));
      c.drawCircle(Offset(s.width * 0.8 - s.height * 0.045, s.height * 0.23), s.height * 0.052, _p(const Color(0xFF0E1230)));
      _ground(c, s, const Color(0xFF151A38), 0.2);
    }),
    BgSpec('day', 'Sunny Day', 'Day', (c, s) {
      _sky(c, s, const Color(0xFF7EC8F0), const Color(0xFFC9EAF8));
      _sun(c, s, const Offset(0.5, 0.14), 52, const Color(0xFFFFE9A8));
      _cloud(c, Offset(s.width * 0.22, s.height * 0.2), s.width * 0.09, Colors.white);
      _cloud(c, Offset(s.width * 0.78, s.height * 0.24), s.width * 0.08, Colors.white);
      _ground(c, s, const Color(0xFF7ABD6F), 0.22);
    }),
    // --- Fantasy ---
    BgSpec('fantasy', 'Fantasy Peaks', 'Fantasy', (c, s) {
      _sky(c, s, const Color(0xFF3A2B6B), const Color(0xFF8A5FB0));
      _stars(c, s, 60, 23);
      final path = Path()
        ..moveTo(0, s.height * 0.85)
        ..lineTo(s.width * 0.22, s.height * 0.3)
        ..lineTo(s.width * 0.38, s.height * 0.85)
        ..lineTo(s.width * 0.55, s.height * 0.42)
        ..lineTo(s.width * 0.72, s.height * 0.85)
        ..lineTo(s.width * 0.88, s.height * 0.36)
        ..lineTo(s.width, s.height * 0.85)
        ..close();
      c.drawPath(path, _p(const Color(0xFF5E4A8F)));
      final glow = Paint()..shader = RadialGradient(colors: [const Color(0x55FFD98A), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(s.width * 0.22, s.height * 0.3), radius: s.height * 0.18));
      c.drawRect(Rect.fromCircle(center: Offset(s.width * 0.22, s.height * 0.3), radius: s.height * 0.18), glow);
      _ground(c, s, const Color(0xFF3E3466), 0.18);
    }),
  ];

  static List<BgSpec> byCategory(String category) => [for (final b in builtIns) if (b.category == category) b];

  static BgSpec? byId(String id) {
    for (final b in builtIns) {
      if (b.id == id) return b;
    }
    return null;
  }
}
