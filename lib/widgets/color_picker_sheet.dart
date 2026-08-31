import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'premium_button.dart';

/// Minimal premium color picker (hue/saturation field + brightness + swatches).
/// Returns a "#rrggbb" hex string. Entirely local — no extra packages.
class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({
    super.key,
    this.initialHex = '#10141F',
    this.title = 'Custom Background',
  });

  final String initialHex;
  final String title;

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late double _hue; // 0..360
  late double _sat; // 0..1
  late double _val; // 0..1
  int? _selectedSwatch;

  static const List<String> _swatchHexes = [
    '#0A0C11', '#10141F', '#17203A', '#1D2547',
    '#123A34', '#3A2410', '#3A1020', '#2E103A',
    '#0E2E3A', '#3F4757', '#8A93A8', '#E9ECF2',
    '#7B9BFF', '#5EEAD4', '#FF7A9E', '#FFC46B',
  ];

  @override
  void initState() {
    super.initState();
    final hsv = hsvFromHex(widget.initialHex);
    _hue = hsv.$1;
    _sat = hsv.$2;
    _val = hsv.$3;
  }

  String get _hex => hexFromHsv(_hue, _sat, _val);

  void _update({double? hue, double? sat, double? val, bool clearSwatch = false}) {
    setState(() {
      if (hue != null) _hue = hue;
      if (sat != null) _sat = sat;
      if (val != null) _val = val;
      if (clearSwatch) _selectedSwatch = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: _HueSatSquare(
                    hue: _hue,
                    sat: _sat,
                    val: _val,
                    onChanged: (h, s, v) => _update(hue: h, sat: s, val: v, clearSwatch: true),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 58,
                        decoration: BoxDecoration(
                          color: colorFromHex(_hex),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.stroke),
                        ),
                      ),
                      _MiniSlider(
                        label: 'B',
                        value: _val,
                        activeColor: colorFromHex(_hex),
                        onChanged: (v) => _update(val: v, clearSwatch: true),
                      ),
                      _MiniSlider(
                        label: 'H',
                        value: _hue / 360,
                        activeColor: colorFromHex(hexFromHsv(_hue, 1, 1)),
                        onChanged: (v) => _update(hue: v * 360, clearSwatch: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _swatchHexes.length; i++)
                  Semantics(
                    label: 'Color swatch ${i + 1}',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        final hsv = hsvFromHex(_swatchHexes[i]);
                        setState(() {
                          _selectedSwatch = i;
                          _hue = hsv.$1;
                          _sat = hsv.$2;
                          _val = hsv.$3;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorFromHex(_swatchHexes[i]),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedSwatch == i
                                ? Colors.white
                                : AppColors.strokeStrong,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PremiumButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    style: PremiumButtonStyle.ghost,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PremiumButton(
                    label: 'Apply',
                    onPressed: () => Navigator.of(context).pop(_hex),
                    style: PremiumButtonStyle.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HueSatSquare extends StatelessWidget {
  const _HueSatSquare({
    required this.hue,
    required this.sat,
    required this.val,
    required this.onChanged,
  });

  final double hue;
  final double sat;
  final double val;
  final void Function(double h, double s, double v) onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.hasBoundedWidth ? constraints.maxWidth : 132.0;
        return GestureDetector(
          onPanDown: (d) => _pick(d.localPosition, size),
          onPanUpdate: (d) => _pick(d.localPosition, size),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.stroke),
              gradient: SweepGradient(
                colors: [
                  for (var h = 0.0; h <= 360; h += 60)
                    colorFromHex(hexFromHsv(h % 360, 1, 1)),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: (sat * size).clamp(0, size) - 7,
                  top: ((1 - val) * size).clamp(0, size) - 7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorFromHex(hexFromHsv(hue, sat, val)),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _pick(Offset local, double size) {
    final s = (local.dx / size).clamp(0.0, 1.0);
    final v = 1 - (local.dy / size).clamp(0.0, 1.0);
    onChanged(hue, s, v);
  }
}

class _MiniSlider extends StatelessWidget {
  const _MiniSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// Pure-math color helpers (version-independent — no Color component APIs).
// ----------------------------------------------------------------------

/// HSV → "#rrggbb".
String hexFromHsv(double hue, double sat, double val) {
  final (r, g, b) = _hsvToRgb(hue, sat, val);
  String two(int v) =>
      v.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${two(r)}${two(g)}${two(b)}';
}

/// "#rrggbb" → (h, s, v).
(double, double, double) hsvFromHex(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 8) h = h.substring(2);
  if (h.length != 6) return (220, 0.12, 0.12);
  final value = int.tryParse(h, radix: 16);
  if (value == null) return (220, 0.12, 0.12);
  final r = ((value >> 16) & 0xFF) / 255.0;
  final g = ((value >> 8) & 0xFF) / 255.0;
  final b = (value & 0xFF) / 255.0;
  return _rgbToHsv(r, g, b);
}

Color colorFromHex(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 8) h = h.substring(2);
  if (h.length != 6) h = '10141F';
  final value = int.tryParse(h, radix: 16) ?? 0xFF10141F;
  return Color(0xFF000000 | value);
}

(int, int, int) _hsvToRgb(double hue, double sat, double val) {
  final c = sat * val;
  final hp = (hue % 360) / 60.0;
  final x = c * (1 - (hp % 2 - 1).abs());
  var (r1, g1, b1) = (0.0, 0.0, 0.0);
  if (hp < 1) {
    (r1, g1, b1) = (c, x, 0);
  } else if (hp < 2) {
    (r1, g1, b1) = (x, c, 0);
  } else if (hp < 3) {
    (r1, g1, b1) = (0, c, x);
  } else if (hp < 4) {
    (r1, g1, b1) = (0, x, c);
  } else if (hp < 5) {
    (r1, g1, b1) = (x, 0, c);
  } else {
    (r1, g1, b1) = (c, 0, x);
  }
  final m = val - c;
  return (
    ((r1 + m) * 255).round(),
    ((g1 + m) * 255).round(),
    ((b1 + m) * 255).round(),
  );
}

(double, double, double) _rgbToHsv(double r, double g, double b) {
  final max = math.max(r, math.max(g, b));
  final min = math.min(r, math.min(g, b));
  final d = max - min;
  var hue = 0.0;
  if (d > 0.00001) {
    if (max == r) {
      hue = 60 * (((g - b) / d) % 6);
    } else if (max == g) {
      hue = 60 * (((b - r) / d) + 2);
    } else {
      hue = 60 * (((r - g) / d) + 4);
    }
  }
  if (hue < 0) hue += 360;
  final sat = max <= 0 ? 0.0 : d / max;
  return (hue, sat, max);
}
