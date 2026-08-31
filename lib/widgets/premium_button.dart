import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum PremiumButtonStyle { primary, tonal, ghost, danger, success }

/// Signature button with press micro-animation.
/// - primary: indigo→teal gradient
/// - tonal: translucent accent
/// - ghost: outline only
/// - danger / success: semantic colors
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PremiumButtonStyle.tonal,
    this.expanded = false,
    this.small = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PremiumButtonStyle style;
  final bool expanded;
  final bool small;
  final String? semanticLabel;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onPressed != null;

    final (bg, fg, border, useGradient) = _colors(context, isDark);

    final height = widget.small ? 38.0 : 52.0;
    final radius = widget.small ? 12.0 : 16.0;

    final child = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: widget.small ? 14 : 20),
        decoration: BoxDecoration(
          gradient: useGradient ? AppColors.primaryGradient : null,
          color: useGradient ? null : (enabled ? bg : (isDark ? AppColors.surfaceAlt : const Color(0xFFE5E9F2))),
          borderRadius: BorderRadius.circular(radius),
          border: border != null ? Border.all(color: border) : null,
          boxShadow: enabled && useGradient
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: widget.small ? 16 : 19, color: enabled ? fg : (isDark ? AppColors.textMuted : const Color(0xFF9AA5B5))),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? fg : (isDark ? AppColors.textMuted : const Color(0xFF9AA5B5)),
                  fontSize: widget.small ? 13 : 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: widget.expanded
            ? SizedBox(width: double.infinity, child: child)
            : child,
      ),
    );
  }

  (Color, Color, Color?, bool) _colors(BuildContext context, bool isDark) {
    switch (widget.style) {
      case PremiumButtonStyle.primary:
        return (AppColors.accent, const Color(0xFF0A0C11), null, true);
      case PremiumButtonStyle.tonal:
        return (isDark ? AppColors.accentSoft : const Color(0xFFE3E9FF),
            isDark ? AppColors.accent : AppColors.lightAccent,
            isDark ? AppColors.stroke : AppColors.lightStroke,
            false);
      case PremiumButtonStyle.ghost:
        return (Colors.transparent,
            isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
            isDark ? AppColors.strokeStrong : AppColors.lightStroke,
            false);
      case PremiumButtonStyle.danger:
        return (AppColors.dangerSoft, AppColors.danger, AppColors.dangerSoft, false);
      case PremiumButtonStyle.success:
        return (Color(0x1F6BD9A5), AppColors.success, Color(0x1F6BD9A5), false);
    }
  }
}

/// Used by premium dialogs for text actions.
class PremiumTextButton extends StatelessWidget {
  const PremiumTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: danger
            ? AppColors.danger
            : (color ?? (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Small circular icon button used across the studio.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 42,
    this.iconSize = 20,
    this.active = false,
    this.foreground,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool active;
  final Color? foreground;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: semanticLabel ?? tooltip,
      button: true,
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: active
              ? AppColors.accentSoft
              : (isDark ? AppColors.surfaceAlt : const Color(0xFFE9EDF6)),
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.stroke),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: iconSize,
                color: foreground ??
                    (active
                        ? AppColors.accent
                        : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
