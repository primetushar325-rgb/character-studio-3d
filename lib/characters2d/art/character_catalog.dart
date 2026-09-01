import 'package:flutter/material.dart';

import '../engine/face_rig.dart';
import '../engine/part2d.dart';
import '../engine/palette_resolver.dart';
import 'bd_farmer.dart';
import 'palettes.dart';
import 'school_teacher.dart';
import 'tiger.dart';
import 'village_girl.dart';

/// Blueprint of a 2D character: art builder + rig kind + face geometry +
/// palette. Adding a new character = one entry here — the engine, editor,
/// export pipeline and HTML export all work unchanged.
class Character2DSpec {
  const Character2DSpec({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.defaultPalette,
    required this.slots,
    this.faceStyle,
    required this.scale,
    required this.rigKind,
    required this.build,
    this.accessoryOptions = const {},
    this.defaultAccessories = const {},
    this.isPromptTemplate = false,
    this.designWidth = 360,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final PaletteColors defaultPalette;
  final List<PaletteSlot> slots;

  /// Humanoid face geometry (null for characters that draw their own face,
  /// e.g. the tiger or imported PNG cutouts).
  final FaceStyle? faceStyle;

  /// Uniform puppet scale (distinct body proportions per character).
  final double scale;

  /// 'humanoid_v1' | 'quadruped_v1' | 'png_cutout'.
  final String rigKind;

  final double designWidth;
  final List<Part2D> Function(Set<String> accessories) build;
  final Map<String, String> accessoryOptions;
  final Set<String> defaultAccessories;
  final bool isPromptTemplate;

  PaletteResolver defaultResolver() => defaultPalette.toResolver();

  /// Structured portable metadata (character.json header).
  Map<String, dynamic> metadata() => {
        'id': id,
        'name': name,
        'category': category,
        'type': '2D_RIGGED_CHARACTER',
        'rig': rigKind,
        'faceRig': true,
        'talking': true,
        'animations': const {
          'idle': true, 'walk': true, 'run': true, 'sit': true,
          'sleep': true, 'talk': true, 'jump': true, 'wave': true,
          'action': true, 'happy': true, 'sad': true, 'think': true,
          'turn': true, 'fall': true,
        },
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
    faceStyle: FaceStyle(
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
    rigKind: 'humanoid_v1',
    build: _farmerWithGamcha,
  );

  static List<Part2D> _farmerWithGamcha(Set<String> accessories) => buildFarmerParts();

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
    faceStyle: FaceStyle(
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
    rigKind: 'humanoid_v1',
    build: _girlWithDupatta,
  );

  static List<Part2D> _girlWithDupatta(Set<String> accessories) => buildGirlParts();

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
    faceStyle: FaceStyle(
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
    rigKind: 'humanoid_v1',
    build: _teacherFull,
  );

  static List<Part2D> _teacherFull(Set<String> accessories) => buildTeacherParts();

  static const tiger = Character2DSpec(
    id: 'tiger',
    name: 'Tiger',
    category: 'Animal',
    description: 'Cartoon tiger — striped quadruped with an expressive face and flowing tail.',
    defaultPalette: Palettes.tigerDefault,
    slots: [
      PaletteSlot(key: 'fur', label: 'Fur', swatches: Palettes.furSwatches),
      PaletteSlot(key: 'stripe', label: 'Stripes', swatches: Palettes.stripeSwatches),
      PaletteSlot(key: 'accent', label: 'Inner ears', swatches: Palettes.accentSwatches),
    ],
    accessoryOptions: {},
    defaultAccessories: {},
    faceStyle: null, // the tiger draws its own face shapes
    scale: 1.0,
    rigKind: 'quadruped_v1',
    designWidth: 340,
    build: _tigerBuild,
  );

  static List<Part2D> _tigerBuild(Set<String> accessories) => buildTigerParts();

  static const List<Character2DSpec> builtIn = [tiger, farmer, villageGirl, teacher];

  /// Runtime-registered characters (imported PNG cutouts, prompt-generated).
  static final List<Character2DSpec> dynamicSpecs = [];
  static void register(Character2DSpec spec) {
    dynamicSpecs.removeWhere((s) => s.id == spec.id);
    dynamicSpecs.add(spec);
  }

  static List<Character2DSpec> get all => [...builtIn, ...dynamicSpecs];

  static Character2DSpec? byId(String id) {
    for (final s in builtIn) {
      if (s.id == id) return s;
    }
    for (final s in dynamicSpecs) {
      if (s.id == id) return s;
    }
    return null;
  }
}
