import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/animation_clip.dart';
import 'glass_card.dart';

/// Card for one detected animation/action.
class AnimationCard extends StatelessWidget {
  const AnimationCard({
    super.key,
    required this.animation,
    required this.onPlay,
    this.selected = false,
    this.compact = false,
    this.showPlayLabel = true,
  });

  final AnimationClip animation;
  final VoidCallback onPlay;
  final bool selected;
  final bool compact;
  final bool showPlayLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = animationIconFor(
        animation.knownAction ? animation.normalizedName : animation.displayName);

    return GlassCard(
      onTap: onPlay,
      padding: EdgeInsets.all(compact ? 10 : 14),
      borderRadius: 18,
      blur: 8,
      shadow: false,
      border: selected ? Border.all(color: AppColors.accent, width: 1.4) : null,
      child: Row(
        children: [
          Container(
            width: compact ? 40 : 46,
            height: compact ? 40 : 46,
            decoration: BoxDecoration(
              gradient: selected ? AppColors.primaryGradient : null,
              color: selected ? null : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: compact ? 19 : 22,
              color: selected ? const Color(0xFF0A0C11) : AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animation.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  animation.durationSeconds != null
                      ? 'Loop · ${Formatters.clipDuration(animation.durationSeconds)}'
                      : 'Loop · length auto-detected',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PlayPill(onPlay: onPlay, showLabel: showPlayLabel),
        ],
      ),
    );
  }
}

class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.onPlay, required this.showLabel});

  final VoidCallback onPlay;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Play animation',
      button: true,
      child: GestureDetector(
        onTap: onPlay,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_rounded,
                  size: 16, color: Color(0xFF0A0C11)),
              if (showLabel) ...[
                const SizedBox(width: 4),
                const Text(
                  'Play',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A0C11),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
