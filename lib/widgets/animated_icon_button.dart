import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Icon button with a press "pop" animation and semantic label.
class AnimatedIconButton extends StatefulWidget {
  const AnimatedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.size = 24,
    this.color,
    this.activeColor,
    this.active = false,
    this.background,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? semanticLabel;
  final double size;
  final Color? color;
  final Color? activeColor;
  final bool active;
  final Color? background;

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.82,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.82);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = widget.active
        ? (widget.activeColor ?? AppColors.accent)
        : (widget.color ??
            (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary));

    return Semantics(
      label: widget.semanticLabel ?? widget.tooltip,
      button: true,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.82, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        ),
        child: IconButton(
          onPressed: _handleTap,
          tooltip: widget.tooltip,
          iconSize: widget.size,
          color: fg,
          style: widget.background == null
              ? null
              : ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(widget.background),
                ),
          icon: Icon(widget.icon),
        ),
      ),
    );
  }
}
