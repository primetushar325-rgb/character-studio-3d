import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/studio_project.dart';
import '../../state/library_provider.dart';
import '../../state/projects_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/thumbnail.dart';
import '../player/player_screen.dart';
import 'new_project_wizard.dart';

/// "Create" tab: saved studio projects + new project wizard entry.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectsProvider>();
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create',
                            style:
                                Theme.of(context).textTheme.headlineMedium),
                        Text(
                          'Studio projects — character, animation, scene & duration',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: PremiumButton(
                label: 'New Project',
                icon: Icons.add_rounded,
                style: PremiumButtonStyle.primary,
                expanded: true,
                onPressed: library.characters.isEmpty
                    ? null
                    : () => NewProjectWizard.open(context),
              ),
            ),
            if (library.characters.isEmpty) ...[
              const SizedBox(height: 28),
              EmptyState(
                icon: Icons.view_in_ar_outlined,
                title: 'No characters yet',
                message:
                    'Import a GLB character first — then create projects that '
                    'combine character, animation, camera and background.',
              ),
            ] else if (projects.projects.isEmpty) ...[
              const SectionHeader(title: 'Projects'),
              const EmptyState(
                icon: Icons.movie_creation_outlined,
                title: 'No projects yet',
                message:
                    'Tap "New Project" to set up a character, animation, camera, '
                    'background and duration — then preview it in one tap.',
              ),
            ] else ...[
              const SectionHeader(
                  title: 'Projects', padding: EdgeInsets.fromLTRB(20, 20, 20, 10)),
              ...List.generate(projects.projects.length, (index) {
                final project = projects.projects[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: StaggeredEntrance(
                    index: index,
                    child: _ProjectCard(project: project),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final StudioProject project;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final projects = context.read<ProjectsProvider>();
    final character = library.byId(project.characterId);
    final missing = character == null;

    return GlassCard(
      onTap: missing
          ? null
          : () {
              projects.markOpened(project);
              library.recordUsage(character, project.animationName);
              Navigator.of(context).push(
                fadeSlideRoute(
                  PlayerScreen(
                    characterId: project.characterId,
                    initialAnimationName: project.animationName,
                    projectBackground: project.background,
                    projectCustomHex: project.customBackgroundHex,
                    projectLighting: project.lighting,
                    projectOrbit: project.cameraOrbit,
                    projectAutoRotate: project.autoRotate,
                  ),
                ),
              );
            },
      padding: const EdgeInsets.all(12),
      borderRadius: 20,
      blur: 8,
      shadow: false,
      child: Row(
        children: [
          if (missing)
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.link_off_rounded,
                  color: AppColors.danger, size: 26),
            )
          else
            CharacterAvatar(character: character, size: 62, borderRadius: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Chip(
                        icon: Icons.animation_rounded,
                        label: project.animationDisplay),
                    _Chip(
                        icon: project.background.icon,
                        label: project.background.label),
                    _Chip(icon: Icons.timer_outlined, label: '${project.durationSeconds}s'),
                    if (project.autoRotate)
                      const _Chip(icon: Icons.screen_rotation_rounded, label: 'Orbit'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  missing
                      ? 'Character missing — this character was deleted'
                      : 'Opened ${Formatters.relativeTime(project.lastOpenedAt ?? project.createdAt)}'
                          ' · created ${Formatters.relativeTime(project.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: missing ? AppColors.danger : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!missing) _playButton(context, project, character),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                size: 20,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  _rename(context, projects, project);
                case 'delete':
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Delete Project?',
                    message:
                        '"${project.name}" will be removed. This cannot be undone.',
                    confirmLabel: 'Delete',
                  );
                  if (confirmed) projects.delete(project);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playButton(BuildContext context, StudioProject project, dynamic character) {
    final projects = context.read<ProjectsProvider>();
    final library = context.read<LibraryProvider>();
    return Semantics(
      label: 'Play project',
      button: true,
      child: GestureDetector(
        onTap: () {
          projects.markOpened(project);
          library.recordUsage(character, project.animationName);
          Navigator.of(context).push(
            fadeSlideRoute(PlayerScreen(
              characterId: project.characterId,
              initialAnimationName: project.animationName,
              projectBackground: project.background,
              projectCustomHex: project.customBackgroundHex,
              projectLighting: project.lighting,
              projectOrbit: project.cameraOrbit,
              projectAutoRotate: project.autoRotate,
            )),
          );
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow_rounded,
              color: Color(0xFF0A0C11), size: 23),
        ),
      ),
    );
  }

  Future<void> _rename(
      BuildContext context, ProjectsProvider projects, StudioProject project) async {
    final controller = TextEditingController(text: project.name);
    final result = await showPremiumDialog<String>(
      context,
      PremiumDialog(
        title: 'Rename Project',
        message: 'Give this project a new name.',
        icon: Icons.edit_rounded,
        actions: [
          PremiumTextButton(
              label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
          PremiumButton(
            label: 'Save',
            small: true,
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.stroke),
            ),
          ),
        ),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await projects.rename(project, result.trim());
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}
