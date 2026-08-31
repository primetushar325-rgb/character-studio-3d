import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'state/settings_provider.dart';

/// Root widget: theme + onboarding gate + shell.
class CharacterStudioApp extends StatelessWidget {
  const CharacterStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) {
        // Clamp extreme text scaling to keep the studio layout intact.
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.25,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: settings.onboarded ? const AppShell() : const OnboardingScreen(),
    );
  }
}
