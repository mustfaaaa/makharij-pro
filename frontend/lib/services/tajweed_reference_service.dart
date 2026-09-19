import '../core/errors/app_exception.dart';
import '../models/tajweed_word_info.dart';
import 'api_client.dart';

/// Reads the per-word Tajweed reference: which Makhraj a word starts from and
/// which rules apply to it.
///
/// Unauthenticated on purpose, matching the backend: which articulation point
/// a word begins from is a fact about the Quran, not about the signed-in user.
/// That also means this keeps working on the reading page before anyone has
/// recited anything.
abstract class TajweedReferenceService {
  /// One word, addressed the way the app itself indexes words: 0-based within
  /// the ayah and counting the Basmala the reading page prepends. The backend
  /// converts to the table's own indexing.
  ///
  /// Returns null when there is nothing to show — a Basmala word, or a server
  /// without the reference table installed. Null rather than throwing because
  /// every caller is decorative: a missing lookup should quietly show less,
  /// never interrupt what the user was doing.
  Future<TajweedWordInfo?> word({
    required int surah,
    required int ayah,
    required int displayWordIndex,
  });

  /// Every word of an ayah, for callers that would otherwise fire one request
  /// per word.
  Future<List<TajweedWordInfo>> ayah({required int surah, required int ayah});

  /// Real Quranic words carrying a rule, for the Tajweed rules screen.
  Future<List<TajweedWordInfo>> examples(String rule, {int limit = 20});

  /// Every word of an ayah keyed by the app's own display index (0-based,
  /// Basmala counted), for the reading page's transliteration line and rule
  /// highlighting. Empty when there is no reference to show.
  Future<Map<int, TajweedWordInfo>> ayahByDisplayIndex({required int surah, required int ayah});
}

class ApiTajweedReferenceService implements TajweedReferenceService {
  final ApiClient _client;

  /// Word lookups are pure and the underlying table never changes, so a
  /// result is worth keeping for the session. The results screen can ask for
  /// the same word repeatedly as a sheet is opened and closed.
  final Map<String, TajweedWordInfo?> _cache = {};

  // Not const: the session cache below is mutable state.
  ApiTajweedReferenceService({this._client = const ApiClient()});

  @override
  Future<TajweedWordInfo?> word({
    required int surah,
    required int ayah,
    required int displayWordIndex,
  }) async {
    final key = '$surah:$ayah:$displayWordIndex';
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final json = await _client.get(
        '/api/v1/tajweed/word/$surah/$ayah/$displayWordIndex?index_base=display',
        authRequired: false,
      );
      final info = TajweedWordInfo.fromJson(json);
      _cache[key] = info;
      return info;
    } on AppException {
      // 404 for a Basmala word, 503 on a server without the table. Both mean
      // "nothing to show here", which is not a failure worth surfacing.
      _cache[key] = null;
      return null;
    }
  }

  @override
  Future<List<TajweedWordInfo>> ayah({required int surah, required int ayah}) async {
    try {
      final json = await _client.get(
        '/api/v1/tajweed/ayah/$surah/$ayah',
        authRequired: false,
      );
      return ((json['words'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(TajweedWordInfo.fromJson)
          .toList();
    } on AppException {
      return const [];
    }
  }

  final Map<String, Map<int, TajweedWordInfo>> _ayahCache = {};

  @override
  Future<Map<int, TajweedWordInfo>> ayahByDisplayIndex({required int surah, required int ayah}) async {
    final key = '$surah:$ayah';
    final cached = _ayahCache[key];
    if (cached != null) return cached;
    try {
      final json = await _client.get('/api/v1/tajweed/ayah/$surah/$ayah', authRequired: false);
      // The table indexes words from 1 and leaves out the Basmala the app
      // prepends to ayah 1; the response says how many words that prefix is.
      final prefix = json['basmala_prefix_len'] as int? ?? 0;
      final words = ((json['words'] as List?) ?? const []).cast<Map<String, dynamic>>().map(TajweedWordInfo.fromJson);
      final map = {for (final w in words) w.wordIndex - 1 + prefix: w};
      _ayahCache[key] = map;
      return map;
    } on AppException {
      return const {};
    }
  }

  @override
  Future<List<TajweedWordInfo>> examples(String rule, {int limit = 20}) async {
    try {
      final json = await _client.get(
        '/api/v1/tajweed/examples/$rule?limit=$limit',
        authRequired: false,
      );
      return ((json['words'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(TajweedWordInfo.fromJson)
          .toList();
    } on AppException {
      return const [];
    }
  }
}
