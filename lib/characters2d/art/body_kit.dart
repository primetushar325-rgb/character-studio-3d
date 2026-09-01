import '../engine/part2d.dart';
import '../engine/shapes.dart';

/// Shared humanoid part builders in portable Shape form. Every character
/// uses these with different geometry/colors: one art universe, distinct looks.
class BodyKit {
  BodyKit._();

  static Part2D limb({
    required String bone,
    required double z,
    required double len,
    required double rTop,
    required double rBottom,
    String fillSlot = 'shirt',
    double topOverlap = 9,
    double bottomOverlap = 9,
  }) {
    return Part2D(
      bone: bone,
      z: z,
      build: (ctx) => limbShapes(
        len: len,
        rTop: rTop,
        rBottom: rBottom,
        fillSlot: fillSlot,
        topOverlap: topOverlap,
        bottomOverlap: bottomOverlap,
      ),
    );
  }

  /// Skin limb with a rolled sleeve cuff (farmer/girl forearms).
  static Part2D cuffedForearm({
    required String bone,
    required double z,
    required double len,
    required double r,
    double cuffH = 13,
  }) {
    return Part2D(
      bone: bone,
      z: z,
      build: (ctx) => [
        Shape(kind: ShapeKind.capsule, args: [0, -8, 0, len + 8, r], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.rrect, args: [-r - 0.6, -8, r * 2 + 1.2, cuffH, 4], fill: const SolidFillSlot('shirt'), stroke: 'outline', strokeWidth: 1.6),
      ],
    );
  }

  /// Torso on the chest bone (+Y up, hem below at hemY).
  static List<Shape> torsoShapes({
    required double hemY,
    required double hemHalf,
    required double shoulderHalf,
    String fillSlot = 'shirt',
    String? trimSlot,
    String? collarSlot,
    bool buttons = false,
    bool belt = false,
    String beltSlot = 'bottom',
  }) {
    final out = <Shape>[];
    final pb = PathBuilder()
      ..move(-hemHalf, hemY)
      ..line(-shoulderHalf, 14)
      ..quad(-shoulderHalf - 3, 20, -shoulderHalf + 5, 21)
      ..line(shoulderHalf - 5, 21)
      ..quad(shoulderHalf + 3, 20, shoulderHalf, 14)
      ..line(hemHalf, hemY)
      ..quad(0, hemY - 6, -hemHalf, hemY)
      ..close();
    out.add(pb.build(fill: SolidFillSlot(fillSlot), stroke: 'outline', strokeWidth: 1.7));
    if (trimSlot != null) {
      out.add(Shape(kind: ShapeKind.rrect, args: [-hemHalf - 4, hemY - 1, hemHalf * 2 + 8, 6.5, 3], fill: SolidFillSlot(trimSlot)));
    }
    if (belt) {
      out.add(Shape(kind: ShapeKind.rrect, args: [-hemHalf - 4, hemY + 6, hemHalf * 2 + 8, 6, 2], fill: SolidFillSlot(beltSlot)));
    }
    // Collar.
    final collar = PathBuilder()
      ..move(-7, 21)
      ..quad(0, 15, 7, 21);
    out.add(collar.build(fill: SolidFillSlot(collarSlot ?? fillSlot), strokeWidth: 1.7));
    if (buttons) {
      for (var y = 8.0; y > hemY + 8; y -= 10) {
        out.add(Shape(kind: ShapeKind.ellipse, args: [0, y, 1.1, 1.1], fill: const SolidFillSlot('outline')));
      }
    }
    return out;
  }

  static Part2D torso({
    required double z,
    required double hemY,
    required double hemHalf,
    required double shoulderHalf,
    String fillSlot = 'shirt',
    String? trimSlot,
    String? collarSlot,
    bool buttons = false,
    bool belt = false,
  }) {
    return Part2D(
      bone: 'chest',
      z: z,
      build: (ctx) => torsoShapes(
        hemY: hemY,
        hemHalf: hemHalf,
        shoulderHalf: shoulderHalf,
        fillSlot: fillSlot,
        trimSlot: trimSlot,
        collarSlot: collarSlot,
        buttons: buttons,
        belt: belt,
      ),
    );
  }

  /// Lungi tube on the hips bone (+Y down).
  static Part2D lungi({double z = 6.5}) {
    return Part2D(
      bone: 'hips',
      z: z,
      build: (ctx) => [
        Shape(kind: ShapeKind.rrect, args: [-22, -8, 44, 52, 7], fill: const SolidFillSlot('outline')),
        Shape(kind: ShapeKind.checks, args: [-21.1, -7.1, 42.2, 50.2, 6.5]),
        Shape(kind: ShapeKind.rrect, args: [-22, 38, 44, 6, 3], fill: SolidFillSlot('outline'), opacity: 0.25),
      ],
    );
  }

  static Part2D pelvis({required double z, required double half, required double bottom, String fillSlot = 'bottom'}) {
    return Part2D(
      bone: 'hips',
      z: z,
      build: (ctx) => [Shape(kind: ShapeKind.rrect, args: [-half, -8, half * 2, bottom + 8, 6], fill: SolidFillSlot(fillSlot), stroke: 'outline', strokeWidth: 1.6)],
    );
  }

  static List<Shape> sandalShapes() => [
        Shape(kind: ShapeKind.ellipse, args: [0, 2.5, 6.2, 4.4], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.ellipse, args: [0, 6.5, 9, 4.6], fill: const SolidFillSlot('footwear'), stroke: 'outline', strokeWidth: 1.6),
      ];

  static List<Shape> shoeShapes() => [
        Shape(kind: ShapeKind.ellipse, args: [0, 4.5, 8.6, 6], fill: const SolidFillSlot('footwear'), stroke: 'outline', strokeWidth: 1.6),
        Shape(kind: ShapeKind.rrect, args: [-8.6, 6.5, 17.2, 2.6, 1.3], fill: SolidFillSlot('outline'), opacity: 0.35),
      ];

  static Part2D neck({required double z}) {
    return Part2D(
      bone: 'neck',
      z: z,
      build: (ctx) => [Shape(kind: ShapeKind.capsule, args: [0, -9, 0, 13, 6.2], fill: const SolidFillSlot('skin'), stroke: 'outline', strokeWidth: 1.6)],
    );
  }

  static Part2D hand({required String bone, required double z, String extraKey = 'handL'}) {
    return Part2D(
      bone: bone,
      z: z,
      build: (ctx) {
        final code = ctx.extras[extraKey]?.round() ?? 0;
        switch (code) {
          case 1:
            return handShapes2('fist');
          case 2:
            return handShapes2('point');
          case 3:
            return handShapes2('thumb');
          default:
            return handShapes2('open');
        }
      },
    );
  }

  /// Face part (head bone frame) — dynamic eyes/brows/mouth via FaceView.
  static Part2D facePart({required double z}) {
    return Part2D(bone: 'head', z: z, layer: PartLayer.face, build: (ctx) => const []);
  }
}
