import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/service_locator.dart';

/// Holds the app-wide [ThemeMode] and writes every change to disk.
///
/// Three modes, not two. The toggle used to be light/dark only and defaulted
/// to light, so a phone in dark mode still opened this app bright white, and
/// the choice was forgotten on the next launch because nothing persisted.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(Services.prefs.themeMode);

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    await Services.prefs.setThemeMode(mode);
  }

  /// Kept for the plain on/off switch: flips between explicit light and dark.
  /// From [ThemeMode.system] it commits to whichever the system is *not*, so
  /// one tap visibly changes something.
  Future<void> toggle() {
    final isDark = state == ThemeMode.dark ||
        (state == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    return setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
