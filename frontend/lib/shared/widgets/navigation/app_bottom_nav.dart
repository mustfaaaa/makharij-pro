import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

/// Five tabs — Home, Quran, Ask AI (raised gold circle in the middle),
/// Progress, Profile — matching the new mockups. Index mapping follows the
/// [StatefulShellRoute] branch order in app_router.dart.
const _items = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _NavItem(Icons.menu_book_outlined, Icons.menu_book_rounded, 'Quran'),
  _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Ask AI'),
  _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Progress'),
  _NavItem(Icons.person_outline, Icons.person_rounded, 'Profile'),
];

const int _centerIndex = 2;

/// Frosted "liquid glass" pill bar with a raised gold Ask-AI circle floating
/// above the middle slot, exactly as in the provided mockups.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  void _handleTap(int index) {
    if (index != currentIndex) HapticFeedback.selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // ── The glass bar ────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 66,
                  decoration: BoxDecoration(
                    color: AppColors.glassSurface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.glassBorder),
                    boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Row(
                    children: [
                      for (int i = 0; i < _items.length; i++)
                        Expanded(
                          child: i == _centerIndex
                              // Label-only slot under the floating circle.
                              ? _CenterLabel(
                                  selected: currentIndex == _centerIndex,
                                  onTap: () => _handleTap(_centerIndex),
                                )
                              : _NavButton(
                                  item: _items[i],
                                  selected: i == currentIndex,
                                  onTap: () => _handleTap(i),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Raised gold Ask-AI circle ────────────────────────────────
            Positioned(
              bottom: 38,
              child: GestureDetector(
                onTap: () => _handleTap(_centerIndex),
                child: Semantics(
                  button: true,
                  selected: currentIndex == _centerIndex,
                  label: 'Ask AI',
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primaryLight, AppColors.primaryDark],
                      ),
                      border: Border.all(color: AppColors.surface, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The middle slot inside the bar: just the "Ask AI" label (the icon floats
/// above it) plus the small selected dot from the mockup.
class _CenterLabel extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _CenterLabel({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Ask AI',
            style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: selected ? 5 : 0,
            height: selected ? 5 : 0,
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySurface : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedScale(
                scale: selected ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                child: Icon(selected ? item.selectedIcon : item.icon, size: 22, color: color),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
