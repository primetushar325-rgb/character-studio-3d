import 'package:flutter/material.dart';

/// Resolved color slots used by every part painter.
class PaletteColors {
  const PaletteColors({
    required this.skin,
    required this.skinShade,
    required this.hair,
    required this.shirt,
    required this.shirtPattern,
    required this.bottom,
    required this.accent,
    required this.footwear,
    required this.outline,
    this.cheek = const Color(0x00000000),
    this.glasses = const Color(0xFF2A2D34),
    this.book = const Color(0xFFB33E3E),
  });

  final Color skin;
  final Color skinShade;
  final Color hair;
  final Color shirt;
  final Color shirtPattern;
  final Color bottom;
  final Color accent;
  final Color footwear;
  final Color outline;
  final Color cheek;
  final Color glasses;
  final Color book;

  PaletteColors withOverrides(Map<String, Color> overrides) {
    Color? c(String k) => overrides[k];
    return PaletteColors(
      skin: c('skin') ?? skin,
      skinShade: c('skinShade') ?? skinShade,
      hair: c('hair') ?? hair,
      shirt: c('shirt') ?? shirt,
      shirtPattern: c('shirtPattern') ?? shirtPattern,
      bottom: c('bottom') ?? bottom,
      accent: c('accent') ?? accent,
      footwear: c('footwear') ?? footwear,
      outline: outline,
      cheek: cheek,
      glasses: c('glasses') ?? glasses,
      book: c('book') ?? book,
    );
  }

  Map<String, Color> toMap() => {
        'skin': skin,
        'skinShade': skinShade,
        'hair': hair,
        'shirt': shirt,
        'shirtPattern': shirtPattern,
        'bottom': bottom,
        'accent': accent,
        'footwear': footwear,
        'glasses': glasses,
        'book': book,
      };
}

/// One editable customization slot shown in the Customize sheet.
class PaletteSlot {
  const PaletteSlot({required this.key, required this.label, required this.swatches});

  final String key;
  final String label;
  final List<Color> swatches;
}

class Palettes {
  const Palettes._();

  static const farmerDefault = PaletteColors(
    skin: Color(0xFFB07A54),
    skinShade: Color(0xFF96633F),
    hair: Color(0xFF23201E),
    shirt: Color(0xFFF3EEDF),
    shirtPattern: Color(0xFFE4DCC6),
    bottom: Color(0xFF3E5F8A),
    accent: Color(0xFFD9532B),
    footwear: Color(0xFF7A5433),
    outline: Color(0xFF2B2523),
    cheek: Color(0x26D96F4A),
  );

  static const villageGirlDefault = PaletteColors(
    skin: Color(0xFFB8825C),
    skinShade: Color(0xFF9C6A46),
    hair: Color(0xFF1E1B1C),
    shirt: Color(0xFFF2A03D),
    shirtPattern: Color(0xFFE08A25),
    bottom: Color(0xFF7C4DBE),
    accent: Color(0xFFE4566F),
    footwear: Color(0xFF8A5A36),
    outline: Color(0xFF2B2523),
    cheek: Color(0x33E0637A),
  );

  static const teacherDefault = PaletteColors(
    skin: Color(0xFFAC7750),
    skinShade: Color(0xFF8F5F3C),
    hair: Color(0xFF26221F),
    shirt: Color(0xFFEAF0F6),
    shirtPattern: Color(0xFFDCE4EE),
    bottom: Color(0xFF2F3640),
    accent: Color(0xFF3D7A5C),
    footwear: Color(0xFF312A24),
    outline: Color(0xFF2B2523),
    cheek: Color(0x1FD96F4A),
  );

  static const shirtSwatches = [
    Color(0xFFF3EEDF), Color(0xFFEAF0F6), Color(0xFF6FA8DC), Color(0xFF4C9A6A),
    Color(0xFFD9532B), Color(0xFFE4566F), Color(0xFFF2A03D), Color(0xFF8E6FC0),
    Color(0xFF7C8B99), Color(0xFF3E5F8A),
  ];

  static const bottomSwatches = [
    Color(0xFF3E5F8A), Color(0xFF2F3640), Color(0xFF4C9A6A), Color(0xFF7C4DBE),
    Color(0xFF8A5A36), Color(0xFFB03A3A), Color(0xFF5A6B7A), Color(0xFF233240),
  ];

  static const hairSwatches = [
    Color(0xFF23201E), Color(0xFF3E2A1C), Color(0xFF5A3A22), Color(0xFF74462A),
    Color(0xFF1E1B1C), Color(0xFF4A4E57),
  ];

  static const accentSwatches = [
    Color(0xFFD9532B), Color(0xFFE4566F), Color(0xFF3D7A5C), Color(0xFF3E5F8A),
    Color(0xFFF2C14E), Color(0xFF7C4DBE), Color(0xFFB03A3A), Color(0xFF2E8B8B),
  ];

  static const skinSwatches = [
    Color(0xFFB07A54), Color(0xFFB8825C), Color(0xFFAC7750), Color(0xFF9A6A48),
    Color(0xFFC68F63), Color(0xFF8A5A3C),
  ];
}
