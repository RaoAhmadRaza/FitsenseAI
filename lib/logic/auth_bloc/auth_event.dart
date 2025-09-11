import 'package:firebase_auth/firebase_auth.dart' show User;

/// Base class for all auth events.
abstract class AuthEvent {
  const AuthEvent();
}

/// Triggered on app start to sync initial auth state.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Triggered when the FirebaseAuth auth state changes.
class AuthUserChanged extends AuthEvent {
  final User? user;
  const AuthUserChanged(this.user);
}

/// Triggered by UI to start Google sign-in.
class AuthSignInWithGoogleRequested extends AuthEvent {
  const AuthSignInWithGoogleRequested();
}

/// Triggered by UI to start Apple sign-in.
class AuthSignInWithAppleRequested extends AuthEvent {
  const AuthSignInWithAppleRequested();
}

/// Triggered by UI to sign out.
class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
