<div align="center">

# FitSense AI – Intelligent Fitness Companion

Personalized, privacy‑aware fitness onboarding & authentication experience built with Flutter, Firebase Auth, Hive local persistence, and a clean BLoC architecture foundation.

![Platforms](https://img.shields.io/badge/platform-iOS%20|%20Android%20|%20Web%20|%20Desktop-blue) ![State](https://img.shields.io/badge/state-BLoC-green) ![Firebase](https://img.shields.io/badge/backend-Firebase%20Auth-orange)

</div>

## Table of Contents
1. Vision & Scope
2. Feature Overview (Implemented)
3. Architecture Overview
4. Frontend Modules & UI Flow
5. Backend / Services Layer
6. State Management (BLoC) Flow
7. Data & Persistence
8. Theming & Styling
9. Security & Keys
10. Project Structure
11. Local Development & Setup
12. Quality & Extensibility Notes
13. Roadmap / Next Steps
14. License

---

## 1. Vision & Scope
FitSense AI aims to become an adaptive fitness companion: guiding users through onboarding, capturing profile & baseline metrics, and eventually delivering AI‑powered recommendations. Current milestone focuses on a polished multi‑stage authentication & greeting experience with reliable session restoration and groundwork for profile enrichment.

## 2. Feature Overview (Implemented)
Frontend:
- Animated multi‑stage Welcome Flow (Landing → Auth → Greeting) using `entry` package for performant declarative transitions.
- Google Sign‑In & Apple Sign‑In buttons with staged entrance animations.
- Dynamic greeting screen addressing user by first name (falls back to “Friend”).
- Lottie animation integration on greeting screen.
- Responsive layout with adaptive panel heights removed in favor of simplified slide transitions for performance & predictability.
- Global color system + custom font family (`Sora`).
- Profile placeholder route (`/profile`) hooked for future expansion.

Backend / Services:
- Firebase Core initialization (multi‑platform `firebase_options.dart`).
- Firebase Authentication integration (Google, Apple providers).
- Auth session restoration on app start (checks Firebase user + Hive cache coherence).
- Local profile/cache persistence via Hive (`userBox`) storing: uid, email, displayName, photoUrl, lastLogin.
- Google Sign-In via `google_sign_in` (v7.x authenticate flow) with lightweight attempt fallback.
- Apple Sign-In via `sign_in_with_apple` library with scopes for email & fullName.

State Management / Logic:
- BLoC (`AuthBloc`) orchestrating auth lifecycle events: start, sign-in Google, sign-in Apple, sign-out.
- Internal stream subscription (`authStateChanges`) rebroadcasting to Bloc for consistent UI state.
- Distinct states: Initial, Loading, Authenticated, Unauthenticated, Error.
- Global (temporary) user info variables exposed for quick access across presentation layer.

Persistence & Data Model:
- Lightweight local cache intentional: no sensitive secrets; only profile display data + lastLogin timestamp.
- Easy extension path for anthropometric fields (age, weight, height, gender, goals).

Animations & UX Decisions:
- Replaced earlier complex `AnimatedContainer` / expansion logic with pure `Entry.offset` surfaces for simpler mental model.
- Landing content fades & slides; auth panel slides from bottom; full greeting view slides upward.
- Avoided over‑animation for accessibility & startup performance.

Resilience / Edge Handling:
- Logout elsewhere detection: if Bloc reports unauthenticated while in greeting stage, UI reverts to landing.
- Cancellation of Google/Apple sign-in returns to unauthenticated state gracefully.
- Defensive try/catch around Hive + Firebase restore to prevent crashes on corrupt cache.

## 3. Architecture Overview
Layered approach:
```
Presentation (Widgets / Screens)
	-> State (BLoC: AuthBloc)
		-> Repository (AuthRepository abstraction over FirebaseAuth + provider SDKs)
			-> External Services (Firebase, Google Sign-In, Apple Sign-In)
Persistence (Hive box for user profile cache)
```
Guiding principles: separation of concerns, testable repository layer, reactive UI bound to auth state.

## 4. Frontend Modules & UI Flow
### Screens
- `WelcomeScreen` (core staged experience)
	- Landing Stage: marketing headline + CTA
	- Auth Stage: animated sign-in buttons & tagline
	- Greeting Stage: personalized salutation + Lottie animation + profile link
- `ProfilePage` (stub) placeholder for extended onboarding.
- `MyHomePage` (from starter template) reserved for dashboard/evolution.

### Notable UI Components & Concepts
- Custom color constants in `features/presentation/widgets/colors.dart`.
- Font assets (`assets/fonts/Sora-*.ttf`) registered in `pubspec.yaml`.
- Gradient / Shader masked brand text (landing & greeting highlights).

### Navigation
`MaterialApp` routes: `/` → Welcome, `/home`, `/profile` (extensible; consider migrating to `go_router` later for deep links).

## 5. Backend / Services Layer
Currently focused purely on Authentication + local caching.
- Firebase Auth initialized with `DefaultFirebaseOptions.currentPlatform`.
- Google Sign-In: uses new `authenticate()` API (v7) plus fallback for lightweight attempt.
- Apple Sign-In: obtains Apple credential, converts to OAuthProvider('apple.com') credential, signs into Firebase.
- No Firestore/Realtime DB/Storage yet (intentionally deferred).

## 6. State Management (Auth Flow)
Events trigger repository calls; results transition states consumed by `WelcomeScreen`:
```
AuthStarted -> (Firebase has user?) -> AuthAuthenticated | AuthUnauthenticated
AuthSignInWithGoogleRequested -> Loading -> AuthAuthenticated | AuthUnauthenticated | AuthError
AuthSignInWithAppleRequested  -> Loading -> AuthAuthenticated | AuthUnauthenticated | AuthError
AuthSignOutRequested          -> Loading -> AuthUnauthenticated | AuthError
```
Internal events mirror `authStateChanges` to keep UI authoritative.

## 7. Data & Persistence
- Hive box: `userBox`
	- Keys: uid, email, displayName, photoUrl, lastLogin
- Global in‑memory mirrors for quick synchronous access (can migrate to a ProfileCubit later).
- Planned future: structured model (e.g., `UserProfile`) + watchers.

## 8. Theming & Styling
- `ColorScheme.fromSeed` for base scheme then overridden keys.
- Light background with accent reds/blues/greens for brand identity.
- Consistent `Sora` typography with limited fontWeight variants for performance.

## 9. Security & Keys
Firebase client API keys are present in `firebase_options.dart` and platform configs (expected for Firebase client apps). They should be usage‑restricted in Google Cloud console by bundle ID / SHA / domain. No server secrets committed. No custom REST tokens stored client‑side.

## 10. Project Structure (simplified)
```
lib/
	main.dart                # App bootstrap, DI wiring
	app.dart                 # (Starter generated home scaffold)
	firebase_options.dart    # Auto-generated Firebase config
	features/
		auth/
			presentation/pages/
				welcome.dart       # Multi-stage auth & greeting UI
				profile.dart       # Placeholder for extended profile
			data/repositories/
				auth_repository.dart
	logic/
		auth_bloc/             # AuthBloc, events, states
	assets/ (fonts, images in project root assets/)
```

## 11. Local Development & Setup
Prerequisites:
- Flutter (3.x+)
- Dart SDK (bundled)
- Firebase project configured (already included options file)

Install deps & run:
```
flutter pub get
flutter run
```
If Apple Sign-In on iOS/macOS: enable the capability in Xcode & ensure correct bundle ID.

### Regenerating Firebase Options
```
flutterfire configure
```

### Hive Box Notes
Box auto-opens in `main.dart`; if adding more boxes, open before `runApp()`.

## 12. Quality & Extensibility Notes
Potential enhancements:
- Add unit tests for AuthRepository with mock FirebaseAuth.
- Introduce a dedicated ProfileCubit and model.
- Migrate routing to declarative approach (go_router / beamer) for deep linking.
- Add analytics & crash reporting (Firebase Analytics / Crashlytics) with user consent.
- Accessibility pass: reduce motion toggle & high contrast palette variant.

## 13. Roadmap / Next Steps
- Profile completion flow (age, height, weight, goals collection UI)
- AI workout recommendation engine integration (likely via serverless endpoints)
- Firestore persistence for extended profile & progress metrics
- Workout session tracking & timeline UI
- Secure preferences (biometric quick re-auth)
- Offline mode & sync strategy

## 14. License
Proprietary (adjust if you plan to open-source). Add a LICENSE file when finalized.

---

> Maintained as part of the FitSense AI initiative. Contributions & discussions welcome—open an issue to propose architectural changes.

