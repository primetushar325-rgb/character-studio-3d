import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/humanoid_detector.dart';
import '../../widgets/premium_button.dart';

/// Humanoid bone mapping editor.
///
/// Auto-detected matches (mixamo / Blender .L-.R / Unreal _l-_r / glTF
/// standard naming) are pre-filled; every bone can be remapped manually from
/// the model's actual bone list. Returns the final mapping via pop().
class BoneMappingSheet extends StatefulWidget {
  const BoneMappingSheet({
    super.key,
    required this.boneNames,
    required this.initialMapping,
  });

  final List<String> boneNames;
  final Map<String, String> initialMapping;

  @override
  State<BoneMappingSheet> createState() => _BoneMappingSheetState();
}

class _BoneMappingSheetState extends State<BoneMappingSheet> {
  late Map<String, String> _mapping;

  @override
  void initState() {
    super.initState();
    // Start from auto-detection, overlay any existing manual mapping.
    final auto = const HumanoidDetector().detect(widget.boneNames);
    _mapping = {
      for (final e in auto.matches.entries)
        if (e.value.matched) e.key: e.value.nodeName!,
    };
    _mapping.addAll(widget.initialMapping);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Column(
                children: [
                  Text('Bone Mapping',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${_mapping.length}/${HumanoidDetector.standardBones.length} '
                    'humanoid bones mapped',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                children: [
                  for (final (key, label) in HumanoidDetector.standardBones)
                    _BoneRow(
                      boneKey: key,
                      label: label,
                      boneNames: widget.boneNames,
                      selected: _mapping[key],
                      onChanged: (v) => setState(() {
                        if (v == null) {
                          _mapping.remove(key);
                        } else {
                          _mapping[key] = v;
                        }
                      }),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: PremiumButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                        style: PremiumButtonStyle.ghost,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PremiumButton(
                        label: 'Save Mapping',
                        icon: Icons.check_rounded,
                        style: PremiumButtonStyle.primary,
                        onPressed: () =>
                            Navigator.of(context).pop(Map<String, String>.from(_mapping)),
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

class _BoneRow extends StatelessWidget {
  const _BoneRow({
    required this.boneKey,
    required this.label,
    required this.boneNames,
    required this.selected,
    required this.onChanged,
  });

  final String boneKey;
  final String label;
  final List<String> boneNames;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapped = selected != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            Icon(boneIconFor(boneKey),
                size: 16, color: mapped ? AppColors.accent : AppColors.textMuted),
            const SizedBox(width: 10),
            SizedBox(
              width: 112,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: boneNames.isEmpty
                  ? Text('No bones detected',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant))
                  : DropdownButton<String?>(
                      value: boneNames.contains(selected) ? selected : null,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(14),
                      hint: Text('— unmapped —',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— unmapped —',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                        for (final bone in boneNames)
                          DropdownMenuItem<String?>(
                            value: bone,
                            child: Text(bone.split('|').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                      ],
                      onChanged: onChanged,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
