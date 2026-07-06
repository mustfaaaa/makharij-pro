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

const _items = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _NavItem(Icons.menu_book_outlined, Icons.menu_book_rounded, 'Quran'),
  _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Progress'),
  _NavItem(Icons.person_outline, Icons.person_rounded, 'Profile'),
];

/// Custom bottom navigation with a springy selected-icon bounce and a
/// morphing pill behind the active tab. Floats as a frosted "liquid glass"
/// pill over the extended body (see [AppShell]) rather than a flat, edge-to-
/// edge bar.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
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
                    child: _NavButton(
                      item: _items[i],
                      selected: i == currentIndex,
                      onTap: () {
                        if (i != currentIndex) HapticFeedback.selectionClick();
                        onTap(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
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
