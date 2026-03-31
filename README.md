<div align="center">

# FitSense AI

**A privacy-conscious Flutter fitness companion with deterministic workout sessions, resilient local persistence, and an extensible architecture for intelligent coaching.**

![Platform](https://img.shields.io/badge/platform-Flutter-02569B?logo=flutter&logoColor=white)
![State](https://img.shields.io/badge/state-BLoC-3DDC84)
![Auth](https://img.shields.io/badge/auth-Firebase%20Auth-FFCA28)
![Storage](https://img.shields.io/badge/storage-Hive%20%2B%20SQLite-7E57C2)

</div>

---

## Table of Contents

- [What is FitSense AI?](#what-is-fitsense-ai)
- [Current Capabilities](#current-capabilities)
- [Architecture at a Glance](#architecture-at-a-glance)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Configuration & Secrets](#configuration--secrets)
- [Quality, Testing, and Security Checks](#quality-testing-and-security-checks)
- [Workout Session Model](#workout-session-model)
- [Key Documentation](#key-documentation)
- [Roadmap](#roadmap)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## What is FitSense AI?

FitSense AI is a cross-platform Flutter app focused on fitness onboarding and plan-driven workout execution.

The project is currently centered on:

- a polished authentication and onboarding flow,
- deterministic workout/session identifiers for traceability,
- resilient local data handling with Hive + SQLite mirroring,
- accessibility-friendly workout interactions,
- and security-first foundation work (secrets handling, audit scripts, CI scanning).

It is designed to evolve toward AI-assisted coaching, deeper analytics, and optional cloud sync.

---

## Current Capabilities

### ✅ Implemented

- **Authentication stack**
  - Firebase Auth initialization
  - Google Sign-In and Apple Sign-In pathways
  - authenticated/unauthenticated routing with BLoC state

- **Workout plan + session flow**
  - plan browser and plan detail screens
  - deterministic `workoutId` and `exerciseId` generation
  - plan seeding into active session progress
  - reps/sets progression with per-set persistence

- **Session lifecycle and recovery**
  - ongoing session tracking
  - pause/resume lifecycle hooks
  - stale/incomplete session handling
  - summary screen for completed sessions

- **Persistence layer**
  - Hive boxes for fast app startup and responsive state
  - SQLite mirror for structured querying and long-term analytics groundwork
  - secure storage integration for encryption key handling

- **Developer-facing quality tools**
  - test suite around session/workout behavior
  - security audit script and CI workflow for static/security checks

### 🛠 In Progress / Planned

- richer motion-based rep intelligence from sensor streams
- deep-link lifecycle completion (`ai-fit://...` flows)
- expanded analytics and observability
- cloud sync and conflict resolution strategy

---

## Architecture at a Glance

```text
UI (Flutter Widgets)
  -> State (Bloc/Cubit)
    -> Repositories
      -> Data Sources
         - Firebase Auth
         - Hive (fast local cache/state)
         - SQLite (structured persistence/mirroring)
```

### Main logical modules

- `AuthBloc` for auth lifecycle and routing decisions
- `SessionCubit` for workout progression, timing, pause/resume, recovery
- `WorkoutsCubit` for plan catalog loading/state
- repositories for auth, plans, and workout session persistence

### Navigation model

Defined in `lib/core/navigation/app_routes.dart`:

- `/home`
- `/plans`
- `/plans/<planId>`
- `/workout/<sessionId>`
- `/session/summary/<sessionId>`
- `/history`
- `/profile`
- `/sensors`

---

## Project Structure

```text
lib/
  main.dart                         # bootstrap: Firebase/Hive/DI/blocs
  app.dart                          # root app shell + home tabs

  core/
    config/                         # secrets/config helpers
    db/                             # SQLite bootstrap + migrations + indexing
    models/                         # workout/session/set/plan/runtime models
    navigation/                     # route names + navigation helpers
    network/                        # Gemini/network clients
    services/                       # local storage + encryption services
    stats/                          # minutes + aggregate services
    ui/                             # design tokens, reusable styles/widgets
    utils/                          # formatters/logging/id helpers

  features/
    auth/                           # onboarding/auth/profile flows
    home/                           # home dashboard, quick actions, recovery panel
    workout/                        # plan/session pages, summary, set progress UI
    sensors/                        # sensor repository integration
    altrix/                         # chat-related feature area
    audit/                          # in-app audit visibility dashboard
    debug/                          # debug pages (sensor demo)

  logic/
    auth_bloc/
    session/
    workouts/

test/                               # unit/widget/integration-oriented tests
scripts/run-audit.sh                # local security/quality scan helper
.github/workflows/security-audit.yml
```

---

## Getting Started

### Prerequisites

- Flutter SDK installed and available in `PATH`
- Dart SDK (bundled with Flutter)
- platform toolchains as needed:
  - Android Studio / Android SDK
  - Xcode (for iOS/macOS)
  - Chrome (for web)
- Firebase project configured for your app targets

### 1) Install dependencies

```bash
flutter pub get
```

### 2) Configure Firebase (if needed)

If Firebase options are not already aligned to your environment:

```bash
flutterfire configure
```

### 3) Configure environment values (optional/local)

```bash
cp .env.example .env
```

Then set values in `.env` for local development (do **not** commit `.env`).

### 4) Run the app

```bash
flutter run
```

You can also target a specific platform/device:

```bash
flutter run -d chrome
flutter run -d macos
flutter run -d ios
flutter run -d android
```

---

## Configuration & Secrets

FitSense AI supports secure key loading with a preference for safer runtime mechanisms.

### Gemini API key

`GEMINI_API_KEY` can be supplied through:

1. secure storage (persisted on device after first retrieval),
2. compile-time define (`--dart-define=GEMINI_API_KEY=...`),
3. local `.env` (development convenience).

Example:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key
```

### Security notes

- Do **not** commit `.env`.
- Firebase client config files are identifiers, not admin secrets—but backend rules must still be locked down.
- Sensitive local data hardening is tracked in `SECURITY.md`.

---

## Quality, Testing, and Security Checks

### Lint / static checks

```bash
flutter analyze
```

### Run tests

```bash
flutter test --reporter=expanded
```

### Run local audit bundle

```bash
bash scripts/run-audit.sh
```

The audit script orchestrates analysis/tests plus security-oriented scans (OSV, Semgrep, detect-secrets) in a best-effort developer flow.

### CI

GitHub Actions workflow: `.github/workflows/security-audit.yml`

CI includes:

- dependency install,
- `flutter analyze`,
- test execution,
- OSV vulnerability scanning (dependency CVE/advisory checks),
- Semgrep static security scanning (code-pattern security linting),
- detect-secrets checks (secret leakage detection in source).

---

## Workout Session Model

FitSense AI uses deterministic IDs to make session resumption, analytics mapping, and future deep links more reliable.

### ID strategy

```text
workoutId  = plan_<planId>_<epochMillis>
exerciseId = plan_<planId>ex<index>
```

### Lifecycle overview

```text
Start plan
  -> seed exercise queue
  -> start first exercise
  -> increment reps / complete sets
  -> advance through queue
  -> complete session
  -> navigate to summary
```

### Persistence behavior

- Hive is the fast-access source for active state and recent data.
- SQLite mirrors session data for structured queries and analytics-readiness.
- Recovery logic reconstructs active context from persisted progress.

---

## Key Documentation

If you want deeper project internals, start here:

- **Security policy and hardening checklist**: `SECURITY.md`
- **Detailed source map**: `FILE_DOCUMENTATION.md`
- **Session consistency contracts**: `CONSISTENCY.md`
- **Edge-case behavior references**: `EDGE_CASES.md`
- **Implementation roadmap**: `NEXT_STEPS.md`
- **Audit report**: `docs/audit-report.md`
- **Structured findings**: `docs/findings.csv`
- **Threat model (Mermaid)**: `docs/dfd.mmd`

---

## Roadmap

High-priority themes:

- improve session analytics depth (volume, density, trends),
- complete deep-link and resume UX hardening,
- expand observability and crash/error monitoring,
- strengthen encryption posture across all local sensitive stores,
- support optional cloud sync and portable export/import.

---

## Troubleshooting

### `flutter: command not found`

Install Flutter SDK and ensure `flutter` is available in shell `PATH`.

### Sign-in issues on iOS

Verify Apple Sign-In capability and Firebase OAuth client configuration.

### Firebase init/runtime issues

Confirm project files and options are aligned for each platform (`lib/firebase_options.dart`, Android/iOS Firebase config files).

### Session not resuming as expected

Check session persistence state in Hive and mirrored SQLite entries, then review `SessionCubit` logic and edge-case docs.

---

## License

No `LICENSE` file is currently included in this repository.

Until a license file is added, treat usage/distribution as restricted by default and coordinate with the maintainers.

---

If you're contributing to architecture or data-layer behavior, please review `CONSISTENCY.md` and `EDGE_CASES.md` before making session-related changes.
