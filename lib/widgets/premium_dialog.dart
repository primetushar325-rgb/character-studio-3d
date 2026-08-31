import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'premium_button.dart';

/// Modal helpers with the studio design language.
class PremiumDialog extends StatelessWidget {
  const PremiumDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.iconColor,
    this.child,
    required this.actions,
    this.semanticLabel,
  });

  final String title;
  final String message;
  final IconData? icon;
  final Color? iconColor;
  final Widget? child;
  final List<Widget> actions;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: semanticLabel ?? title,
      scopesRoute: true,
      explicitChildNodes: true,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Dialog(
          backgroundColor:
              isDark ? AppColors.surface : Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor?.withOpacity(0.14) ??
                          AppColors.accentSoft,
                    ),
                    child: Icon(icon, color: iconColor ?? AppColors.accent, size: 28),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (child != null) ...[
                  const SizedBox(height: 16),
                  child!,
                ],
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showPremiumDialog<T>(BuildContext context, Widget dialog) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondary) => dialog,
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Standard destructive-confirmation dialog.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showPremiumDialog<bool>(
    context,
    PremiumDialog(
      title: title,
      message: message,
      icon: destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
      iconColor: destructive ? AppColors.danger : AppColors.accent,
      actions: [
        PremiumTextButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
        PremiumButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive ? PremiumButtonStyle.danger : PremiumButtonStyle.primary,
          small: true,
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Animated success dialog (import success, export success…).
class SuccessCheckDialog extends StatefulWidget {
  const SuccessCheckDialog({
    super.key,
    required this.title,
    required this.message,
    this.details,
    required this.actions,
  });

  final String title;
  final String message;
  final Widget? details;
  final List<Widget> actions;

  @override
  State<SuccessCheckDialog> createState() => _SuccessCheckDialogState();
}

class _SuccessCheckDialogState extends State<SuccessCheckDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Dialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surface
            : Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0x336BD9A5), Color(0x116BD9A5)],
                    ),
                    border: Border.all(color: AppColors.success.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.success, size: 40),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (widget.details != null) ...[
                const SizedBox(height: 14),
                widget.details!,
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: widget.actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
