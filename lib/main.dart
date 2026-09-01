import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'characters2d/character2d_repository.dart';
import 'state/editor_provider.dart';
import 'state/library2d_provider.dart';
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: library2d),
        ChangeNotifierProvider(create: (_) => ShellProvider()),
        ChangeNotifierProvider(create: (_) => EditorProvider(library2d)),
      ],
      child: const CharacterStudioApp(),
    );
  }
}
