import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'premium_button.dart';

/// Elegant empty state with icon, copy and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 64 : 84,
              height: compact ? 64 : 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [AppColors.accentSoft, AppColors.surface]
                      : [const Color(0xFFE3E9FF), Colors.white],
                ),
                border:
                    Border.all(color: isDark ? AppColors.stroke : AppColors.lightStroke),
              ),
              child: Icon(icon,
                  size: compact ? 28 : 36,
                  color: isDark ? AppColors.accent : AppColors.lightAccent),
            ),
            SizedBox(height: compact ? 14 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              PremiumButton(
                label: actionLabel!,
                onPressed: onAction,
                icon: Icons.add_rounded,
                style: PremiumButtonStyle.tonal,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
