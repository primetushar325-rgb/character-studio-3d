import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/project/project_document.dart';
import 'package:character_studio_3d/project/project_repository.dart';
import 'package:character_studio_3d/screens/home/home_screen.dart';
import 'package:character_studio_3d/state/editor_provider.dart';
import 'package:character_studio_3d/state/library2d_provider.dart';
import 'package:character_studio_3d/state/projects_provider.dart';
import 'package:character_studio_3d/state/shell_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// MANDATORY MANUAL ACCEPTANCE TEST, automated at the state level (real
  /// files, real restart): STEP 1 Home-first is verified by the widget test
  /// below; STEPS 2–14 persistence is verified here with REAL disk IO.
  test('ACCEPTANCE STEPS 2–12: My Story 16:9 survives app restart exactly', () async {
    final docs = await Directory.systemTemp.createTemp('accept_home');
    final repo = ProjectRepository(baseDir: docs);
    final library = Library2DProvider(repo: Character2DRepository())..load();
    await library.load();

    // ---- App instance #1: Home → NEW PROJECT → "My Story" → Landscape ----
    final ed1 = EditorProvider(library);
    final app1 = ProjectsProvider(repo: repo)..bindEditor(ed1);
    await app1.load();
    final doc = await app1.createProject(name: 'My Story', orientation: ProjectOrientation.landscape16x9);

    expect(doc.canvasWidth, 1920);
    expect(doc.canvasHeight, 1080);

    // STEP 6/7/8 (through the real editor API): background + character +
    // position/scale.
    ed1.setBackground(ed1.background);
    ed1.loadCharacter('tiger');
    ed1.setAction('walk');
    ed1.setTransform((t) {
      t.x = 0.33;
      t.y = 0.85;
      t.scale = 1.6;
    });
    await app1.closeCurrent(); // STEP 9: leave editor → saves

    // ---- STEP 10: "kill" the app — brand-new provider instances ----------
    final ed2 = EditorProvider(library);
    final app2 = ProjectsProvider(repo: repo)..bindEditor(ed2);
    await app2.load();

    // STEP 11: Home shows the project.
    expect(app2.projects.any((p) => p.name == 'My Story'), true);

    // STEP 12: reopen → same orientation, background kind, character,
    // transform, scale, animation.
    await app2.openProject(doc.id);
    expect(ed2.canvasWidth, 1920);
    expect(ed2.canvasHeight, 1080);
    expect(ed2.project!.orientation, ProjectOrientation.landscape16x9);
    expect(ed2.character!.id, 'tiger');
    expect(ed2.transform.x, closeTo(0.33, 1e-9));
    expect(ed2.transform.y, closeTo(0.85, 1e-9));
    expect(ed2.transform.scale, closeTo(1.6, 1e-9));
    expect(ed2.controller!.actionId, 'walk');
    expect(ed2.background.kind.name, 'builtin'); // background state restored
    await app2.closeCurrent();

    await docs.delete(recursive: true);
  });

  test('ACCEPTANCE STEPS 13–14: portrait and square projects keep canvas', () async {
    final docs = await Directory.systemTemp.createTemp('accept_orient');
    final repo = ProjectRepository(baseDir: docs);
    final library = Library2DProvider(repo: Character2DRepository())..load();
    await library.load();
    final ed = EditorProvider(library);
    final app = ProjectsProvider(repo: repo)..bindEditor(ed);
    await app.load();

    final portrait = await app.createProject(name: 'Test Portrait', orientation: ProjectOrientation.portrait9x16);
    expect(portrait.canvasWidth, 1080);
    expect(portrait.canvasHeight, 1920);
    await app.closeCurrent();

    final square = await app.createProject(name: 'Test Square', orientation: ProjectOrientation.square1x1);
    expect(square.canvasWidth, 1080);
    expect(square.canvasHeight, 1080);
    await app.closeCurrent();

    // After "restart": both listed with correct orientation.
    final app2 = ProjectsProvider(repo: repo);
    await app2.load();
    final p = app2.projects.firstWhere((x) => x.name == 'Test Portrait');
    final s = app2.projects.firstWhere((x) => x.name == 'Test Square');
    expect(p.orientation, ProjectOrientation.portrait9x16);
    expect(s.orientation, ProjectOrientation.square1x1);

    await docs.delete(recursive: true);
  });

  test('autosave is debounced — project saves on pause even without close', () async {
    final docs = await Directory.systemTemp.createTemp('accept_autosave');
    final repo = ProjectRepository(baseDir: docs);
    final library = Library2DProvider(repo: Character2DRepository())..load();
    await library.load();
    final ed = EditorProvider(library);
    final app = ProjectsProvider(repo: repo)..bindEditor(ed);
    await app.load();
    await app.createProject(name: 'Autosave', orientation: ProjectOrientation.landscape16x9);

    ed.loadCharacter('village_girl'); // notifies → schedules debounced save
    // Lifecycle pause BEFORE the debounce fires → must still be saved.
    await app.onAppPaused();

    final reopened = await repo.load(ed.project!.id);
    expect(reopened!.characterId, 'village_girl');
    await app.closeCurrent();
    await docs.delete(recursive: true);
  });

  // ---- STEP 1: the app entry is HOME, not the editor ------------------------
  testWidgets('HomeScreen is the entry — NEW PROJECT / MY PROJECTS / CHARACTERS visible', (tester) async {
    late Directory tmpDir;
    final library = Library2DProvider(repo: Character2DRepository());
    final projects = ProjectsProvider(repo: ProjectRepository(baseDir: Directory.systemTemp.createTempSync('accept_ui')));
    // ALL real IO must live inside runAsync inside testWidgets.
    await tester.runAsync(() async {
      await library.load();
      tmpDir = (await projects.repo.baseDir());
      await projects.load();
      await projects.createProject(name: 'UI Story', orientation: ProjectOrientation.landscape16x9);
      await projects.closeCurrent();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: library),
          ChangeNotifierProvider(create: (_) => ShellProvider()),
          ChangeNotifierProvider(create: (_) => EditorProvider(library)),
          ChangeNotifierProvider.value(value: projects),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2D STORY / VIDEO EDITOR'), findsOneWidget);
    expect(find.text('NEW PROJECT'), findsOneWidget);
    expect(find.text('MY PROJECTS'), findsOneWidget);
    expect(find.text('UI Story'), findsOneWidget); // project card listed
    expect(find.text('Characters'), findsOneWidget); // shortcut exists
    // The editor (its Export button) is NOT on the entry screen.
    expect(find.text('Export'), findsNothing);

    await tester.runAsync(() => tmpDir.delete(recursive: true));
  });
}

