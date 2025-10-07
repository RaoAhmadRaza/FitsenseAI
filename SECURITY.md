# Security Policy

This document outlines how we handle security for the FitsenseAI project.

## Supported Versions

We maintain security fixes on the main branch. Versioned releases will inherit fixes as they are cut.

## Reporting a Vulnerability

Please email the maintainers or open a private advisory on GitHub (if enabled). Provide:

- A clear description of the issue and potential impact
- Steps to reproduce or a proof of concept
- Affected files and commit SHAs

We aim to acknowledge within 72 hours and provide an ETA for a fix or mitigation.

## Hardening Checklist (client)

- [ ] Encrypt sensitive Hive boxes (done: userBox)
- [ ] Encrypt SQLite (SQLCipher or column-level crypto)
- [ ] Add Crashlytics/Sentry with redaction
- [ ] Block PII in logs; scrub error messages
- [ ] Enforce CI checks (analyze, tests, Semgrep, OSV, secrets)
- [ ] Maintain detect-secrets baseline and pre-commit hooks

## Firebase Checklist (out-of-repo)

- [ ] Lock down Firestore/Storage rules with least privilege
- [ ] Restrict OAuth client to correct package IDs + SHA-1/256
- [ ] Enable MFA for Firebase project admins
- [ ] Monitor usage anomalies; set alerts
