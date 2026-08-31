import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Premium search field with instant local search.
class StudioSearchBar extends StatelessWidget {
  const StudioSearchBar({
    super.key,
    required this.hint,
    this.onChanged,
    this.controller,
    this.semanticsLabel,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: semanticsLabel ?? hint,
      textField: true,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? AppColors.textMuted : const Color(0xFF9AA5B5),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              size: 21,
              color: isDark ? AppColors.textMuted : const Color(0xFF9AA5B5)),
          suffixIcon: controller != null && (controller?.text.isNotEmpty ?? false)
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: isDark ? AppColors.textMuted : const Color(0xFF9AA5B5)),
                  onPressed: () {
                    controller?.clear();
                    onChanged?.call('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? AppColors.surface : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: isDark ? AppColors.stroke : AppColors.lightStroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: isDark ? AppColors.stroke : AppColors.lightStroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
          ),
        ),
      ),
    );
  }
}
