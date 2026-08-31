import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/characters/characters_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/projects/projects_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../state/shell_provider.dart';
import '../widgets/studio_bottom_nav.dart';

/// Root scaffold: IndexedStack pages + premium bottom navigation.
/// IndexedStack keeps each tab's state alive (no reload jank).
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellProvider>();

    final pages = const [
      HomeScreen(),
      CharactersScreen(),
      ProjectsScreen(),
      FavoritesScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: shell.index,
        children: pages,
      ),
      bottomNavigationBar: Semantics(
        label: 'Main navigation',
        child: StudioBottomNav(
          currentIndex: shell.index,
          onTap: (i) {
            // Ignore taps that would rebuild the page needlessly.
            context.read<ShellProvider>().go(i);
          },
        ),
      ),
    );
  }
}
