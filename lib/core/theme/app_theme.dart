import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Design system for Character Studio 3D.
/// Premium dark theme by default, with a clean light variant.
class AppTheme {
  AppTheme._();

  static const double radius = 20;
  static const double radiusSmall = 12;

  // ------------------------------------------------------------------
  // DARK (default)
  // ------------------------------------------------------------------
  static ThemeData dark() {
    final scheme = const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Color(0xFF0A0C11),
      secondary: AppColors.accentAlt,
      onSecondary: Color(0xFF0A0C11),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceAlt,
      onSurfaceVariant: AppColors.textSecondary,
      error: AppColors.danger,
      onError: Color(0xFF16070A),
      outline: AppColors.strokeStrong,
      outlineVariant: AppColors.stroke,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
    );

    return base.copyWith(
      textTheme: _textTheme(AppColors.textPrimary, AppColors.textSecondary),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.stroke),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.stroke, thickness: 1, space: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.strokeStrong,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.stroke),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.stroke),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.strokeStrong,
        thumbColor: Colors.white,
        overlayColor: AppColors.accentSoft,
        trackHeight: 3,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.stroke),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accentSoft,
        selectionHandleColor: AppColors.accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.strokeStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textMuted,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.stroke),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),
    );
  }

  // ------------------------------------------------------------------
  // LIGHT
  // ------------------------------------------------------------------
  static ThemeData light() {
    final scheme = const ColorScheme.light(
      primary: AppColors.lightAccent,
      onPrimary: Colors.white,
      secondary: Color(0xFF0E9488),
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: Color(0xFFE9EDF6),
      onSurfaceVariant: AppColors.lightTextSecondary,
      error: Color(0xFFD64560),
      outline: Color(0x3310142A),
      outlineVariant: AppColors.lightStroke,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      ),
    );

    return base.copyWith(
      textTheme: _textTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
      cardTheme: CardTheme(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.lightStroke),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.lightStroke, thickness: 1, space: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.lightStroke),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: const TextStyle(color: AppColors.lightTextPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.lightStroke),
        ),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 3),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 40, height: 1.05, fontWeight: FontWeight.w800, color: primary, letterSpacing: -1.5),
      displayMedium: TextStyle(fontSize: 32, height: 1.1, fontWeight: FontWeight.w800, color: primary, letterSpacing: -1),
      headlineLarge: TextStyle(fontSize: 26, height: 1.15, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.4),
      headlineSmall: TextStyle(fontSize: 18, height: 1.25, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.2),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.1),
      titleSmall: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: TextStyle(fontSize: 15.5, height: 1.45, color: primary),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: secondary),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.35, color: secondary),
      labelLarge: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: primary, letterSpacing: 0.1),
      labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: secondary, letterSpacing: 0.2),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: secondary, letterSpacing: 0.3),
    );
  }
}
