import '../dummy/dummy_tajweed_rules.dart';
import '../models/tajweed_rule.dart';

abstract class TajweedRuleService {
  Future<List<TajweedRule>> getRules();
  Future<TajweedRule> getRuleById(String id);
  Future<TajweedRule> toggleBookmark(String id);
}

class DummyTajweedRuleService implements TajweedRuleService {
  final List<TajweedRule> _rules = List.of(dummyTajweedRules);

  @override
  Future<List<TajweedRule>> getRules() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.unmodifiable(_rules);
  }

  @override
  Future<TajweedRule> getRuleById(String id) async {
    await Future.delayed(const Duration(milliseconds: 350));
    return _rules.firstWhere((r) => r.id == id, orElse: () => _rules.first);
  }

  @override
  Future<TajweedRule> toggleBookmark(String id) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _rules.indexWhere((r) => r.id == id);
    if (index == -1) return _rules.first;
    final current = _rules[index];
    final updated = TajweedRule(
      id: current.id,
      title: current.title,
      arabicExample: current.arabicExample,
      shortDescription: current.shortDescription,
      fullExplanation: current.fullExplanation,
      category: current.category,
      isBookmarked: !current.isBookmarked,
    );
    _rules[index] = updated;
    return updated;
  }
}
