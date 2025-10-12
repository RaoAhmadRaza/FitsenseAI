# FitsenseAI Backend Security & Architecture Audit

Date: 2025-10-03
Repo: FitsenseAI (branch: main)

## Executive Summary

Overall risk posture: Medium. This project is primarily a Flutter client with local     1storage (Hive + SQLite) and Firebase Auth integration. There is no custom server backend in this repository. Key exposures center on client-side handling of PII (profile data) at rest, lack of CI/CD security gates, and committed cloud configuration files (Firebase) which are not secrets but still require strict backend-side rules. No API servers, IaC, or container images were found in the repo.

Top 5 issues and quick remediation:

1) PII stored unencrypted locally (Hive and SQLite). Remediate by encrypting sensitive Hive boxes (userBox) with platform keystores; consider SQLCipher or app-level encryption for SQLite. Effort: 6–16h.

2) No CI security gates. Add GitHub Actions to run static analysis (semgrep), dependency checks (OSV), secret scans, and Flutter analyze/tests. Effort: 2–6h.

3) Secrets scanning and pre-commit hardening absent. Add detect-secrets/gitleaks and a baseline, enforce in CI. Effort: 2–4h.

4) Firebase config present in repo (expected), but rules/governance unknown. Ensure Firestore/Storage rules locked down, enable MFA for Firebase project admins, rotate keys if misuse is detected. Effort: 4–8h (rules) + policy updates.

5) Observability minimal. Add crash/error reporting (e.g., Crashlytics or Sentry), structured logs, and basic analytics for auth/session flows. Effort: 4–12h.

Estimated effort for critical/high fixes: ~1–2 weeks.

## Full Audit Report

### Architecture

- Flutter client application. No server code, containers, or IaC present.
- Local persistence: Hive boxes (user profile, workout sessions, sets, plans, meals, sensor samples) and SQLite (user profile mirror, sessions, sets, plans, meals) via sqflite.
- Auth: Firebase Authentication (Google, Apple). No Firestore usage found despite dependency.

### Source Code Issues

- PII at rest: `user_profile` (SQLite) and `userBox` (Hive) contain PII (age, weight, height, gender, goals). Plaintext at rest.
- Logging: custom `logError` may print stack traces; ensure no PII or secrets get logged.
- Error handling: DB operations wrapped with try/catch and logged; good pattern.

### API Security

- No custom HTTP/GraphQL/gRPC endpoints in codebase. Auth flows use Firebase SDKs. Endpoint inventory limited to auth providers.

### Data Layer

- SQLite schema created in `lib/core/db/app_database.dart`. No encryption. Consider SQLCipher or application-layer encryption for sensitive columns.
- Hive boxes unencrypted by default. Mitigation added in this audit for `userBox` (AES via keystore-backed key). Consider extending to other sensitive boxes (e.g., `mealBox`).

### Infra & IaC

- None present. Cloud infra managed externally (Firebase). Ensure Firebase project rules and IAM hardened separately.

### CI/CD

- No workflows found. Added a proposed GitHub Actions workflow `security-audit.yml` to run formatting, analysis, tests, and security scans.

### Secrets & Config

- Firebase configs committed (firebase_options.dart, google-services.json, GoogleService-Info.plist). These are identifiers, not confidential secrets. Ensure backend-side rules and OAuth client restrictions mitigate abuse.
- No other secrets found. Add automated scanning over history.

### Observability

- No crash reporting or metrics. Recommend Crashlytics/Sentry and app-level analytics events for auth/sessions. Add redaction to logs.

### Performance

- No backend endpoints; performance relates to local storage and UI.

### Dependencies

- Flutter packages managed via pubspec. Add OSV scanning in CI. Consider pinning critical packages.

### Compliance

- PII present locally. Provide privacy policy, data export/deletion flows, and retention policy. Add in-app “Delete my data” that clears Hive + SQLite.

## Findings

See `docs/findings.csv` for structured list. Key examples:

1) Title: PII stored unencrypted in local storage
Severity: High
Component(s): Hive (userBox), SQLite (user_profile)
Location / Evidence: `lib/main.dart` opens `userBox`; `lib/core/db/app_database.dart` creates `user_profile` table
Description: PII (age, weight, height, gender) persisted without encryption.
Impact: Device compromise or backup extraction could expose user data.
Reproduction steps: Inspect on-device app data directory; read `fitsense.db` and Hive files.
Remediation: Encrypt Hive box using AES key stored in platform keystore (implemented for userBox); consider SQLCipher for SQLite or column-level encryption.
Estimated Effort: 6–16h
Verification & Acceptance Criteria: At-rest files are not readable in plaintext; automated tests still pass; app loads encrypted Hive successfully after reinstall/upgrade paths.

2) Title: Missing CI security gates
Severity: Medium
Component(s): CI/CD
Location / Evidence: No `.github/workflows` in repo
Description: No automated analysis or security scanning on PRs.
Impact: Vulnerabilities and secrets can enter main branch unnoticed.
Reproduction steps: Inspect repository structure.
Remediation: Add provided `security-audit.yml` workflow; integrate semgrep, OSV, detect-secrets; block on failures.
Estimated Effort: 2–6h
Verification & Acceptance Criteria: CI runs on PRs, failing builds on discovered issues.

3) Title: Incomplete secrets detection controls
Severity: Medium
Component(s): Repo workflow
Location / Evidence: No detect-secrets baseline or gitleaks
Description: No guardrails to prevent committing secrets.
Impact: Accidental secret leakage risks.
Reproduction steps: Search repo for sensitive tokens/keys; add test secret and observe no blocker.
Remediation: Add detect-secrets and baseline; integrate in CI and pre-commit.
Estimated Effort: 2–4h
Verification & Acceptance Criteria: CI fails on committed secrets; baseline maintained.

4) Title: Firebase configuration governs access; rules unknown
Severity: Medium
Component(s): Firebase Auth/Firestore/Storage config
Location / Evidence: `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
Description: Client holds API keys and project identifiers (expected). Without strong server-side rules and OAuth restrictions, abuse risk exists.
Impact: Abuse of open rules could leak or corrupt data.
Reproduction steps: Review Firebase console rules.
Remediation: Ensure strict Firestore/Storage rules; restrict OAuth clients to correct package IDs and SHA; enable MFA for admins.
Estimated Effort: 4–8h
Verification & Acceptance Criteria: Security rules tests pass; access from unauthorized clients denied.

5) Title: Lack of crash/telemetry
Severity: Low
Component(s): Observability
Location / Evidence: No Crashlytics/Sentry setup
Description: Limited ability to detect security-relevant failures in the wild.
Impact: Slower detection and response.
Remediation: Add Crashlytics/Sentry, basic dashboards and alerts.
Estimated Effort: 4–12h
Verification & Acceptance Criteria: Crashes and key events visible in dashboard; alerting configured.

## Threat Model / Data Flow Diagram

See `docs/dfd.mmd` (Mermaid) for data flows between device, Firebase Auth, and local stores.

## Automated Checks & Scripts

- Run `scripts/run-audit.sh` to execute static and dependency scans locally.
- CI workflow `.github/workflows/security-audit.yml` included.

## Remediation Roadmap

- Phase 0 (0–3 days): Land CI security gates; generate secrets baseline; confirm Firebase rules strict.
- Phase 1 (1–2 weeks): Extend encryption to additional stores; implement data deletion/export; add telemetry.
- Phase 2 (2–6 weeks): Add pre-commit hooks, branch protections, dependency pinning.
- Phase 3 (1–3 months): Mature observability, SLOs, and compliance docs.

## Scope & Methodology

In scope:

- Flutter application code under `lib/`, tests under `test/`, project configs, and assets.
- Local persistence layers (Hive, SQLite) and Firebase client configuration.
- CI/CD within this repository.

Out of scope (assessed qualitatively where applicable):

- Firebase project configuration and security rules in the console (recommendations included).
- Third-party service backends not present in this repo.

Methods used:

- Static review of code and configurations, targeted searches over the codebase.
- Creation of automated scans: Semgrep, OSV dependency scan, and secrets scans.
- Light threat modeling focused on client data flows and auth.

## Security Controls Matrix (summary)

- Authentication: Firebase Auth (Google/Apple) on client; recommend enforcing MFA for admins and OAuth client/package/SHA restrictions.
- Authorization: No custom backend; depends on Firebase rules if Firestore/Storage are used later.
- Data at rest: Hive user box encrypted (this audit); SQLite not encrypted (recommend SQLCipher/column crypto).
- Data in transit: No custom HTTP clients; Firebase SDKs use HTTPS.
- Secrets management: Client configs committed (expected); add detect-secrets baseline and CI enforcement.
- CI/CD: Workflow added for analysis, tests, and scans.
- Logging/Observability: Minimal; recommend Crashlytics/Sentry and redaction.
- Dependency hygiene: OSV scanning configured in CI; consider pinning critical packages.

## Deliverables and Evidence

- Report: `docs/audit-report.md` (this file)
- Findings: `docs/findings.csv`
- DFD: `docs/dfd.mmd`
- CI workflow: `.github/workflows/security-audit.yml`
- Local scan script: `scripts/run-audit.sh`
- Semgrep rules: `.semgrep/semgrep.yml`
- Inventory utility: `tool/inventory.dart`
- Commit introducing these artifacts: see repository history (short SHA: 367e044)

## How to Run Scans Locally

Prereqs: Flutter SDK and Python 3 available.

Run the helper script from the repo root:

```bash
bash scripts/run-audit.sh
```

Optional: configure `SEMGREP_APP_TOKEN` in your shell to use Semgrep Cloud features.

## Sign-off

This audit provides an actionable baseline for a client-only Flutter app with Firebase Auth and local storage. The most impactful next steps are: encrypting SQLite or sensitive columns, enabling CI security gates end-to-end (with a maintained secrets baseline), and hardening Firebase project rules and OAuth restrictions. Implementing crash reporting and minimal analytics will materially improve detection and response.

## Appendix: SQLite Encryption Guide (SQLCipher or Column-Level Crypto)

Your app uses `sqflite` for persistence; by default it is not encrypted. You have two viable paths to add encryption:

1) Full-Database Encryption (SQLCipher)

Encrypts the entire DB file on disk with AES-256 so a copied `fitsense.db` is unreadable.

- Switch to SQLCipher

  In `pubspec.yaml`, replace sqflite with:

  ```yaml
  dependencies:
    sqflite_sqlcipher: ^2.3.0
  ```

  Remove `sqflite` to avoid conflicts (API is drop-in compatible).

- Generate/Store an Encryption Key

  Use `flutter_secure_storage` to store a random key bound to the OS keystore:

  ```dart
  import 'dart:convert';
  import 'dart:math';
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';

  final storage = const FlutterSecureStorage();
  var key = await storage.read(key: 'db_key');
  if (key == null) {
    final random = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    key = base64UrlEncode(random); // store URL-safe base64
    await storage.write(key: 'db_key', value: key);
  }
  final dbPassword = key; // pass this string to SQLCipher
  ```

- Open Encrypted Database

  In `lib/core/db/app_database.dart`, import SQLCipher and pass the password:

  ```dart
  import 'package:sqflite_sqlcipher/sqflite.dart';

  final db = await openDatabase(
    path,
    password: dbPassword,
    version: 2,
    onCreate: _createSchema,
    onUpgrade: _onUpgrade,
  );
  ```

- Handle Old Databases (Migration)

  Options:

  - Early-stage: detect an existing unencrypted DB and recreate it encrypted (rehydrate user profile from Hive if needed).
  - Export/import: open legacy DB without password, export rows, create encrypted DB, import rows table-by-table.

- Verify on Device

  ```bash
  # After running the app once
  adb shell run-as <your.package.name> cat databases/fitsense.db > fitsense.db
  # Opening fitsense.db with sqlite3 should fail (ciphertext)
  ```

2) Column-Level Encryption (Alternative)

Encrypt only sensitive fields while keeping SQLite unchanged.

- Keep `sqflite`, reuse the keystore key, and wrap fields with encrypt/decrypt (example using the `encrypt` package):

  ```dart
  import 'package:encrypt/encrypt.dart' as enc;

  final key = enc.Key.fromUtf8(dbPassword.padRight(32)); // 32 bytes
  final iv = enc.IV.fromLength(16);
  final encrypter = enc.Encrypter(enc.AES(key));

  String encryptField(String text) => encrypter.encrypt(text, iv: iv).base64;
  String decryptField(String base64) => encrypter.decrypt64(base64, iv: iv);
  ```

Trade-offs:

- ✅ Simpler migration; you can keep the existing DB.
- ❌ Schema/indexes and non-sensitive columns remain plaintext.
- ❌ Requires wrapping for every read/write site.

Recommendation for FitsenseAI: adopt SQLCipher (whole-DB protection), store the password only in `flutter_secure_storage`, and choose migration strategy based on your current install base.
