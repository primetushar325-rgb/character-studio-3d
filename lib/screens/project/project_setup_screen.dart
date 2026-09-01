import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../project/project_document.dart';
import '../../state/projects_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_button.dart';
import 'editor_launcher.dart';

/// PROJECT SETUP — name + orientation, then CREATE.
class ProjectSetupScreen extends StatefulWidget {
  const ProjectSetupScreen({super.key});

  @override
  State<ProjectSetupScreen> createState() => _ProjectSetupScreenState();
}

class _ProjectSetupScreenState extends State<ProjectSetupScreen> {
  final _name = TextEditingController();
  String _orientation = ProjectOrientation.landscape16x9; // recommended default
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    final projects = context.read<ProjectsProvider>();
    final doc = await projects.createProject(
      name: _name.text.isEmpty ? 'My Story' : _name.text,
      orientation: _orientation,
    );
    if (!mounted) return;
    // Capture the navigator BEFORE popping this screen — pushing with a
    // defunct context would throw.
    final nav = Navigator.of(context);
    nav.pop(); // setup sheet
    openProjectEditor(nav.context, doc.id);
  }

  @override
  Widget build(BuildContext context) {
    final (w, h) = ProjectOrientation.canvasSize(_orientation);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('New Project', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text('PROJECT NAME', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            GlassCard(
              child: TextField(
                controller: _name,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'My Story',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('ORIENTATION', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (i, o) in ProjectOrientation.all.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _OrientationCard(
                      orientation: o,
                      selected: _orientation == o,
                      recommended: o == ProjectOrientation.landscape16x9,
                      onTap: () => setState(() => _orientation = o),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                '$w × $h · ${ProjectOrientation.label(_orientation)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 26),
            PremiumButton(
              label: _creating ? 'CREATING…' : 'CREATE PROJECT',
              icon: Icons.rocket_launch_rounded,
              style: PremiumButtonStyle.primary,
              onPressed: _creating ? null : _create,
            ),
            const SizedBox(height: 10),
            const Text(
              'Starts empty — add a background from Gallery and a character inside the editor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrientationCard extends StatelessWidget {
  const _OrientationCard({
    required this.orientation,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final String orientation;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (w, h) = ProjectOrientation.canvasSize(orientation);
    final ratio = w / h;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 74,
              width: double.infinity,
              decoration: BoxDecoration(
                color: selected ? AppColors.accentSoft : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? AppColors.accent : AppColors.stroke, width: selected ? 2 : 1),
              ),
              child: Center(
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent.withOpacity(.32) : AppColors.stroke.withOpacity(.6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ProjectOrientation.label(orientation),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text('$w×$h', style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
            if (recommended)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('RECOMMENDED', style: TextStyle(color: AppColors.accent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .6)),
              ),
          ],
        ),
      ),
    );
  }
}
