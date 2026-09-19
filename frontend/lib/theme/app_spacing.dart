/// Spacing scale on a 4pt base (see DESIGN.md). Related items sit 8-12 apart,
/// sections 32 apart, reading surfaces breathe at 48.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double screenPadding = 20;
  static const double cardPadding = 16;

  /// Space a scrollable tab screen leaves below its last item. The bottom
  /// navigation bar is opaque and part of the Scaffold now, so the body no
  /// longer runs underneath it; this is ordinary end-of-list breathing room,
  /// not clearance for a floating bar.
  static const double bottomNavClearance = 24;
}
