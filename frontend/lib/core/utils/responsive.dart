import 'package:flutter/widgets.dart';

/// Breakpoints and helpers so the phone-first layouts don't stretch
/// awkwardly on tablets. The product ships Android-only, but Android
/// spans phones through large tablets, so this still matters.
abstract class Breakpoints {
  static const double tablet = 600;
}

bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

/// Column count for grids: 2 on phones, 4 once there's tablet-width room.
int gridColumns(BuildContext context, {int base = 2, int tablet = 4}) {
  return isTablet(context) ? tablet : base;
}
