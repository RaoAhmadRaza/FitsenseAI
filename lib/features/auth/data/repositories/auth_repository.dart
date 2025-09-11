// lib/data/repositories/auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart'; // Firebase user types & auth APIs
import 'package:google_sign_in/google_sign_in.dart'
    as gsi; // Google sign-in helper (v7.x)
import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // Apple sign-in helper

/// AuthRepository handles authentication concerns:
/// - Sign in with Google
/// - Sign in with Apple
/// - Sign out
/// - Exposes authStateChanges stream for listening to logged-in user changes
class AuthRepository {
  // 1) Allow dependency injection to make testing easier:
  final FirebaseAuth _firebaseAuth;
  final gsi.GoogleSignIn _googleSignIn;

  // Constructor with optional injected instances (useful for tests/mocks)
  AuthRepository({FirebaseAuth? firebaseAuth, gsi.GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? gsi.GoogleSignIn.instance;

  // 2) Public auth state stream: UI or Bloc can listen to this to react to sign in/out.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // -------------------------
  // Google sign-in
  // -------------------------
  /// Signs in the user using the Google Sign-In flow and links that credential
  /// to Firebase Auth. Returns the [User] on success, or throws on failure.
  Future<User?> signInWithGoogle() async {
    // 1. Trigger the Google authentication flow (v7.x API)
    gsi.GoogleSignInAccount? googleUser;
    if (_googleSignIn.supportsAuthenticate()) {
      final lightweight = _googleSignIn.attemptLightweightAuthentication();
      if (lightweight != null) {
        googleUser = await lightweight;
      }
      googleUser ??= await _googleSignIn.authenticate();
    } else {
      throw UnsupportedError(
        'GoogleSignIn.authenticate() not supported on this platform. Use the platform-specific sign-in button.',
      );
    }

    // If the flow fails, an exception will be thrown; otherwise googleUser is non-null here.

    // 2. Obtain the auth details from the request
    final gsi.GoogleSignInAuthentication googleAuth = googleUser.authentication;

    // 3. Create a new credential for Firebase Auth
    final OAuthCredential credential = GoogleAuthProvider.credential(
      // google_sign_in 7.x exposes idToken only
      idToken: googleAuth.idToken,
    );

    // 4. Sign in to Firebase with the Google credential
    final UserCredential userCredential = await _firebaseAuth
        .signInWithCredential(credential);

    // 5. Return the Firebase user (can be null, but usually present)
    return userCredential.user;
  }

  // -------------------------
  // Apple sign-in
  // -------------------------
  /// Signs in the user using "Sign in with Apple" and Firebase Auth.
  /// On iOS, the sign-in flow is native. On Android/web it may open a browser flow.
  Future<User?> signInWithApple() async {
    // 1. Request the Apple ID credential. We ask for email & fullName scopes.
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    // 2. Build an OAuth credential compatible with Firebase Auth.
    // Note: For Apple, use 'apple.com' as the provider id.
    final oAuthProvider = OAuthProvider('apple.com');

    final credential = oAuthProvider.credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    // 3. Sign in to Firebase using the generated credential
    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    // 4. Return the authenticated user
    return userCredential.user;
  }

  // -------------------------
  // Sign out
  // -------------------------
  /// Signs out from Firebase and tries to disconnect Google sign-in as well.
  Future<void> signOut() async {
    try {
      // 1. Sign out of Firebase
      await _firebaseAuth.signOut();

      // 2. Sign out & disconnect Google session (best-effort)
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (e) {
      // Re-throw so caller (Bloc) can surface a message if needed.
      rethrow;
    }
  }
}
