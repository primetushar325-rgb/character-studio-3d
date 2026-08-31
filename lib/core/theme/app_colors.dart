import 'package:flutter/material.dart';

/// Central color system for the premium dark theme (plus a light variant).
class AppColors {
  AppColors._();

  // ---- Core palette (dark) ----
  static const Color bg = Color(0xFF0A0C11);
  static const Color bgAlt = Color(0xFF0D1017);
  static const Color surface = Color(0xFF12151D);
  static const Color surfaceAlt = Color(0xFF171B26);
  static const Color card = Color(0xFF151925);

  static const Color stroke = Color(0x14FFFFFF); // ~8% white
  static const Color strokeStrong = Color(0x26FFFFFF);

  static const Color textPrimary = Color(0xFFEDEFF7);
  static const Color textSecondary = Color(0xFF9AA3B8);
  static const Color textMuted = Color(0xFF6B7385);

  static const Color accent = Color(0xFF7B9BFF);
  static const Color accentSoft = Color(0x1F7B9BFF);
  static const Color accentAlt = Color(0xFF5EEAD4);
  static const Color accentAltSoft = Color(0x1F5EEAD4);

  static const Color danger = Color(0xFFFF6B7A);
  static const Color dangerSoft = Color(0x1FFF6B7A);
  static const Color warning = Color(0xFFFFC46B);
  static const Color success = Color(0xFF6BD9A5);
  static const Color favorite = Color(0xFFFF7A9E);

  static const Color glassOverlay = Color(0x0FFFFFFF);
  static const Color shimmerBase = Color(0x0FFFFFFF);
  static const Color shimmerHighlight = Color(0x1FFFFFFF);

  // ---- Light palette ----
  static const Color lightBg = Color(0xFFF2F4F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightStroke = Color(0x1410142A);
  static const Color lightTextPrimary = Color(0xFF151926);
  static const Color lightTextSecondary = Color(0xFF5A6377);
  static const Color lightAccent = Color(0xFF4C6BF2);

  /// The signature premium gradient used sparingly (hero, primary buttons).
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6E8BFF), Color(0xFF5EEAD4)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF232C4B), Color(0xFF141A2C), Color(0xFF0A0C11)],
  );
}
