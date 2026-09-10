import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/cubit/verse_text_size_cubit.dart';

/// The one place on-device user preferences are read and written.
///
/// Before this existed nothing the user chose survived a restart: the dark
/// mode toggle, the verse text size and the notifications switch were all
/// plain in-memory cubit state, so every launch came back light, medium and
/// on. The Settings screen looked like it worked and then quietly forgot.
///
/// [load] is called once from `main()` before the app builds, so the first
/// frame already carries the saved values — no flash of the wrong theme.
class PreferencesService {
  static const _kThemeMode = 'pref.themeMode';
  static const _kVerseTextSize = 'pref.verseTextSize';
  static const _kNotifications = 'pref.notificationsEnabled';

  SharedPreferences? _prefs;

  /// Reads the store once. Safe to call before `runApp`.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Theme ────────────────────────────────────────────────────────────────
  /// Defaults to [ThemeMode.system] so a first launch follows the phone
  /// rather than forcing light on someone whose device is in dark mode.
  ThemeMode get themeMode {
    switch (_prefs?.getString(_kThemeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs?.setString(_kThemeMode, mode.name);
  }

  // ── Verse text size ──────────────────────────────────────────────────────
  VerseTextSize get verseTextSize {
    final stored = _prefs?.getString(_kVerseTextSize);
    return VerseTextSize.values.firstWhere(
      (v) => v.name == stored,
      orElse: () => VerseTextSize.medium,
    );
  }

  Future<void> setVerseTextSize(VerseTextSize size) async {
    await _prefs?.setString(_kVerseTextSize, size.name);
  }

  // ── Notifications ────────────────────────────────────────────────────────
  bool get notificationsEnabled => _prefs?.getBool(_kNotifications) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool(_kNotifications, enabled);
  }
}
