import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// Premium gold-accented bottom nav with animated active pill.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(Icons.home_rounded,      Icons.home_outlined,          'Home'),
    _NavItem(Icons.auto_stories_rounded, Icons.auto_stories_outlined, 'Quran'),
    _NavItem(Icons.bar_chart_rounded, Icons.bar_chart_outlined,     'Progress'),
    _NavItem(Icons.person_rounded,    Icons.person_outline_rounded,  'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 16,
              offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final item    = _items[i];
            final active  = i == currentIndex;
            final color   = active ? AppColors.primary : AppColors.textSecondary;
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                          active ? item.activeIcon : item.icon,
                          color: color, size: 22),
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      child: Text(item.label),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}
