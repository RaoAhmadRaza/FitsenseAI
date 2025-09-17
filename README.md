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

### Plan-Driven Workout Sessions (Wave Additions)

Deterministic session & exercise identifiers + queued progression logic enabling reliable resume, analytics correlation, and future deep-linking.

ID Scheme:

```text
workoutId: plan_<planId>_<epochMillis>
exerciseId: plan_<planId>ex<index>    (index = 1-based position within plan)
```

Session Flow:

```text
Select Plan -> startPlanSession(plan) -> seed ExerciseProgress queue
  -> startExercise(first) -> incrementRep()/completeSet() loop
    -> on last set of exercise: startExercise(next) OR completeSession()
      -> navigate to sessionSummary(workoutId)
```

Recovery & Resume:

- Queue persisted (Hive) via `WorkoutSession` + `ExerciseProgress` entries.
- Incomplete session can be resumed by reconstructing active exercise from persisted progress (current exercise = first with uncompleted sets).
- Parsing helpers: `_parseExerciseIndex(exerciseId)` & `extractPlanIdFromWorkoutId()` ensure robust reverse mapping.

Edge Handling:

- Starting a new plan auto-completes lingering incomplete session to avoid multi-session ambiguity.
- Missing / corrupt progress entries are recreated on the fly (fail-soft) so the user never loses the ability to proceed.

Accessibility Enhancements:

- Live region updates for rep counting (announce increment & set completion).
- Focus shifts to next exercise card upon transition for screen reader continuity.

Future Enhancements (Planned):

- Real-time motion-based rep detection feeding `incrementRep`.
- Pause / resume states with wall-clock drift reconciliation.
- Deep link: `ai-fit://workout/<workoutId>` opens active or summary view.

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

## 2b. Routing Map (Wave Additions)

Centralized in `lib/core/navigation/app_routes.dart`.

| Route Helper / Name | Pattern | Purpose |
| ------------------- | ------- | ------- |
| AppRoutes.home | /home | Post-auth home/dashboard (placeholder) |
| AppRoutes.plans | /plans | Browse available workout plans |
| AppRoutes.planDetail(planId) | /plans/<planId> | Detail + Start action for specific plan |
| AppRoutes.workout(sessionId) | /workout/<sessionId> | Active workout session (progress UI) |
| AppRoutes.sessionSummary(sessionId) | /session/summary/<sessionId> | Post-session metrics & completion summary |
| AppRoutes.history | /history | (Placeholder) Historical sessions list |
| AppRoutes.profile | /profile | User profile / settings (placeholder) |
| AppRoutes.sensors | /sensors | Sensor demo / motion telemetry sandbox |

Notes:

- Dynamic segments (<planId>, <sessionId>) are currently string-based and validated lazily when accessed.
- Deterministic IDs allow future server reconciliation & shareable links.
- Migration path: adopt `go_router` for guarded routes + web URL sync.

Deep Link Examples (Future):

```text
ai-fit://plans/strength_beginner      -> plan detail screen
ai-fit://workout/plan_push_1726500000 -> resume or summary depending on completion
```

## 2c. Analytics Hook Points

Instrumentation TODOs placed inline for future analytics layer integration. Each entry identifies the semantic event to emit.

| Location (File:Line approx) | Event Template | Description |
| --------------------------- | -------------- | ----------- |
| main.dart: deep link handler | deep_link_open(uri) | App opened or navigated via deep link |
| plan_detail_screen.dart | plan_start(planId) | User initiated a plan session |
| session_cubit.dart (startPlanSession) | session_started(workoutId) | New workout session seeded |
| session_cubit.dart (startExercise) | exercise_start(exerciseId) | Exercise becomes active |
| session_cubit.dart (completeSet) | set_complete(exerciseId,setIndex) | User completed a set |
| session_cubit.dart (completeSession) | session_complete(workoutId) | User finished entire session |
| inividualWorkout.dart (legacy flow) | session_complete(planSession=planId) | Legacy screen session completion |
| inividualWorkout.dart (legacy flow) | session_complete(legacySession) | Non-plan / legacy completion fallback |
| Session pause action (SessionCubit.pauseSession) | pause_session(workoutId) | User paused an active session |
| Session resume action (SessionCubit.resumeSession) | resume_session(workoutId) | User resumed a paused session |
| Rest start (set completion handler) | rest_started(exerciseId,setIndex) | User entered timed rest after completing a set |
| Rest skip (Skip Rest button) | rest_skipped(exerciseId,setIndex) | User skipped/short-circuited a rest period |
| Recovery banner shown (OngoingSessionPanel) | recovery_banner_shown(workoutId,ageSeconds) | Incomplete session detected and surfaced |
| Recovery banner dismiss (Resume / Dismiss) | recovery_banner_dismissed(workoutId,action) | User resumed or dismissed recovery prompt |
| Navigation helper start plan | plan_start(planId) | User initiated plan via AppNavigator |
| Navigation helper start workout | workout_start(workoutId) | Deterministic workout session lifecycle init |

Planned Analytics Layer:

- Thin abstraction (e.g., `Analytics.log(eventName, params)`) with compile-time noop stub when disabled.
- Consent gate surfaced in profile/settings (persisted preference).
- Batched dispatch (timers) to minimize network chatter; offline queue in Hive.

Privacy Considerations:

- Avoid raw PII (no names/emails). Use stable anonymous user id.
- Weight reps/time data treated as optional & purgable upon user delete request.
- Provide export + delete functions aligned with roadmap.

4. Data & Persistence
Hive (Session Cache)
Stores: uid, email, displayName, photoUrl, lastLogin.

SQLite (Structured)
user_profile → singleton row for extended fields.

workouts → reserved for logging & analytics.

Workout Sessions (NEW)
- Hive box: `sessionBox` storing serialized `WorkoutSession` objects (fast lookup for ongoing + last completed).
- Models: `WorkoutSession` (workoutId, date, durationSeconds, progress[], completed) & `ExerciseProgress` (exerciseId, completedSets, completedReps, usedWeight, timeSpentSeconds).
- SQLite mirror tables: `workout_sessions`, `exercise_progress` (additive; legacy `workouts` table left untouched) + `exercise_sets` (fine-grained per-set; unique(session_id, exercise_id, set_index)).
- Repository: `WorkoutSessionRepository` (startSession, updateDuration, upsertExerciseProgress, completeSession, getOngoing, getLastCompleted, addExerciseSet) writes Hive first then mirrors to SQLite best-effort.
- SessionCubit now wired minimally to home Ongoing Workout panel (reactive duration + resume action).
- Invariant: Only one ongoing (completed = false) session retained; starting a new session auto-completes any lingering one to avoid drift.
- Duration ticker: `SessionCubit` runs a 5s periodic timer to increment `durationSeconds` for the ongoing session (best-effort, paused when no session) PLUS reconciliation on refresh (wall-clock recompute) to correct drift.
- Per-set granularity: `ExerciseSet` model (Hive `exerciseSetBox`, adapter id=12) mirrored into SQLite `exercise_sets` for analytics readiness.
- Stale session cleanup: sessions older than 8h without completion auto-completed during refresh.
- Resume navigation: home panel Resume button pushes `Inividualworkout` with `sessionWorkoutId` for contextual continuity.

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
 
## Workout Interaction Components (New)

This subsection documents the interactive workout/session layer introduced in recent refactors, emphasizing accessibility, deterministic identifiers, and future analytics extensibility.

### 1. ExerciseSetProgress

Purpose: Visual + semantic representation of per-exercise set progression.

Props:

- totalSets (int)
- completedSets (int) – clamped to totalSets
- spacing / size (layout tuning)
- animateActive (bool, default true) – disabled in tests to avoid animation flakiness.

States per chip:

- completed: solid green + check icon + semantics "Set 2 of 5 completed"
- active: outlined + gentle pulse (AnimationController) + semantics "Set 3 of 5 active"
- pending: outlined grey + semantics "Set 4 of 5 pending"

Accessibility:

- Root Semantics container announces overall progress.
- Each chip individually labeled for granular traversal.
- Animation optional; test harness sets animateActive=false.

### 2. Rest Timer (Ephemeral)

Lifecycle:

1. Triggered when a set completes (except final session completion).
2. Local state only (Phase 5 will consider persistence / wall-clock reconciliation).
3. Announces remaining time at 10s intervals + final 5s countdown using SemanticsService.announce.

Events (planned instrumentation): rest_started / rest_skipped.

Rationale: Reduces cognitive load; defers backend modeling until adaptive rest recommendations are introduced.

### 3. Pause Overlay & Recovery Banner

- Pause Overlay (visual layer currently trimmed back) intended to return with a lightweight dialog semantics (scopesRoute: true). Business logic persists in SessionCubit for pause/resume.
- Recovery Banner (OngoingSessionPanel) surfaces stale / incomplete session with "Resume" action invoking AppNavigator.resumeSession.

Events:
- pause_session / resume_session
- recovery_banner_shown / recovery_banner_dismissed

### 4. AppNavigator Helpers

Centralized navigation + lifecycle guardrails around starting or resuming sessions.

Responsibilities:

- Deduplicate concurrent startPlan calls (double-start guard).
- Ensure lingering incomplete session is completed or resumed deterministically before seeding a new one.
- Provide semantic wrappers for analytics hooks (plan_start, workout_start) – TODO markers inline.

Benefits:

- Reduces navigation scattering (previous raw Navigator.push usage inside UI widgets).
- Provides a single interception point for future deep-link + permission checks.

### 5. State Diagram (Workout Session Flow)

```text
   ┌────────┐     startExercise       ┌────────────┐     completeSet (not last)   ┌───────────┐
   │ ready  │ ──────────────────────▶ │ exercising │ ───────────────────────────▶ │  resting  │
   └────────┘                         └─────┬──────┘                              └─────┬─────┘
  ▲         resumeSession              │ completeSet (last set of exercise)       │ rest timer ends / skip
  │                                     │                                         │
  │                                     ▼                                         │
  │                               (advance exercise)                              │
  │                                     │                                         │
  │                                     ▼                                         │
  │                                 exercising (next) ◀────────────────────────────┘
  │                                     │
  │  pauseSession                      │ completeSession (final exercise complete)
  │                                     ▼
  ├──────────────────────────────▶ paused
  │                                 │
  │  resumeSession                   ▼
  └──────────────────────────────  exercising → complete (summary screen)
```

Notes:

- resting state is ephemeral; not persisted yet.
- paused state lives in SessionRuntime (persisted partial metadata) enabling recovery after app kill.
- All transitions funnel through SessionCubit to maintain invariants.

### 6. General Integration Notes

State/Data Contracts:

- SessionCubit additions prefer optional fields + helper methods (non-breaking) over structural rewrites.
- Rest period not persisted; only mode and core progress retained.

Performance:

- One periodic rest timer per active workout screen (cheap).
- ExerciseSetProgress is O(n) small (n = # sets) and stable.
- Session summary renders once post-completion (acceptable to do aggregation in build).

Error Handling:

- Plan exercise name resolution wrapped with safe fallback to generic labels if plan entry missing.
- Semantics announcements are best-effort; failures are non-fatal.


### 7. Analytics TODO Markers Recap

Inline TODOs for: plan_start, workout_start, pause_session, resume_session, rest_started, rest_skipped, recovery_banner_shown, recovery_banner_dismissed.

### 8. Minimal Guardrails

- Double start guard: disable Start Plan button while async startPlanSession runs (AppNavigator responsibility; TODO marker).
- Pause idempotency: ignore pause if already paused; ignore resume if not paused.
- Recovery banner only appears when exactly one incomplete session exists.

### 9. Future Persistence Considerations (Phase 5)

- Persist rest start timestamp + intended duration for drift-safe background resume.
- Record per-set rest actual duration for adaptive recommendations.
- Integrate motion-based auto-pause (no reps & no movement).

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


