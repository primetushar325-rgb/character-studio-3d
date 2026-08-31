import 'package:flutter/material.dart';

/// Background options for the 3D stage.
enum BackgroundPreset {
  studio('Studio'),
  dark('Dark'),
  light('Light'),
  transparent('Transparent'),
  gradient('Gradient'),
  custom('Custom');

  const BackgroundPreset(this.label);
  final String label;

  IconData get icon => switch (this) {
        studio => Icons.blur_circular_rounded,
        dark => Icons.dark_mode_rounded,
        light => Icons.light_mode_rounded,
        transparent => Icons.grid_on_rounded,
        gradient => Icons.gradient_rounded,
        custom => Icons.palette_rounded,
      };
}

/// Studio lighting presets — mapped onto the 3D engine's exposure/shadow
/// controls so no online HDRI is ever needed.
enum LightingPreset {
  studio(1.0, 1.0, 0.85, 'Studio'),
  soft(0.85, 0.45, 1.0, 'Soft'),
  bright(1.35, 0.65, 0.6, 'Bright'),
  dark(0.62, 0.25, 0.9, 'Dark'),
  dramatic(1.18, 1.0, 0.25, 'Dramatic');

  const LightingPreset(this.exposure, this.shadowIntensity, this.shadowSoftness, this.label);
  final double exposure;
  final double shadowIntensity;
  final double shadowSoftness;
  final String label;

  IconData get icon => switch (this) {
        studio => Icons.tungsten_rounded,
        soft => Icons.light_mode_outlined,
        bright => Icons.wb_sunny_rounded,
        dark => Icons.nights_stay_rounded,
        dramatic => Icons.highlight_rounded,
      };
}

/// Camera orbit presets (model-viewer orbit strings).
class CameraPresets {
  CameraPresets._();

  static const String front = '0deg 75deg auto';
  static const String threeQuarter = '35deg 75deg auto';
  static const String side = '90deg 75deg auto';
  static const String back = '180deg 75deg auto';
  static const String elevated = '15deg 55deg auto';

  static const List<(String, String, IconData)> all = [
    ('front', front, Icons.crop_square_rounded),
    ('three-quarter', threeQuarter, Icons.threed_rotation_rounded),
    ('side', side, Icons.flip_rounded),
    ('back', back, Icons.replay_rounded),
    ('elevated', elevated, Icons.flight_takeoff_rounded),
  ];

  static String labelFor(String orbit) {
    for (final (label, value, _) in all) {
      if (value == orbit) return label;
    }
    return 'custom';
  }
}

/// Build the CSS background used by the 3D stage.
String backgroundCss(BackgroundPreset preset, {String? customHex}) {
  switch (preset) {
    case BackgroundPreset.studio:
      return 'radial-gradient(circle at 50% 30%, #1c2233 0%, #10141f 55%, #0a0c11 100%)';
    case BackgroundPreset.dark:
      return '#06070a';
    case BackgroundPreset.light:
      return '#e9ecf2';
    case BackgroundPreset.transparent:
      // Checkerboard communicates transparency without any external asset.
      return 'repeating-conic-gradient(#161a24 0% 25%, #0e1119 0% 50%) 50% / 24px 24px';
    case BackgroundPreset.gradient:
      return 'linear-gradient(160deg, #1d2547 0%, #10141f 45%, #10312e 100%)';
    case BackgroundPreset.custom:
      final hex = customHex ?? '#10141f';
      final normalized = hex.startsWith('#') ? hex : '#$hex';
      return normalized.toLowerCase();
  }
}
