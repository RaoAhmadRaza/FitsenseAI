// lib/logic/auth_bloc/auth_state.dart

import 'package:firebase_auth/firebase_auth.dart';

/// Base class for authentication states.
abstract class AuthState {}

/// Initial state before any action.
class AuthInitial extends AuthState {}

/// In-progress state (show loader).
class AuthLoading extends AuthState {}

/// Signed-in state carrying the authenticated Firebase User.
class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}

/// Signed-out / unauthenticated state.
class AuthUnauthenticated extends AuthState {}

/// Error state carrying a message for UI display.
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
