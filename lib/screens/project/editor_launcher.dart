import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/projects_provider.dart';
import '../editor/editor_screen.dart';

/// Opens (and awaits) the project editor route. The editor always runs
/// inside a project context; leaving it saves the project.
Future<void> openProjectEditor(BuildContext context, String projectId) async {
  final projects = context.read<ProjectsProvider>();
  await projects.openProject(projectId);
  if (projects.current == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this project.')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const EditorScreen()),
  );
  // Editor popped → final save already happened inside; refresh list.
  await projects.reloadList();
}
