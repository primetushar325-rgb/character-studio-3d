import 'package:flutter/material.dart';

/// Palette slot resolver — one map from slot name to Color for any character
/// (vector built-ins, prompt-generated and PNG cutouts all use the same
/// resolver so recolors work everywhere, including HTML export).
class PaletteResolver {
  const PaletteResolver(this._slots);

  final Map<String, Color> _slots;

  static const builtInSlots = <String>[
    'skin', 'skinShade', 'hair', 'shirt', 'shirtPattern', 'bottom',
    'accent', 'footwear', 'outline', 'cheek', 'glasses', 'book',
    'white', 'mouth', 'tongue', 'tear',
    // Tiger-specific (also usable by any animal).
    'fur', 'furShade', 'belly', 'stripe', 'nose', 'earInner',
  ];

  Color? operator [](String slot) => _slots[slot];

  Color get(String slot, Color fallback) => _slots[slot] ?? fallback;

  Map<String, Color> get slots => _slots;

  PaletteResolver withOverrides(Map<String, Color> overrides) => PaletteResolver({..._slots, ...overrides});

  Map<String, String> toHexMap() => {
        for (final e in _slots.entries)
          e.key: '#${e.value.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      };
}
