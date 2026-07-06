import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/service_locator.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  const AuthState._(this.status, this.user);

  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.authenticated(User user) : this._(AuthStatus.authenticated, user);
  const AuthState.unauthenticated() : this._(AuthStatus.unauthenticated, null);
}

/// Mirrors Firebase's auth state as app-wide Bloc state — go_router's
/// redirect logic reads [Services.auth.currentUser] directly (synchronous),
/// but screens that need to rebuild on sign-in/sign-out (e.g. the app shell)
/// watch this cubit instead.
class AuthCubit extends Cubit<AuthState> {
  late final StreamSubscription<User?> _subscription;

  AuthCubit() : super(const AuthState.unknown()) {
    _subscription = Services.auth.authStateChanges.listen((user) {
      emit(user != null ? AuthState.authenticated(user) : const AuthState.unauthenticated());
    });
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
