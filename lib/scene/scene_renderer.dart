import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../backgrounds/backgrounds.dart';
import '../characters2d/engine/puppet.dart';
import '../state/editor_provider.dart';
import 'scene_object.dart';

/// Paints the exact project composition — background (bottom-most) → all
/// SceneObjects in z-order → effects. The editor canvas, playback preview
/// and the export frame renderer all use this ONE function: WYSIWYG by
/// construction. Object hit-testing uses the same geometry via
/// [objectBounds].
void paintScene(Canvas canvas, Size size, EditorProvider ed) {
  final bg = ed.background;

  // ---- Background (project-level, always the bottom-most layer) -----------
  if (ed.backgroundVisible) {
    _paintBackground(canvas, size, ed, bg);
  }

  // ---- Scene objects in z-order (low → high) --------------------------------
  for (final obj in ed.objectsInPaintOrder) {
    if (!obj.visible) continue;
    switch (obj.type) {
      case SceneObjectType.character:
        _paintCharacterObject(canvas, size, ed, obj);
      case SceneObjectType.image:
        _paintImageObject(canvas, size, ed, obj);
      case SceneObjectType.text:
        _paintTextObject(canvas, size, obj);
      case SceneObjectType.shape:
        _paintShapeObject(canvas, size, obj);
    }
  }

  // ---- Effects overlays --------------------------------------------------
  if (ed.effectsVignette) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: math.max(size.width, size.height) * 0.75,
          colors: [Colors.transparent, Colors.black.withOpacity(0.38)],
        ).createShader(rect),
    );
  }
  if (ed.foregroundHaze) {
    final rect = Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28);
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: [Colors.white.withOpacity(0), Colors.white.withOpacity(0.18)]).createShader(rect),
    );
  }
}

void _paintBackground(Canvas canvas, Size size, EditorProvider ed, BgConfig bg) {
  final rec = ui.PictureRecorder();
  final bc = Canvas(rec);
  switch (bg.kind) {
    case BgKind.transparent:
      _checker(bc, size);
    case BgKind.solid:
      bc.drawRect(Offset.zero & size, Paint()..color = bg.color1);
    case BgKind.gradient:
      final rect = Offset.zero & size;
      final a = bg.gradientAngle * math.pi / 180;
      bc.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [bg.color1, bg.color2],
            begin: Alignment(-math.cos(a), -math.sin(a)),
            end: Alignment(math.cos(a), math.sin(a)),
          ).createShader(rect),
      );
    case BgKind.builtin:
      final spec = Backgrounds.byId(bg.builtinId);
      if (spec != null) spec.painter(bc, size);
    case BgKind.image:
      _paintImageBg(bc, size, ed.bgImage, bg);
  }
  final picture = rec.endRecording();
  final paint = Paint()..color = Colors.white.withOpacity(bg.opacity);
  if (bg.brightness != 0 || bg.contrast != 0) {
    final k = 1 + bg.contrast * 1.6;
    final b = bg.brightness * 90;
    paint.colorFilter = ui.ColorFilter.matrix(Float64List.fromList([
      k, 0, 0, 0, b, //
      0, k, 0, 0, b, //
      0, 0, k, 0, b, //
      0, 0, 0, 1, 0, //
    ]));
  }
  canvas.saveLayer(Offset.zero & size, paint);
  canvas.drawPicture(picture);
  canvas.restore();
  picture.dispose();
}

void _paintCharacterObject(Canvas canvas, Size size, EditorProvider ed, SceneObject obj) {
  final controller = ed.controllerFor(obj);
  if (controller == null) return;
  final t = obj.transform;

  canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withOpacity(t.opacity));

  // Ground shadow (matches the character's feet).
  final shadowW = size.height * 0.24 * t.scaleX;
  canvas.drawOval(
    Rect.fromCenter(center: Offset(size.width * t.x, size.height * t.y + size.height * 0.012), width: shadowW, height: shadowW * 0.16),
    Paint()..color = const Color(0x33000000),
  );

  final spec = controller.spec;
  final designW = spec.designWidth.toDouble();
  const designH = 340.0;
  final puppetScale = (size.height * 0.5 / designH) * spec.scale * t.scaleY;

  canvas.translate(size.width * t.x, size.height * t.y);
  canvas.scale(t.flipH ? -puppetScale : puppetScale, puppetScale);
  if (t.rotation != 0) canvas.rotate(t.rotation * math.pi / 180);

  final painter = PuppetPainter(
    spec: spec,
    resolver: controller.resolver,
    accessories: controller.accessories,
    frameGetter: () => controller.frame,
    directionLeft: controller.directionLeft,
    background: null,
    showGroundShadow: false,
    designSpace: Size(designW, designH),
  );
  canvas.translate(-designW / 2, -(designH - 14));
  painter.paint(canvas, Size(designW, designH));
  canvas.restore();
}

void _paintImageObject(Canvas canvas, Size size, EditorProvider ed, SceneObject obj) {
  final image = ed.imageFor(obj);
  if (image == null) {
    // Friendly placeholder box while/broken — never crashes the render.
    _placeholderBox(canvas, size, obj, const Color(0x33FFFFFF), 'IMAGE');
    return;
  }
  final t = obj.transform;
  final h = size.height * 0.5 * t.scaleY;
  final w = h * (image.width / image.height) * (t.scaleX / t.scaleY);
  canvas.saveLayer(
    Offset.zero & size,
    Paint()..color = Colors.white.withOpacity(t.opacity),
  );
  canvas.translate(size.width * t.x, size.height * t.y);
  if (t.rotation != 0) canvas.rotate(t.rotation * math.pi / 180);
  if (t.flipH) canvas.scale(-1, 1);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromCenter(center: Offset.zero, width: w, height: h),
    Paint()..filterQuality = FilterQuality.medium,
  );
  canvas.restore();
}

void _paintTextObject(Canvas canvas, Size size, SceneObject obj) {
  final t = obj.transform;
  final scale = size.width / 1920; // text sizes are authored in 1920-space
  final span = TextSpan(
    text: obj.text,
    style: TextStyle(
      color: Color(obj.textColor).withOpacity(t.opacity),
      fontSize: obj.fontSize * scale * t.scaleY,
      fontWeight: FontWeight.values[obj.fontWeight.clamp(0, 8)],
      fontFamily: obj.fontFamily,
      height: 1.15,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.45 * t.opacity),
          offset: Offset(0, 2 * scale),
          blurRadius: 4 * scale,
        ),
      ],
    ),
  );
  final align = obj.textAlign == 'left'
      ? TextAlign.left
      : obj.textAlign == 'right'
          ? TextAlign.right
          : TextAlign.center;
  final tp = TextPainter(text: span, textAlign: align, textDirection: TextDirection.ltr);
  tp.layout(maxWidth: size.width * 0.92);

  canvas.save();
  canvas.translate(size.width * t.x, size.height * t.y);
  if (t.rotation != 0) canvas.rotate(t.rotation * math.pi / 180);

  // Optional background pill behind the text.
  if (obj.textBgColor != null) {
    final r = Rect.fromCenter(
      center: Offset(0, -tp.height / 2),
      width: tp.width + 48 * scale,
      height: tp.height + 24 * scale,
    );
    final radius = Radius.circular(12 * scale);
    canvas.drawRRect(RRect.fromRectAndRadius(r, radius), Paint()..color = Color(obj.textBgColor!).withOpacity(t.opacity));
  }

  if (obj.strokeWidth > 0) {
    // Stroke pass under the fill (painter's algorithm: stroke first, wider).
    final strokeSpan = TextSpan(
      text: obj.text,
      style: TextStyle(
        color: Color(obj.strokeColor).withOpacity(t.opacity),
        fontSize: obj.fontSize * scale * t.scaleY,
        fontWeight: FontWeight.values[obj.fontWeight.clamp(0, 8)],
        fontFamily: obj.fontFamily,
        foreground: null,
        height: 1.15,
      ),
    );
    final stp = TextPainter(text: strokeSpan, textAlign: align, textDirection: TextDirection.ltr)
      ..layout(maxWidth: size.width * 0.92);
    canvas.save();
    // Simulate stroke by 8 offset draws (works on every Flutter build).
    const dirs = [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1), Offset(0.7, 0.7), Offset(-0.7, 0.7), Offset(0.7, -0.7), Offset(-0.7, -0.7)];
    for (final d in dirs) {
      canvas.save();
      canvas.translate(d.dx * obj.strokeWidth * scale * t.scaleY, d.dy * obj.strokeWidth * scale * t.scaleY);
      stp.paint(canvas, Offset(-tp.width / 2, -tp.height));
      canvas.restore();
    }
    canvas.restore();
  }

  tp.paint(canvas, Offset(-tp.width / 2, -tp.height));
  canvas.restore();
}

void _paintShapeObject(Canvas canvas, Size size, SceneObject obj) {
  final t = obj.transform;
  final w = size.width * obj.width * t.scaleX;
  final h = size.height * obj.height * t.scaleY;

  canvas.saveLayer(
    Offset.zero & size,
    Paint()..color = Colors.white.withOpacity(t.opacity),
  );
  canvas.translate(size.width * t.x, size.height * t.y);
  if (t.rotation != 0) canvas.rotate(t.rotation * math.pi / 180);

  final fill = Paint()..color = Color(obj.fillColor);
  final stroke = obj.shapeStrokeWidth > 0
      ? (Paint()
          ..color = Color(obj.shapeStrokeColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = obj.shapeStrokeWidth * (size.width / 1920))
      : null;

  switch (obj.shapeKind) {
    case 'circle':
      final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawOval(r, fill);
      if (stroke != null) canvas.drawOval(r, stroke);
    case 'line':
      final p = Paint()
        ..color = Color(obj.fillColor)
        ..strokeWidth = math.max(2.0, h)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(-w / 2, 0), Offset(w / 2, 0), p);
    case 'rect':
    default:
      final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawRect(r, fill);
      if (stroke != null) canvas.drawRect(r, stroke);
  }
  canvas.restore();
}

void _placeholderBox(Canvas canvas, Size size, SceneObject obj, Color c, String label) {
  final r = objectBounds(obj, size);
  final p = Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  canvas.drawRect(r, p);
  final tp = TextPainter(text: TextSpan(text: label, style: TextStyle(color: c, fontSize: 14)), textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
}

/// Approximate rendered bounds of an object in canvas pixels — used for
/// SELECTION and hit-testing (same geometry the painters above use).
Rect objectBounds(SceneObject obj, Size size) {
  final t = obj.transform; // used by every branch below
  final cx = size.width * t.x;
  final cy = size.height * t.y;
  switch (obj.type) {
    case SceneObjectType.character:
      final h = size.height * 0.55 * t.scaleY;
      final w = h * 0.62 * t.scaleX;
      return Rect.fromCenter(center: Offset(cx, cy - h / 2), width: w, height: h);
    case SceneObjectType.image:
      final h = size.height * 0.5 * t.scaleY;
      final w = h * (16 / 9) * (t.scaleX / t.scaleY); // assume 16:9 until measured
      return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    case SceneObjectType.text:
      final scale = size.width / 1920;
      final fs = obj.fontSize * scale * t.scaleY;
      final est = obj.text.length * fs * 0.55;
      final lines = obj.text.isEmpty ? 1 : '\n'.allMatches(obj.text).length + 1;
      final w = math.min(size.width * 0.92, est) * t.scaleX;
      final h = lines * fs * 1.15 * t.scaleY;
      return Rect.fromCenter(center: Offset(cx, cy - h / 2), width: w, height: h);
    case SceneObjectType.shape:
      final w = size.width * obj.width * t.scaleX;
      final h = size.height * obj.height * t.scaleY;
      if (obj.shapeKind == 'line') return Rect.fromCenter(center: Offset(cx, cy), width: w, height: math.max(24.0, h));
      return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }
}

/// Topmost-first hit test. Returns the object whose bounds contain the
/// canvas point, respecting z-order (highest zIndex wins on overlap).
SceneObject? hitTest(Iterable<SceneObject> objects, Offset canvasPoint, Size size) {
  final sorted = [...objects]..sort((a, b) => b.zIndex.compareTo(a.zIndex));
  for (final o in sorted) {
    if (!o.visible || o.locked && false) continue;
    if (objectBounds(o, size).contains(canvasPoint)) return o;
  }
  return null;
}

void _checker(Canvas canvas, Size size) {
  final cell = size.height / 18;
  final p1 = Paint()..color = const Color(0xFF232838);
  final p2 = Paint()..color = const Color(0xFF2A3044);
  for (var y = 0; y * cell < size.height; y++) {
    for (var x = 0; x * cell < size.width; x++) {
      canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), (x + y) % 2 == 0 ? p1 : p2);
    }
  }
}

void _paintImageBg(Canvas canvas, Size size, ui.Image? image, BgConfig bg) {
  if (image == null) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF171B26));
    return;
  }
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  var w = size.width.toDouble();
  var h = size.height.toDouble();
  switch (bg.fit) {
    case BgFit.cover:
      final r = math.max(size.width / iw, size.height / ih);
      w = iw * r;
      h = ih * r;
    case BgFit.contain:
      final r = math.min(size.width / iw, size.height / ih);
      w = iw * r;
      h = ih * r;
    case BgFit.fill:
      break;
  }
  w *= bg.scale;
  h *= bg.scale;
  final dx = (size.width - w) / 2 + bg.offsetX * size.width;
  final dy = (size.height - h) / 2 + bg.offsetY * size.height;
  if (bg.blur > 0) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.saveLayer(Offset.zero & size, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: bg.blur * 2, sigmaY: bg.blur * 2));
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, iw, ih), Rect.fromLTWH(dx, dy, w, h), Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
    canvas.restore();
  } else {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, iw, ih), Rect.fromLTWH(dx, dy, w, h), Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
  }
}

/// Renders one composition frame at an exact pixel size (export path — the
/// SAME paintScene used by the editor preview).
Future<ui.Image> renderSceneFrame(EditorProvider ed, int width, int height) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  paintScene(canvas, Size(width.toDouble(), height.toDouble()), ed);
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}
