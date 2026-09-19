import '../models/assistant_answer.dart';
import '../models/qari.dart';
import 'api_client.dart';

abstract class RattilService {
  Future<List<Qari>> getQaris();
  Future<RecitationResult> getRecitation({required String qariId, required int surah, int? ayahStart, int? ayahEnd});

  /// Rattil's assistant, for a message the app's own parser could not read.
  /// [history] is the conversation so far as {role: user|model, text}, oldest
  /// first. Throws [AppException]: 503 when the server has no assistant
  /// configured, 429 when its free-tier limit is reached.
  Future<AssistantAnswer> ask(String message, {List<Map<String, String>> history = const []});
}

/// Real backend-backed implementation. No auth required -- reference audio
/// isn't tied to a signed-in user's own data (see rattil.py's docstring).
class ApiRattilService implements RattilService {
  final ApiClient _client;
  const ApiRattilService([this._client = const ApiClient()]);

  @override
  Future<List<Qari>> getQaris() async {
    final json = await _client.get('/api/v1/rattil/qaris', authRequired: false);
    final qaris = (json['qaris'] as List).cast<Map<String, dynamic>>();
    return qaris.map(Qari.fromJson).toList();
  }

  @override
  Future<RecitationResult> getRecitation({required String qariId, required int surah, int? ayahStart, int? ayahEnd}) async {
    final params = {
      'qari_id': qariId,
      'surah': surah.toString(),
      if (ayahStart != null) 'ayah_start': ayahStart.toString(),
      if (ayahEnd != null) 'ayah_end': ayahEnd.toString(),
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final json = await _client.get('/api/v1/rattil/recitation?$query', authRequired: false);
    return RecitationResult.fromJson(json);
  }

  @override
  Future<AssistantAnswer> ask(String message, {List<Map<String, String>> history = const []}) async {
    // Signed-in: the assistant's tools read the user's own progress.
    final json = await _client.postJson('/api/v1/rattil/chat', {'message': message, 'history': history});
    return AssistantAnswer.fromJson(json);
  }
}
