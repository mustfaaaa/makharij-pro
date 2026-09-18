import '../models/qari.dart';
import '../models/surah.dart';

/// Understands what someone typed into Rattil AI: which surah, which reciter.
///
/// It lives apart from the screen so it can be tested without one, and because
/// the screen's first version got three things wrong that are easy to get wrong
/// again:
///
///  * **Reciters by their common name.** It matched a reciter by full name or by
///    the *first* word of it -- "abdul", "mishary", "yasser". People say
///    "Sudais", "Alafasy", "Dosari". None of those matched, and the screen then
///    quietly played the first reciter in the list instead of the one asked for.
///  * **Surahs as people spell them.** It needed the exact transliteration in
///    the app's list: "Al-Fatihah" worked, "Fatiha", "Yaseen" and "Rehman" did
///    not. Transliteration has no single spelling, so this folds the common
///    variants together (ee/i, doubled letters, a final -ah, th/s, dh/z, a
///    leading al-/an-/ar-) and then allows a small edit distance on top.
///  * **The welcome message.** It listed every available surah by name, which
///    was fine for 15 and became a wall of 114 names once one reciter had the
///    whole Quran. [describeLibrary] summarises by reciter instead.
///
/// Arabic input works too ("سورة الفاتحة"), as does a surah's meaning ("the
/// Cow") and its number ("surah 18").
class RattilRequestParser {
  final List<Surah> surahs;
  final List<Qari> qaris;

  late final List<_SurahKeys> _surahKeys = [for (final s in surahs) _SurahKeys.of(s)];
  late final List<_QariKeys> _qariKeys = [for (final q in qaris) _QariKeys.of(q)];

  RattilRequestParser({required this.surahs, required this.qaris});

  /// What the message asks for. Any part can be missing.
  RattilRequest parse(String text) {
    final tokens = _latinTokens(text);
    final qariMatch = _matchQari(text, tokens);
    final usedByQari = qariMatch?.tokenIndices ?? const <int>{};

    // A juz or a page is a different unit, and "juz 30" must not play surah 30.
    if (RegExp(r'\b(?:juz|juzz|para|parah|sipara|siparah|hizb|page|safha)\b').hasMatch(_fold(text))) {
      return RattilRequest(
          qari: qariMatch?.qari,
          problem: 'I can play surahs and particular ayat, but not a whole juz or page yet. '
              'Try "Al-Mulk" or "An-Naba 1-10".');
    }

    // Which ayat (FR-19): a named passage, "2:255", or a surah plus numbers.
    Surah? surah;
    _Span? span;
    String? passageName;
    final passage = _matchPassage(text, tokens);
    final colon = RegExp(r'(?<!\d)(\d{1,3})\s*:\s*(\d{1,3})(?:\s*(?:-|–|to|se)\s*(\d{1,3}))?')
        .firstMatch(_lowerKeep(text));
    if (passage != null) {
      surah = _byNumber(passage.surah);
      span = _Span(passage.start, passage.end);
      passageName = passage.name;
    } else if (colon != null) {
      final number = int.parse(colon.group(1)!);
      surah = _byNumber(number);
      if (surah == null) {
        return RattilRequest(
            qari: qariMatch?.qari,
            problem: 'The Quran has ${surahs.length} surahs, so there is no surah $number.');
      }
      final a = int.parse(colon.group(2)!);
      span = _Span(a, int.tryParse(colon.group(3) ?? '') ?? a);
    } else {
      final hit = _matchSurah(text, tokens, usedByQari);
      surah = hit?.surah;
      if (hit != null) {
        span = _ayahSpan(text, consumed: hit.consumed, allowBareNumbers: !hit.byBareNumber);
        // "Yaseen 36": 36 is Ya-Sin's own number, restated -- not its 36th ayah.
        if (span != null && span.fromBareNumber && span.start == hit.surah.number &&
            hit.consumed == null) {
          span = null;
        }
      } else if (RegExp(_ayahWordPattern + r'\s*(?:no\.?|number|#)?\s*\d').hasMatch(_lowerKeep(text))) {
        return RattilRequest(
            qari: qariMatch?.qari,
            problem: 'Which surah? Try "Al-Baqarah 255" or "2:255".');
      }
    }

    String? problem;
    if (surah != null && span != null) {
      problem = span.problemFor(surah);
      if (problem == null) span = span.resolvedFor(surah);
    }

    String? unknownReciter;
    if (qariMatch == null) {
      // Only "by X": "from" is as often "from the beginning" as "from Sudais".
      final m = RegExp(r'\bby\s+(?:(?:al|as|ad|ar|an|ash)\s+)?([a-z]{3,})').firstMatch(_fold(text));
      final named = m?.group(1);
      if (named != null && !_stopwords.contains(named) &&
          (surah == null || !_isPartOfSurahName(named, surah))) {
        unknownReciter = named;
      }
    }
    return RattilRequest(
      surah: surah,
      qari: qariMatch?.qari,
      unknownReciter: unknownReciter,
      ayahStart: problem == null ? span?.start : null,
      ayahEnd: problem == null ? span?.end : null,
      passage: passageName,
      problem: problem,
    );
  }

  /// Turns a parsed request into what Rattil should do: play something, or say
  /// why it can't. Never silently swaps the reciter someone asked for.
  ///
  /// [preferred] is the reciter picked on screen (FR-16). A reciter named in
  /// the message outranks it. If the picked one lacks the surah, someone who
  /// has it plays instead -- the picker is a default, not a demand -- and
  /// [RattilReply.note] says so, so the switch is never silent either.
  RattilReply decide(RattilRequest request, {Qari? preferred}) {
    if (request.problem != null) return RattilReply.say(request.problem!);
    final surah = request.surah;
    if (surah == null) {
      return RattilReply.say(
          "I couldn't find a surah in that. Try a name like \"Al-Kahf\" or \"Yaseen\", "
          'or a number like "surah 112".');
    }
    if (request.unknownReciter != null) {
      return RattilReply.say(
          "I don't have a reciter called \"${_capitalise(request.unknownReciter!)}\". "
          'I have ${_joinAnd(qaris.map((q) => q.nameEnglish).toList())}.');
    }

    RattilReply play(Qari q, {String? note}) => RattilReply.play(q, surah,
        ayahStart: request.ayahStart, ayahEnd: request.ayahEnd, passage: request.passage, note: note);
    // What to call this request in a suggestion. It must read back as the same
    // request, so it is written the way the parser reads it.
    final asked = request.passage ??
        (request.ayahStart == null
            ? surah.nameEnglish
            : '${surah.nameEnglish} ${_spanText(request.ayahStart!, request.ayahEnd!)}');

    final requested = request.qari;
    if (requested != null) {
      if (requested.availableSurahs.contains(surah.number)) return play(requested);
      final others = qaris.where((q) => q.availableSurahs.contains(surah.number)).toList();
      final alternative = others.isEmpty
          ? ''
          : ' ${others.first.nameEnglish} does -- try "$asked by ${shortName(others.first)}".';
      return RattilReply.say(
          "${requested.nameEnglish} doesn't have ${surah.nameEnglish} here yet.$alternative");
    }

    // No reciter named: the one picked on screen, if they have it.
    if (preferred != null && preferred.availableSurahs.contains(surah.number)) {
      return play(preferred);
    }
    // Otherwise the first one who actually has it, rather than an error.
    for (final q in qaris) {
      if (q.availableSurahs.contains(surah.number)) {
        return play(q,
            note: preferred == null
                ? null
                : "${preferred.nameEnglish} doesn't have ${surah.nameEnglish} yet, "
                    'so this is ${q.nameEnglish}.');
      }
    }
    return RattilReply.say('No reciter here has ${surah.nameEnglish} yet.');
  }

  /// The opening message: who has what, summarised rather than listed.
  String describeLibrary() {
    if (qaris.isEmpty) return 'No reciters are available right now.';

    final groups = <String, List<Qari>>{};
    for (final q in qaris) {
      final key = ([...q.availableSurahs]..sort()).join(',');
      groups.putIfAbsent(key, () => []).add(q);
    }

    final lines = <String>[];
    for (final group in groups.values) {
      final names = _joinAnd(group.map((q) => q.nameEnglish).toList());
      lines.add('• $names — ${_describeSurahSet(group.first.availableSurahs)}');
    }

    final examples = <String>[];
    final full = qaris.where((q) => q.availableSurahs.length >= surahs.length).toList();
    if (full.isNotEmpty) {
      final kahf = surahs.where((s) => s.number == 18);
      if (kahf.isNotEmpty) examples.add('"${kahf.first.nameEnglish}"');
    }
    if (qaris.any((q) => q.availableSurahs.contains(_passages.first.surah))) {
      examples.add('"${_passages.first.name}"');
    }
    final partial = qaris.where((q) => q.availableSurahs.length < surahs.length).toList();
    if (partial.isNotEmpty) {
      final q = partial.first;
      final last = ([...q.availableSurahs]..sort()).last;
      final name = _surahName(last);
      if (name != null) examples.add('"$name by ${shortName(q)}"');
    }

    final tryLine = examples.isEmpty ? '' : '\nTry ${_joinOr(examples)}.';
    return 'Ask for a surah or particular ayat, and a reciter if you like.\n'
        '${lines.join('\n')}$tryLine';
  }

  /// The name people actually use for a reciter: the family name, without its
  /// article -- "Sudais", "Alafasy", "Dosari".
  static String shortName(Qari q) {
    final last = q.nameEnglish.split(RegExp(r'\s+')).last;
    final bare = last.replaceFirst(RegExp(r'^(al|as|ad|ar|an|ash)-', caseSensitive: false), '');
    return bare.isEmpty ? last : bare;
  }

  // ── surah matching ──────────────────────────────────────────────────────

  /// The surah, and how it was found -- which matters for reading the ayat:
  /// the number in "surah 2 255" is spent on the surah, and in a bare "112"
  /// there is no number left over to be an ayah.
  _SurahHit? _matchSurah(String text, List<String> tokens, Set<int> excluded) {
    final folded = _fold(text);

    // 1. "surah 18", "sura no. 2", "chapter 55" -- an explicit number wins.
    final explicit = RegExp(r'\b(?:surah|sura|surat|chapter)\s*(?:no\.?|number|#)?\s*(\d{1,3})\b')
        .firstMatch(_lowerKeep(text));
    final explicitSurah = _byNumber(int.tryParse(explicit?.group(1) ?? ''));
    if (explicitSurah != null) return _SurahHit(explicitSurah, consumed: explicit!.group(0));

    // 2. The surah's name, in Arabic script.
    final arabic = _arabicWords(text);
    if (arabic.isNotEmpty) {
      final joined = ' ${arabic.join(' ')} ';
      for (final k in _surahKeys) {
        for (final a in k.arabic) {
          if (joined.contains(' $a ')) return _SurahHit(k.surah);
        }
      }
    }

    // 3. The surah's name, however it was transliterated.
    final candidates = <String>{};
    for (var i = 0; i < tokens.length; i++) {
      if (excluded.contains(i) || _stopwords.contains(tokens[i])) continue;
      var joined = '';
      for (var j = i; j < tokens.length && j < i + 3; j++) {
        if (excluded.contains(j) || _stopwords.contains(tokens[j])) break;
        joined += tokens[j];
        // A lone article is never a name. Without this "al" -- on its own in
        // every "Al-..." request -- would be an exact hit for Al-A'la.
        if (j == i && _articles.contains(tokens[j])) continue;
        candidates.addAll(_keys(joined));
      }
    }
    _SurahKeys? best;
    var bestDistance = 1 << 30;
    var bestLength = 0;
    for (final k in _surahKeys) {
      for (final key in k.latin) {
        for (final c in candidates) {
          final d = _distance(c, key);
          if (d > _tolerance(key, c)) continue;
          if (d < bestDistance || (d == bestDistance && key.length > bestLength)) {
            best = k;
            bestDistance = d;
            bestLength = key.length;
          }
        }
      }
    }
    if (best != null) return _SurahHit(best.surah);

    // 4. Its meaning -- "the Cow", "the Opening".
    final padded = ' $folded ';
    for (final k in _surahKeys) {
      if (k.meaning.length >= 3 && padded.contains(' ${k.meaning} ')) return _SurahHit(k.surah);
    }

    // 5. A bare number, if it is a surah number -- but not a count of ayat
    // ("recite 10 ayat"), an ayah ("ayah 5"), or how many times ("3 baar").
    const notACount = r'(?!\s*(?:ayahs?|ayat|aayat|ayaat|aya|ayet|verses?|times|x|baar|bar|dafa|dafaa|martaba)\b)';
    final bare = RegExp(r'(?<!' + _ayahWordPattern + r'\s*)(?<!\d)(\d{1,3})(?!\d)' + notACount);
    for (final m in bare.allMatches(_lowerKeep(text))) {
      final s = _byNumber(int.tryParse(m.group(1)!));
      if (s != null) return _SurahHit(s, byBareNumber: true);
    }
    return null;
  }

  // ── ayah matching (FR-19) ───────────────────────────────────────────────

  /// A passage people ask for by name rather than by number.
  _Passage? _matchPassage(String text, List<String> tokens) {
    final keys = {for (final t in tokens) ..._keys(t)};
    bool has(List<String> words) => words.any((w) => _keys(w).any(keys.contains));
    final arabic = ' ${_arabicWords(text).join(' ')} ';

    // Ayat al-Kursi: "kursi" says it on its own, in any spelling.
    if (has(['kursi', 'kursee']) || arabic.contains(' الكرسي ') || arabic.contains(' كرسي ')) {
      return _passages[0];
    }
    // Amana ar-Rasul: the closing two ayat of Al-Baqarah, named by their opening.
    if ((has(['amana', 'aamana', 'amanar']) && has(['rasul', 'rasool'])) ||
        (arabic.contains(' امن ') && arabic.contains(' الرسول '))) {
      return _passages[1];
    }
    // Ayat an-Nur -- but "ayat 5 of an-nur" is ayah 5 of the surah, so only
    // when no number is given.
    final hasNumber = RegExp(r'\d').hasMatch(text);
    final saysAyah = has(['ayat', 'ayah', 'ayatun', 'ayatul', 'verse']);
    if (!hasNumber &&
        ((saysAyah && has(['nur', 'noor', 'light'])) || arabic.contains(' ايه النور '))) {
      return _passages[2];
    }
    return null;
  }

  /// Which ayat of [surah] the message asks for, or null for the whole surah.
  ///
  /// [consumed] is the text that already named the surah ("surah 2"), so its
  /// number is not read a second time as an ayah. With [allowBareNumbers] off
  /// -- the surah itself was a bare number -- a number needs "ayah" beside it.
  _Span? _ayahSpan(String text, {String? consumed, required bool allowBareNumbers}) {
    var lower = _lowerKeep(text);
    if (consumed != null) lower = lower.replaceFirst(consumed, ' ');
    // "3 times", "2 baar": how often, not which ayah.
    lower = lower.replaceAll(RegExp(r'\b\d{1,3}\s*(?:times|x|baar|bar|dafa|dafaa|martaba)\b'), ' ');
    const n = r'(\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|'
        r'ek|do|teen|char|chaar|paanch|panch|chay|chhe|saat|aath|nau|das)';
    const upTo = r'(?:-|–|to|se|till|until|through|tak)';

    const firstWord = r'\b(?:first|pehli|pehle|shuru\s+ki|opening)\s+';
    const lastWord = r'\b(?:last|aakhri|akhri|aakhir|akhir|aakhiri|akhiri|final|closing)\s+';
    final first = RegExp(firstWord + n + r'\b').firstMatch(lower);
    if (first != null) return _Span.first(_number(first.group(1)!));
    final last = RegExp(lastWord + n + r'\b').firstMatch(lower);
    if (last != null) return _Span.last(_number(last.group(1)!));
    // "the last ayah of Al-Baqarah" -- one, with no number said.
    if (RegExp(firstWord + _ayahWordPattern).hasMatch(lower)) return _Span.first(1);
    if (RegExp(lastWord + _ayahWordPattern).hasMatch(lower)) return _Span.last(1);

    final keyword =
        RegExp(_ayahWordPattern + r'\s*(?:no\.?|number|#)?\s*(\d{1,3})(?:\s*' + upTo + r'\s*(\d{1,3}))?')
            .firstMatch(lower);
    if (keyword != null) {
      final a = int.parse(keyword.group(1)!);
      return _Span(a, int.tryParse(keyword.group(2) ?? '') ?? a);
    }

    if (!allowBareNumbers) return null;
    final range = RegExp(r'(?<!\d)(\d{1,3})\s*' + upTo + r'\s*(\d{1,3})(?!\d)').firstMatch(lower);
    if (range != null) return _Span(int.parse(range.group(1)!), int.parse(range.group(2)!));
    final single = RegExp(r'(?<!\d)(\d{1,3})(?!\d)').firstMatch(lower);
    if (single != null) {
      final a = int.parse(single.group(1)!);
      return _Span(a, a, fromBareNumber: true);
    }
    return null;
  }

  Surah? _byNumber(int? n) {
    if (n == null) return null;
    for (final s in surahs) {
      if (s.number == n) return s;
    }
    return null;
  }

  String? _surahName(int number) => _byNumber(number)?.nameEnglish;

  bool _isPartOfSurahName(String word, Surah surah) =>
      _SurahKeys.of(surah).latin.any((k) => _keys(word).any(k.contains));

  String _describeSurahSet(List<int> numbers) {
    final sorted = ([...numbers]..sort());
    if (sorted.length >= surahs.length) return 'the whole Quran';
    final runs = <List<int>>[];
    for (final n in sorted) {
      if (runs.isNotEmpty && runs.last.last == n - 1) {
        runs.last.add(n);
      } else {
        runs.add([n]);
      }
    }
    final parts = [
      for (final r in runs)
        r.length == 1
            ? (_surahName(r.first) ?? 'surah ${r.first}')
            : '${_surahName(r.first) ?? r.first} to ${_surahName(r.last) ?? r.last}',
    ];
    return '${sorted.length} surahs: ${_joinAnd(parts)}';
  }

  // ── reciter matching ────────────────────────────────────────────────────

  _QariMatch? _matchQari(String text, List<String> tokens) {
    final arabic = ' ${_arabicWords(text).join(' ')} ';
    for (final k in _qariKeys) {
      for (final a in k.arabic) {
        if (arabic.contains(' $a ')) return _QariMatch(k.qari, const {});
      }
    }

    _QariMatch? best;
    var bestDistance = 1 << 30;
    for (var i = 0; i < tokens.length; i++) {
      if (_stopwords.contains(tokens[i])) continue;
      // One word, or two run together ("al afasy", "as sudais").
      for (var span = 1; span <= 2 && i + span <= tokens.length; span++) {
        for (final key in _keys(tokens.sublist(i, i + span).join())) {
          for (final k in _qariKeys) {
            for (final alias in k.latin) {
              final d = _distance(key, alias);
              if (d > _tolerance(alias, key)) continue;
              if (d < bestDistance) {
                bestDistance = d;
                best = _QariMatch(k.qari, {for (var j = i; j < i + span; j++) j});
              }
            }
          }
        }
      }
    }
    return best;
  }
}

/// A parsed message.
class RattilRequest {
  final Surah? surah;

  /// Only set when the message named a reciter and it was recognised.
  final Qari? qari;

  /// A name that followed "by" and matched no reciter -- worth saying so,
  /// instead of playing someone else as if it had been understood.
  final String? unknownReciter;

  /// The ayat asked for, both inclusive; null for the whole surah.
  final int? ayahStart;
  final int? ayahEnd;

  /// Set when they were asked for by name, e.g. "Ayat al-Kursi".
  final String? passage;

  /// Why the ayat asked for cannot be played -- "Al-Ikhlas has 4 ayat".
  final String? problem;

  const RattilRequest({
    this.surah,
    this.qari,
    this.unknownReciter,
    this.ayahStart,
    this.ayahEnd,
    this.passage,
    this.problem,
  });

  /// The same ayat, asked of [reciter] by name -- what picking a reciter on
  /// screen means for the passage already playing.
  RattilRequest withQari(Qari reciter) => RattilRequest(
        surah: surah,
        qari: reciter,
        ayahStart: ayahStart,
        ayahEnd: ayahEnd,
        passage: passage,
        problem: problem,
      );

  /// Whether this is something that could be played again by another reciter.
  bool get isPlayable => surah != null && problem == null && unknownReciter == null;
}

/// What Rattil should do with a request: play, or explain.
class RattilReply {
  final Qari? qari;
  final Surah? surah;
  final int? ayahStart;
  final int? ayahEnd;
  final String? passage;
  final String? message;

  /// Said alongside the recitation -- when the reciter playing is not the
  /// one picked on screen, and why.
  final String? note;

  const RattilReply.play(Qari this.qari, Surah this.surah,
      {this.ayahStart, this.ayahEnd, this.passage, this.note})
      : message = null;
  const RattilReply.say(String this.message)
      : qari = null,
        surah = null,
        ayahStart = null,
        ayahEnd = null,
        passage = null,
        note = null;

  bool get plays => qari != null && surah != null;

  /// How to name what is playing: "Ayat al-Kursi (Al-Baqarah 255)",
  /// "Al-Kahf 1–10", or just "Al-Kahf".
  String get label {
    final s = surah;
    if (s == null) return '';
    if (ayahStart == null) return s.nameEnglish;
    final where = '${s.nameEnglish} ${_spanText(ayahStart!, ayahEnd!, dash: '–')}';
    return passage == null ? where : '$passage ($where)';
  }
}

// ── internals ─────────────────────────────────────────────────────────────

class _QariMatch {
  final Qari qari;
  final Set<int> tokenIndices;
  _QariMatch(this.qari, this.tokenIndices);
}

class _SurahHit {
  final Surah surah;

  /// The text that named the surah by number ("surah 2"), if it did.
  final String? consumed;

  /// Found as a lone number: nothing else in the message is an ayah unless
  /// it says "ayah".
  final bool byBareNumber;

  _SurahHit(this.surah, {this.consumed, this.byBareNumber = false});
}

/// A run of ayat. "First N" and "last N" only become concrete once the
/// surah's length is known.
class _Span {
  final int start;
  final int end;
  final int? _first;
  final int? _last;

  /// A lone number after the surah's name, with no "ayah" beside it.
  final bool fromBareNumber;

  _Span(int a, int b, {this.fromBareNumber = false})
      // "Kahf 10-1" means 1 to 10; nobody asks for a range backwards.
      : start = a <= b ? a : b,
        end = a <= b ? b : a,
        _first = null,
        _last = null;
  _Span.first(int n)
      : start = 1,
        end = n,
        _first = n,
        _last = null,
        fromBareNumber = false;
  _Span.last(int n)
      : start = 0,
        end = 0,
        _first = null,
        _last = n,
        fromBareNumber = false;

  /// Why these ayat cannot be played, or null if they can.
  String? problemFor(Surah s) {
    final count = s.ayahCount;
    final asked = _first ?? _last;
    if (asked != null) {
      if (asked < 1) return 'Ask for at least one ayah.';
      if (asked > count) {
        return '${s.nameEnglish} has only $count ayat -- ask for the whole surah instead.';
      }
      return null;
    }
    if (start < 1) return 'Ayat are numbered from 1.';
    if (end > count) return '${s.nameEnglish} has $count ayat, so there is no ayah $end.';
    return null;
  }

  _Span resolvedFor(Surah s) {
    if (_first != null) return _Span(1, _first);
    if (_last != null) return _Span(s.ayahCount - _last + 1, s.ayahCount);
    return this;
  }
}

class _Passage {
  final String name;
  final int surah;
  final int start;
  final int end;
  const _Passage(this.name, this.surah, this.start, this.end);
}

/// Passages asked for by name. Kept short and to references that are not in
/// dispute: a wrong ayah here would be the app misquoting the Quran.
const _passages = [
  _Passage('Ayat al-Kursi', 2, 255, 255),
  _Passage('Amana ar-Rasul', 2, 285, 286),
  _Passage('Ayat an-Nur', 24, 35, 35),
];

/// The words that introduce an ayah number: "ayah 255", "verses 1 to 12".
const _ayahWordPattern = r'\b(?:ayahs?|ayat|aayat|ayaat|aya|ayet|verses?)';

/// Lower case, apostrophes gone, but ":" and "-" kept -- the punctuation that
/// carries "2:255" and "1-10", which [_fold] would erase.
String _lowerKeep(String s) => s
    .toLowerCase()
    .replaceAll(RegExp("[’‘'`ʿʾ]"), '')
    .replaceAll(RegExp(r'\s+'), ' ');

/// "255" or "1-10": the form the parser itself reads back.
String _spanText(int a, int b, {String dash = '-'}) => a == b ? '$a' : '$a$dash$b';

int _number(String s) =>
    int.tryParse(s) ??
    const {
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7,
      'eight': 8, 'nine': 9, 'ten': 10,
      'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'chaar': 4, 'paanch': 5, 'panch': 5,
      'chay': 6, 'chhe': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'das': 10,
    }[s]!;

class _SurahKeys {
  final Surah surah;
  final Set<String> latin;
  final Set<String> arabic;
  final String meaning;

  _SurahKeys(this.surah, this.latin, this.arabic, this.meaning);

  factory _SurahKeys.of(Surah s) {
    final tokens = _latinTokens(s.nameEnglish);
    final withoutArticle = [
      for (var i = 0; i < tokens.length; i++)
        if (!(i == 0 && _articles.contains(tokens[i]) && tokens.length > 1)) tokens[i],
    ];
    final latin = {..._keys(withoutArticle.join()), ..._keys(tokens.join())};

    final arabicWords = _arabicWords(s.nameArabic);
    final arabic = <String>{
      arabicWords.join(' '),
      arabicWords.map(_stripArabicArticle).join(' '),
    }..removeWhere((a) => a.isEmpty);

    final meaning = _fold(s.meaning).replaceFirst(RegExp(r'^the '), '');
    return _SurahKeys(s, latin, arabic, meaning);
  }
}

class _QariKeys {
  final Qari qari;
  final Set<String> latin;
  final Set<String> arabic;

  _QariKeys(this.qari, this.latin, this.arabic);

  factory _QariKeys.of(Qari q) {
    // Every distinctive word of the display name and of the id -- the id
    // carries spellings the display name does not ("yasser_ad_dussary"
    // against "Yasser Al-Dosari").
    final words = [
      ..._latinTokens(q.nameEnglish),
      ..._latinTokens(q.qariId.replaceAll('_', ' ')),
    ];
    final latin = <String>{};
    for (final w in words) {
      if (_articles.contains(w) || _genericNameWords.contains(w)) continue;
      latin.addAll(_keys(w).where((k) => k.length >= 4));
      // "alafasy" -> also "afasy".
      final m = RegExp(r'^(al|as|ad|ar|an)(.{4,})$').firstMatch(w);
      if (m != null) latin.addAll(_keys(m.group(2)!));
    }
    final arabic = {
      for (final w in _arabicWords(q.nameArabic))
        if (!_genericArabicNameWords.contains(w)) _stripArabicArticle(w),
    }..removeWhere((a) => a.length < 3 || _genericArabicNameWords.contains(a));
    return _QariKeys(q, latin, arabic);
  }
}

const _articles = {'al', 'an', 'ar', 'as', 'ash', 'at', 'ad', 'adh', 'az', 'ath', 'aal', 'el'};

/// Parts of a reciter's name too common to identify them -- and "rahman" would
/// otherwise collide with the surah Ar-Rahman.
const _genericNameWords = {'abdul', 'abd', 'abdur', 'rahman', 'bin', 'ibn', 'muhammad', 'sheikh', 'shaykh', 'qari'};

/// The same, in Arabic script: عبد and الرحمن would otherwise make "سورة الرحمن"
/// read as a request for As-Sudais.
const _genericArabicNameWords = {'عبد', 'رحمن', 'الرحمن', 'محمد', 'بن'};

/// Words in a request that are never part of a surah or reciter name.
const _stopwords = {
  'surah', 'sura', 'surat', 'surahs', 'chapter', 'by', 'from', 'of', 'the', 'a', 'an',
  'play', 'recite', 'recited', 'recitation', 'listen', 'hear', 'please', 'pls', 'plz',
  'to', 'me', 'i', 'want', 'give', 'can', 'you', 'some', 'and', 'in', 'voice', 'qari',
  'reciter', 'sheikh', 'shaykh', 'with', 'for', 'no', 'number',
  // Roman Urdu, as people here write it.
  'ki', 'ka', 'ke', 'ko', 'se', 'mein', 'main', 'sunao', 'sunaye', 'sunna', 'awaz',
  'chalao', 'lagao', 'krdo', 'kardo', 'karo', 'do', 'tak',
  // Words that pick ayat (FR-19) -- never a surah's name, and short enough
  // that fuzzy matching would otherwise try to make them one.
  'ayah', 'ayahs', 'ayat', 'aayat', 'ayaat', 'aya', 'ayet', 'verse', 'verses',
  'first', 'last', 'pehli', 'pehle', 'shuru', 'aakhri', 'akhri', 'aakhir', 'akhir',
  'aakhiri', 'akhiri', 'final', 'closing', 'opening', 'till', 'until', 'through',
  'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
  'ek', 'teen', 'char', 'chaar', 'paanch', 'panch', 'chay', 'chhe', 'saat', 'aath', 'nau', 'das',
};

String _fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp("[’‘'`ʿʾ]"), '')
    .replaceAll(RegExp(r'[^a-z0-9؀-ۿ]+'), ' ')
    .trim();

List<String> _latinTokens(String s) =>
    _fold(s).split(' ').where((t) => t.isNotEmpty && RegExp(r'^[a-z]+$').hasMatch(t)).toList();

/// Every key one Latin spelling of an Arabic name folds to.
///
/// "th" and "dh" each stand for two different Arabic letters, and people
/// transliterate them differently: ث as th, s or t ("Kawthar", "Kausar"); ض and
/// ذ as dh, d or z ("Ad-Dhuha" / "Duha", "Adh-Dhariyat" / "Zariyat"). No single
/// rewrite serves both, so each spelling yields every reading and two
/// spellings match if any of their readings do.
Set<String> _keys(String word) => {
      for (final th in const ['s', 't'])
        for (final dh in const ['z', 'd'])
          _squash(word.replaceAll('dh', dh).replaceAll('th', th)),
    };

/// Folds the spelling variation that is not ambiguous. Applied to both sides,
/// so only consistency matters, not accuracy.
String _squash(String word) {
  var w = word.replaceAll('ee', 'i').replaceAll('oo', 'u');
  if (w.length > 1) w = w[0] + w.substring(1).replaceAll('y', 'i');
  w = w.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
  if (w.length > 3 && w.endsWith('ah')) w = w.substring(0, w.length - 1);
  // A final vowel is the least reliable letter in a transliteration --
  // "Zalzala" / "Zilzal", "Baqara" / "Baqarah". Dropped when enough of the
  // name is left to still tell it apart, so "Taha" and "Nisa" keep theirs.
  if (w.length > 4 && w.endsWith('a')) w = w.substring(0, w.length - 1);
  return w;
}

/// How many edits a match may be off by, from the shorter of the two: short
/// names must match exactly, or "Nas" would find "Nasr" and "Nisa".
int _tolerance(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  if (n <= 4) return 0;
  if (n <= 7) return 1;
  return 2;
}

int _distance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty || b.isEmpty) return a.length + b.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = [previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}

List<String> _arabicWords(String s) {
  final normal = s
      .replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
  return RegExp('[ء-ي]+')
      .allMatches(normal)
      .map((m) => m.group(0)!)
      .where((w) => w != 'سوره' && w != 'سورة')
      .toList();
}

String _stripArabicArticle(String w) => w.startsWith('ال') && w.length > 3 ? w.substring(2) : w;

String _joinAnd(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

String _joinOr(List<String> items) {
  if (items.length <= 1) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')} or ${items.last}';
}

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
