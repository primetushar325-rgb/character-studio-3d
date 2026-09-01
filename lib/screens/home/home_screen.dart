import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../project/project_document.dart';
import '../../state/projects_provider.dart';
import '../../state/shell_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/section_header.dart';
import '../project/project_setup_screen.dart';
import '../project/editor_launcher.dart';

/// HOME — the app entry point. Projects first, editor only through a project.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectsProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.movie_filter_rounded, color: AppColors.accent, size: 26),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('2D STORY / VIDEO EDITOR', style: TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: .4)),
                            Text('Make stories with 2D characters', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: PremiumButton(
                        label: 'NEW PROJECT',
                        icon: Icons.add_rounded,
                        style: PremiumButtonStyle.primary,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProjectSetupScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader(title: 'MY PROJECTS')),
            if (!projects.loaded)
              const SliverPadding(
                padding: EdgeInsets.all(40),
                sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: AppColors.accent))),
              )
            else if (projects.projects.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: GlassCard(
                    child: Column(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: AppColors.textMuted, size: 30),
                        SizedBox(height: 8),
                        Text('No projects yet', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text(
                          'Tap NEW PROJECT, choose an orientation,\nadd a background and a character.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ProjectCard(doc: projects.projects[i]),
                    childCount: projects.projects.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'QUICK LINKS'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickLink(
                        icon: Icons.accessibility_new_rounded,
                        title: 'Characters',
                        subtitle: 'Library & import',
                        onTap: () => context.read<ShellProvider>().go(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickLink(
                        icon: Icons.settings_rounded,
                        title: 'Settings',
                        subtitle: 'Canvas & export info',
                        onTap: () => context.read<ShellProvider>().go(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.doc});
  final ProjectDocument doc;

  @override
  Widget build(BuildContext context) {
    final projects = context.read<ProjectsProvider>();
    final thumb = doc.thumbnailPath;
    final hasThumb = thumb != null && File(thumb).existsSync();

    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openProjectEditor(context, doc.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: hasThumb
                        ? Image.file(File(thumb), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const _ThumbFallback())
                        : const _ThumbFallback(),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.bg.withOpacity(.82),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _orientationBadge(doc.orientation),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          '${doc.canvasWidth}×${doc.canvasHeight} · ${_ago(doc.updatedAt)}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: AppColors.surface,
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 19),
                    onSelected: (v) async {
                      switch (v) {
                        case 'rename':
                          await _rename(context, projects);
                        case 'duplicate':
                          await projects.duplicateProject(doc);
                        case 'delete':
                          await _confirmDelete(context, projects);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename', style: TextStyle(color: AppColors.textSecondary))),
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicate', style: TextStyle(color: AppColors.textSecondary))),
                      PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, ProjectsProvider projects) async {
    final controller = TextEditingController(text: doc.name);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename project', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await projects.renameProject(doc, name);
    }
  }

  Future<void> _confirmDelete(BuildContext context, ProjectsProvider projects) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete "${doc.name}"?', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: const Text('This permanently removes the project. This cannot be undone.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await projects.deleteProject(doc.id);
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_creation_outlined,
        color: AppColors.textMuted.withOpacity(.5),
        size: 34,
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

String _orientationBadge(String o) => switch (o) {
      ProjectOrientation.portrait9x16 => '9:16',
      ProjectOrientation.square1x1 => '1:1',
      _ => '16:9',
    };

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
