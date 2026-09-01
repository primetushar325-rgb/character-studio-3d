import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'art/character_catalog.dart';
import 'art/palettes.dart';
import 'engine/part2d.dart';
import 'engine/palette_resolver.dart';
import 'engine/shapes.dart';

/// PNG cutout character: the imported artwork is preserved exactly (no
/// redesign) and mounted on the universal rig. The image attaches to the
/// character's core bone so the whole hierarchy (position/rotation/scale/
/// flips + every base animation's root motion) drives it. Limb-level
/// deformation of an unsegmented bitmap is not invented — this is the
/// honest "best possible 2D cutout rig" the spec allows when automatic
/// segmentation is impossible.
class PngCharacterArt {
  PngCharacterArt(this.image, this.imagePath);

  final ui.Image image;
  final String imagePath;
  late final PaletteResolver resolver = PaletteResolver({
    'outline': const Color(0xFF2B2523),
    'skin': const Color(0xFFB07A54),
    'fur': const Color(0xFFF09A2E),
    'bottom': const Color(0xFF3E5F8A),
    'shirt': const Color(0xFFEAF0F6),
    'shirtPattern': const Color(0xFFDCE4EE),
    'accent': const Color(0xFFD9532B),
    'hair': const Color(0xFF23201E),
    'stripe': const Color(0xFF2E2620),
    'belly': const Color(0xFFFCE8C8),
    'nose': const Color(0xFFB95B5B),
    'earInner': const Color(0xFFEFA3A3),
    'footwear': const Color(0xFF7A5433),
    'skinShade': const Color(0xFF96633F),
    'glasses': const Color(0xFF2A2D34),
    'book': const Color(0xFFB33E3E),
    'cheek': const Color(0x26D96F4A),
  });
}

PngCharacterArt? _cached;
String? _cachedPath;

/// Loads (and caches) the last imported PNG artwork.
Future<PngCharacterArt?> loadPngArt(String path) async {
  if (_cachedPath == path && _cached != null) return _cached;
  final file = File(path);
  if (!await file.exists()) return null;
  final data = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(data);
  final frame = await codec.getNextFrame();
  _cached = PngCharacterArt(frame.image, path);
  _cachedPath = path;
  return _cached;
}

/// Builds the cutout part list: the artwork drawn in the hips/body frame,
/// feet on the ground line, full body visible.
List<Part2D> buildPngParts(ui.Image image, String rigKind) {
  final isQuad = rigKind == 'quadruped_v1';
  final bone = isQuad ? 'body' : 'hips';
  // Fit the artwork height to ~ the rig's standing height.
  final targetH = isQuad ? 96.0 : 300.0;
  final s = targetH / image.height;
  final w = image.width * s;
  return [
    Part2D(
      bone: bone,
      z: 5,
      build: (ctx) => [
        DynShape(
          base: Shape(kind: ShapeKind.image, args: [-w / 2, -targetH * (isQuad ? 0.38 : 0.52), w, targetH]),
          image: image,
        ),
      ],
    ),
  ];
}

/// A PNG character spec: rig kind selectable (humanoid silhouette by
/// default), image resolved lazily from [imagePath].
Character2DSpec pngCharacterSpec({
  required String id,
  required String name,
  required String imagePath,
  String rigKind = 'humanoid_v1',
}) {
  return Character2DSpec(
    id: id,
    name: name,
    category: 'Imported PNG',
    description: 'Imported artwork on a $rigKind cutout rig.',
    defaultPalette: Palettes.farmerDefault,
    slots: const [],
    faceStyle: null,
    scale: 1,
    rigKind: rigKind,
    build: (accessories) => const [],
    isPromptTemplate: false,
  );
}
