import 'dart:math' as math;
import 'dart:ui' as ui;

import 'engine/part2d.dart';
import 'engine/shapes.dart';
import 'zip_pack.dart' show PackArtCache;

/// Props / accessories layer (RigStudio §6 mapped onto this engine).
///
/// A prop is a cosmetic item (hat, glasses, stick, bag, phone, or an
/// imported transparent PNG) attached to ONE bone. Props ride the bone's
/// world transform through the ordinary part pipeline, so they inherit
/// animation for free — a stick attached to a hand swings with the arm —
/// and they mirror with the rig automatically (the painter mirrors the
/// whole part group). Props are NOT bones: rotation limits never apply.
enum PropKind { hat, glasses, stick, bag, phone, custom }

String propLabel(PropKind k) => switch (k) {
      PropKind.hat => 'Hat',
      PropKind.glasses => 'Glasses',
      PropKind.stick => 'Stick',
      PropKind.bag => 'Bag',
      PropKind.phone => 'Phone',
      PropKind.custom => 'Custom PNG',
    };

/// Bones that make sense to hang props on (dropdown choices). Any rig bone
/// is accepted at the model level; this list only shapes the UI.
const kPropBoneChoices = <String>[
  'head', 'neck', 'chest', 'spine', 'hips',
  'leftHand', 'rightHand', 'leftFoot', 'rightFoot',
  'earL', 'earR', 'tail1',
];

class PropAttachment {
  PropAttachment({
    required this.id,
    required this.kind,
    required this.attachedBoneId,
    this.imagePath,
    this.dx = 0,
    this.dy = 0,
    this.rotation = 0,
    this.scale = 1,
    this.zIndex = 10.5,
    this.visible = true,
  });

  final String id;
  final PropKind kind;

  /// Bone the prop follows (must exist in the character's rig).
  final String attachedBoneId;

  /// For [PropKind.custom]: app-documents path of a transparent PNG
  /// (decoded once through the shared pack art cache).
  final String? imagePath;

  /// Offset in the bone's local frame (rig units, +Y along the bone).
  final double dx;
  final double dy;

  /// Rotation in degrees — the engine-wide convention (restAngle, pose
  /// angles) is degrees, so props match it.
  final double rotation;

  final double scale;

  /// Draw order relative to body parts (head ≈ 9, near hand ≈ 12).
  final double zIndex;

  bool visible;

  PropAttachment copyWith({
    String? attachedBoneId,
    double? dx,
    double? dy,
    double? rotation,
    double? scale,
    double? zIndex,
    bool? visible,
  }) =>
      PropAttachment(
        id: id,
        kind: kind,
        attachedBoneId: attachedBoneId ?? this.attachedBoneId,
        imagePath: imagePath,
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        rotation: rotation ?? this.rotation,
        scale: scale ?? this.scale,
        zIndex: zIndex ?? this.zIndex,
        visible: visible ?? this.visible,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'bone': attachedBoneId,
        'imagePath': imagePath,
        'dx': dx,
        'dy': dy,
        'rotation': rotation,
        'scale': scale,
        'zIndex': zIndex,
        'visible': visible,
      };

  static PropAttachment fromJson(Map<String, dynamic> j) => PropAttachment(
        id: j['id'] as String? ?? '',
        kind: PropKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => PropKind.hat,
        ),
        attachedBoneId: j['bone'] as String? ?? 'rightHand',
        imagePath: j['imagePath'] as String?,
        dx: (j['dx'] as num?)?.toDouble() ?? 0,
        dy: (j['dy'] as num?)?.toDouble() ?? 0,
        rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
        scale: (j['scale'] as num?)?.toDouble() ?? 1,
        zIndex: (j['zIndex'] as num?)?.toDouble() ?? 10.5,
        visible: j['visible'] as bool? ?? true,
      );
}

/// Vector prop artwork in the bone-local frame (palette-slot fills keep
/// props recolourable; portable shapes render identically in the app,
/// thumbnails and exports because they use the ordinary part pipeline).
List<Shape> buildPropShapes(PropAttachment p) {
  switch (p.kind) {
    case PropKind.hat:
      // Pointed cap sitting on the skull (head art top ≈ y = 1).
      return [
        Shape(kind: ShapeKind.ellipse, args: [0, -3.5, 19, 4.6], fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.capsule, args: [0, -4, 0, -19, 10.5], fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.ellipse, args: [0, -21, 2.6, 2.6], fill: const SolidFillSlot('belly'), stroke: 'outline', strokeWidth: 1.2),
      ];
    case PropKind.glasses:
      // Round spectacles at the standard eye row (y ≈ 24).
      return [
        for (final sx in [-1.0, 1.0])
          Shape(kind: ShapeKind.ellipse, args: [8.5 * sx, 24, 5.6, 5.6], fill: ConstFill('white', const ui.Color(0x33FFFFFF)), stroke: 'outline', strokeWidth: 1.5),
        (PathBuilder()..move(-3.2, 23.4)..quad(0, 25.2, 3.2, 23.4)).build(stroke: 'outline', strokeWidth: 1.5),
        (PathBuilder()..move(-14.1, 23.6)..line(-17.5, 22.2)).build(stroke: 'outline', strokeWidth: 1.4),
        (PathBuilder()..move(14.1, 23.6)..line(17.5, 22.2)).build(stroke: 'outline', strokeWidth: 1.4),
      ];
    case PropKind.stick:
      // Walking stick gripped in the hand, knob at the top.
      return [
        Shape(kind: ShapeKind.capsule, args: [0, -34, 0, 52, 2.6], fill: const SolidFillSlot('bottom'), stroke: 'outline', strokeWidth: 1.4),
        Shape(kind: ShapeKind.ellipse, args: [0, -35, 3.6, 3.0], fill: const SolidFillSlot('accent'), stroke: 'outline', strokeWidth: 1.3),
      ];
    case PropKind.bag:
      // Jute bag hanging from the hand.
      return [
        (PathBuilder()..move(-6, 2)..quad(0, -10, 6, 2)).build(stroke: 'outline', strokeWidth: 1.8),
        Shape(kind: ShapeKind.rrect, args: [-11, 2, 22, 24, 4], fill: const SolidFillSlot('hair'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.rrect, args: [-7.5, 6, 15, 5, 2], fill: const SolidFillSlot('accent')),
      ];
    case PropKind.phone:
      // Smartphone held in the palm.
      return [
        Shape(kind: ShapeKind.rrect, args: [-5, -2, 10, 17, 2.2], fill: const SolidFillSlot('outline'), stroke: 'outline', strokeWidth: 1.2),
        Shape(kind: ShapeKind.rrect, args: [-3.8, -0.6, 7.6, 13, 1.4], fill: ConstFill('white', const ui.Color(0xFF9FD8FF))),
        Shape(kind: ShapeKind.rrect, args: [-1.6, 13.2, 3.2, 1.2, 0.6], fill: const SolidFillSlot('belly')),
      ];
    case PropKind.custom:
      return const [];
  }
}

/// Wraps a prop as a [Part2D] bound to its bone — the exact pipeline body
/// parts use, so bone world transforms, mirroring and export come free.
Part2D propPart(PropAttachment p, {ui.Image? image}) {
  return Part2D(
    bone: p.attachedBoneId,
    z: p.zIndex,
    build: (ctx) {
      if (p.kind == PropKind.custom) {
        final img = image ?? (p.imagePath == null ? null : PackArtCache.instance.peek(p.imagePath!));
        if (img == null) return const [];
        // PNG props support offset + scale (axis-aligned draw rect; the
        // engine's image shape has no arbitrary rotation).
        final h = 46.0 * p.scale;
        final w = img.width * (h / img.height);
        return [
          DynShape(
            base: Shape(kind: ShapeKind.image, args: [p.dx - w / 2, p.dy - h, w, h]),
            image: img,
          ),
        ];
      }
      final shapes = buildPropShapes(p);
      if (p.dx == 0 && p.dy == 0 && p.rotation == 0 && p.scale == 1) return shapes;
      return [for (final sh in shapes) _transformed(sh, p.dx, p.dy, p.rotation, p.scale)];
    },
  );
}

/// Applies a local translate→rotate→scale to one portable shape, producing
/// another portable shape (no canvas state involved).
Shape _transformed(Shape sh, double dx, double dy, double rotDeg, double s) {
  final rad = rotDeg * math.pi / 180.0;
  final c = math.cos(rad);
  final sn = math.sin(rad);
  double tx(double x, double y) => dx + (x * c - y * sn) * s;
  double ty(double x, double y) => dy + (x * sn + y * c) * s;

  List<double> args;
  switch (sh.kind) {
    case ShapeKind.ellipse: // [cx, cy, rx, ry]
      args = [tx(sh.args[0], sh.args[1]), ty(sh.args[0], sh.args[1]), sh.args[2] * s, sh.args[3] * s];
    case ShapeKind.capsule: // [ax, ay, bx, by, r]
      args = [tx(sh.args[0], sh.args[1]), ty(sh.args[0], sh.args[1]), tx(sh.args[2], sh.args[3]), ty(sh.args[2], sh.args[3]), sh.args[4] * s];
    case ShapeKind.rrect: // [left, top, width, height, radius]
      final l = sh.args[0], t = sh.args[1], w = sh.args[2], h = sh.args[3], r = sh.args[4];
      final x1 = tx(l, t + h), y1 = ty(l, t + h);
      final x2 = tx(l + w, t), y2 = ty(l + w, t);
      args = [
        x1 < x2 ? x1 : x2,
        y1 < y2 ? y1 : y2,
        (x2 - x1).abs(),
        (y2 - y1).abs(),
        r * s,
      ];
    case ShapeKind.path:
      final ops = sh is DynShape ? sh.ops : const <String>[];
      return DynShape(
        base: Shape(
          kind: ShapeKind.path,
          args: const [],
          points: [for (final pt in sh.points) ui.Offset(tx(pt.dx, pt.dy), ty(pt.dx, pt.dy))],
          fill: sh.fill,
          stroke: sh.stroke,
          strokeWidth: sh.strokeWidth,
          opacity: sh.opacity,
        ),
        ops: ops,
      );
    default:
      return sh;
  }
  return Shape(
    kind: sh.kind,
    args: args,
    points: sh.points,
    fill: sh.fill,
    stroke: sh.stroke,
    strokeWidth: sh.strokeWidth * s,
    opacity: sh.opacity,
  );
}
