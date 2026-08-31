import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/character.dart';
import 'glass_card.dart';
import 'thumbnail.dart';

/// Card shown in the character library grid.
class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.character,
    required this.onOpen,
    required this.onFavoriteToggle,
    this.onRename,
    this.onDelete,
    this.onShare,
    this.onDetails,
    this.onDuplicate,
    this.showImportedDate = false,
    this.entryIndex = 0,
  });

  final Character character;
  final VoidCallback onOpen;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onDetails;
  final VoidCallback? onDuplicate;
  final bool showImportedDate;
  final int entryIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      borderRadius: 22,
      blur: 10,
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- preview ----
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(21)),
                    child: Hero(
                      tag: 'character-${character.id}',
                      child: CharacterAvatar(
                        character: character,
                        size: double.infinity,
                        borderRadius: 0,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 0,
                  child: FavoriteHeart(
                    favorite: character.isFavorite,
                    onToggle: onFavoriteToggle,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Row(
                    children: [
                      if (character.source == CharacterSource.bundled)
                        const _Badge(
                            icon: Icons.download_done_rounded, label: 'Sample'),
                      const SizedBox(width: 5),
                      _ReadinessDot(readiness: character.readiness),
                    ],
                  ),
                ),
                if (character.hasSkeleton)
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: _Badge(
                      icon: Icons.accessibility_rounded,
                      label: '${character.boneCount} bones',
                    ),
                  ),
              ],
            ),
          ),
          // ---- info ----
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${character.animationCount} '
                        '${character.animationCount == 1 ? 'Animation' : 'Animations'}'
                        '  ·  ${Formatters.fileSize(character.fileSizeBytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      if (showImportedDate) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Imported ${Formatters.relativeTime(character.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textMuted
                                : const Color(0xFF8B94A6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _MenuButton(
                  character: character,
                  onRename: onRename,
                  onDelete: onDelete,
                  onShare: onShare,
                  onDetails: onDetails,
                  onDuplicate: onDuplicate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessDot extends StatelessWidget {
  const _ReadinessDot({required this.readiness});

  final CharacterReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (readiness) {
      CharacterReadiness.ready => (const Color(0xFF6BD9A5), 'Ready'),
      CharacterReadiness.partial => (const Color(0xFFFFC46B), 'Partial'),
      CharacterReadiness.invalid => (const Color(0xFFFF6B7A), 'Invalid'),
    };
    return Tooltip(
      message: label,
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 4),
          Text(
            label!,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.character,
    this.onRename,
    this.onDelete,
    this.onShare,
    this.onDetails,
    this.onDuplicate,
  });

  final Character character;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onDetails;
  final VoidCallback? onDuplicate;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded,
          size: 20,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.textSecondary
              : AppColors.lightTextSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        switch (value) {
          case 'details':
            onDetails?.call();
          case 'rename':
            onRename?.call();
          case 'duplicate':
            onDuplicate?.call();
          case 'share':
            onShare?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'details', child: Text('Details')),
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuItem(value: 'share', child: Text('Share')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete',
              style:
                  TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
