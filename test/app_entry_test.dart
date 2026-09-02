import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/navigation/app_shell.dart';
import 'package:character_studio_3d/project/project_repository.dart';
import 'package:character_studio_3d/screens/editor/editor_screen.dart';
import 'package:character_studio_3d/screens/home/home_screen.dart';
import 'package:character_studio_3d/state/editor_provider.dart';
import 'package:character_studio_3d/state/library2d_provider.dart';
import 'package:character_studio_3d/state/projects_provider.dart';
import 'package:character_studio_3d/state/shell_provider.dart';

/// REGRESSION TEST for the real app entry.
///
/// History: Phase 1-4 built HomeScreen + the whole project system, but
/// `AppShell` still opened the OLD editor tab first — shipped like that in
/// v2.1.0/v2.4.0 because every test pumped screens in isolation instead of
/// the actual shell. This test pumps the REAL shell so that can never happen
/// again: the app must open on HOME, with the editor reachable only by
/// opening a project.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('REAL app entry: shell opens on HOME, not the editor',
      (tester) async {
    final library = Library2DProvider(repo: Character2DRepository());
    final projects = ProjectsProvider(
        repo: ProjectRepository(
            baseDir: Directory.systemTemp.createTempSync('entry_ui')));

    await tester.runAsync(() async {
      await library.load();
      await projects.load();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: library),
          ChangeNotifierProvider(create: (_) => ShellProvider()),
          ChangeNotifierProvider(create: (_) => EditorProvider(library)),
          ChangeNotifierProvider.value(value: projects),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // HOME is what the user sees first.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('NEW PROJECT'), findsOneWidget);
    expect(find.text('MY PROJECTS'), findsOneWidget);

    // The editor is NOT mounted until a project is opened.
    expect(find.byType(EditorScreen), findsNothing);

    // Bottom nav: Home is the first tab and selected.
    expect(find.text('Home'), findsOneWidget);

    // Quick links still navigate to the other tabs (the QUICK LINK card,
    // not the identically-labelled bottom-nav item).
    await tester.tap(find.text('Characters').first);
    await tester.pumpAndSettle();
    // IndexedStack keeps Home alive but OFFSTAGE (invisible) on tab 2.
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('NEW PROJECT'), findsNothing);

    // Temp dir under /tmp — OS cleanup; real IO must stay inside runAsync.
  });
}
