# Edge Cases & Error Handling

This document enumerates potential edge cases for workout sessions, plan templates, and exercise tracking along with current or planned handling strategies.

## 1. Workout Session Lifecycle
| Scenario | Description | Current Handling | Future Enhancement |
|----------|-------------|------------------|--------------------|
| Duplicate session start | User triggers start while one is ongoing | Existing ongoing marked completed before new start (repository) | Offer resume prompt instead of auto-complete |
| System clock change backwards | Duration reconciliation could shrink | We only ever increase duration (no shrink) | Record wall-clock + monotonic delta for higher accuracy |
| Crash during session | App killed mid-session | Session restored from Hive; duration reconciled on refresh | Persist last tick timestamp for tighter accuracy |
| Stale session (left overnight) | User forgets to finish | Auto-complete after 8h | Make threshold configurable per user |
| Complete with no exercises | User starts then finishes | Allowed; stored as empty progress | Prompt user: discard or keep |
| Large session duration overflow | Extremely long session (multi-day) | int seconds accumulates; unlikely overflow | Switch to BigInt if needed (far future) |

## 2. Exercise Progress Tracking
| Scenario | Description | Current Handling | Future Enhancement |
|----------|-------------|------------------|--------------------|
| Increment reps before startExercise | User taps rep immediately | incrementRep auto-starts exercise | Visual feedback that exercise was auto-started |
| completeSet with 0 reps | User finishes set prematurely | Allowed (logs 0 reps set) | Validate > 0 unless forced override |
| Negative/zero delta in incrementRep | Provided by mistake | Ignored (delta <= 0 early return) | Log warning in debug mode |
| Weight changes mid exercise | User updates weight | Last usedWeight captured on set completion | Add field per set for variance analytics |
| Time spent not tracked per exercise | Timer only in UI | timeSpentSeconds increments via default in completeSet | Add optional periodic timeSpent updates |

## 3. Per-Set Logging
| Scenario | Description | Current Handling | Future Enhancement |
|----------|-------------|------------------|--------------------|
| Duplicate set index | Same setIndex passed twice | REPLACE semantics (SQLite) + overwrite in Hive list (we store sets separately) | Detect and warn user |
| Out-of-order set indexes | Logging set 5 before 4 | Accepted; consumer sorts by setIndex | Enforce sequential sets unless override flag |
| Very large reps/weight values | Accidental large input | Stored raw | Add client-side validation caps |
| DurationSeconds mismatch | Provided duration unrealistic | Stored raw | Compute from timestamps automatically |

## 4. Workout Plans (Templates)
| Scenario | Description | Current Handling | Future Enhancement |
|----------|-------------|------------------|--------------------|
| Seeding rerun after edits | User edits defaults then app restarts | seedDefaultsIfEmpty prevents overwrite | Versioned seed with migration transform |
| Duplicate exercise IDs in a plan | Two exercises share id | Last write wins (unique constraint) | Reject duplicate with human-readable error |
| Mirror failure for plan | SQLite locked/unavailable | Hive remains source; error logged | Retry queue + exponential backoff |
| Plan deletion (not implemented) | Removing a plan | Not yet supported | Add deletePlan + cascade in mirror |

## 5. Data Consistency & Mirroring
| Scenario | Description | Current Handling | Future Enhancement |
|----------|-------------|------------------|--------------------|
| Partial mirror (plan only) | Plan row written, exercises failed | Next mutation does full replace | Periodic reconciliation pass |
| Session mirror race | Rapid updates faster than mirror | Last successful update persists | Debounce / transaction batching |
| Hive corruption | Box unreadable | Not handled | Attempt box recovery & fallback to SQLite snapshot |

## 6. UI Interaction Edge Cases
| Scenario | Description | Current Handling | Future Enhancement |
|----------|-------------|------------------|--------------------|
| Pressing Complete Rep after workout done | Buttons still active momentarily | completeSession no-ops if already completed | Disable buttons via state after completion |
| Fast tapping rep button | Multiple rapid increments | Each processed; sync overhead minimal | Aggregate burst increments before persist |
| Navigating away mid-set | User leaves screen | Ticker continues; state safe | Auto-pause on background with callback |

## 7. Error Surfaces
Currently most repository errors are swallowed (logged) to avoid user disruption. Future improvements:
- Expose transient error flags in SessionState / WorkoutsState.
- Surface non-blocking snackbars for mirror failures in debug builds.

## 8. Validation Checklist (Future)
| Validation | Rule | Location |
|-----------|------|----------|
| Reps range | 0 <= reps <= 200 | UI input layer |
| Weight range | 0 <= weight <= 1000 | UI input layer |
| Set index monotonic (optional) | next == prev + 1 | SessionCubit (optional flag) |

---
This document will evolve as more UI surfaces and analytics features are added.
