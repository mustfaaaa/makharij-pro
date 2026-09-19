/// Lightweight Gregorian → Hijri (tabular/civil Islamic calendar) conversion.
/// No external package needed: this is the standard arithmetic algorithm
/// used by most calendar apps for a display like this. It is accurate to
/// within about a day of local moon-sighting calendars, so screens say
/// "Hijri" rather than claiming the local sighting.
abstract class HijriDate {
  static int _gregorianToJdn(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  }

  /// (year, month 1-12, day) in the tabular Hijri calendar.
  static (int, int, int) fromGregorian(DateTime date) {
    final jdn = _gregorianToJdn(date.year, date.month, date.day);
    final l1 = jdn - 1948440 + 10632;
    final n = (l1 - 1) ~/ 10631;
    final l2 = l1 - 10631 * n + 354;
    final j = ((10985 - l2) ~/ 5316) * ((50 * l2) ~/ 17719) + (l2 ~/ 5670) * ((43 * l2) ~/ 15238);
    final l3 = l2 - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
    final month = (24 * l3) ~/ 709;
    final day = l3 - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return (year, month, day);
  }

  static int yearFor(DateTime date) => fromGregorian(date).$1;

  static const monthNames = [
    'Muharram', 'Safar', "Rabi' al-Awwal", "Rabi' al-Thani", 'Jumada al-Ula', 'Jumada al-Akhirah',
    'Rajab', "Sha'ban", 'Ramadan', 'Shawwal', "Dhu al-Qa'dah", 'Dhu al-Hijjah',
  ];

  /// e.g. "27 Rabi' al-Awwal 1448".
  static String format(DateTime date) {
    final (y, m, d) = fromGregorian(date);
    return '$d ${monthNames[(m - 1).clamp(0, 11)]} $y';
  }

  static const _easternArabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  static String _toEasternArabicDigits(int n) {
    return n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : _easternArabicDigits[i];
    }).join();
  }

  /// e.g. "١٤٤٧ هـ": the current Hijri year in Eastern Arabic-Indic numerals.
  static String currentYearLabel() {
    return '${_toEasternArabicDigits(yearFor(DateTime.now()))} هـ';
  }
}
