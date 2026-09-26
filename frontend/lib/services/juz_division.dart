import '../models/quran_position.dart';
import 'quran_script_repository.dart';

/// One juz: where it begins and where it ends, both inclusive.
class JuzBoundary {
  final int number;
  final QuranPosition start;
  final QuranPosition end;

  const JuzBoundary({required this.number, required this.start, required this.end});

  bool containsAyah(int surah, int ayah) {
    final at = QuranPosition(surah, ayah);
    return at >= start && at <= end;
  }
}

/// A division of the Quran into thirty juz.
///
/// Mushafs do not all divide it the same way. Para 4 is known in Pakistan and
/// India as "Lan tanaalu", the opening words of 3:92, while the Madinah juz 4
/// begins at 3:93 -- and Para 21, "Utlu maa oohiya", is named for 29:45 where
/// the Madinah juz 21 begins at 29:46. Everything that shows or navigates by
/// juz asks this interface, never the data directly, so a second division can
/// be added beside the first without the reader or the recitation flow
/// changing.
///
/// Only the Madinah division is bundled and verified. A second one must come
/// from a source that can be checked, not be typed in.
abstract class JuzDivision {
  /// The division in use. The one place a choice between divisions would go.
  static Future<JuzDivision> load() async {
    await QuranScriptRepository.instance.ensureLoaded();
    return _madinah ??= MadinahJuzDivision.fromRepository(QuranScriptRepository.instance);
  }

  static MadinahJuzDivision? _madinah;

  /// Which mushaf this division follows, for the reader to name.
  String get mushaf;

  /// All thirty, in order.
  List<JuzBoundary> get all;

  JuzBoundary juz(int number) => all[number - 1];

  /// The juz an ayah belongs to.
  int juzOf(int surah, int ayah) {
    for (final j in all) {
      if (j.containsAyah(surah, ayah)) return j.number;
    }
    throw ArgumentError('No juz holds $surah:$ayah');
  }

  /// The juz that begins at ayah [ayah] of [surah], if one does.
  int? juzStartingAt(int surah, int ayah) {
    for (final j in all) {
      if (j.start.surah == surah && j.start.ayah == ayah) return j.number;
    }
    return null;
  }
}

/// The juz as the Madinah mushaf has them, read from the juz number the
/// bundled scripts asset carries on every ayah (quran.com's `juz_number`).
class MadinahJuzDivision extends JuzDivision {
  @override
  final List<JuzBoundary> all;

  MadinahJuzDivision._(this.all);

  @override
  String get mushaf => 'Madinah';

  /// Walks every ayah once. The asset must be loaded.
  factory MadinahJuzDivision.fromRepository(QuranScriptRepository repo) {
    final starts = <int, QuranPosition>{};
    QuranPosition? last;
    var previous = 0;
    for (var surah = 1; surah <= 114; surah++) {
      final count = repo.ayahCount(surah);
      for (var ayah = 1; ayah <= count; ayah++) {
        final juz = repo.placement(surah, ayah)!.juz;
        if (juz != previous) {
          // The asset numbers every ayah, in order, one juz after another. If
          // it ever did not, boundaries built from it would be wrong in ways
          // the reader could not show, so refuse rather than guess.
          if (juz != previous + 1) {
            throw StateError('Juz numbering jumps from $previous to $juz at $surah:$ayah');
          }
          starts[juz] = QuranPosition(surah, ayah);
          previous = juz;
        }
        last = QuranPosition(surah, ayah);
      }
    }
    if (starts.length != 30 || last == null) {
      throw StateError('Expected 30 juz in the scripts asset, found ${starts.length}');
    }

    final boundaries = <JuzBoundary>[];
    for (var n = 1; n <= 30; n++) {
      final QuranPosition end;
      if (n == 30) {
        end = last;
      } else {
        final next = starts[n + 1]!;
        end = next.ayah > 1
            ? QuranPosition(next.surah, next.ayah - 1)
            : QuranPosition(next.surah - 1, repo.ayahCount(next.surah - 1));
      }
      boundaries.add(JuzBoundary(number: n, start: starts[n]!, end: end));
    }
    return MadinahJuzDivision._(List.unmodifiable(boundaries));
  }
}
