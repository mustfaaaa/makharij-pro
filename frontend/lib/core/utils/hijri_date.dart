/// Lightweight Gregorian → Hijri (tabular/civil Islamic calendar) conversion.
/// No external package needed — this is the standard arithmetic algorithm
/// used by most calendar apps for a decorative display like this; it's
/// accurate to within about a day of local moon-sighting-based calendars.
abstract class HijriDate {
  static int _gregorianToJdn(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  }

  static int yearFor(DateTime date) {
    final jdn = _gregorianToJdn(date.year, date.month, date.day);
    final l1 = jdn - 1948440 + 10632;
    final n = (l1 - 1) ~/ 10631;
    final l2 = l1 - 10631 * n + 354;
    final j = ((10985 - l2) ~/ 5316) * ((50 * l2) ~/ 17719) + (l2 ~/ 5670) * ((43 * l2) ~/ 15238);
    return 30 * n + j - 30;
  }

  static const _easternArabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  static String _toEasternArabicDigits(int n) {
    return n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : _easternArabicDigits[i];
    }).join();
  }

  /// e.g. "١٤٤٧ هـ" — the current Hijri year in Eastern Arabic-Indic numerals.
  static String currentYearLabel() {
    return '${_toEasternArabicDigits(yearFor(DateTime.now()))} هـ';
  }
}
