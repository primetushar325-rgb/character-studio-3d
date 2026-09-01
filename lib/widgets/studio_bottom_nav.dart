import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class StudioNavItem {
  const StudioNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Premium bottom navigation with an animated selection pill.
class StudioBottomNav extends StatelessWidget {
  const StudioBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<StudioNavItem> items = [
    StudioNavItem(
        icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    StudioNavItem(
        icon: Icons.accessibility_new_outlined,
        activeIcon: Icons.accessibility_new_rounded,
        label: 'Characters'),
    StudioNavItem(
        icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.stroke : AppColors.lightStroke),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _buildItem(context, i, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, bool isDark) {
    final item = items[index];
    final selected = currentIndex == index;

    return Semantics(
      label: item.label,
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  key: ValueKey('${item.label}-$selected'),
                  size: 23,
                  color: selected
                      ? AppColors.accent
                      : (isDark ? AppColors.textMuted : const Color(0xFF9AA5B5)),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.2,
                  color: selected
                      ? AppColors.accent
                      : (isDark ? AppColors.textMuted : const Color(0xFF9AA5B5)),
                ),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
