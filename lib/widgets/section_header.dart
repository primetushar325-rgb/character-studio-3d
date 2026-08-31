import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Uppercase section label with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 12),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onAction,
                child: Row(
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
