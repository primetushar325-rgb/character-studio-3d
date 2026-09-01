import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../backgrounds/backgrounds.dart';
import '../characters2d/engine/puppet.dart';
import '../state/editor_provider.dart';

/// Paints the exact 16:9 composition (background → shadow → character →
/// effects → foreground) at ANY pixel size. The editor canvas and the export
/// frame renderer both use this — WYSIWYG by construction.
void paintScene(Canvas canvas, Size size, EditorProvider ed) {
  final bg = ed.background;
  final layersVisible = {for (final l in ed.layers) l.id: l.visible};

  // ---- Background (recorded to a picture so filters apply cleanly) --------
  if (layersVisible['background'] != false) {
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

  // ---- Character ------------------------------------------------------------
  final controller = ed.controller;
  if (controller != null && layersVisible['character'] != false) {
    final t = ed.transform;
    canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withOpacity(t.opacity));

    if (layersVisible['shadow'] != false) {
      final shadowW = size.height * 0.24 * t.scale;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * t.x, size.height * t.y + size.height * 0.012), width: shadowW, height: shadowW * 0.16),
        Paint()..color = const Color(0x33000000),
      );
    }

    final spec = controller.spec;
    final designW = spec.designWidth.toDouble();
    const designH = 340.0;
    final puppetScale = (size.height * 0.5 / designH) * spec.scale * t.scale;

    canvas.translate(size.width * t.x, size.height * t.y);
    canvas.scale(t.flipH ? -puppetScale : puppetScale, t.flipV ? -puppetScale : puppetScale);
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
    // PuppetPainter anchors feet at (size.width/2, size.height-14): shift so
    // the puppet's ground point lands exactly on this transform origin.
    canvas.translate(-designW / 2, -(designH - 14));
    painter.paint(canvas, Size(designW, designH));
    canvas.restore();
  }

  // ---- Effects -----------------------------------------------------------------
  if (ed.effectsVignette && layersVisible['effects'] != false) {
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

  // ---- Foreground ----------------------------------------------------------------
  if (ed.foregroundHaze && layersVisible['foreground'] != false) {
    final rect = Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28);
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: [Colors.white.withOpacity(0), Colors.white.withOpacity(0.18)]).createShader(rect),
    );
  }
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

/// Renders one composition frame at an exact pixel size (export path).
Future<ui.Image> renderSceneFrame(EditorProvider ed, int width, int height) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  paintScene(canvas, Size(width.toDouble(), height.toDouble()), ed);
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}
