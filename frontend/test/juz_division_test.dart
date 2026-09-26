// The juz the Quran tab lists and the reader marks come from the juz number
// the bundled scripts asset carries on every ayah. These pin that the
// boundaries built from it are the Madinah mushaf's, that they cover the whole
// Quran once with no gap or overlap, and that a juz may begin in one surah and
// end in another -- checked over every ayah, not a sample.
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/quran_position.dart';
import 'package:frontend/services/juz_division.dart';
import 'package:frontend/services/quran_script_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JuzDivision division;
  setUpAll(() async => division = await JuzDivision.load());

  final repo = QuranScriptRepository.instance;

  QuranPosition after(QuranPosition p) => p.ayah < repo.ayahCount(p.surah)
      ? QuranPosition(p.surah, p.ayah + 1)
      : QuranPosition(p.surah + 1, 1);

  test('thirty juz, beginning where the Madinah mushaf begins them', () {
    // The Madinah mushaf's juz starts. If the asset is ever rebuilt from a
    // source with a different division, this is where it shows.
    const madinah = [
      '1:1', '2:142', '2:253', '3:93', '4:24', '4:148', '5:82', '6:111', '7:88', '8:41', //
      '9:93', '11:6', '12:53', '15:1', '17:1', '18:75', '21:1', '23:1', '25:21', '27:56', //
      '29:46', '33:31', '36:28', '39:32', '41:47', '46:1', '51:31', '58:1', '67:1', '78:1',
    ];
    expect(division.mushaf, 'Madinah');
    expect(division.all.map((j) => j.number), List.generate(30, (i) => i + 1));
    expect(division.all.map((j) => j.start.toString()), madinah);
  });

  test('each juz ends on the ayah before the next begins, and the last ends the Quran', () {
    for (var i = 0; i < 29; i++) {
      expect(after(division.all[i].end), division.all[i + 1].start, reason: 'gap or overlap after juz ${i + 1}');
    }
    expect(division.juz(30).end, const QuranPosition(114, 6));
  });

  test('every ayah of the Quran is in exactly one juz, the one the asset names', () {
    var ayahs = 0;
    for (var surah = 1; surah <= 114; surah++) {
      for (var ayah = 1; ayah <= repo.ayahCount(surah); ayah++) {
        final holders = division.all.where((j) => j.containsAyah(surah, ayah)).map((j) => j.number).toList();
        expect(holders, [repo.placement(surah, ayah)!.juz], reason: '$surah:$ayah');
        expect(division.juzOf(surah, ayah), holders.single);
        ayahs++;
      }
    }
    expect(ayahs, 6236);
  });

  test('a juz may begin mid-surah and end in the next surah', () {
    expect(division.juz(1).end, const QuranPosition(2, 141));
    expect(division.juz(2).start, const QuranPosition(2, 142));
    expect(division.juz(2).end, const QuranPosition(2, 252));
    expect(division.juz(3).start, const QuranPosition(2, 253));
    expect(division.juz(3).end, const QuranPosition(3, 92));
    // Juz 30 runs across 37 surahs.
    expect(division.juz(30).start, const QuranPosition(78, 1));
  });

  test('juzStartingAt names only the first ayah of a juz', () {
    expect(division.juzStartingAt(2, 142), 2);
    expect(division.juzStartingAt(2, 143), isNull);
    expect(division.juzStartingAt(2, 141), isNull);
    expect(division.juzStartingAt(78, 1), 30);
    expect(division.juzStartingAt(1, 1), 1);
    expect(division.juzStartingAt(1, 2), isNull);
  });
}
