import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../state/library2d_provider.dart';
import '../state/shell_provider.dart';
import '../widgets/studio_bottom_nav.dart';
import '../screens/characters/characters2d_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen2.dart';

/// App shell: HOME · Characters · Settings. The app opens on HOME (project
/// list / new project); the editor is pushed full-screen per project via
/// [openProjectEditor]. Spec §1/§19: no project is auto-created and no
/// character is auto-loaded into the editor.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellProvider>();
    final library = Provider.of<Library2DProvider>(context, listen: false);

    final screens = [
      const HomeScreen(),
      Characters2DScreen(),
      const SettingsScreen2(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: shell.index, children: screens),
      bottomNavigationBar: StudioBottomNav(
        currentIndex: shell.index,
        onTap: (i) {
          // Keep the character picker in sync with the library. The editor
          // itself stays untouched until a real project is opened.
          library.load();
          shell.go(i);
        },
      ),
    );
  }
}
