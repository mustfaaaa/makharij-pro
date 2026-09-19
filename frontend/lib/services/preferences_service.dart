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

  // ── Onboarding ───────────────────────────────────────────────────────────
  static const _kOnboardingSeen = 'pref.onboardingSeen';

  /// Onboarding is shown once. It used to reappear on every signed-out
  /// launch, because nothing remembered it had been seen.
  bool get onboardingSeen => _prefs?.getBool(_kOnboardingSeen) ?? false;

  Future<void> setOnboardingSeen() async {
    await _prefs?.setBool(_kOnboardingSeen, true);
  }

  // ── Reading ──────────────────────────────────────────────────────────────
  static const _kTranslationMode = 'pref.translationMode';
  static const _kTransliteration = 'pref.transliteration';
  static const _kPreferredQari = 'pref.preferredQari';

  /// Whether the reader shows the translation never, when an ayah is tapped
  /// (the long-standing behaviour, and the default), or under every ayah.
  TranslationMode get translationMode => TranslationMode.values.firstWhere(
        (m) => m.name == _prefs?.getString(_kTranslationMode),
        orElse: () => TranslationMode.onTap,
      );

  Future<void> setTranslationMode(TranslationMode mode) async {
    await _prefs?.setString(_kTranslationMode, mode.name);
  }

  /// Transliteration under each ayah, from the Tajweed reference service.
  bool get showTransliteration => _prefs?.getBool(_kTransliteration) ?? false;

  Future<void> setShowTransliteration(bool show) async {
    await _prefs?.setBool(_kTransliteration, show);
  }

  /// The reciter chosen for listening in the reader; null until one is picked.
  String? get preferredQariId => _prefs?.getString(_kPreferredQari);

  Future<void> setPreferredQariId(String id) async {
    await _prefs?.setString(_kPreferredQari, id);
  }

  // ── Last read ────────────────────────────────────────────────────────────
  // Where the reader was last settled, on this device only. It is what lets
  // Home and the Quran tab offer "Continue reading" at a real place instead of
  // a made-up one. Nothing is sent anywhere.
  static const _kLastReadSurah = 'pref.lastRead.surah';
  static const _kLastReadAyah = 'pref.lastRead.ayah';
  static const _kLastReadAt = 'pref.lastRead.at';

  LastRead? get lastRead {
    final surah = _prefs?.getInt(_kLastReadSurah);
    final ayah = _prefs?.getInt(_kLastReadAyah);
    final at = _prefs?.getInt(_kLastReadAt);
    if (surah == null || ayah == null) return null;
    return LastRead(
      surah: surah,
      ayah: ayah,
      at: at == null ? null : DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  Future<void> setLastRead(int surah, int ayah) async {
    await _prefs?.setInt(_kLastReadSurah, surah);
    await _prefs?.setInt(_kLastReadAyah, ayah);
    await _prefs?.setInt(_kLastReadAt, DateTime.now().millisecondsSinceEpoch);
  }
}

enum TranslationMode { off, onTap, always }

/// The place the reader was last settled on this device.
class LastRead {
  final int surah;
  final int ayah;
  final DateTime? at;
  const LastRead({required this.surah, required this.ayah, this.at});
}
