import 'package:flutter/material.dart';

import '../engine/face_rig.dart';
import '../engine/part2d.dart';
import 'bd_farmer.dart';
import 'palettes.dart';
import 'school_teacher.dart';
import 'village_girl.dart';

/// Blueprint of a 2D character: art builder + face geometry + palette slots.
/// Adding Character 04+ means adding one entry here — no engine changes.
class Character2DSpec {
  const Character2DSpec({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.defaultPalette,
    required this.slots,
    required this.face,
    required this.scale,
    required this.build,
    this.accessoryOptions = const {},
    this.defaultAccessories = const {},
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final PaletteColors defaultPalette;
  final List<PaletteSlot> slots;
  final FaceStyle face;

  /// Uniform puppet scale (distinct body proportions per character).
  final double scale;

  /// Accessory key -> toggle label (shown in Customize).
  final Map<String, String> accessoryOptions;
  final Set<String> defaultAccessories;

  final List<Part2D> Function(PaletteColors colors, Set<String> accessories) build;

  /// Structured metadata (spec §32).
  Map<String, dynamic> metadata() => {
        'id': id,
        'name': name,
        'category': category,
        'type': '2d_skeletal',
        'rig': 'humanoid_v1',
        'faceRig': true,
        'talking': true,
        'animations': {
          'idle': true,
          'walk': true,
          'run': true,
          'sit': true,
          'sleep': true,
          'talk': true,
        },
        'headMovements': ['nod', 'shake', 'tilt_left', 'tilt_right', 'look_left', 'look_right'],
        'gestures': [
          'wave', 'greet', 'point_left', 'point_right', 'point_forward',
          'open_palm', 'thumbs_up', 'explain', 'thinking', 'angry_gesture',
        ],
        'expressions': [
          'neutral', 'happy', 'sad', 'angry', 'surprised', 'scared',
          'confused', 'thinking', 'laughing', 'crying',
        ],
        'mouthShapes': MouthShapes.all.keys.toList(),
        'accessories': accessoryOptions.keys.toList(),
      };
}

class CharacterCatalog {
  CharacterCatalog._();

  static const farmer = Character2DSpec(
    id: 'bd_farmer_male',
    name: 'BD Farmer Male',
    category: 'Villager',
    description: 'Friendly hard-working farmer — lungi, gamcha and a warm smile.',
    defaultPalette: Palettes.farmerDefault,
    slots: [
      PaletteSlot(key: 'shirt', label: 'Shirt', swatches: Palettes.shirtSwatches),
      PaletteSlot(key: 'bottom', label: 'Lungi', swatches: Palettes.bottomSwatches),
      PaletteSlot(key: 'accent', label: 'Gamcha', swatches: Palettes.accentSwatches),
      PaletteSlot(key: 'skin', label: 'Skin', swatches: Palettes.skinSwatches),
    ],
    accessoryOptions: {'gamcha': 'Gamcha on shoulder'},
    defaultAccessories: {'gamcha'},
    face: FaceStyle(
      eyeDx: 8.6,
      eyeY: 29,
      eyeRx: 4.9,
      eyeRy: 5.6,
      browY: 40,
      browLen: 9.5,
      browThick: 2.8,
      mouthY: 11.5,
      mouthW: 8.0,
    ),
    scale: 1.02,
    build: buildFarmerParts,
  );

  static const villageGirl = Character2DSpec(
    id: 'village_girl',
    name: 'Village Girl',
    category: 'Villager',
    description: 'Curious, energetic village girl with two braids and a bright kameez.',
    defaultPalette: Palettes.villageGirlDefault,
    slots: [
      PaletteSlot(key: 'shirt', label: 'Kameez', swatches: Palettes.shirtSwatches),
      PaletteSlot(key: 'bottom', label: 'Salwar', swatches: Palettes.bottomSwatches),
      PaletteSlot(key: 'accent', label: 'Dupatta & ribbons', swatches: Palettes.accentSwatches),
      PaletteSlot(key: 'skin', label: 'Skin', swatches: Palettes.skinSwatches),
    ],
    accessoryOptions: {'dupatta': 'Dupatta scarf'},
    defaultAccessories: {'dupatta'},
    face: FaceStyle(
      eyeDx: 8.8,
      eyeY: 29,
      eyeRx: 6.0,
      eyeRy: 6.8,
      browY: 41.5,
      browLen: 8.5,
      browThick: 2.0,
      mouthY: 12.0,
      mouthW: 7.4,
      lash: true,
    ),
    scale: 0.9,
    build: buildGirlParts,
  );

  static const teacher = Character2DSpec(
    id: 'school_teacher',
    name: 'School Teacher',
    category: 'Professional',
    description: 'Calm, intelligent teacher — glasses, formal shirt and a notebook.',
    defaultPalette: Palettes.teacherDefault,
    slots: [
      PaletteSlot(key: 'shirt', label: 'Shirt', swatches: Palettes.shirtSwatches),
      PaletteSlot(key: 'bottom', label: 'Trousers', swatches: Palettes.bottomSwatches),
      PaletteSlot(key: 'glasses', label: 'Glasses', swatches: [Color(0xFF2A2D34), Color(0xFF5A4632), Color(0xFF3D5A80)]),
      PaletteSlot(key: 'skin', label: 'Skin', swatches: Palettes.skinSwatches),
    ],
    accessoryOptions: {'glasses': 'Glasses', 'book': 'Notebook'},
    defaultAccessories: {'glasses', 'book'},
    face: FaceStyle(
      eyeDx: 8.4,
      eyeY: 29,
      eyeRx: 4.6,
      eyeRy: 5.4,
      browY: 40,
      browLen: 9,
      browThick: 2.4,
      mouthY: 11.5,
      mouthW: 7.6,
    ),
    scale: 1.05,
    build: buildTeacherParts,
  );

  static const List<Character2DSpec> builtIn = [farmer, villageGirl, teacher];

  static Character2DSpec? byId(String id) {
    for (final s in builtIn) {
      if (s.id == id) return s;
    }
    return null;
  }
}
