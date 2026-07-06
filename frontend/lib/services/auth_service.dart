import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

abstract class AuthService {
  Stream<User?> get authStateChanges;
  User? get currentUser;

  Future<void> signInWithEmail({required String email, required String password});
  Future<void> registerWithEmail({required String name, required String email, required String password});

  /// Android/desktop: opens the account picker directly. Not supported on
  /// web — see [initializeGoogleSignIn]/[googleWebSignInCompleted].
  Future<void> signInWithGoogle();

  /// Must resolve before rendering the web-only Google button.
  Future<void> initializeGoogleSignIn();

  /// Emits (or errors) each time the web-rendered Google button completes a
  /// sign-in — already exchanged for a Firebase session by the time it fires.
  Stream<void> get googleWebSignInCompleted;

  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();

  /// Maps a thrown auth error to a user-facing message. Returns an empty
  /// string for a user-initiated cancellation (caller should show nothing).
  String errorMessageFor(Object error);
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  // The project's auto-created "Web client" OAuth id (client_type: 3 in
  // google-services.json) — required by google_sign_in on web, where there's
  // no google-services.json for it to read the id from automatically.
  static const _webClientId = '639830542253-76krmb3ql1numt1fsbfae2qi5drkuol0.apps.googleusercontent.com';

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<void> get googleWebSignInCompleted {
    return _googleSignIn.authenticationEvents
        .where((event) => event is GoogleSignInAuthenticationEventSignIn)
        .asyncMap((event) => _completeGoogleSignIn((event as GoogleSignInAuthenticationEventSignIn).user));
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(clientId: kIsWeb ? _webClientId : null);
    _googleInitialized = true;
  }

  @override
  Future<void> initializeGoogleSignIn() => _ensureGoogleInitialized();

  @override
  Future<void> signInWithEmail({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  @override
  Future<void> registerWithEmail({required String name, required String email, required String password}) async {
    final trimmedName = name.trim();
    final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = credential.user!;
    await user.updateDisplayName(trimmedName);
    await _createUserDocumentIfAbsent(uid: user.uid, name: trimmedName, email: user.email ?? email.trim());
  }

  @override
  Future<void> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw StateError(
        'Google sign-in needs the rendered Google button on this platform (web) — '
        'use initializeGoogleSignIn()/googleAuthEvents/completeGoogleSignIn instead.',
      );
    }
    final account = await _googleSignIn.authenticate();
    await _completeGoogleSignIn(account);
  }

  Future<void> _completeGoogleSignIn(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in did not return an ID token.');
    }
    final userCredential = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    final user = userCredential.user;
    if (user != null) {
      await _createUserDocumentIfAbsent(
        uid: user.uid,
        name: user.displayName ?? account.displayName ?? 'Learner',
        email: user.email ?? account.email,
      );
    }
  }

  /// Only writes on first sign-in, so a later name edit is never clobbered
  /// by a repeat Google/email sign-in re-running this method.
  Future<void> _createUserDocumentIfAbsent({required String uid, required String name, required String email}) async {
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);
    final snapshot = await doc.get();
    if (snapshot.exists) return;
    await doc.set({'name': name, 'email': email, 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized) {
      await _googleSignIn.signOut();
    }
  }

  @override
  String errorMessageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'invalid-credential':
          return 'No account found with that email and password.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'email-already-in-use':
          return 'An account already exists with that email.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) return '';
      return 'Google sign-in failed: ${error.description ?? error.code}';
    }
    return 'Something went wrong. Please try again.';
  }
}
