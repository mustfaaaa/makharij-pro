/// Comfortable, consistent spacing scale used across the app.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double screenPadding = 20;
  static const double cardPadding = 16;

  /// Fixed clearance a scrollable screen needs above its content's natural
  /// bottom padding so the floating frosted bottom nav (see [AppBottomNav])
  /// never overlaps the last item. Add the device's bottom safe-area inset
  /// on top of this per screen.
  static const double bottomNavClearance = 90;
}
