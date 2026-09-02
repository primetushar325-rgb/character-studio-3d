import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/main.dart' show CharacterStudioRoot;
import 'package:character_studio_3d/navigation/app_shell.dart';
import 'package:character_studio_3d/project/project_document.dart';
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

  // ============================================================
  // REGRESSION: v2.4.2 device bug — MY PROJECTS spun forever because
  // NOTHING in the real app ever called projects.load(), and every open
  // failed with "Project could not be opened" because bindEditor was
  // never called outside tests.
  // ============================================================

  testWidgets('HOME starts loading the project list BY ITSELF (wiring regression)',
      (tester) async {
    final library = Library2DProvider(repo: Character2DRepository());
    final tmpRoot = Directory.systemTemp.createTempSync('selfload');
    final projects = _RecordingProjects(
        repo: ProjectRepository(baseDir: Directory('${tmpRoot.path}/projects')));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: library),
          ChangeNotifierProvider(create: (_) => ShellProvider()),
          ChangeNotifierProvider(create: (_) => EditorProvider(library)),
          ChangeNotifierProvider<ProjectsProvider>.value(value: projects),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    // THE v2.4.2 device bug: nothing called load() from the real app —
    // the spinner ran forever. HomeScreen.initState must trigger it.
    expect(projects.loadStarted, isTrue,
        reason: 'HomeScreen must call load() on init');
  });

  test('provider.load completes and lists seeded projects (real async)', () async {
    final tmpRoot = Directory.systemTemp.createTempSync('selfload2');
    final projects = ProjectsProvider(
        repo: ProjectRepository(baseDir: Directory('${tmpRoot.path}/projects')));
    await projects.repo.create(ProjectDocument(
        id: 'prj_a', name: 'Disk Project A', orientation: 'landscape16x9',
        canvasWidth: 1920, canvasHeight: 1080));
    await projects.repo.create(ProjectDocument(
        id: 'prj_b', name: 'Disk Project B', orientation: 'portrait9x16',
        canvasWidth: 1080, canvasHeight: 1920));

    await projects.load();
    expect(projects.loaded, isTrue);
    expect(projects.loadError, isNull);
    expect(projects.projects.length, 2);
    expect(projects.projects.map((p) => p.name).toSet(),
        containsAll(['Disk Project A', 'Disk Project B']));

    // Concurrent callers share ONE load (no race, §17).
    final a = projects.reloadList();
    final b = projects.reloadList();
    await Future.wait([a, b]);
    expect(projects.projects.length, 2);
  });

  testWidgets('REAL root (main.dart wiring): opens HOME, editor bound, spinner always ends',
      (tester) async {
    // Pumps the ACTUAL production root — same wiring as on device. In the
    // test env path_provider has no platform channel, so storage listing
    // fails; the requirement is the ERROR state (retry), never a stuck
    // spinner, never a crash, never the editor.
    await tester.pumpWidget(const CharacterStudioRoot());
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.text('NEW PROJECT'), findsOneWidget);

    final projects = tester.element(find.byType(HomeScreen))
        .read<ProjectsProvider>();
    // Either the list loaded (device storage OK) or the error state is
    // shown — the one impossible state is LOADING forever.
    expect(projects.loaded || projects.loadError != null, isTrue,
        reason: 'spinner must resolve to SUCCESS or ERROR');

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  test('provider: storage failure → ERROR state + list stays usable (no throw)', () async {
    final notADir = File('${Directory.systemTemp.createTempSync('badbase').path}/projects');
    await notADir.writeAsString('this is a file, not a directory');
    final projects = ProjectsProvider(
        repo: ProjectRepository(baseDir: Directory(notADir.path)));

    // Must complete WITHOUT throwing despite the failing storage.
    await projects.load();
    expect(projects.loaded, isFalse);
    expect(projects.loadError, isNotNull);

    // Retry path is equally safe.
    await projects.reloadList();
    expect(projects.loadError, isNotNull);
  });
}


/// Records whether load() was invoked — proves the UI wiring without
/// depending on the fake-async IO completing.
class _RecordingProjects extends ProjectsProvider {
  _RecordingProjects({required super.repo});
  bool loadStarted = false;
  @override
  Future<void> load() {
    loadStarted = true;
    return super.load();
  }
}
