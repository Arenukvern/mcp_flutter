---
name: flutter-mcp-cli-runtime-validation
description: Run Flutter MCP runtime validation from CLI in two steps (launch app, then run validate-runtime), including toolkit-extension gating, screenshot/layout capture, app error collection, optional reload verification, and retry handling for transient first-connect failures.
---

<!-- @FMT_MODE_PRELUDE -->

# Flutter MCP CLI Runtime Validation

Use this skill when you need agent-style runtime validation through `flutter-mcp-toolkit` with minimal operator steps.

## Two-Step Flow

1. Launch the Flutter app in debug mode.
2. Run one CLI command:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart --save-images --output-dir .flutter_mcp/runtime_validation validate-runtime \
  --target ws://127.0.0.1:8181/<token>/ws \
  --timeout-ms 10000 \
  --post-reload-delay-ms 500 \
  --after-reload
```

Optional skill install in the same command:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart validate-runtime \
  --target ws://127.0.0.1:8181/<token>/ws \
  --install-skill
```

Permission behavior for this flow:

- `validate-runtime` stays read/write only for visual capture and defaults to `auto_request_once`.
- `doctor` remains read-only.
- On macOS, Screen Recording permission belongs to the host process running `flutter-mcp-toolkit`.
- On web: `desktop_window` uses macOS ScreenCaptureKit then Chrome CDP (`Page.captureScreenshot`); Linux/Windows use CDP when remote debugging is reachable. Pass `--web-browser-debugging-port` if discovery fails. For web targets, pass `--flutter-device chrome` so validation does not pick macOS host `desktop_window` by mistake.
- Executor recovery retries host capture once (`desktopCaptureRetried` in screenshot payloads). If `desktop_window` still fails (including when platform views are detected), `validate-runtime` retries once with `flutter_layer`. Check `data.summary.captureFallbackUsed`.
- You may pass the VM URI as global `--vm-service-uri` instead of `validate-runtime --target` when only one URI is needed.

## What `validate-runtime` Must Prove

- Doctor preflight passes critical checks.
- Required toolkit extensions exist:
  - `ext.mcp.toolkit.app_errors`
  - `ext.mcp.toolkit.view_details`
  - `ext.mcp.toolkit.view_screenshots`
  - `ext.mcp.toolkit.inspect_widget_at_point`
- Screenshot capture works.
- View details (layout metadata) are available.
- App errors are retrievable.
- If `--after-reload` is enabled, post-reload screenshot also works.

## Output Handling

- Use `data.summary` as pass/fail status for automation.
- Use `data.summary.capturePlatformViewsDetected` and `captureFocusAttempted` for platform-view routing.
- Use `data.summary.captureFallbackUsed` to see whether a `flutter_layer` retry ran (skipped when platform views were detected).
- Use `data.steps` for per-step evidence and retries.
- Use `data.doctor.checks` to explain setup blockers.
- Use `data.summary.screenshotFiles` for saved screenshot paths when `--save-images` is enabled.
- When `--save-images` is enabled, read screenshot file URLs from step data.
- For visual debugging reports, also run:
  - `exec --name capture_ui_snapshot --args '{"errorsCount":4,"compress":true,"includeViewDetails":true,"includeErrors":true}'`
  - `exec --name inspect_widget_at_point --args '{"x":<int>,"y":<int>}'`

## Failure Rules

- If toolkit extensions are missing, stop and report instrumentation gap with exact fix:
  - add `mcp_toolkit` to app dependencies
  - ensure `MCPToolkitBinding.instance.bootstrapFlutter(...)` or equivalent manual initialization runs before `runApp`
  - hot restart or rerun the app
- If first explicit URI connect fails, retry is automatic for retryable connection errors.
- If screenshots are blank, verify app window is visible and retry.
- If macOS visual capture is denied, use:
  - `dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart permissions status`
  - `dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart permissions request`
  - `dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart permissions open-settings`
- If app cannot be instrumented, do not claim screenshot/layout/error inspection success.

## Visual QA + Source Mapping Rules

- Always compare before/after screenshot evidence around changes.
- For each reported visual issue, provide coordinate + `inspect_widget_at_point` output.
- Map defects to source using `get_app_errors` top stack frame (`file`, `line`, `column`) when available.
- Do not use `debug_dump_*` unless explicitly requested.

## Challenge Cases (Always Call Out Explicitly)

- No running debug app: `doctor` critical failure on `vm_target_reachable`; request app launch before continuing.
- Wrong target URI/token: treat as connection mismatch and retry with exact `app.debugPort.wsUri`.
- Toolkit added but still missing extensions: hot reload is often insufficient, require hot restart/full rerun.
- Non-modifiable app (cannot add toolkit): report inspection as unavailable instead of guessing.
