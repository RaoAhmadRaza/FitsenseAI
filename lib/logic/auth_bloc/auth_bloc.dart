// lib/logic/auth_bloc/auth_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/db/app_database.dart';
import '../../core/utils/logger.dart';

import '../../features/auth/data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// AuthBloc coordinates UI events and repository actions.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  // Listen to Firebase authStateChanges to keep the Bloc state in sync.

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(AuthInitial()) {
    // Map events to handlers
    on<AuthStarted>((event, emit) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    });
    on<AuthSignInWithGoogleRequested>(_onSignInWithGoogle);
    on<AuthSignInWithAppleRequested>(_onSignInWithApple);
    on<AuthSignOutRequested>(_onSignOut);

    // Subscribe to the repository's auth state stream so Bloc reflects external changes.
    _authRepository.authStateChanges.listen((user) {
      // If a user exists -> authenticated state; else unauthenticated.
      if (user != null) {
        add(_AuthInternalUserChanged(user)); // internal event to update state
      } else {
        add(_AuthInternalUserSignedOut());
      }
    });

    // Register handlers for internal events (not exposed to UI)
    on<_AuthInternalUserChanged>((event, emit) {
      emit(AuthAuthenticated(event.user));
    });

    on<_AuthInternalUserSignedOut>((event, emit) {
      emit(AuthUnauthenticated());
    });
  }

  // -----------------------
  // Event handlers
  // -----------------------

  Future<void> _onSignInWithGoogle(
    AuthSignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signInWithGoogle();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        // user canceled the Google sign-in flow (returned null)
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithApple(
    AuthSignInWithAppleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signInWithApple();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signOut();
      try {
        // Clear persisted profile (SQLite + Hive cache)
        await AppDatabase.clearUserProfile(resetGlobals: true);
        if (Hive.isBoxOpen('userBox')) {
          await Hive.box('userBox').clear();
        }
        logInfo('Profile data cleared on sign-out');
      } catch (e, st) {
        logError('Failed clearing persisted profile on sign-out: $e', st);
      }
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}

// -----------------------
// Internal-only events
// -----------------------
// These are used to convert authStateChanges stream updates into Bloc states.
// They are private to this file (underscore-prefixed).

class _AuthInternalUserChanged extends AuthEvent {
  final User user;
  _AuthInternalUserChanged(this.user);
}

class _AuthInternalUserSignedOut extends AuthEvent {}
