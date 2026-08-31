import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/premium_button.dart';
import '../../characters2d/character2d_model.dart';

/// Customization sheet: color slots, accessory toggles and Save Variant.
/// Never modifies the original — always saves (or updates) a variant.
Future<void> showCustomizeSheet(
  BuildContext context, {
  required Character2D character,
  required Future<void> Function(String name, Map<String, Color> palette, Set<String> accessories) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CustomizeSheet(character: character, onSave: onSave),
  );
}

class _CustomizeSheet extends StatefulWidget {
  const _CustomizeSheet({required this.character, required this.onSave});

  final Character2D character;
  final Future<void> Function(String name, Map<String, Color> palette, Set<String> accessories) onSave;

  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  late final TextEditingController _name;
  late Map<String, Color> _palette;
  late Set<String> _accessories;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.character.isVariant ? widget.character.name : '${widget.character.name} — Custom');
    _palette = {...widget.character.paletteOverrides};
    _accessories = {...widget.character.accessories};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.character.spec;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Customize Character',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            for (final slot in spec.slots) ...[
              const SizedBox(height: 12),
              Text(
                slot.label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in slot.swatches)
                    _swatch(c, selected: _palette[slot.key] == c, onTap: () => setState(() => _palette[slot.key] = c)),
                ],
              ),
            ],
            if (spec.accessoryOptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Accessories', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              for (final e in spec.accessoryOptions.entries)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.accent,
                  title: Text(e.value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  value: _accessories.contains(e.key),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _accessories.add(e.key);
                    } else {
                      _accessories.remove(e.key);
                    }
                  }),
                ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Variant name',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.stroke),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Saves as a separate variant — the original character stays untouched.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                label: widget.character.isVariant ? 'Update Variant' : 'Save as Variant',
                icon: Icons.check_rounded,
                style: PremiumButtonStyle.primary,
                onPressed: () async {
                  await widget.onSave(_name.text.trim().isEmpty ? 'Custom' : _name.text.trim(), _palette, _accessories);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(Color c, {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? AppColors.accent : AppColors.strokeStrong, width: selected ? 3 : 1),
        ),
      ),
    );
  }
}
