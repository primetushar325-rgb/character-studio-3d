import 'palette_resolver.dart';
import 'shapes.dart';

/// Context handed to part shape-builders each frame.
class ShapeCtx {
  const ShapeCtx({required this.colors, required this.extras, required this.face});
  final PaletteResolver colors;
  final Map<String, double> extras;
  final FaceView face;
}

/// One separable artwork piece attached to one bone with a draw order.
/// `z` controls stacking: smaller = further back. Parts produce portable
/// [Shape]s so the same artwork renders on Canvas, SVG and HTML export.
class Part2D {
  const Part2D({required this.bone, required this.z, required this.build, this.layer = PartLayer.body});

  final String bone;
  final double z;
  final PartLayer layer;
  final List<Shape> Function(ShapeCtx ctx) build;
}

/// Broad layers, sorted before per-part `z` inside each layer.
enum PartLayer { back, body, face, front, fx }

/// Sorts parts into a stable painting order.
List<Part2D> orderParts(List<Part2D> parts) {
  final list = List<Part2D>.of(parts);
  list.sort((a, b) {
    final d = a.layer.index.compareTo(b.layer.index);
    if (d != 0) return d;
    final z = a.z.compareTo(b.z);
    if (z != 0) return z;
    return a.bone.compareTo(b.bone);
  });
  return list;
}
