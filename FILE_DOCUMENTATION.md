# AI Fitness Tracker – Source File Documentation Index

This document provides an overview of each active Dart source file (excluding generated Hive *.g.dart* adapter code already present and any history artifacts) under `lib/` as of this snapshot. For every file you get: purpose, primary classes/functions, key responsibilities, dependencies, and potential improvement notes.

Legend:

- (M) = Model / Data structure
- (R) = Repository / Data access
- (C) = Cubit / Bloc (state management)
- (UI) = UI widget/screen
- (U) = Utility / helper
- (NAV) = Navigation helper
- (THEME) = Styling / design tokens

---

## Core Layer

### lib/core/models/workout_session.dart (M)
 
Models `WorkoutSession` (session metadata + progress collection) and `ExerciseProgress` (per-exercise aggregates). Responsibilities: persistence via Hive, mapping to/from generic maps (for potential future DB/serialization). Depends on: `hive`. Improvement: Consider extracting a dedicated DTO for DB mapping vs Hive object to avoid coupling; add unit tests validating copy/serialization round-trips.

### lib/core/models/session_runtime.dart (M)
 
Ephemeral-but-persisted runtime state (`SessionRuntime`) tracking UI-centric exercise timing, current indices, paused status, and originating `planId`. Enables robust resume/recovery flows without polluting canonical progress model. Depends on: `hive`. Improvement: Add invariants (e.g., `currentExerciseIndex >= 1`) and a migration strategy for additional modes (e.g., `cooldown`).

### lib/core/models/exercise_set.dart (M)
 
Hive model for individual logged sets (reps, weight, duration). Supports granular history and analytics beyond aggregate `ExerciseProgress`. Improvements: Add effort metrics (RPE) and unify weight units.

### lib/core/models/workout_plan.dart (M)
 
Plan structure (list of planned exercises + metadata). Used to seed deterministic session exercise IDs and provide friendly names in summaries. Improvement: Add versioning + localized display names.

### lib/core/utils/plan_exercise_id.dart (U)
 
`PlanExerciseId.build(planId, index)` generates deterministic exercise IDs (`plan_<planId>ex<index>`) providing stable ordering and enabling runtime reconstruction. Improvement: Add parse helper returning `(planId, index)` and centralize validation.

### lib/core/utils/formatters.dart (U)
 
Formatting helpers: `formatDuration` (hh:mm:ss / mm:ss) and `formatFriendlyDate` (Today/Yesterday/`MMM d`). Improvement: Inject locale & add tests for boundary cases (negative seconds, DST transitions).

### lib/core/ui/design_tokens.dart (THEME)
 
Design tokens: spacing (`Gaps`), layout sizing (`AppLayout`), radii, shadows, surface decorations (`AppDecorations`). Improvement: Extract color palette into dedicated file; consider using `ThemeExtension` for stronger theming integration.

### lib/core/ui/app_text_styles.dart (THEME)
 
Centralized typography constants (`AppText`). Reduces ad-hoc `TextStyle` creation. Improvement: Provide dark/light adaptive colors and semantic naming (e.g., `headlineLarge`, `labelSmall`).

### lib/core/ui/widgets/app_card.dart (UI)
 
Reusable card container (not yet referenced widely in captured snapshot). Improvement: Add semantic elevation variants and interactive states.

### lib/core/ui/widgets/rounded_image_thumb.dart (UI)
 
Simple image thumbnail with rounded corners; uses design token defaults. Improvement: Add placeholder / error handling via `Image.asset` fallback or `FadeInImage`.

### lib/core/navigation/app_routes.dart (NAV)
 
Route name helpers (not shown in extracted snippet but assumed). Improvement: Co-locate with `AppNavigator` or generate strongly typed route objects.

### lib/core/navigation/app_navigator.dart (NAV)
 
Centralized navigation for starting plan sessions and resuming ongoing ones. Guards against double-taps via `StartPlanInFlightMarker`. Improvement: Integrate analytics hooks & error surfacing (snackbars) on failures; add deep link mapping.

### lib/core/db/app_database.dart (R)
 
Database bootstrap (likely for SQLite) enabling structured data storage beyond Hive (not opened here). Improvement: Document schema versioning & migrations.

### lib/core/utils/logger.dart (U)
 
Lightweight logging abstraction (not opened). Improvement: Provide log level filtering + conditional compilation for release mode.

---

## State / Logic Layer

### lib/logic/session/session_cubit.dart (C)
 
State machine for workout sessions: creation, plan seeding, exercise lifecycle (start, reps, set completion, pause/resume), recovery detection, ticker-based duration updates, runtime persistence flush, and completion finalization. Depends on: `WorkoutSessionRepository`, Hive box for `SessionRuntime`, timers. Improvement: Extract ticker & runtime flush to separate service for testability; add explicit analytics dispatch points; enforce max session duration policy; add unit tests for recovery edge cases.

### lib/logic/workouts/workouts_cubit.dart (C)
 
Manages collection of `WorkoutPlan` objects (not opened). Improvement: Add filtering, caching invalidation, and error states.

### lib/logic/workouts/workouts_state.dart (C)
 
Immutable state container for `WorkoutsCubit`. Improvement: Add copyWith, equality, and doc comments (if absent) plus tests.

### lib/logic/auth_bloc/auth_bloc.dart (C)
 
Authentication flow orchestrator using Bloc pattern (events in `auth_event.dart`, states in `auth_state.dart`). Improvement: Harden error mapping and token refresh logic; add analytics for sign-in/out events.

### lib/logic/auth_bloc/auth_event.dart (C)
 
Defines auth events (sign in, sign out, bootstrap, etc.). Improvement: Seal with `sealed class` (Dart 3) for exhaustiveness.

### lib/logic/auth_bloc/auth_state.dart (C)
 
Defines auth states (authenticated, unauthenticated, loading, error). Improvement: Provide convenience getters (e.g., `bool get isAuthenticated`).

---

## Feature: Home

### lib/app.dart (UI)
Root `MyApp` + `MyHomePage` scaffold with bottom navigation, and `Home` tab composition: greeting, date timeline, quick actions, session panel, suggested plan, last completed summary, and exercise list. Contains private widgets (`_ExercisesList`, `_ExerciseCard`, `_LastCompletedCard`, `_SuggestedPlanCard`, etc.). Improvement: Split into modular feature widgets (already began with `OngoingSessionPanel`); move static exercise list to dynamic data source; reduce inline styling in favor of tokens.

### lib/features/home/widgets/ongoing_session_panel.dart (UI)
Displays recovery banner (if session reconstructed) and ongoing workout card with resume action and thumbnails. Improvement: Replace static thumbnails with real current session exercises; animate recovery banner entrance.

### lib/features/home/pages/history_placeholder.dart (UI)
Placeholder for history view. Improvement: Implement session archive list using repository queries.

### lib/features/home/pages/plan_detail_screen.dart (UI)
Displays plan details (assumed). Improvement: Add ability to start session from specific exercise index.

### lib/features/home/widgets/home_quick_actions.dart (UI)
Quick access buttons (not opened). Improvement: Drive from configuration & add haptic feedback.

### lib/features/home/widgets/home_quick_actions.dart (UI)
See above (duplicate path in listing due to formatting); ensure single canonical file.

---

## Feature: Auth & Profile

### lib/features/auth/data/repositories/auth_repository.dart (R)
Authentication data access (Firebase or custom). Improvement: Abstract provider (email, OAuth) strategies; centralize error translation.

### lib/features/auth/presentation/pages/login.dart (UI)
Login screen. Improvement: Add form validation, password visibility toggle, and accessible labels.

### lib/features/auth/presentation/pages/welcome.dart (UI)
Onboarding / splash welcome. Improvement: Introduce feature highlights carousel.

### lib/features/auth/presentation/pages/onboarding.dart (UI)
Guided onboarding steps collecting user info/goals. Improvement: Persist partial progress; analytics instrumentation for funnel.

### lib/features/auth/presentation/pages/profile.dart (UI)
User profile display. Improvement: Lazy-load avatar & allow editing quick stats.

### lib/features/auth/presentation/pages/profileSettings.dart (UI)
Profile settings management. Improvement: Group sections with accessible semantics and add confirmation dialogs.

### lib/features/auth/presentation/pages/meals.dart (UI)
Meals/nutrition screen. Improvement: Integrate macro summary & meal logging.

### lib/features/auth/presentation/pages/workouts.dart (UI)
Workout library / selection. Improvement: Filter/search; integrate plan start.

### lib/features/auth/presentation/pages/inividualWorkout.dart (UI)
Primary workout interaction screen (now includes rest state, semantics for controls, focus handling, and pause/resume wiring). Improvement: Factor timer & set entry into smaller widgets; add accessible announcements for set completion; integrate `ExerciseSetProgress`.

---

## Feature: Workout

### lib/features/workout/data/workout_session_repository.dart (R)
Repository for session CRUD, progress updates, set storage, and completion. Improvement: Add caching layer + error instrumentation.

### lib/features/workout/data/workout_plan_repository.dart (R)
Repository for plan persistence (create/read/update/delete). Improvement: Add diffing & optimistic updates.

### lib/features/workout/pages/session_summary_screen.dart (UI)
Expanded summary view: duration, exercise stats table (per-exercise sets/reps/time) plus totals and navigation back home. Improvement: Add share/export action & charts (volume over time).

### lib/features/workout/widgets/exercise_set_progress.dart (UI)
Semantic + animated per-set progress chips with completed/active/pending states. Improvement: Parameterize colors via theme; expose callback for tapping historical sets (e.g., edit).

### lib/features/workout/widgets/exercise_queue.dart (UI)
Queue/list of exercises (not opened). Improvement: Support drag reordering pre-session, show upcoming vs completed grouping.

---

## Presentation Utilities

### lib/features/presentation/widgets/colors.dart (THEME)
Color palette constants. Improvement: Convert to `ColorScheme` extensions and remove direct static references.

---

## Debug / Dev

### lib/features/debug/sensor_demo_page.dart (UI)
Demo page for sensors (e.g., motion) experimentation. Improvement: Guard behind debug flag & add permission prompts.

---

## Firebase / Generated Setup

### lib/firebase_options.dart (U)
Generated Firebase initialization options. Do not manually edit. Improvement: None (managed by FlutterFire CLI).

---

## Application Entry

### lib/main.dart
Bootstrap: initializes Flutter bindings, Firebase/Hive setup (assumed), sets globals (`gUser*`) and launches `MyApp`. Improvement: Remove global mutable user fields in favor of scoped providers or auth state; add error zone + crash reporting.

---

## Tests

### test/widget_test.dart
Default Flutter template test (placeholder). Improvement: Replace with golden tests for critical widgets.

### test/workout_accessibility_test.dart
Accessibility semantics smoke test for `ExerciseSetProgress`. Improvement: Extend to cover rest timer announcements & recovery banner semantics.

---

## Cross-Cutting Improvement Themes
1. Analytics: Insert real analytics dispatch (session start, set complete, rest start/skip, recovery resume) where TODOs exist.
2. Accessibility: Continue expanding semantics for navigation elements, plan cards, and dynamic lists.
3. Theming: Migrate inline colors to design tokens; implement light/dark adaptive palette.
4. Testing: Add unit tests for `SessionCubit` (recovery flow, pause/resume, set completion), formatters, and `PlanExerciseId`.
5. Error Handling: Surface repository errors to UI via snackbars or inline banners instead of silent catches.
6. Data Modeling: Introduce domain layer mappers to decouple Hive objects from UI & potential future REST/GraphQL sources.
7. Performance: Debounce duration ticker updates to UI (currently 5s interval is fine) and batch repository writes where possible.
8. Navigation: Complete transition to centralized `AppNavigator` & typed routes, removing ad-hoc `MaterialPageRoute` instances.

---

## Documentation Maintenance
Regenerate this file when adding/removing files or substantially changing responsibilities. Consider adding a script that parses headers/doc comments to auto-build this index to prevent drift.
