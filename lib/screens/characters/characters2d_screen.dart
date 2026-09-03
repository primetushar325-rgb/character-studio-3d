import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../characters2d/character2d_model.dart';
import '../../characters2d/widgets2d/puppet_stage.dart';
import '../../core/theme/app_colors.dart';
import '../../state/editor_provider.dart';
import '../../state/library2d_provider.dart';
import '../../state/projects_provider.dart';
import '../project/editor_launcher.dart';
import '../project/project_setup_screen.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/section_header.dart';
import '../editor/character_export.dart';
import 'character_import.dart';

/// 2D Character library: recently used, built-ins, variants — each with
/// thumbnail, rig status, animation status + Use / Favorite / Export.
class Characters2DScreen extends StatelessWidget {
  const Characters2DScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<Library2DProvider>();
    final all = lib.all;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('2D Characters', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                          Text(
                            '${all.length} rigged characters · 14 animations each',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    PremiumButton(label: 'From Prompt', icon: Icons.auto_awesome_rounded, small: true, onPressed: () => showPromptDialog(context)),
                    const SizedBox(width: 8),
                    PremiumButton(label: 'PNG', icon: Icons.add_photo_alternate_outlined, small: true, style: PremiumButtonStyle.tonal, onPressed: () => importPngCharacter(context)),
                    PremiumButton(label: 'ZIP', icon: Icons.folder_zip_outlined, small: true, style: PremiumButtonStyle.tonal, onPressed: () => importZipPackCharacter(context)),
                  ],
                ),
              ),
            ),
            if (lib.recentCharacters.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader(title: 'Recently Used')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: lib.recentCharacters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final c = lib.recentCharacters[i];
                      return _RecentChip(character: c);
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],
            const SliverToBoxAdapter(child: SectionHeader(title: 'All Characters')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.62),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _CharacterCard(character: all[i]),
                  childCount: all.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.character});
  final Character2D character;

  @override
  Widget build(BuildContext context) {
    final lib = context.read<Library2DProvider>();
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _use(context, lib),
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(width: 44, height: 60, child: PuppetThumbnail(spec: character.spec, resolver: character.colors.toResolver(), accessories: character.accessories)),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(character.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text('used ${character.usageCount}×', style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _use(BuildContext context, Library2DProvider lib) async {
    // Characters are used inside a project — open the newest project or the
    // setup screen if none exists yet.
    final projects = context.read<ProjectsProvider>();
    if (projects.projects.isEmpty) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProjectSetupScreen()));
      return;
    }
    await openProjectEditor(context, projects.projects.first.id);
    if (context.mounted) context.read<EditorProvider>().loadCharacter(character.id);
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character});
  final Character2D character;

  @override
  Widget build(BuildContext context) {
    final lib = context.read<Library2DProvider>();
    final ed = context.read<EditorProvider>();
    final projects = context.read<ProjectsProvider>();
    final fav = lib.isFavorite(character.id);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: PuppetThumbnail(
                      spec: character.spec,
                      resolver: character.colors.toResolver(),
                      accessories: character.accessories,
                      background: const Color(0xFF1B2130),
                    ),
                  ),
                ),
                // Long-press: manage user-imported characters (rename/delete).
                // Built-ins are never editable here — nothing destructive.
                if (character.isVariant)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onLongPress: () => _manage(context, lib),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: () => lib.toggleFavorite(character.id),
                    child: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? AppColors.favorite : AppColors.textMuted, size: 19),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(character.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 3),
                const Text(
                  'Rig: Ready · Anim: 14\nFace ✓ · Talk ✓',
                  style: TextStyle(color: AppColors.success, fontSize: 10.5, height: 1.4, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: PremiumButton(
                        label: 'Use',
                        small: true,
                        style: PremiumButtonStyle.primary,
                        onPressed: () async {
                          await openProjectEditor(context, projects.projects.first.id);
                          if (context.mounted) ed.loadCharacter(character.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: PremiumButton(
                        label: 'HTML',
                        small: true,
                        onPressed: () => _exportHtml(context, ed),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manage(BuildContext context, Library2DProvider lib) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(character.name,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline, color: AppColors.accent, size: 20),
            title: const Text('Rename', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
            title: const Text('Delete from library', style: TextStyle(color: AppColors.danger, fontSize: 13)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (action == 'rename') {
      final controller = TextEditingController(text: character.name);
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Rename character', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: AppColors.textPrimary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) await lib.renameVariant(character.id, name);
    } else if (action == 'delete') {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Delete character?', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: Text('"${character.name}" will be removed from your library.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (sure == true) await lib.deleteVariant(character.id);
    }
  }

  Future<void> _exportHtml(BuildContext context, EditorProvider ed) async {
    final projects = context.read<ProjectsProvider>();
    if (projects.projects.isEmpty) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProjectSetupScreen()));
      return;
    }
    await openProjectEditor(context, projects.projects.first.id);
    if (context.mounted) await exportCharacterHtml(context, ed);
  }
}
