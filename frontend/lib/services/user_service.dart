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
}

/// Name and email are real, read from Firebase Auth / Firestore. Every other
/// field (streak, accuracy, sessions, target surahs, hasanah) is layered in
/// from [dummyUser] until the real recitation/AI pipeline exists.
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
}
