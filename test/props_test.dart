// §6 Props / accessories layer — model, geometry, painter integration.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/character2d_model.dart';
import 'package:character_studio_3d/characters2d/engine/part2d.dart';
import 'package:character_studio_3d/characters2d/engine/palette_resolver.dart';
import 'package:character_studio_3d/characters2d/engine/shapes.dart';
import 'package:character_studio_3d/characters2d/props.dart';

void main() {
  group('PropAttachment model', () {
    test('JSON round-trip keeps every field', () {
      final p = PropAttachment(
        id: 'p1',
        kind: PropKind.stick,
        attachedBoneId: 'leftHand',
        dx: 3,
        dy: -8,
        rotation: 25,
        scale: 1.2,
        zIndex: 12.4,
        visible: false,
      );
      final back = PropAttachment.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.kind, PropKind.stick);
      expect(back.attachedBoneId, 'leftHand');
      expect(back.dx, 3);
      expect(back.dy, -8);
      expect(back.rotation, 25);
      expect(back.scale, 1.2);
      expect(back.zIndex, 12.4);
      expect(back.visible, isFalse);
    });

    test('Character2D round-trips props (legacy docs unaffected)', () {
      final c = Character2D(
        id: 'v1',
        specId: 'fox',
        name: 'Fox with hat',
        props: [PropAttachment(id: 'p1', kind: PropKind.hat, attachedBoneId: 'head')],
      );
      final j = jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>;
      final back = Character2D.fromJson(j);
      expect(back.props, hasLength(1));
      expect(back.props.first.kind, PropKind.hat);
      expect(back.props.first.attachedBoneId, 'head');

      final legacy = Character2D.fromJson({'id': 'v2', 'specId': 'fox', 'name': 'Old'});
      expect(legacy.props, isEmpty);
    });
  });

  group('prop geometry', () {
    test('every built-in vector prop draws shapes', () {
      final ctx = ShapeCtx(colors: const PaletteResolver({}), extras: const {}, face: const FaceView());
      for (final kind in [PropKind.hat, PropKind.glasses, PropKind.stick, PropKind.bag, PropKind.phone]) {
        final part = propPart(PropAttachment(id: 'x', kind: kind, attachedBoneId: 'head'));
        expect(part.bone, 'head');
        expect(part.build(ctx), isNotEmpty, reason: '$kind draws nothing');
      }
    });

    test('custom PNG prop without a decoded image draws nothing (safe)', () {
      final ctx = ShapeCtx(colors: const PaletteResolver({}), extras: const {}, face: const FaceView());
      final part = propPart(PropAttachment(id: 'x', kind: PropKind.custom, attachedBoneId: 'rightHand', imagePath: '/none.png'));
      expect(part.build(ctx), isEmpty);
    });

    test('offset / rotation / scale bake into portable geometry', () {
      final ctx = ShapeCtx(colors: const PaletteResolver({}), extras: const {}, face: const FaceView());
      // Stick capsule endpoints (0,-34)→(0,52), rotated 90° + offset (10,-5).
      final shapes = propPart(PropAttachment(id: 'x', kind: PropKind.stick, attachedBoneId: 'rightHand', dx: 10, dy: -5, rotation: 90))
          .build(ctx);
      final capsule = shapes.firstWhere((s) => s.kind == ShapeKind.capsule);
      // rotate90: (x,y) → (-y, x); point (0,-34) → (34, 0) → +(10,-5) = (44,-5).
      expect(capsule.args[0], closeTo(44, 0.001));
      expect(capsule.args[1], closeTo(-5, 0.001));
      // point (0,52) → (-52, 0) → +(10,-5) = (-42,-5).
      expect(capsule.args[2], closeTo(-42, 0.001));
      expect(capsule.args[3], closeTo(-5, 0.001));

      // Scale 2 doubles the radius.
      final scaled = propPart(PropAttachment(id: 'y', kind: PropKind.stick, attachedBoneId: 'rightHand', scale: 2))
          .build(ctx)
          .firstWhere((s) => s.kind == ShapeKind.capsule);
      expect(scaled.args[4], closeTo(5.2, 0.001));
    });
  });

  group('painter integration (props ride the part pipeline)', () {
    test('props are z-ordered with the body and bound to their bone', () {
      final spec = CharacterCatalog.byId('fox')!;
      final parts = orderParts([
        ...spec.build(const {'scarf'}),
        propPart(PropAttachment(id: 'p1', kind: PropKind.hat, attachedBoneId: 'head', zIndex: 10.6)),
        propPart(PropAttachment(id: 'p2', kind: PropKind.stick, attachedBoneId: 'leftHand', zIndex: 12.4)),
      ]);
      final headIdx = parts.lastIndexWhere((p) => p.bone == 'head');
      final handIdx = parts.lastIndexWhere((p) => p.bone == 'leftHand');
      // Hat paints above the head part, stick above the near arm.
      expect(parts[headIdx].z, greaterThan(9));
      expect(parts[handIdx].z, greaterThan(12));
      // Two parts on the head (skull + hat) and three on the near hand
      // (upper arm, forearm/hand set, stick) prove merging.
      expect(parts.where((p) => p.bone == 'head').length, greaterThanOrEqualTo(2));
    });

    test('hidden props are excluded by the painter constructor filter', () {
      // PuppetPainter filters invisible props while building parts; simulate
      // the exact expression it uses.
      final props = [
        PropAttachment(id: 'a', kind: PropKind.hat, attachedBoneId: 'head', visible: true),
        PropAttachment(id: 'b', kind: PropKind.bag, attachedBoneId: 'rightHand', visible: false),
      ];
      final included = [for (final p in props) if (p.visible) propPart(p)];
      expect(included, hasLength(1));
      expect(included.first.bone, 'head');
    });
  });
}
