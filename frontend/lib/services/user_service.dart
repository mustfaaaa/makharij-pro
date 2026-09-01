import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../dummy/dummy_user.dart';
import '../models/user_profile.dart';

abstract class UserService {
  Future<UserProfile> getCurrentUser();

  /// Live updates as the Firestore profile document changes — used by the
  /// Profile screen so an edited name reflects immediately everywhere.
  Stream<UserProfile> watchCurrentUser();

  Future<void> updateName(String name);
  Future<void> updateTargetSurahs(List<String> surahs);

  /// Real, persisted running total -- ten hasanah per Arabic letter recited
  /// (Tirmidhi 2910), accumulated across every real session rather than
  /// reset to a placeholder seed on every app launch.
  Future<int> getHasanahTotal();
  Future<void> addHasanahTotal(int amount);
}

/// Name, email, and joinedAt are real, read from Firebase Auth / Firestore
/// (createdAt is written once at signup — see auth_service.dart). targetSurahs
/// is real too, stored per-user in the same document. Streak/accuracy/sessions
/// live in ProgressService instead (backed by real session history), not here
/// — [dummyUser] is used only as a display fallback before the profile doc
/// has loaded, never as a source of truth.
class FirebaseUserService implements UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return _firestore.collection('users').doc(uid);
  }

  UserProfile _merge(Map<String, dynamic>? data) {
    final authUser = _auth.currentUser;
    final createdAt = data?['createdAt'];
    return dummyUser.copyWith(
      name: (data?['name'] as String?) ?? authUser?.displayName ?? dummyUser.name,
      email: (data?['email'] as String?) ?? authUser?.email ?? dummyUser.email,
      joinedAt: createdAt is Timestamp ? createdAt.toDate() : dummyUser.joinedAt,
      targetSurahs: (data?['targetSurahs'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  Future<UserProfile> getCurrentUser() async {
    final snapshot = await _doc.get();
    return _merge(snapshot.data());
  }

  @override
  Stream<UserProfile> watchCurrentUser() {
    return _doc.snapshots().map((snapshot) => _merge(snapshot.data()));
  }

  @override
  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    await _doc.set({'name': trimmed}, SetOptions(merge: true));
    await _auth.currentUser?.updateDisplayName(trimmed);
  }

  @override
  Future<void> updateTargetSurahs(List<String> surahs) async {
    await _doc.set({'targetSurahs': surahs}, SetOptions(merge: true));
  }

  @override
  Future<int> getHasanahTotal() async {
    final snapshot = await _doc.get();
    return (snapshot.data()?['hasanahTotal'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> addHasanahTotal(int amount) async {
    await _doc.set({'hasanahTotal': FieldValue.increment(amount)}, SetOptions(merge: true));
  }
}
