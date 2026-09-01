import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../characters2d/widgets2d/puppet_stage.dart';
import '../../core/theme/app_colors.dart';
import '../../state/editor_provider.dart';
import '../../state/library2d_provider.dart';
import '../../widgets/premium_button.dart';
import 'character_import.dart';

/// Character picker: built-ins + variants + PNG import + prompt generation.
Future<void> showCharacterPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _PickerSheet(),
  );
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet();

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<Library2DProvider>();
    final ed = context.read<EditorProvider>();
    final chars = lib.all;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 14),
          const Text('Add Character', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PremiumButton(label: 'From Prompt', icon: Icons.auto_awesome_rounded, small: true, onPressed: () => showPromptDialog(context)),
              const SizedBox(width: 10),
              PremiumButton(label: 'Import PNG', icon: CollectionsPlaceholder.icon, small: true, onPressed: () => importPngCharacter(context)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: chars.length,
              itemBuilder: (context, i) {
                final c = chars[i];
                final selected = ed.character?.id == c.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor: selected ? AppColors.accentSoft : AppColors.surfaceAlt,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? AppColors.accent : AppColors.stroke)),
                    leading: SizedBox(width: 44, height: 56, child: PuppetThumbnail(spec: c.spec, resolver: c.colors.toResolver(), accessories: c.accessories)),
                    title: Text(c.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text(
                      '${c.spec.category} · rig ${c.spec.rigKind}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                    ),
                    trailing: Icon(selected ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded, color: selected ? AppColors.accent : AppColors.textMuted),
                    onTap: () {
                      ed.loadCharacter(c.id);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal icon alias (avoids missing icon pitfalls on older material sets).
class CollectionsPlaceholder {
  static const icon = Icons.add_photo_alternate_outlined;
}
