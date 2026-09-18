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
      final example = RegExp(r'"([^"]+ by [^"]+)"').firstMatch(text)!.group(1)!;
      expect(parser.decide(parser.parse(example)).plays, isTrue, reason: example);
    });
  });
}
