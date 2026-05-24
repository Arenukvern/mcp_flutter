---
name: flutter-mcp-toolkit-debug
description: Diagnose problems in a running Flutter app — read logs, evaluate Dart expressions, interpret error envelopes. Use when something broke.
---

<!-- @FMT_MODE_PRELUDE -->

## When to use

Use this skill when something broke and you need to understand why:

- A tool call returned an error envelope (`ok: false`).
- The app behaves unexpectedly and you need runtime log output.
- You need to inspect live app state without changing it (read `AgentState.instance.value`).
- A prior `control` action (tap, hot_reload, navigate) completed without error but the result is wrong.

Do NOT use this skill for:

- Reading what is currently on screen — use `flutter-mcp-toolkit-inspect`.
- The toolkit itself failing to connect — load `flutter-mcp-toolkit-setup`.

## Triage flow

1. **Error envelope returned?** Read `error.code` first, then `error.descriptor.retryable`. Look the code up in the Error envelope playbook below.
2. **Retryable error?** Run `flutter-mcp-toolkit doctor --json`. If doctor fails, load `flutter-mcp-toolkit-setup`.
3. **Need log output?** Call `get_recent_logs` with `count: 100` and a level filter. Look for stack traces or assertion messages near the timestamp of the failure.
4. **Need live state?** Call `evaluate_dart_expression` with a targeted expression (e.g. `MyBloc.instance.state.toString()`). Do this after logs, not instead of them.
5. **Chaining with inspect?** Order: `semantic_snapshot` → `evaluate_dart_expression` → `get_recent_logs`. Snapshot gives you the current widget tree before expression evaluation mutates nothing; logs give trailing context.
6. **Multiple targets?** If `connection_selection_required`, call `discover_debug_apps`, pick the `targetId`, then pass `connection: {targetId: "..."}` to every subsequent call.

## Tool reference

### get_recent_logs

Retrieve recent `print()` and `debugPrint()` output from the running app's main isolate.

- `count` • integer • optional, default: 50 — number of log lines to return.
- `connection` • object • optional — connection override; required when multiple debug apps are running.

```
get_recent_logs(count: 100)
get_recent_logs(count: 50, connection: {targetId: "ws://127.0.0.1:8181/<token>/ws"})
```

Returns: `{"logs": ["[INFO] page loaded", "[ERROR] assertion failed: ..."], "count": 50}`

Read-only; no code executed. Returns only lines buffered since last app start or hot restart. On failure see `getRecentLogsFailed` in the playbook.

### evaluate_dart_expression

Evaluate a Dart expression in the running app's main isolate and return its string representation.

- `expression` • string • **required** — Dart expression (e.g. `"MyClass.instance.counter"`).
- `connection` • object • optional — connection override.

```
evaluate_dart_expression(expression: "Navigator.of(context).canPop()")
evaluate_dart_expression(expression: "AgentState.instance.value.toString()")
```

Returns: `{"result": "42"}` — always a string-serialized value. Executes arbitrary code in the live isolate — avoid side-effecting expressions. Debug mode only. On failure see `evaluateExpressionFailed` in the playbook.

## Connect / multi-app flows

When `discover_debug_apps` returns more than one entry (or any call returns `connection_selection_required`):

1. Call `discover_debug_apps()` — read `targets[*].targetId` for each running app.
2. Identify the target by port or hostname.
3. Call `connect_debug_app(connection: {targetId: "ws://127.0.0.1:<port>/<token>/ws"})` to pin the session.
4. Pass the same `connection` object to every subsequent tool call for the session.

Connection override pattern — pass `connection` on any call:

```
get_recent_logs(count: 50, connection: {targetId: "ws://127.0.0.1:8182/<token>/ws"})
evaluate_dart_expression(expression: "x.toString()", connection: {targetId: "ws://127.0.0.1:8182/<token>/ws"})
```

If the target changes (app restarted, port shifted), re-run `discover_debug_apps` to get the new `targetId`. Stale URIs return `connect_failed`.

## Error envelope playbook

Every failure returns `{code, message, details, descriptor, recovery}`. Always read `error.descriptor` (not the top-level envelope) for `retryable` and `exitCode`. Run `error.recovery.fix_command` directly when provided.

### `unexpectedExecutorError` (`unexpected_executor_error`)

**Means:** unhandled exception in the command executor.
**Causes:** bug in the server; unexpected nil; unrecoverable VM state.
**Recovery:**

1. `flutter-mcp-toolkit doctor --json`
2. If doctor passes, retry once; if it recurs, file a bug with `error.details`.

### `connectFailed` (`connect_failed`)

**Means:** connection to the VM Service WebSocket failed.
**Causes:** wrong port, stale token, app not running.
**Recovery:**

1. `flutter-mcp-toolkit exec --name get_vm --args '{"connection":{"uri":"ws://127.0.0.1:8181/<token>/ws"}}'`
2. Get the exact URI from `app.debugPort.wsUri` in Flutter output.

### `vmNotConnected` (`vm_not_connected`)

**Means:** a VM-dependent command was called before a connection was established.
**Recovery:**

1. `flutter-mcp-toolkit exec --name status --args '{}'`
2. Then `flutter-mcp-toolkit doctor --json`.

### `connectionSelectionRequired` (`connection_selection_required`)

**Means:** multiple debug targets exist; an explicit target is required.
**Causes:** more than one Flutter app running in debug mode simultaneously.
**Recovery:**

1. `flutter-mcp-toolkit exec --name discover_debug_apps --args '{}'`
2. Pick the correct `targetId` from `details.availableTargets`.
3. Retry the original call with `connection: {targetId: "<chosen_id>"}`.

### `discoverDebugAppsFailed` (`discover_debug_apps_failed`)

**Means:** discovery scan of local VM Service ports failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `getVmFailed` (`get_vm_failed`)

**Means:** `get_vm` RPC to the VM Service failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `getExtensionRpcsFailed` (`get_extension_rpcs_failed`)

**Means:** listing registered extension RPCs failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `hotReloadFailed` (`hot_reload_failed`)

**Means:** hot reload was rejected by the Dart compiler or VM.
**Causes:** compile error in changed files; isolate in bad state.
**Recovery:**

1. `flutter-mcp-toolkit exec --name get_app_errors --args '{}'`
2. Fix the compile error, then retry.

### `hotRestartFailed` (`hot_restart_failed`)

**Means:** full hot restart failed.
**Recovery:** `flutter-mcp-toolkit doctor --json` — if VM is unreachable, restart the app manually.

### `getActivePortsFailed` (`get_active_ports_failed`)

**Means:** scan for active debug ports failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `getAppErrorsFailed` (`get_app_errors_failed`)

**Means:** retrieving app errors from the toolkit bridge failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `getScreenshotsFailed` (`get_screenshots_failed`)

**Means:** screenshot capture failed (wrong mode, host window not available, Simulator window race, etc.).
**Recovery:**

1. `flutter-mcp-toolkit doctor --json` — check `visual_capture_permission_denied` separately.
2. Check `captureHints.platformViewsDetected` on `get_view_details` or screenshot payloads. Detectors include `UiKitView`, `AppKitView`, `AndroidView`, and `HtmlElementView`. Black holes in `flutter_layer` PNGs usually mean native platform views — use `desktop_window` or `auto` on macOS host (including iOS Simulator). The repo showcase (`make showcase-stop` then `make showcase`) exposes a macOS `AppKitView` in its Capture section for routing smoke tests. Run `make showcase-stop` before starting another showcase or integration run to avoid orphaned `test_app` windows.
3. Run `focus_window` (MCP: `fmt_focus_window`) then retry `get_screenshots` with `mode: desktop_window`.
4. For **`validate-runtime`**, executor recovery retries focus+capture once (`desktopCaptureRetried`). When platform views are detected, validate-runtime does not fall back to `flutter_layer`. Read `capturePlatformViewsDetected`, `captureFocusAttempted`, and `captureFallbackUsed` in `data.summary`.

### `visualCapturePermissionDenied` (`visual_capture_permission_denied`)

**Means:** macOS Screen Recording permission is not granted.
**Recovery:**

1. `flutter-mcp-toolkit permissions request --kind visual_capture`
2. Or open System Settings → Privacy & Security → Screen Recording.

### `visualCaptureUnsupported` (`visual_capture_unsupported`)

**Means:** visual capture is not supported on this platform or capture mode. Not retryable.
**Recovery:** `flutter-mcp-toolkit permissions status && flutter-mcp-toolkit doctor --json`

### `getViewDetailsFailed` (`get_view_details_failed`)

**Means:** retrieving FlutterView dimensions failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `debugDumpFailed` (`debug_dump_failed`)

**Means:** a VM debug-dump RPC (render tree, semantics, layers) failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `dynamicRegistryDisabled` (`dynamic_registry_disabled`)

**Means:** a dynamic tool/resource call was made but the dynamic registry is disabled. Not retryable.
**Recovery:** `flutter-mcp-toolkit --dynamics exec --name status --args '{}'` — pass `--dynamics` flag to enable.

### `dynamicRegistryListFailed` (`dynamic_registry_list_failed`)

**Means:** listing dynamic tools/resources from the registry failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `missingToolName` (`missing_tool_name`)

**Means:** a dynamic tool call was made without providing a tool name. Not retryable.
**Recovery:** include `tool_name` parameter in the call; `flutter-mcp-toolkit schema --name fmt_client_tool`.

### `dynamicToolFailed` (`dynamic_tool_failed`)

**Means:** invocation of a dynamic tool failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `missingResourceUri` (`missing_resource_uri`)

**Means:** a dynamic resource read was called without a URI. Not retryable.
**Recovery:** include `uri` parameter; `flutter-mcp-toolkit schema --name fmt_client_resource`.

### `dynamicResourceFailed` (`dynamic_resource_failed`)

**Means:** reading a dynamic resource failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `sessionManagerNotConfigured` (`session_manager_not_configured`)

**Means:** a session command was called but no session manager is wired. Not retryable.
**Recovery:** `flutter-mcp-toolkit doctor --json` — server config issue; reload `flutter-mcp-toolkit-setup`.

### `sessionNotFound` (`session_not_found`)

**Means:** the requested session ID does not exist. Not retryable.
**Recovery:** list active sessions; start a new session before referencing it.

### `invalidCommand` (`invalid_command`)

**Means:** command name or argument schema is invalid. Not retryable.
**Recovery:** `flutter-mcp-toolkit schema --name <command_name>`

### `stateStoreReadFailed` (`state_store_read_failed`)

**Means:** reading from persistent state store failed.
**Recovery:** `flutter-mcp-toolkit doctor --json` — check filesystem permissions on state directory.

### `stateStoreWriteFailed` (`state_store_write_failed`)

**Means:** writing to persistent state store failed.
**Recovery:** `flutter-mcp-toolkit doctor --json` — check disk space and permissions.

### `stateLockTimeout` (`state_lock_timeout`)

**Means:** acquiring the state lock timed out (concurrent agent contention).
**Causes:** another agent or CLI call holds the lock; deadlock.
**Recovery:** wait and retry; if recurring, kill other agent processes holding the lock.

### `stateLockConflict` (`state_lock_conflict`)

**Means:** a conflicting state lock was detected.
**Causes:** parallel agents writing simultaneously.
**Recovery:** serialise calls; retry after the conflicting operation completes.

### `diagnoseFailed` (`diagnose_failed`)

**Means:** the composite `diagnose` command failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `explainErrorsFailed` (`explain_errors_failed`)

**Means:** the error-explanation command failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `unsupportedSummaryProvider` (`unsupported_summary_provider`)

**Means:** an unrecognised summary provider was requested. Not retryable.
**Recovery:** `flutter-mcp-toolkit schema --name diagnose` — check allowed `provider` values.

### `snapshotNotFound` (`snapshot_not_found`)

**Means:** the referenced snapshot ID does not exist. Not retryable.
**Recovery:** `flutter-mcp-toolkit snapshot create --name <snapshot_id> --args '{}'`

### `snapshotInvalid` (`snapshot_invalid`)

**Means:** snapshot payload is malformed or fails validation. Not retryable.
**Recovery:** recreate the snapshot; do not reuse corrupted files.

### `staleSnapshot` (`stale_snapshot`)

**Means:** the provided `snapshotId` no longer matches the current app state.
**Causes:** a hot reload or interaction changed the widget tree after the snapshot was taken.
**Recovery:**

1. `evaluate_dart_expression(expression: "true")` — verify app is reachable.
2. `semantic_snapshot()` — obtain a fresh snapshot ID, then retry the original call.

### `bundleBuildFailed` (`bundle_build_failed`)

**Means:** bundle creation or publish failed.
**Recovery:** `flutter-mcp-toolkit doctor --json` — check build artefacts and output path.

### `writeBlocked` (`write_blocked`)

**Means:** a write was blocked because `--no-overwrite` is set and the target already exists. Not retryable.
**Recovery:** retry without `--no-overwrite`, or choose a different `--output`/`--name`.

### `doctorCriticalFailed` (`doctor_critical_failed`)

**Means:** one or more critical doctor checks failed.
**Recovery:** `flutter-mcp-toolkit doctor --json` — read `checks[*]` where `status: "fail"` and `critical: true`; load `flutter-mcp-toolkit-setup`.

### `interactionFailed` (`interaction_failed`)

**Means:** a tap/scroll/swipe/drag/long_press/enter_text call failed.
**Causes:** stale `ref`; widget not visible or not interactive; toolkit bridge not initialized.
**Recovery:**

1. `semantic_snapshot()` — get fresh refs.
2. Retry with the new ref.

### `semanticSnapshotFailed` (`semantic_snapshot_failed`)

**Means:** `semantic_snapshot` execution failed.
**Recovery:** `flutter-mcp-toolkit doctor --json` — verify `MCPToolkitBinding.initialize()` is called.

### `evaluateExpressionFailed` (`evaluate_expression_failed`)

**Means:** `evaluate_dart_expression` execution failed.
**Causes:** expression syntax error; exception thrown at runtime; isolate not reachable.
**Recovery:** simplify the expression; check syntax; `flutter-mcp-toolkit doctor --json`.

### `getRecentLogsFailed` (`get_recent_logs_failed`)

**Means:** `get_recent_logs` retrieval failed.
**Recovery:** `flutter-mcp-toolkit doctor --json` — verify toolkit is initialized.

### `waitTimeout` (`wait_timeout`)

**Means:** `wait_for` predicate did not match before `timeoutMs` elapsed.
**Causes:** predicate condition never becomes true; app state does not change; `timeoutMs` too short.
**Recovery:**

1. `semantic_snapshot()` — verify the expected widget state.
2. Increase `timeoutMs` or adjust the predicate.

### `waitForFailed` (`wait_for_failed`)

**Means:** `wait_for` execution failed (malformed predicate or toolkit error).
**Recovery:** `flutter-mcp-toolkit schema --name wait_for`

### `pressKeyFailed` (`press_key_failed`)

**Means:** `press_key` execution failed.
**Recovery:** `flutter-mcp-toolkit schema --name press_key`

### `handleDialogFailed` (`handle_dialog_failed`)

**Means:** `handle_dialog` (dismiss/accept dialog) execution failed.
**Causes:** no dialog present; dialog already dismissed.
**Recovery:** `semantic_snapshot()` — verify a dialog is visible before calling.

### `navigateFailed` (`navigate_failed`)

**Means:** `navigate` push/pop/popUntil failed.
**Recovery:** `flutter-mcp-toolkit schema --name navigate`

### `navigatorNotRegistered` (`navigator_not_registered`)

**Means:** `navigate` was called but the app did not register a `GlobalKey<NavigatorState>`. Not retryable.
**Causes:** `MCPToolkitBinding.instance.navigatorKey` was never set in the host app.
**Recovery:** assign `MCPToolkitBinding.instance.navigatorKey = navigatorKey` in the app's `main.dart` and hot restart.

### `fillFormFailed` (`fill_form_failed`)

**Means:** `fill_form` orchestration failed (transport or per-field error).
**Recovery:** `flutter-mcp-toolkit schema --name fill_form`

### `hoverFailed` (`hover_failed`)

**Means:** `hover` execution failed.
**Recovery:** `flutter-mcp-toolkit doctor --json`

### `unknown` (`unknown_error`)

**Means:** fallback for any unrecognised error code.
**Recovery:** `flutter-mcp-toolkit doctor --json` — inspect `error.details` for raw cause.
