import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/tajweed_rules.dart';
import 'package:frontend/dummy/dummy_surahs.dart';
import 'package:frontend/models/assistant_answer.dart';
import 'package:frontend/models/qari.dart';
import 'package:frontend/services/rattil_request_parser.dart';

/// Reading Rattil's assistant's reply, and deciding when to ask it at all.
void main() {
  group('AssistantAnswer.fromJson', () {
    test('a reply with a play action and a rule action', () {
      final a = AssistantAnswer.fromJson({
        'reply': 'Here it is. ',
        'actions': [
          {'type': 'play', 'surah': 2, 'ayah_start': 255, 'ayah_end': 255, 'qari_id': 'abdurrahmaan_as_sudais'},
          {'type': 'rule', 'rule': 'ghunnah'},
        ],
      });
      expect(a.reply, 'Here it is.');
      final play = a.actions[0] as PlayAction;
      expect([play.surah, play.ayahStart, play.ayahEnd, play.qariId], [2, 255, 255, 'abdurrahmaan_as_sudais']);
      expect((a.actions[1] as RuleAction).rule, 'ghunnah');
    });

    test('a whole-surah play has no ayat', () {
      final a = AssistantAnswer.fromJson({
        'reply': '',
        'actions': [
          {'type': 'play', 'surah': 112, 'ayah_start': null, 'ayah_end': null, 'qari_id': 'alafasy'}
        ],
      });
      final play = a.actions.single as PlayAction;
      expect(play.ayahStart, isNull);
      expect(play.ayahEnd, isNull);
    });

    test('an action type from a newer server is skipped, not a crash', () {
      final a = AssistantAnswer.fromJson({
        'reply': 'ok',
        'actions': [
          {'type': 'something_new', 'x': 1},
          {'type': 'rule', 'rule': 'madd'},
        ],
      });
      expect(a.actions, hasLength(1));
    });

    test('a malformed play action is skipped', () {
      final a = AssistantAnswer.fromJson({
        'reply': 'ok',
        'actions': [
          {'type': 'play', 'surah': 'two', 'qari_id': 'alafasy'},
          {'type': 'play', 'surah': 2},
          'not even a map',
        ],
      });
      expect(a.actions, isEmpty);
    });

    test('missing fields do not throw', () {
      final a = AssistantAnswer.fromJson({});
      expect(a.reply, '');
      expect(a.actions, isEmpty);
    });
  });

  group('which messages go to the assistant', () {
    final parser = RattilRequestParser(
      surahs: dummySurahs,
      qaris: [
        Qari(
          qariId: 'abdurrahmaan_as_sudais',
          nameEnglish: 'Abdul Rahman As-Sudais',
          nameArabic: 'عبد الرحمن السديس',
          availableSurahs: [for (var i = 1; i <= 114; i++) i],
        ),
      ],
      rules: tajweedRules,
    );
    bool goesToAssistant(String text) => parser.decide(parser.parse(text)).unread;

    test('only what the rules cannot read', () {
      expect(goesToAssistant('how can I stop making ghunnah mistakes every day'), isFalse,
          reason: 'names a rule: the library answers it');
      expect(goesToAssistant('which surah should I learn after the short ones'), isTrue);
      expect(goesToAssistant('I keep rushing when I recite, any advice'), isTrue);
    });

    test('everything the parser handles stays with the parser', () {
      for (final text in [
        'Ayat al-Kursi', 'kahf 1-10', 'yaseen by sudais', 'repeat', 'slower', 'what is madd',
        'salam', 'thank you', 'ikhlas ayah 7', 'juz 30', 'what is idgham',
      ]) {
        expect(goesToAssistant(text), isFalse, reason: text);
      }
    });

    test('the fallback text is still there if the assistant is unavailable', () {
      final reply = parser.decide(parser.parse('which surah should I learn next'));
      expect(reply.message, contains('surah 112'));
    });
  });
}
