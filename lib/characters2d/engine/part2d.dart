import 'package:flutter/rendering.dart';

import '../art/palettes.dart';

/// Context handed to every part painter. The canvas is already transformed
/// into the bone's local frame: origin = joint pivot, +Y = along the bone,
/// +X = to the bone's own right. Draw in rig units (design height ~330u).
class PaintCtx {
  const PaintCtx({
    required this.canvas,
    required this.colors,
    required this.extras,
    required this.time,
  });

  final Canvas canvas;

  /// Resolved palette slots for this character/variant.
  final PaletteColors colors;

  /// Extra parameters from the current pose (hand shape, prop angles, ...).
  final Map<String, double> extras;

  /// Animation time (seconds) — used for subtle secondary motion in parts.
  final double time;

  double extra(String key, [double fallback = 0]) => extras[key] ?? fallback;
}

/// One separable artwork piece attached to one bone with a draw order.
///
/// `z` controls stacking: smaller = further back.
class Part2D {
  const Part2D({required this.bone, required this.z, required this.painter, this.layer = PartLayer.body});

  final String bone;
  final double z;
  final PartLayer layer;
  final void Function(PaintCtx ctx) painter;
}

/// Broad layers, sorted before per-part `z` inside each layer.
enum PartLayer { back, body, face, front, fx }

int _layerOrder(PartLayer l) => l.index;

/// Sorts parts into a stable painting order.
List<Part2D> orderParts(List<Part2D> parts) {
  final list = List<Part2D>.of(parts);
  list.sort((a, b) {
    final la = _layerOrder(a.layer);
    final lb = _layerOrder(b.layer);
    if (la != lb) return la.compareTo(lb);
    final d = a.z.compareTo(b.z);
    if (d != 0) return d;
    return a.bone.compareTo(b.bone);
  });
  return list;
}
