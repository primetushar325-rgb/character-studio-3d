import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'premium_button.dart';

/// Clean error card with retry + optional secondary action.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel = 'Try Again',
    this.secondaryLabel,
    this.onRetry,
    this.onSecondary,
    this.compact = false,
  });

  final String title;
  final String message;
  final String retryLabel;
  final String? secondaryLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.dangerSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 2),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (onRetry != null)
                Expanded(
                  child: PremiumButton(
                    label: retryLabel,
                    onPressed: onRetry,
                    icon: Icons.refresh_rounded,
                  ),
                ),
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: PremiumButton(
                    label: secondaryLabel!,
                    onPressed: onSecondary,
                    style: PremiumButtonStyle.ghost,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
