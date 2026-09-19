import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltip;
  const _NavItem(this.icon, this.selectedIcon, this.label, this.tooltip);
}

/// Five tabs, in the [StatefulShellRoute] branch order of app_router.dart:
/// Home, Quran, Rattil, Progress, Profile.
///
/// This used to be a frosted pill floating over the page with a raised gold
/// "Ask AI" disc in the middle. The pill covered the bottom of every list (so
/// each screen hand-padded for it), re-blurred the content under it every
/// frame, and gave the centre slot -- the most prominent place in the app --
/// to a chat. It is now an ordinary opaque bar that the Scaffold lays out,
/// with Rattil as a destination like the others.
const _items = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home', 'Home'),
  _NavItem(Icons.menu_book_outlined, Icons.menu_book_rounded, 'Quran', 'Quran'),
  _NavItem(Icons.graphic_eq_rounded, Icons.graphic_eq_rounded, 'Rattil', 'Rattil: reciters and questions'),
  _NavItem(Icons.insights_outlined, Icons.insights_rounded, 'Progress', 'Progress'),
  _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', 'Profile'),
];

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _handleTap,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        animationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        destinations: [
          for (final item in _items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
              tooltip: item.tooltip,
            ),
        ],
      ),
    );
  }
}
