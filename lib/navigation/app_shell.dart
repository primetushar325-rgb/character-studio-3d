import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../state/editor_provider.dart';
import '../state/library2d_provider.dart';
import '../state/shell_provider.dart';
import '../widgets/studio_bottom_nav.dart';
import '../screens/characters/characters2d_screen.dart';
import '../screens/editor/editor_screen.dart';
import '../screens/settings/settings_screen2.dart';

/// App shell: Editor · Characters · Settings. The 16:9 editor is home.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellProvider>();
    final library = Provider.of<Library2DProvider>(context, listen: false);
    final editor = Provider.of<EditorProvider>(context, listen: false);

    final screens = [
      const EditorScreen(),
      Characters2DScreen(),
      const SettingsScreen2(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: shell.index, children: screens),
      bottomNavigationBar: StudioBottomNav(
        currentIndex: shell.index,
        onTap: (i) {
          // Keep the editor's character picker in sync with the library.
          library.load();
          editor.controller ?? (editor.loadCharacter(library.all.first.id));
          shell.go(i);
        },
      ),
    );
  }
}
