import '../dummy/dummy_progress.dart';
import '../models/progress_point.dart';

abstract class ProgressService {
  Future<List<ProgressPoint>> getProgressPoints();
  Future<Map<String, double>> getErrorTypeBreakdown();
}

class DummyProgressService implements ProgressService {
  @override
  Future<List<ProgressPoint>> getProgressPoints() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.unmodifiable(dummyProgressPoints);
  }

  @override
  Future<Map<String, double>> getErrorTypeBreakdown() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return Map.unmodifiable(dummyErrorTypeBreakdown);
  }
}
