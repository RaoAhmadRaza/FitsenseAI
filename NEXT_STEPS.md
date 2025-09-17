# Workout Session Layer – Next Steps

1. UI Integration (Phase 1 Complete)
   - Ongoing Workout panel now bound to `SessionCubit` (duration live, Resume enabled when session active).
   - Resume navigation pushes `Inividualworkout` with `sessionWorkoutId`.
   - Ticking handled internally (5s) – optional visual indicator still pending.
   - Thumbnails still static; future: derive from most recent ExerciseSets.

2. Duration Tracking Enhancements (Partially Complete)
   - 5s periodic ticker implemented.
   - Reconciliation added: on refresh recompute via wall-clock and adjust upward drift.
   - Future: adaptive intervals (active vs idle), down-drift prevention for clock changes.

3. Enhanced Exercise Granularity (Phase 2 Advanced)
   - Hive `ExerciseSet` + repository APIs implemented.
   - SQLite `exercise_sets` table added with upsert (unique per session/exercise/set_index).
   - Future: computed metrics (session volume, per-exercise density) and RPE/tempo fields.

4. Migration Strategy
   - Bump DB version when adding tables; implement `onUpgrade` migration path.
   - Provide one-off Hive migration if changing `WorkoutSession` field layout (e.g., adding calories, heartRateAvg).

5. Data Validation & Cleanup (Initial)
   - Stale session auto-complete: sessions >8h auto-completed during refresh.
   - Future: configurable threshold + user prompt, archival of abandoned duplicates.

6. Analytics & Insights
   - Aggregate volume (Σ weight * reps) per muscle group.
   - Track personal bests (per lift: 1RM estimate via Epley, heaviest set, max reps @ weight).
   - Session qual score: density (reps per minute) & consistency (variance of rest durations) – later.

7. Sync & Cloud Backup (Future)
   - Add optional cloud sync (e.g., Firestore) with conflict resolution using `date` + monotonic local revision.
   - Provide export/import (JSON) for portability.

8. Performance Considerations
   - Introduce in-memory LRU cache if sessions grow large (limit to recent N in Hive, archive old to SQLite only).
   - Lazy load progress details when opening historical session view.

9. Testing (Planned)
   - Pending: repository lifecycle tests (start→reconcile→complete), set mirroring, stale cleanup.
   - Add harness for temporary directory DB + in-memory Hive boxes.

10. Observability
   - Pending: structured logs around reconciliation, stale cleanup, resume navigation events.
   - Future: event batching & privacy toggles.

11. Upcoming Small Wins
   - Visual ticker pulse / subtle shimmer when session active.
   - Show last completed session summary (duration, sets) under panel.
   - Provide cancel/end button inside resume flow.

---
This document scopes future iterations while keeping the current implementation intentionally minimal and non-invasive to existing workflows.
