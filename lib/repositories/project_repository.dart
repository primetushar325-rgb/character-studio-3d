import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/studio_project.dart';

/// Local persistence for studio projects.
class ProjectRepository {
  static const _key = 'projects.list.v1';

  List<StudioProject> _projects = [];
  List<StudioProject> get projects => List.unmodifiable(_projects);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      _projects = list
          .whereType<Map<String, dynamic>>()
          .map(StudioProject.fromJson)
          .toList()
        ..sort((a, b) => (b.lastOpenedAt ?? b.createdAt)
            .compareTo(a.lastOpenedAt ?? a.createdAt));
    } catch (_) {
      _projects = [];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_projects.map((p) => p.toJson()).toList()),
    );
  }

  Future<StudioProject> create(StudioProject project) async {
    _projects.insert(0, project);
    await _persist();
    return project;
  }

  Future<void> markOpened(StudioProject project) async {
    project.lastOpenedAt = DateTime.now();
    await _persist();
  }

  Future<void> rename(StudioProject project, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    project.name = trimmed;
    await _persist();
  }

  Future<void> delete(StudioProject project) async {
    _projects.removeWhere((p) => p.id == project.id);
    await _persist();
  }

  /// Drop projects pointing at deleted characters (called after a delete).
  Future<void> pruneMissing(Set<String> existingCharacterIds) async {
    final before = _projects.length;
    _projects.removeWhere((p) => !existingCharacterIds.contains(p.characterId));
    if (_projects.length != before) await _persist();
  }
}
