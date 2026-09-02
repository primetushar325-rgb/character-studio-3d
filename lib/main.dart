import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'characters2d/character2d_repository.dart';
import 'state/editor_provider.dart';
import 'state/library2d_provider.dart';
import 'state/projects_provider.dart';
import 'state/shell_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CharacterStudioRoot());
}

class CharacterStudioRoot extends StatelessWidget {
  const CharacterStudioRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = Character2DRepository();
    final library2d = Library2DProvider(repo: repo)..load();
    // THE app wiring: the projects provider owns the editor provider from
    // the very start (open/create/autosave all depend on this binding).
    final editor2d = EditorProvider(library2d);
    final projects2d = ProjectsProvider()..bindEditor(editor2d);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: library2d),
        ChangeNotifierProvider(create: (_) => ShellProvider()),
        ChangeNotifierProvider.value(value: editor2d),
        ChangeNotifierProvider.value(value: projects2d),
      ],
      child: const CharacterStudioApp(),
    );
  }
}
