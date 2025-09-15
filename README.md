<div align="center">

# FitSense AI – Intelligent Fitness Companion  

Personalized, privacy-aware fitness onboarding & authentication experience built with Flutter, Firebase Auth, Hive local persistence, and a clean BLoC architecture foundation.  

![Platforms](https://img.shields.io/badge/platform-iOS%20|%20Android%20|%20Web%20|%20Desktop-blue) 
![State](https://img.shields.io/badge/state-BLoC-green) 
![Firebase](https://img.shields.io/badge/backend-Firebase%20Auth-orange)  

</div>

---

## Table of Contents
1. Vision & Scope  
2. Features (Implemented)  
3. Architecture Overview  
4. Data & Persistence  
5. Project Structure  
6. Local Development & Setup  
7. Quality & Next Steps  
8. License  

---

## 1. Vision & Scope
Provide a frictionless, privacy-aware fitness entry point.  
Current scope: robust authentication lifecycle, session restoration, and persistence foundations.  
Next steps: workout logging, rep counting, adaptive recommendations, and AI-driven coaching.

---

## 2. Features (Implemented)

### UI / Experience
- Multi-stage welcome flow (Landing → Auth → Greeting) with entry animations.  
- Google & Apple sign-in (staggered button reveal).  
- Personalized greeting (first-name fallback to “Friend”).  
- Lottie animation on greeting screen.  
- Sensor demo screen (`/sensors`) streaming accelerometer + gyroscope.  

### Architecture & Logic
- BLoC (`AuthBloc`) orchestrates auth lifecycle.  
- Firebase `authStateChanges` mirrored as bloc events.  
- Hive for fast warm start; SQLite for extended profile/workout groundwork.  
- Fail-soft approach: persistence/cache errors never block UI.  

---

## 3. Architecture Overview

```text
Presentation (Widgets)
  -> State (BLoC: AuthBloc)
    -> Repository (AuthRepository over FirebaseAuth + providers)
      -> External Services (Firebase, Google Sign-In, Apple Sign-In)

Persistence:
  Hive (session cache)
  SQLite (profile/workouts groundwork)
Principles: minimal now, extensible later, resilience by design.

4. Data & Persistence
Hive (Session Cache)
Stores: uid, email, displayName, photoUrl, lastLogin.

SQLite (Structured)
user_profile → singleton row for extended fields.

workouts → reserved for logging & analytics.

Lifecycle
Sign-in → write to Hive + upsert profile row.

App start → hydrate from Hive + SQLite.

Sign-out → clear Hive + delete profile row.

5. Project Structure
text
Copy code
lib/
  main.dart
  app.dart
  firebase_options.dart
  features/
    auth/presentation/pages/welcome.dart
    auth/presentation/pages/profile.dart (placeholder)
    auth/data/repositories/auth_repository.dart
    debug/sensor_demo_page.dart
  logic/auth_bloc/
  core/db/app_database.dart
  core/utils/logger.dart
assets/
  fonts/ (Sora)
  images/
6. Local Development & Setup
Prerequisites
Flutter 3.x+

Configured Firebase project (firebase_options.dart present)

Run
bash
Copy code
flutter pub get
flutter run
Regenerate Firebase Options
bash
Copy code
flutterfire configure
Notes
Open Hive boxes before runApp() for deterministic warm start.

Enable Apple Sign-In capability in Xcode for iOS.

7. Quality & Next Steps
Replace global user vars with typed Profile model + cubit.

Workout logging + rep counting (signal processing → ML).

Introduce go_router (deep linking, guarded routes, web URL sync).

Dark mode + accessibility options.

Analytics & crash reporting (consent + opt-in).

CI pipeline: format, analyze, test, coverage.

8. License
Proprietary (adjust if open-sourcing).
Add a LICENSE file when finalized.

Maintained as part of the FitSense AI initiative.

---
<details>
<summary><strong>Full Alternate / Original Expanded Version (Preserved as requested)</strong></summary>

# FitSense AI – Intelligent Fitness Companion

Personalized, privacy‑aware fitness onboarding & authentication experience built with Flutter, Firebase Auth, Hive (fast session cache), and SQLite (structured profile/workout storage). A lean BLoC architecture powers a staged welcome → auth → greeting flow and lays groundwork for motion‑driven fitness intelligence.

![Platforms](https://img.shields.io/badge/platform-iOS%20|%20Android%20|%20Web%20|%20Desktop-blue) ![State](https://img.shields.io/badge/state-BLoC-green) ![Firebase](https://img.shields.io/badge/backend-Firebase%20Auth-orange)

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

Deliver an adaptive fitness companion: frictionless authentication, baseline profile capture, and future AI‑guided workout & motion insight features. Current milestone: polished multi‑stage entry (landing → auth → greeting), reliable session restoration, and sensor + persistence foundations for rep counting and analytics.

## 2. Feature Overview (Implemented)

### Frontend

- Multi‑stage Welcome Flow (Landing → Auth → Greeting) with lightweight `entry` animations.
- Google & Apple Sign‑In with staggered introduction.
- Personalized greeting (first‑name; fallback “Friend”).
- Lottie animation in greeting stage.
- Simplified slide/opacity transitions (removed height expansion animation).
- Global color + typography system (`Sora`).
- Sensor demo page (`/sensors`) streaming accelerometer & gyroscope.
- Navigation from greeting to sensor demo.
- Profile placeholder route (`/profile`).

### Recent Frontend Refactors

- Replaced `AnimatedContainer` expansion with stateless stage enum + `Entry.offset`.
- Sequenced greeting scale + opacity for a softer entrance.
- Added structured logging (persistence + sensor events).

### Backend / Services

- Firebase init (`firebase_options.dart`).
- Firebase Authentication (Google & Apple) + session restore.
- Hive cache (`userBox`): uid, email, displayName, photoUrl, lastLogin.
- SQLite (`AppDatabase`): `user_profile` (singleton) & `workouts` (future).
- Startup hydration + sign‑out cleanup (Hive + SQLite + globals).
- Fail‑soft DB operations (exceptions logged; UI uninterrupted).

### State Management / Logic

- `AuthBloc` handles start, sign‑ins, sign‑out.
- Firebase `authStateChanges` mirrored into bloc events.
- States: Initial, Loading, Authenticated, Unauthenticated, Error.
- Interim global user variables (to be replaced by typed Profile layer).

### Data Model & Persistence

- Non‑sensitive display fields + timestamps cached.
- Extended profile scaffold: age, weight_kg, height_cm, gender, goals (CSV), primary_goal, updated_at.
- `workouts` table reserved for future session logging + analytics.

### Animations & UX

- Entry offset / scale / opacity only (deterministic & performant).
- Planned reduce‑motion + dark theme options.

### Resilience / Edge Handling

- Remote logout returns to landing stage.
- Provider cancel gracefully reverts to unauthenticated.
- Corrupt Hive entries trapped (try/catch) – fall back to fresh auth.
- SQLite absence tolerated (auth still functions).

## 3. Architecture Overview

```text
Presentation (Widgets)
  -> State (BLoC: AuthBloc)
    -> Repository (AuthRepository over FirebaseAuth + providers)
      -> External Services (Firebase, Google Sign-In, Apple Sign-In)
Persistence: Hive (fast session cache) + SQLite (structured profile/workouts)
```

Principles: clear layering, predictable state, fail‑soft persistence, incremental evolution.

## 4. Frontend Modules & UI Flow

### Screens

- WelcomeScreen (Landing → Auth → Greeting)
- ProfilePage (placeholder)
- SensorDemoPage (live motion visualization)
- MyHomePage (future dashboard)

### Concepts

- Stage enum drives conditional rendering & entry transitions.
- Declarative `Entry.offset/scale/opacity` chains vs implicit layout animations.
- Central color/typography tokens (future dedicated theme module).

### Navigation

Static `MaterialApp` routes: `/`, `/home`, `/profile`, `/sensors` (candidate for `go_router` to add deep linking + guards).

## 5. Backend / Services Layer

Authentication + local profile caching + sensor groundwork. Firestore & remote sync deferred until profile enrichment + workout logging stabilize.

## 6. State Management (BLoC) Flow

```text
AuthStarted -> AuthAuthenticated | AuthUnauthenticated
AuthSignInWithGoogleRequested -> Loading -> Authenticated | Unauthenticated | Error
AuthSignInWithAppleRequested  -> Loading -> Authenticated | Unauthenticated | Error
AuthSignOutRequested          -> Loading -> Unauthenticated | Error
```

`authStateChanges` subscription ensures UI reflects canonical Firebase state.

## 7. Data & Persistence

### Hive (Fast Session Cache)

`userBox`: uid, email, displayName, photoUrl, lastLogin.

### SQLite (Structured)

`user_profile` (id=1) extended fields; `workouts` prepared for session logs.

### Sync Lifecycle

1. Sign‑in → Update globals + Hive → Upsert SQLite profile row.  
2. App start → Hive session check → Hydrate extended profile from SQLite.  
3. Sign‑out → Firebase sign‑out → Clear Hive + delete SQLite row + reset globals.

Rationale: Hive accelerates hot path; SQLite enables relational growth & offline analytics.

## 8. Theming & Styling

- Seed `ColorScheme` + curated overrides.
- `Sora` typography (selected weights for bundle efficiency).
- Planned: dark mode & high‑contrast accessibility variant.

## 9. Security & Keys

- Firebase client keys: public by design; restrict via bundle ID / SHA / domain.
- No server secrets or custom tokens stored locally.
- Planned: consent‑based analytics & crash reporting toggles.

## 10. Project Structure

```text
lib/
  main.dart                  # Bootstrap & initialization
  app.dart                   # Root scaffold
  firebase_options.dart      # Generated Firebase config
  features/
    auth/
      presentation/pages/welcome.dart
      presentation/pages/profile.dart
      data/repositories/auth_repository.dart
    debug/sensor_demo_page.dart
  logic/auth_bloc/            # AuthBloc, events, states
  core/
    db/app_database.dart      # SQLite (profile/workouts)
    utils/logger.dart         # Logging helpers
assets/
  fonts/
  images/
```

## 11. Local Development & Setup

### Prerequisites

- Flutter 3.x+
- Dart SDK (bundled)
- Firebase project configured (options file present)

### Run

```bash
flutter pub get
flutter run
```

Apple Sign‑In: enable capability in Xcode & confirm bundle ID + entitlement settings.

### Regenerate Firebase Options

```bash
flutterfire configure
```

### Hive Notes

Open boxes before `runApp()` for deterministic warm start.

## 12. Quality & Extensibility Notes

- Add unit tests (AuthRepository, AppDatabase CRUD, AuthBloc transitions).
- Replace global user vars with typed Profile model + ProfileCubit.
- Migrate to `go_router` (deep linking, guarded routes, web URL sync).
- Add Crashlytics & Analytics (consent gating & opt‑in privacy controls).
- Accessibility: reduce‑motion toggle, text scale audits, high contrast theme.
- Workout DAO & analytics pre‑processing (rep segmentation pipeline foundation).
- CI pipeline (format, analyze, test) via GitHub Actions.
- Sensor smoothing & baseline rep detection (peak/trough heuristics → ML refinement later).

## 13. Roadmap / Next Steps

- Profile completion UI (anthropometrics, goals, units)  
- Workout session logging & timeline  
- Rep counting & motion classification (signal processing → ML)  
- AI workout recommendation (serverless inference endpoints)  
- Firestore sync & offline conflict resolution  
- Data export (CSV / JSON)  
- Dark & high‑contrast themes  

## 14. License

Proprietary (adjust if open-sourcing). Add a LICENSE file when finalized.

---
> Maintained as part of the FitSense AI initiative. Open an issue to propose architectural improvements.


