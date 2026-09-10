import 'package:flutter/material.dart';

/// Rounded-corner radii used for cards, buttons, and sheets.
///
/// These six steps are the whole vocabulary. The app had drifted to fifteen
/// raw values (2, 3.5, 4, 6, 8, 9, 10, 12, 14, 16, 18, 20, 24, 26, 30), which
/// is why cards on Home, Progress and Profile didn't match each other — the
/// differences were too small to read as intentional and too large to look
/// like one system. Round to the nearest step rather than adding a new one.
abstract class AppRadii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static BorderRadius get xsRadius => BorderRadius.circular(xs);
  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}
