<div align="center">
# FitSense AI – Intelligent Fitness Companion

Lean Flutter app delivering a staged welcome → authentication → greeting experience using Firebase Auth, Hive (session cache), and SQLite (structured profile groundwork). Built on BLoC for predictable state and future motion/workout intelligence.

![Platforms](https://img.shields.io/badge/platform-iOS%20|%20Android%20|%20Web%20|%20Desktop-blue) ![State](https://img.shields.io/badge/state-BLoC-green) ![Firebase](https://img.shields.io/badge/backend-Firebase%20Auth-orange)

</div>

## 1. Vision

Provide a frictionless, privacy‑aware fitness entry point. Current milestone: robust auth lifecycle, session restoration, sensor + persistence foundations. Next: workout logging, rep counting, adaptive recommendations.

## 2. Implemented Features

### UI / Experience

- Multi‑stage welcome (Landing → Auth → Greeting) via lightweight `entry` animations (offset / scale / opacity only).
- Google & Apple sign‑in (staggered button reveal).
- Personalized greeting (first name fallback → "Friend").
- Lottie greeting animation.
- Sensor demo screen (`/sensors`) streaming accelerometer + gyroscope.

### Architecture & Logic

- `AuthBloc` manages start, provider sign‑ins, sign‑out.
- Firebase `authStateChanges` mirrored into bloc events (single source of truth).
- Hive session cache (fast warm start); SQLite for extended profile + future workouts.
- Fail‑soft: persistence/cache errors never block UI.

## 3. Architecture Overview

```text
Presentation (Widgets)
  -> State (BLoC: AuthBloc)
    -> Repository (AuthRepository over FirebaseAuth + providers)
      -> External Services (Firebase, Google Sign-In, Apple Sign-In)
Persistence: Hive (session cache) + SQLite (profile/workouts groundwork)
```

Principles: minimal surface now, clear layering, resilience, incremental evolution.

## 4. Data & Persistence

### Hive (Session Cache)

Stores: uid, email, displayName, photoUrl, lastLogin.

### SQLite (Structured)

Tables: `user_profile` (singleton extended fields), `workouts` (reserved for logging).

### Lifecycle

1. Sign‑in → update globals + Hive + upsert profile row.  
2. App start → hydrate profile from Hive + SQLite.  
3. Sign‑out → clear Hive, delete profile row, reset globals.

Rationale: Hive accelerates hot path; SQLite enables relational + analytical growth.

## 5. Project Structure

```text
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
```

## 6. Local Development

### Prerequisites

- Flutter 3.x+
- Firebase project configured (`firebase_options.dart` present)

### Run

```bash
flutter pub get
flutter run
```

### Regenerate Firebase Options

```bash
flutterfire configure
```

### Notes

- Open Hive boxes before `runApp()` for deterministic warm start.
- Enable Apple Sign‑In capability & entitlements in Xcode (iOS).

## 7. Quality & Roadmap

Planned / Next Steps:

- Typed `Profile` model + dedicated cubit (remove globals).
- Workout logging + session timeline.
- Rep counting (signal processing → ML refinement).
- `go_router` migration (deep linking, guarded routes, web URL sync).
- Dark mode + reduce motion accessibility options.
- Analytics / crash reporting (consent & opt‑in gating).
- CI: format, analyze, test, coverage badges.

## 8. License

Proprietary (adjust if open‑sourcing). Add a LICENSE file when finalized.

---
Maintained as part of the FitSense AI initiative.

# FitSense AI – Intelligent Fitness Companion

Lean Flutter app delivering a staged welcome → authentication → greeting experience with Firebase Auth, Hive (fast session cache), and SQLite (structured profile groundwork). Built on BLoC for predictable state and future AI-driven motion insights.

![Platforms](https://img.shields.io/badge/platform-iOS%20|%20Android%20|%20Web%20|%20Desktop-blue) ![State](https://img.shields.io/badge/state-BLoC-green) ![Firebase](https://img.shields.io/badge/backend-Firebase%20Auth-orange)

## Table of Contents

1. Vision  
2. Implemented Features  
3. Architecture Overview  
4. Data & Persistence  
5. Project Structure  
6. Local Development  
7. Quality & Next Steps  
8. License

---

## 1. Vision

Provide a frictionless entry point into an intelligent fitness companion. Current scope: robust auth flow, session restoration, sensor + persistence foundations for upcoming rep counting, workout logging, and adaptive recommendations.

## 2. Implemented Features

### UI / Experience

- Multi‑stage welcome flow (Landing → Auth → Greeting) using `entry` animations (offset / scale / opacity only).
- Google & Apple sign‑in with staggered button reveal.
- Personalized greeting (first-name fallback to “Friend”).
- Lottie animation on greeting screen.
- Sensor demo screen (`/sensors`) streaming accelerometer + gyroscope.

### Architecture & Logic

- BLoC (`AuthBloc`) drives auth lifecycle (start, sign-in, sign-out).
- Firebase `authStateChanges` mirrored into bloc events for single source of truth.
- Hive cache for fast session warm start; SQLite for extended profile scaffolding.
- Graceful failure: DB/cache errors never block authentication UI.

## 3. Architecture Overview

```text
Presentation (Widgets)
  -> State (BLoC: AuthBloc)
    -> Repository (AuthRepository over FirebaseAuth + providers)
      -> External Services (Firebase, Google Sign-In, Apple Sign-In)
Persistence: Hive (session cache) + SQLite (profile/workouts groundwork)
```

Principles: minimal surface now, extensible layering later, fail-soft persistence.

## 4. Data & Persistence

### Hive (Session Cache)

Stores: uid, email, displayName, photoUrl, lastLogin.

### SQLite (Structured)

Tables: `user_profile` (singleton row, extended fields), `workouts` (reserved for logging).

### Lifecycle

1. Sign-in → update globals + Hive + upsert profile row.  
2. App start → hydrate profile from Hive + SQLite.  
3. Sign-out → clear Hive, delete profile row, reset globals.

Rationale: Combine ultra-fast key/value (Hive) for hot-path bootstrap with structured storage (SQLite) for analytical & incremental data.

## 5. Project Structure

```text
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
```

## 6. Local Development

### Prerequisites

- Flutter 3.x+
- Firebase project configured (generated `firebase_options.dart` present)

### Run

```bash
flutter pub get
flutter run
```

### Regenerate Firebase Options

```bash
flutterfire configure
```

### Notes

- Hive boxes opened before `runApp()` for deterministic warm start.
- Apple Sign‑In: enable capability & confirm bundle ID entitlements in Xcode.

## 7. Quality & Next Steps

- Add unit tests (AuthRepository, AppDatabase CRUD, AuthBloc transitions).
- Replace global user variables with typed `Profile` model + cubit.
- Implement workout logging + rep counting (signal → features → ML refinement).
- Introduce `go_router` (deep linking, guarded routes, web URL sync).
- Dark mode & reduce‑motion accessibility toggle.
- Analytics & crash reporting (consent / opt‑in gating).
- CI pipeline (format, analyze, test) + code coverage.

## 8. License

Proprietary (adjust if open-sourcing). Add LICENSE file when finalized.

---

Maintained as part of the FitSense AI initiative.
- Interim global user variables (to be replaced by typed Profile layer).

### Data Model & Persistence

- Only non‑sensitive profile display fields + timestamps cached.
- Extended profile scaffold: age, weight_kg, height_cm, gender, goals (CSV), primary_goal, updated_at.
- `workouts` table reserved for session logging & analytics / AI enrichment.


- Entry animations (offset / scale / opacity) for determinism & performance.
- Moderate motion (future: user selectable reduce‑motion + dark theme).

### Resilience / Edge Handling

- Remote/logout detection returns to landing stage.
- Provider cancel surfaces graceful return to unauthenticated state.
- Corrupt Hive entries trapped via try/catch (non‑fatal path).
Persistence: Hive (fast session cache) + SQLite (structured profile/workouts)
```


### Screens


- Stage enum drives conditional rendering & entry transitions.
- Declarative `Entry.offset/scale/opacity` chains instead of layout/size animations.
Static `MaterialApp` route map: `/`, `/home`, `/profile`, `/sensors`. Candidate for `go_router` (deep links, guards, web URLs).

## 5. Backend / Services Layer
## 6. State Management (BLoC) Flow

```text
AuthSignInWithAppleRequested  -> Loading -> Authenticated | Unauthenticated | Error
AuthSignOutRequested          -> Loading -> Unauthenticated | Error
```

### Hive (Fast Session Cache)

`userBox`: uid, email, displayName, photoUrl, lastLogin.

### SQLite (Structured)

`user_profile` (id=1) extended fields; `workouts` prepared for session logs.

### Sync Lifecycle

1. Sign‑in → Update globals + Hive → Upsert SQLite profile row.  
2. App start → Hive session check → Hydrate extended profile from SQLite.  
3. Sign‑out → Firebase sign‑out → Clear Hive + delete SQLite row + reset globals.

Rationale: Hive accelerates hot path; SQLite supports relational growth & offline analytics.

- Roadmap: dark mode + high‑contrast accessibility variant.

## 9. Security & Keys
- Planned: environment gating, consent‑based analytics & crash reporting toggles.

## 10. Project Structure

```text
lib/
  main.dart                  # Bootstrap & initialization
  app.dart                   # Starter scaffold
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
- Configured Firebase project (options file present)

### Run

```bash
flutter pub get
flutter run
```

Apple Sign‑In: enable capability in Xcode & confirm bundle ID signature settings.
```bash
flutterfire configure
```
Boxes opened before `runApp()` for deterministic warm start (see bootstrap code).

## 12. Quality & Extensibility Notes

- Unit tests (AuthRepository, AppDatabase CRUD, AuthBloc transitions).
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

Proprietary (adjust if open‑sourcing). Add a LICENSE file when finalized.


# FitSense AI – Intelligent Fitness Companion

Personalized, privacy‑aware fitness onboarding & authentication experience built with Flutter, Firebase Auth, Hive local persistence, and a clean BLoC architecture foundation.

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
## 2. Feature Overview (Implemented)

### Frontend
- Sensor demo page (`/sensors`) streaming accelerometer & gyroscope data.
- Navigation button from greeting to sensor demo.
- Profile route placeholder (`/profile`).

### Recent Frontend Refactors
- Replaced `AnimatedContainer` expansion with stateless stage model + `Entry.offset`.
- Added scale/opacity sequencing for greeting entrance.
- Logging hooks for persistence & sensor activity.

### Backend / Services

- Firebase initialization via generated `firebase_options.dart`.
- Firebase Authentication (Google & Apple) with session restore.
- Hive cache (`userBox`) storing uid, email, displayName, photoUrl, lastLogin.
- SQLite (`AppDatabase`) tables: `user_profile` (singleton) & `workouts` (future use).
- Startup hydration of extended profile from SQLite.
- Cleanup (Hive + SQLite + globals) on sign-out.
- Error-tolerant DB operations (fail-soft logging).

### State Management / Logic

- `AuthBloc` orchestrates lifecycle events (start, provider sign-ins, sign-out).
- States: Initial, Loading, Authenticated, Unauthenticated, Error.
- Temporary global user variables until Profile model formalization.

### Data Model & Persistence

- Minimal sensitive data (display profile + timestamps).
- Extended profile scaffold: age, weight_kg, height_cm, gender, goals, primary_goal, updated_at.
- `workouts` table prepared for session logging & analytics.

- Corrupt Hive defense (try/catch guard).
- SQLite absence degrades gracefully.

Presentation (UI Widgets)
  -> State (BLoC: AuthBloc)
    -> Repository (AuthRepository over FirebaseAuth + providers)

### Screens


### Concepts
- Stage enum drives conditional rendering & entry animations.
### Navigation

Routes: `/`, `/home`, `/profile`, `/sensors` (candidate for `go_router`).
```

`authStateChanges` mirrored for canonical UI state.
## 8. Theming & Styling
- Seed-based `ColorScheme` + curated overrides.
Firebase client keys restricted by platform identifiers; no secrets or custom tokens persisted. Future: analytics/crash gating & environment stratification.

## 10. Project Structure
  main.dart
  app.dart
  firebase_options.dart
    auth/presentation/pages/profile.dart
    auth/data/repositories/auth_repository.dart
    debug/sensor_demo_page.dart
assets/images/
```

## 11. Local Development & Setup

### Prerequisites
flutter pub get
flutter run
```bash
flutterfire configure

## 12. Quality & Extensibility Notes
- Add tests (repository, bloc, db).
- Accessibility enhancements (reduce motion, scaling audit).
- Workout DAO & analytics pipeline preparation.
- CI (format/analyze/test) pipeline.
- Sensor signal smoothing + rep detection prototype.

## 13. Roadmap / Next Steps
- Profile completion flow.  
- Workout session logging & timeline.  
- Rep counting & motion classification (signal processing → ML).  
- Firestore sync & offline strategy.  
- Data export (CSV / JSON).  
- Dark / high-contrast themes.  

## 14. License
Proprietary (adjust if open-sourcing). Add a LICENSE file when finalized.

---

> Maintained as part of the FitSense AI initiative. Open an issue to propose architectural enhancements.



1. Sign-in success → globals + Hive write → SQLite upsert.

2. App start → Hive session check → SQLite hydration for extended metrics.

3. Sign-out → Firebase sign-out → SQLite row deletion + Hive clear + global resets.

Rationale: Combine ultra-fast key/value (Hive) for critical boot path with structured relational storage (SQLite) for analytical & incremental data.

## 8. Theming & Styling


- Light background with accent reds/blues/greens for brand identity.

- Consistent `Sora` typography with limited fontWeight variants for performance.






      presentation/pages/
        welcome.dart       # Multi-stage auth & greeting UI


        profile.dart       # Placeholder for extended profile

      data/repositories/
        auth_repository.dart
    debug/
      sensor_demo_page.dart # Accelerometer & gyroscope demo
  logic/
    auth_bloc/             # AuthBloc, events, states
  core/
    db/app_database.dart   # SQLite (profile/workouts)
    utils/logger.dart      # Logging helpers
assets/ (fonts, images in project root assets/)
```

## 11. Local Development & Setup
Prerequisites:
- Flutter (3.x+)
- Dart SDK (bundled)
- Firebase project configured (already included options file)


flutter pub get
```bash
flutterfire configure
```


### Hive Box Notes

Box auto-opens in `main.dart`; if adding more boxes, open before `runApp()`.

## 12. Quality & Extensibility Notes

Potential enhancements:

- Add unit tests for AuthRepository & DB layer (mock sqflite / in-memory DB).


- Introduce a dedicated ProfileCubit and strongly-typed Profile model.

- Migrate routing to declarative approach (go_router / beamer) for deep linking.



- AI workout recommendation engine integration (likely via serverless endpoints)



Proprietary (adjust if you plan to open-source). Add a LICENSE file when finalized.






> Maintained as part of the FitSense AI initiative. Contributions & discussions welcome—open an issue to propose architectural changes.

