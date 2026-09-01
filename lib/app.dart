import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'navigation/app_shell.dart';

/// Root widget: dark premium 2D studio theme + shell.
class CharacterStudioApp extends StatelessWidget {
  const CharacterStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2D Character Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.25);
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppShell(),
    );
  }
}
