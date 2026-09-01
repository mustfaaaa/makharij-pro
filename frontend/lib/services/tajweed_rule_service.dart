import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/tajweed_rules.dart';
import '../models/tajweed_rule.dart';

abstract class TajweedRuleService {
  Future<List<TajweedRule>> getRules();
  Future<TajweedRule> getRuleById(String id);
  Future<TajweedRule> toggleBookmark(String id);
}

/// Rule content is real, static reference material bundled locally (see
/// data/tajweed_rules.dart). Bookmarks are real per-user state, persisted to
/// the same Firestore user document used for targetSurahs.
class LocalTajweedRuleService implements TajweedRuleService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return _firestore.collection('users').doc(uid);
  }

  Future<List<String>> _bookmarkedIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];
    final snapshot = await _doc.get();
    return (snapshot.data()?['bookmarkedRuleIds'] as List?)?.cast<String>() ?? const [];
  }

  Future<List<TajweedRule>> _rulesWithRealBookmarks() async {
    final bookmarked = await _bookmarkedIds();
    return tajweedRules.map((r) => r.copyWith(isBookmarked: bookmarked.contains(r.id))).toList();
  }

  @override
  Future<List<TajweedRule>> getRules() => _rulesWithRealBookmarks();

  @override
  Future<TajweedRule> getRuleById(String id) async {
    final rules = await _rulesWithRealBookmarks();
    return rules.firstWhere((r) => r.id == id, orElse: () => rules.first);
  }

  @override
  Future<TajweedRule> toggleBookmark(String id) async {
    final rules = await _rulesWithRealBookmarks();
    final current = rules.firstWhere((r) => r.id == id, orElse: () => rules.first);
    final nowBookmarked = !current.isBookmarked;
    await _doc.set({
      'bookmarkedRuleIds': nowBookmarked ? FieldValue.arrayUnion([id]) : FieldValue.arrayRemove([id]),
    }, SetOptions(merge: true));
    return current.copyWith(isBookmarked: nowBookmarked);
  }
}
