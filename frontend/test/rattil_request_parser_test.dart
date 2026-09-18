import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/dummy/dummy_surahs.dart';
import 'package:frontend/models/qari.dart';
import 'package:frontend/services/rattil_request_parser.dart';

/// Rattil AI's reading of a chat message.
///
/// The reciters below are the three in the real Firestore catalogue, with the
/// display names and ids it actually holds -- including the mismatch between
/// "Yasser Al-Dosari" and "yasser_ad_dussary" that the parser has to bridge.
const _shortSurahs = [1, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114];

final _qaris = [
  Qari(
    qariId: 'abdurrahmaan_as_sudais',
    nameEnglish: 'Abdul Rahman As-Sudais',
    nameArabic: 'عبد الرحمن السديس',
    availableSurahs: [for (var i = 1; i <= 114; i++) i],
  ),
  const Qari(
    qariId: 'alafasy',
    nameEnglish: 'Mishary Rashid Alafasy',
    nameArabic: 'مشاري راشد العفاسي',
    availableSurahs: _shortSurahs,
  ),
  const Qari(
    qariId: 'yasser_ad_dussary',
    nameEnglish: 'Yasser Al-Dosari',
    nameArabic: 'ياسر الدوسري',
    availableSurahs: _shortSurahs,
  ),
];

void main() {
  final parser = RattilRequestParser(surahs: dummySurahs, qaris: _qaris);
  int? surahOf(String text) => parser.parse(text).surah?.number;
  String? qariOf(String text) => parser.parse(text).qari?.qariId;

  group('surahs as people actually write them', () {
    final cases = {
      'Al-Fatihah': 1,
      'fatiha': 1,
      'Fatihah please': 1,
      'surah fatiha sunao': 1,
      'baqarah': 2,
      'Al Baqara': 2,
      'yaseen': 36,
      'Ya Sin': 36,
      'yasin': 36,
      'rehman': 55,
      'Ar-Rahman': 55,
      'arrahman': 55,
      'kausar': 108,
      'Al-Kawthar': 108,
      'ikhlaas': 112,
      'Al-Ikhlas': 112,
      'mulk': 67,
      'kahf': 18,
      'surah kahf ki tilawat': 18,
      'muzammil': 73,
      'An-Nas': 114,
      'naas': 114,
      // "dh" read as d, and as z -- the same letter, spelled both ways.
      'duha': 93,
      'zuha': 93,
      'Ad-Dhuha': 93,
      'zariyat': 51,
      'dhariyat': 51,
      // A final vowel people drop.
      'zilzal': 99,
      'zalzala': 99,
      // An article in front of a misspelling must not become Al-A'la.
      'al bakara': 2,
    };
    cases.forEach((text, number) {
      test('"$text" -> $number', () => expect(surahOf(text), number));
    });
  });

  group('every surah finds itself', () {
    // The guard against the fuzziness above going too far: loosening one
    // spelling must never make another surah's exact name resolve elsewhere.
    for (final s in dummySurahs) {
      test('${s.number} ${s.nameEnglish}', () {
        expect(surahOf(s.nameEnglish), s.number, reason: 'by English name');
        expect(surahOf(s.nameArabic), s.number, reason: 'by Arabic name');
        expect(surahOf('surah ${s.number}'), s.number, reason: 'by number');
      });
    }
  });

  group('names that sit close together stay apart', () {
    // Short names must match exactly, or one would swallow the other.
    test('An-Nas is not An-Nasr', () {
      expect(surahOf('An-Nas'), 114);
      expect(surahOf('An-Nasr'), 110);
    });
    test('An-Nas is not An-Nisa', () => expect(surahOf('An-Nisa'), 4));
    test('Al-Falaq is not Al-Alaq', () {
      expect(surahOf('falaq'), 113);
      expect(surahOf('alaq'), 96);
    });
    test('Al-Fil is not Al-Fath', () {
      expect(surahOf('Al-Fil'), 105);
      expect(surahOf('Al-Fath'), 48);
    });
  });

  group('numbers, meanings and Arabic', () {
    test('"surah 18"', () => expect(surahOf('surah 18'), 18));
    test('"chapter 55"', () => expect(surahOf('chapter 55'), 55));
    test('a bare surah number', () => expect(surahOf('112'), 112));
    test('a number that is not a surah is ignored', () => expect(surahOf('999'), isNull));
    test('the explicit "surah N" wins over another number', () {
      expect(surahOf('2 times surah 112'), 112);
    });
    test('by meaning: "the Cow"', () => expect(surahOf('the cow'), 2));
    test('in Arabic', () {
      expect(surahOf('سورة الفاتحة'), 1);
      expect(surahOf('الإخلاص'), 112);
    });
    test('nothing recognisable', () => expect(surahOf('hello there'), isNull));
  });

  group('reciters by the names people use', () {
    final cases = {
      'Al-Ikhlas by Sudais': 'abdurrahmaan_as_sudais',
      'an-nas by as-sudais': 'abdurrahmaan_as_sudais',
      'fatiha sudais ki awaz mein': 'abdurrahmaan_as_sudais',
      'Al-Ikhlas by Alafasy': 'alafasy',
      'an nas by al afasy': 'alafasy',
      'kausar by Mishary': 'alafasy',
      'fatiha afasy': 'alafasy',
      'An-Nas by Dosari': 'yasser_ad_dussary',
      'An-Nas by Dossary': 'yasser_ad_dussary',
      'An-Nas by Dussary': 'yasser_ad_dussary',
      'Al-Fatihah by Yasser': 'yasser_ad_dussary',
    };
    cases.forEach((text, id) {
      test('"$text" -> $id', () => expect(qariOf(text), id));
    });

    test('no reciter named is not the same as the first reciter', () {
      expect(qariOf('Al-Kahf'), isNull);
    });

    test("a reciter's name never becomes the surah", () {
      expect(surahOf('An-Nas by Yasser'), 114);
    });

    test('Ar-Rahman is a surah, not part of Abdul Rahman As-Sudais', () {
      final r = parser.parse('Ar-Rahman by Alafasy');
      expect(r.surah?.number, 55);
      expect(r.qari?.qariId, 'alafasy');
      expect(parser.parse('سورة الرحمن').qari, isNull);
    });
  });

  group('what Rattil does with it', () {
    test('plays the reciter that was asked for', () {
      final reply = parser.decide(parser.parse('Al-Ikhlas by Alafasy'));
      expect(reply.plays, isTrue);
      expect(reply.qari!.qariId, 'alafasy');
      expect(reply.surah!.number, 112);
    });

    test('with no reciter named, picks one who has the surah', () {
      final reply = parser.decide(parser.parse('Al-Baqarah'));
      expect(reply.plays, isTrue);
      expect(reply.qari!.qariId, 'abdurrahmaan_as_sudais');
    });

    test('never swaps the requested reciter; says who has it instead', () {
      final reply = parser.decide(parser.parse('Al-Baqarah by Alafasy'));
      expect(reply.plays, isFalse);
      expect(reply.message, contains('Mishary Rashid Alafasy'));
      expect(reply.message, contains('Abdul Rahman As-Sudais'));
      expect(reply.message, contains('Al-Baqarah by Sudais'));
    });

    test('an unknown reciter is said so, not replaced', () {
      final reply = parser.decide(parser.parse('Al-Fatihah by Minshawi'));
      expect(reply.plays, isFalse);
      expect(reply.message, contains('Minshawi'));
    });

    test('"from the beginning" is not a reciter', () {
      final r = parser.parse('Al-Kahf from the beginning');
      expect(r.unknownReciter, isNull);
      expect(parser.decide(r).plays, isTrue);
    });

    test('no surah found gives a hint', () {
      final reply = parser.decide(parser.parse('something nice'));
      expect(reply.plays, isFalse);
      expect(reply.message, contains('surah 112'));
    });
  });

  group('particular ayat (FR-19)', () {
    /// (surah, first ayah, last ayah) as parsed; null ayat = the whole surah.
    List<int?> span(String text) {
      final r = parser.parse(text);
      return [r.surah?.number, r.ayahStart, r.ayahEnd];
    }

    group('passages by name', () {
      final cases = {
        'Ayat al-Kursi': [2, 255, 255],
        'ayatul kursi': [2, 255, 255],
        'ayat ul kursi sunao': [2, 255, 255],
        'kursi by sudais': [2, 255, 255],
        'آية الكرسي': [2, 255, 255],
        'Amana ar-Rasul': [2, 285, 286],
        'aamanar rasool': [2, 285, 286],
        'ayat an nur': [24, 35, 35],
        'ayatun noor': [24, 35, 35],
      };
      cases.forEach((text, expected) {
        test('"$text" -> $expected', () => expect(span(text), expected));
      });

      test('"ayat 5 of an-nur" is ayah 5 of the surah, not Ayat an-Nur', () {
        expect(span('an-nur ayat 5'), [24, 5, 5]);
      });
      test('"surah nur" is the whole surah', () => expect(span('surah nur'), [24, null, null]));
    });

    group('by number', () {
      final cases = {
        '2:255': [2, 255, 255],
        '18:1-10': [18, 1, 10],
        'surah 2 ayah 255': [2, 255, 255],
        'ayah 255 of surah 2': [2, 255, 255],
        'baqarah ayat 255': [2, 255, 255],
        'baqarah 255': [2, 255, 255],
        'baqarah ki ayat 255': [2, 255, 255],
        'kahf 1-10': [18, 1, 10],
        'kahf 1 to 10': [18, 1, 10],
        'kahf 1 se 10 tak': [18, 1, 10],
        'kahf 10-1': [18, 1, 10],
        'yaseen verses 1 to 12': [36, 1, 12],
      };
      cases.forEach((text, expected) {
        test('"$text" -> $expected', () => expect(span(text), expected));
      });
    });

    group('first and last', () {
      final cases = {
        'mulk ki pehli 5 ayat': [67, 1, 5],
        'first ten ayat of kahf': [18, 1, 10],
        'kahf ki aakhri 10 ayat': [18, 101, 110],
        'last two ayat of baqarah': [2, 285, 286],
        'baqarah ki akhri do ayat': [2, 285, 286],
      };
      cases.forEach((text, expected) {
        test('"$text" -> $expected', () => expect(span(text), expected));
      });
    });

    group('the whole surah when no ayah is asked for', () {
      for (final text in ['surah 112', '112', 'ikhlas', 'Al-Kahf by Sudais', '2 times surah 112']) {
        test('"$text"', () => expect(span(text).sublist(1), [null, null]));
      }
    });

    group('numbers that are not ayat', () {
      test('"yaseen 36" is Ya-Sin restating its own number, not ayah 36', () {
        expect(span('yaseen 36'), [36, null, null]);
      });
      test('"baqarah 36" is still ayah 36 -- only the surah\'s own number is special', () {
        expect(span('baqarah 36'), [2, 36, 36]);
      });
      test('"recite 10 ayat" is a count, not Surah Yunus', () {
        final r = parser.parse('recite 10 ayat');
        expect(r.surah, isNull);
        expect(parser.decide(r).plays, isFalse);
      });
      test('"ayah 5" alone is not Surah Al-Ma\'idah -- it asks which surah', () {
        final r = parser.parse('ayah 5');
        expect(r.surah, isNull);
        expect(r.problem, contains('Which surah'));
      });
      for (final text in ['juz 30', 'para 1', 'page 5', 'sipara 30 by sudais']) {
        test('"$text" is a juz or page, not a surah', () {
          final r = parser.parse(text);
          expect(r.surah, isNull);
          expect(r.problem, contains('juz or page'));
        });
      }
      test('"115:1" names a surah that does not exist', () {
        expect(parser.parse('115:1').problem, contains('114 surahs'));
      });
    });

    group('first and last without a number', () {
      test('"last ayah of baqarah"', () => expect(span('last ayah of baqarah'), [2, 286, 286]));
      test('"first ayah of fatiha"', () => expect(span('first ayah of fatiha'), [1, 1, 1]));
    });

    group('ayat that do not exist are explained, not requested', () {
      test('past the end of the surah', () {
        final r = parser.parse('ikhlas ayah 7');
        expect(r.problem, contains('4 ayat'));
        expect(r.ayahStart, isNull);
        expect(parser.decide(r).plays, isFalse);
      });
      test('a range that runs past the end', () {
        expect(parser.parse('baqarah 280-300').problem, contains('286 ayat'));
      });
      test('more "first" ayat than the surah has', () {
        expect(parser.parse('first 10 ayat of ikhlas').problem, contains('only 4'));
      });
      test('ayah 0', () => expect(parser.parse('kahf ayah 0').problem, isNotNull));
    });

    group('what Rattil does with them', () {
      test('plays the range, and names it', () {
        final reply = parser.decide(parser.parse('Ayat al-Kursi'));
        expect(reply.plays, isTrue);
        expect([reply.surah!.number, reply.ayahStart, reply.ayahEnd], [2, 255, 255]);
        expect(reply.label, 'Ayat al-Kursi (Al-Baqarah 255)');
        expect(parser.decide(parser.parse('kahf 1-10')).label, 'Al-Kahf 1–10');
        expect(parser.decide(parser.parse('kahf')).label, 'Al-Kahf');
      });

      test('a reciter who lacks the surah gets a suggestion that works as typed', () {
        for (final text in ['Ayat al-Kursi by Alafasy', 'kahf 1-10 by Alafasy', 'baqarah 255 by Dosari']) {
          final reply = parser.decide(parser.parse(text));
          expect(reply.plays, isFalse, reason: text);
          final suggestion = RegExp(r'try "([^"]+)"').firstMatch(reply.message!)!.group(1)!;
          final original = parser.parse(text);
          final followed = parser.decide(parser.parse(suggestion));
          expect(followed.plays, isTrue, reason: suggestion);
          expect([followed.surah!.number, followed.ayahStart, followed.ayahEnd],
              [original.surah!.number, original.ayahStart, original.ayahEnd],
              reason: '"$suggestion" must ask for the same ayat as "$text"');
        }
      });
    });
  });

  group('the welcome message', () {
    final text = parser.describeLibrary();

    test('summarises instead of listing 114 surahs', () {
      expect(text, contains('the whole Quran'));
      expect(text.length, lessThan(400), reason: text);
      expect(text, isNot(contains('Al-Baqarah')));
    });

    test('groups reciters that hold the same surahs', () {
      expect(text, contains('Mishary Rashid Alafasy and Yasser Al-Dosari'));
      expect(text, contains("Al-Fatihah and Al-Qari'ah to An-Nas"));
    });

    test('offers examples that actually work', () {
      expect(text, contains('"Al-Kahf"'));
      expect(text, contains('"Ayat al-Kursi"'));
      final examples = RegExp(r'"([^"]+)"').allMatches(text).map((m) => m.group(1)!).toList();
      expect(examples, hasLength(greaterThanOrEqualTo(3)));
      for (final example in examples) {
        expect(parser.decide(parser.parse(example)).plays, isTrue, reason: example);
      }
    });
  });
}
