import 'package:flutter/material.dart';

import '../models/studio_project.dart';
import '../repositories/project_repository.dart';

class ProjectsProvider extends ChangeNotifier {
  ProjectsProvider(this._repo);

  final ProjectRepository _repo;

  List<StudioProject> _projects = const [];
  List<StudioProject> get projects => _projects;

  Future<void> load() async {
    await _repo.load();
    _projects = _repo.projects;
    notifyListeners();
  }

  Future<void> create(StudioProject project) async {
    await _repo.create(project);
    _projects = _repo.projects;
    notifyListeners();
  }

  Future<void> markOpened(StudioProject project) async {
    await _repo.markOpened(project);
    _projects = _repo.projects;
    notifyListeners();
  }

  Future<void> rename(StudioProject project, String name) async {
    await _repo.rename(project, name);
    _projects = _repo.projects;
    notifyListeners();
  }

  Future<void> delete(StudioProject project) async {
    await _repo.delete(project);
    _projects = _repo.projects;
    notifyListeners();
  }

  /// Remove projects referencing deleted characters.
  Future<void> pruneMissing(Set<String> existingCharacterIds) async {
    await _repo.pruneMissing(existingCharacterIds);
    _projects = _repo.projects;
    notifyListeners();
  }
}

/// Generates unique project ids without any external dependency.
String newProjectId() => 'p${DateTime.now().millisecondsSinceEpoch}'
    '-${DateTime.now().microsecond}';
