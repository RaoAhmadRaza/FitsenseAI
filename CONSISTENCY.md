# Local Plan & Session Consistency Strategy

This document outlines how workout plan templates (Hive primary + SQLite mirror) maintain integrity and recover from partial failures.

## Layers
- Source of Truth (Local): Hive boxes
  - `workoutPlanBox` stores `WorkoutPlan` objects with embedded `PlanExercise` lists and equipment array.
- Mirror: SQLite tables
  - `workout_plans`, `workout_plan_exercises`, `workout_plan_equipment`

## Write Path
1. Mutations apply to Hive first (fast, synchronous, low-latency).
2. A mirror call runs (best-effort) to persist normalized rows in SQLite.
3. Errors during mirror are caught and logged; user flow not blocked.

## Failure Modes & Recovery
| Failure | Impact | Recovery Strategy |
|---------|--------|------------------|
| Hive write fails (rare disk/full) | Mutation aborted | Surface error upstream (future UI), do not attempt mirror. |
| SQLite unavailable (migration error, file lock) | Mirror incomplete | Log error, schedule lazy retry on next mutation or explicit `reconcile()` call. |
| Partial mirror (plan row written but exercises not) | Inconsistent analytics / queries | Next mutation executes full `replace*` operations which overwrite stale subsets (idempotent). |
| App crash mid-mirror | Same as partial | Idempotent replace ensures consistency later. |

## Idempotency Guarantees
- `upsertWorkoutPlan`: replace semantics — safe to call repeatedly.
- `replacePlanExercises` / `replacePlanEquipment`: delete-then-insert pattern guarantees final state matches Hive snapshot at invocation time.

## Reconciliation Hook (Future)
A background reconciliation can:
1. Iterate all plans in Hive.
2. For each plan, re-run `_mirrorPlan(plan)` (forced refresh) if a last-mirror timestamp > X minutes or error flag set.
3. Clear error flags on success.

Potential location: `WorkoutsCubit.load()` after seeding OR a dedicated `ConsistencyService` invoked at app cold start.

## Integrity Checks
Add lightweight assertions (optional):
- Count exercises in Hive vs `SELECT COUNT(*)` in SQLite for a random subset of plans.
- Log discrepancy metrics for telemetry.

## Edge Handling
- Duplicate exercise IDs in same plan: last one wins due to unique constraint in SQL (plan_id, exercise_id) via replace.
- Removal uses full replacement list; ensures no orphan rows remain.

## Future Enhancements
- Write-ahead queue: persist pending mirror tasks if offline / locked; retry on resume.
- CRC hash per plan stored in mirror table for fast drift detection.
- Telemetry counters for mirror success/failure rates.

## Testing Focus
- Simulate mirror failure (inject exception) -> verify Hive persisted and second mutation reconciles.
- Add/remove exercise sequences maintain accurate counts.

---
This strategy keeps runtime logic simple while enabling future robustness layers without breaking current UI constraints.
