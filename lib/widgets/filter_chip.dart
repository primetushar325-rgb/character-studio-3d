import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Premium selectable chip (used for filters & option rows).
class StudioFilterChip extends StatelessWidget {
  const StudioFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentSoft
                : (isDark ? AppColors.surface : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withOpacity(0.55)
                  : (isDark ? AppColors.stroke : AppColors.lightStroke),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16,
                    color: selected
                        ? AppColors.accent
                        : (isDark ? AppColors.textSecondary : const Color(0xFF5A6377))),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: selected
                      ? AppColors.accent
                      : (isDark ? AppColors.textSecondary : const Color(0xFF5A6377)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
