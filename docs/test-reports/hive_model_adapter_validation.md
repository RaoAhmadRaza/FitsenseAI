# Hive Model & Adapter Validation

Goal: Confirm Altrix Hive adapters serialize and deserialize new fields without runtime errors and preserve backward compatibility.

Date: 2025-10-10
Scope:
- Models: `AltrixMessage`, `AltrixThread`
- Adapters: `AltrixMessageAdapter` (typeId 30), `AltrixThreadAdapter` (typeId 31)

## Preconditions
- App builds and runs in debug.
- Adapters are registered at startup (see `lib/main.dart` after `Hive.initFlutter()`).

TypeId map:
- 30 → AltrixMessage
- 31 → AltrixThread

New fields:
- AltrixMessage: `status`, `tokensUsed`, `latencyMs`, `isGeminiResponse`
- AltrixThread: `model`, `promptCount`, `avgLatencyMs`

## 1) Startup smoke test
- Launch the app (debug).
- Observe logs for any Hive adapter errors (e.g., `HiveError: Cannot read, unknown typeId`). Expected: none.
- Optional logging (if added): "AltrixMessageAdapter registered" and "AltrixThreadAdapter registered".

## 2) Console verification (assert adapters registered)
Add the following one-time assertions in `main.dart` immediately after the adapter registration block.

```dart
assert(Hive.isAdapterRegistered(30)); // AltrixMessageAdapter
assert(Hive.isAdapterRegistered(31)); // AltrixThreadAdapter
```

Expected: Both assertions pass without crashing in debug.

Remove after validation to avoid leaving asserts in production builds.

## 3) Runtime field check (backward compatibility + new fields)
Use a quick dev-only snippet (e.g., in a debug screen or `main.dart` inside an async init block) to read an existing message and print fields.

```dart
final msgBox = await Hive.openBox<AltrixMessage>('altrix_messages');
if (msgBox.isNotEmpty) {
  final msg = msgBox.values.first;
  debugPrint('status=${msg.status}, tokens=${msg.tokensUsed}, latencyMs=${msg.latencyMs}, gemini=${msg.isGeminiResponse}');
}
```

- For older entries (created before adding new fields), expected:
  - `status=success, tokens=0, latencyMs=0, gemini=false`
- For new entries (after the update), expected values reflect what was stored by the repository when sending messages.

## 4) Create-and-send flow (manual)
- Start a new chat and send a message.
- Expected:
  - User message initially `status='sending'` (visible in UI spinner), then transitions to `success`.
  - Assistant reply includes metadata; persisted as:
    - `status='success'`, `tokensUsed` > 0 (e.g., 120 for the simulated reply), `latencyMs` > 0, `isGeminiResponse=true` for simulated Gemini path.

Optional: Inspect via the DB inspector or by reading from Hive boxes:

```dart
final threadBox = await Hive.openBox<AltrixThread>('altrix_threads');
final t = threadBox.get(yourThreadId);
if (t != null) {
  debugPrint('model=${t.model}, prompts=${t.promptCount}, avgLatencyMs=${t.avgLatencyMs}');
}
```

Expected for threads: `model=gemini-2.0-flash`, `promptCount` increments per assistant reply, `avgLatencyMs` is a running average.

## Expected Outcomes
- No adapter version conflicts or unknown typeId errors.
- Old records load with default values for new fields (no crashes).
- New records persist and reload extra fields correctly.
- Thread analytics (`promptCount`, `avgLatencyMs`) update after assistant replies.

## Troubleshooting
- If you see `unknown typeId` on startup, ensure:
  - Adapters are registered before opening boxes.
  - TypeIds match (`30` for messages, `31` for threads).
- If fields are null or missing:
  - Confirm manual adapters read with defaults.
  - Verify the writeByte count includes all fields (10 for both models currently).
- If boxes fail to open:
  - Confirm encryption setup and keys; ensure the same AES key is used across boxes.

## Clean-up
- Remove any temporary asserts and debug prints after validation.
- Keep this document under `docs/test-reports/` for future regression checks.
