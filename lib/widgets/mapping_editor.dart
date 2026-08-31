import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/animation_names.dart';
import '../models/animation_clip.dart';
import '../services/validation_service.dart'
    show ValidationStatus, statusColor, statusIcon;

/// Editor for the standard-action → actual-clip mapping.
///
/// Shows each of the six required actions with a dropdown of the model's
/// real clips. Auto-detected entries display their confidence; suggested
/// (low-confidence) entries must be confirmed by the user. Nothing is
/// claimed to exist unless selected or auto-mapped with high confidence.
class ActionMappingEditor extends StatelessWidget {
  const ActionMappingEditor({
    super.key,
    required this.clips,
    required this.mapping,
    required this.suggestions,
    required this.confidences,
    required this.onChanged,
    this.compact = false,
  });

  /// All clips actually embedded in the model (original identifiers).
  final List<AnimationClip> clips;

  /// Current mapping: action → clip name (null/empty = unmapped).
  final Map<String, String?> mapping;

  /// Low-confidence candidates: action → suggested clip name.
  final Map<String, String> suggestions;

  /// Confidence per action (0..1) for the currently mapped clip.
  final Map<String, double> confidences;

  final void Function(String action, String? clipName) onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in StandardAction.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MappingRow(
              action: action,
              clips: clips,
              selectedClip: mapping[action],
              suggestion: suggestions[action],
              confidence: confidences[action] ?? 0,
              isDark: isDark,
              onChanged: (clip) => onChanged(action, clip),
            ),
          ),
      ],
    );
  }
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({
    required this.action,
    required this.clips,
    required this.selectedClip,
    required this.suggestion,
    required this.confidence,
    required this.isDark,
    required this.onChanged,
  });

  final String action;
  final List<AnimationClip> clips;
  final String? selectedClip;
  final String? suggestion;
  final double confidence;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSuggested = selectedClip != null &&
        suggestion == selectedClip &&
        confidence < StandardActionMatcher.autoMapThreshold;

    final state = selectedClip == null
        ? ValidationStatus.fail
        : isSuggested
            ? ValidationStatus.warn
            : ValidationStatus.pass;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.stroke : AppColors.lightStroke,
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon(state), size: 17, color: statusColor(state)),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              StandardAction.label(action),
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: clips.isEmpty
                ? Text(
                    'No clips in model',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                : DropdownButton<String?>(
                    value: _dropdownValue,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(14),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— Not mapped —',
                            style: TextStyle(fontSize: 13)),
                      ),
                      for (final clip in clips)
                        DropdownMenuItem<String?>(
                          value: clip.name,
                          child: Text(
                            clip.displayName == clip.name
                                ? clip.name.split('|').last
                                : '${clip.displayName}  (${clip.name.split('|').last})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (v) => onChanged(v),
                  ),
          ),
          if (selectedClip != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor(state).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isSuggested
                    ? '${(confidence * 100).round()}% ?'
                    : '${(confidence * 100).round()}%',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: statusColor(state),
                ),
              ),
            ),
          ] else if (suggestion != null) ...[
            const SizedBox(width: 4),
            Semantics(
              label: 'Use suggested clip for ${StandardAction.label(action)}',
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(suggestion),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          size: 12, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        'Use? ${(suggestion ?? '').split('|').last}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Dropdown needs the value to exist among items; guard stale selections.
  String? get _dropdownValue {
    if (selectedClip == null) return null;
    final exists = clips.any((c) => c.name == selectedClip);
    if (exists) return selectedClip;
    // The suggestion may reference a clip list built elsewhere — accept it
    // when it matches any clip name, else reset display to unmapped.
    return null;
  }
}
