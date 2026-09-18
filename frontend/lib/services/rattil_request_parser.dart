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

  /// What the message asks for. Either part can be missing.
  RattilRequest parse(String text) {
    final tokens = _latinTokens(text);
    final qariMatch = _matchQari(text, tokens);
    final usedByQari = qariMatch?.tokenIndices ?? const <int>{};
    final surah = _matchSurah(text, tokens, usedByQari);

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
    return RattilRequest(surah: surah, qari: qariMatch?.qari, unknownReciter: unknownReciter);
  }

  /// Turns a parsed request into what Rattil should do: play something, or say
  /// why it can't. Never silently swaps the reciter someone asked for.
  RattilReply decide(RattilRequest request) {
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

    final requested = request.qari;
    if (requested != null) {
      if (requested.availableSurahs.contains(surah.number)) {
        return RattilReply.play(requested, surah);
      }
      final others = qaris.where((q) => q.availableSurahs.contains(surah.number)).toList();
      final alternative = others.isEmpty
          ? ''
          : ' ${others.first.nameEnglish} does -- try "${surah.nameEnglish} by '
              '${shortName(others.first)}".';
      return RattilReply.say(
          "${requested.nameEnglish} doesn't have ${surah.nameEnglish} here yet.$alternative");
    }

    // No reciter named: the first one who actually has it, rather than the
    // first in the list and an error.
    for (final q in qaris) {
      if (q.availableSurahs.contains(surah.number)) return RattilReply.play(q, surah);
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
    final partial = qaris.where((q) => q.availableSurahs.length < surahs.length).toList();
    if (partial.isNotEmpty) {
      final q = partial.first;
      final last = ([...q.availableSurahs]..sort()).last;
      final name = _surahName(last);
      if (name != null) examples.add('"$name by ${shortName(q)}"');
    }

    final tryLine = examples.isEmpty ? '' : '\nTry ${examples.join(' or ')}.';
    return 'Ask for a surah, and a reciter if you like.\n${lines.join('\n')}$tryLine';
  }

  /// The name people actually use for a reciter: the family name, without its
  /// article -- "Sudais", "Alafasy", "Dosari".
  static String shortName(Qari q) {
    final last = q.nameEnglish.split(RegExp(r'\s+')).last;
    final bare = last.replaceFirst(RegExp(r'^(al|as|ad|ar|an|ash)-', caseSensitive: false), '');
    return bare.isEmpty ? last : bare;
  }

  // ── surah matching ──────────────────────────────────────────────────────

  Surah? _matchSurah(String text, List<String> tokens, Set<int> excluded) {
    final folded = _fold(text);

    // 1. "surah 18", "sura no. 2", "chapter 55" -- an explicit number wins.
    final explicit = RegExp(r'\b(?:surah|sura|surat|chapter)\s*(?:no\.?|number|#)?\s*(\d{1,3})\b')
        .firstMatch(folded);
    final explicitSurah = _byNumber(int.tryParse(explicit?.group(1) ?? ''));
    if (explicitSurah != null) return explicitSurah;

    // 2. The surah's name, in Arabic script.
    final arabic = _arabicWords(text);
    if (arabic.isNotEmpty) {
      final joined = ' ${arabic.join(' ')} ';
      for (final k in _surahKeys) {
        for (final a in k.arabic) {
          if (joined.contains(' $a ')) return k.surah;
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
    if (best != null) return best.surah;

    // 4. Its meaning -- "the Cow", "the Opening".
    final padded = ' $folded ';
    for (final k in _surahKeys) {
      if (k.meaning.length >= 3 && padded.contains(' ${k.meaning} ')) return k.surah;
    }

    // 5. A bare number, if it is a surah number.
    for (final m in RegExp(r'\b(\d{1,3})\b').allMatches(folded)) {
      final s = _byNumber(int.tryParse(m.group(1)!));
      if (s != null) return s;
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

  /// A name that followed "by"/"from" and matched no reciter -- worth saying
  /// so, instead of playing someone else as if it had been understood.
  final String? unknownReciter;

  const RattilRequest({this.surah, this.qari, this.unknownReciter});
}

/// What Rattil should do with a request: play, or explain.
class RattilReply {
  final Qari? qari;
  final Surah? surah;
  final String? message;

  const RattilReply.play(Qari this.qari, Surah this.surah) : message = null;
  const RattilReply.say(String this.message)
      : qari = null,
        surah = null;

  bool get plays => qari != null && surah != null;
}

// ── internals ─────────────────────────────────────────────────────────────

class _QariMatch {
  final Qari qari;
  final Set<int> tokenIndices;
  _QariMatch(this.qari, this.tokenIndices);
}

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
  'chalao', 'lagao', 'krdo', 'kardo', 'karo', 'do',
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

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
