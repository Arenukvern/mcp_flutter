---
name: flutter-mcp
description: Use this skill whenever inspecting, interacting with, or live-editing a running Flutter app via the flutter-inspector MCP server. Covers preflight, snapshot/tap/enter/scroll loop, hot-reload validation, and error envelope parsing.
---

# Flutter MCP

Golden path for agents driving a live Flutter app via the `flutter-inspector` MCP server.

## When to use

- User references a running Flutter app (debug mode) and wants to inspect, screenshot, interact with, or hot-reload it.
- User pastes a VM service URI (`ws://127.0.0.1:8181/.../ws`) or mentions port 8181.
- You need runtime proof (before/after screenshots) that a code edit took effect.

## Preflight (always first)

Before any VM-dependent call:

1. Call `doctor` (or run `flutter_mcp_cli doctor --json`) — parses env, ports, app reachability.
2. Confirm required toolkit extensions exist on the target:
   - `ext.mcp.toolkit.app_errors`
   - `ext.mcp.toolkit.view_details`
   - `ext.mcp.toolkit.view_screenshots`
   - `ext.mcp.toolkit.inspect_widget_at_point`

If missing, stop and report the instrumentation gap — do **not** guess:

- Add `mcp_toolkit` to `pubspec.yaml`.
- Ensure `MCPToolkitBinding.instance..initialize()..initializeFlutterToolkit();` runs before `runApp`.
- Hot **restart** (not reload) — reload is often insufficient for extension registration.

## Tool naming (v3.0.0+)

All MCP tools surface under the `fmt_` capability prefix
(`fmt_tap_widget`, `fmt_hot_reload_and_capture`, etc.). The prefix is
mandatory in `tools/call`. Skill-local references below use the bare name
for readability — when invoking, prepend `fmt_`. The dynamic-registry
host tools (`listClientToolsAndResources`, `runClientTool`,
`runClientResource`) stay unprefixed — they are server machinery, not part
of the capability surface.

## Interaction loop (Playwright-style)

1. `fmt_semantic_snapshot` → returns `s_0..s_N` refs + `snapshot_id`.
2. `fmt_tap_widget` / `fmt_enter_text` / `fmt_scroll` / `fmt_swipe` / `fmt_long_press` / `fmt_drag` — act on a ref. **Always pass `snapshotId`** — you get a structured `stale_snapshot` error if the tree moved, instead of a silent wrong tap.
3. `fmt_evaluate_dart_expression` — read state directly (e.g. `AgentState.instance.counter`).
4. `fmt_hot_reload_and_capture` — after a code edit, returns reload status + screenshot + fresh snapshot + errors in one response. Prefer this over manual reload + separate capture.

## Error envelope contract

Errors are `{code, message, details, descriptor, recovery}`. Parse `error.descriptor` (not the top-level object) for the machine-readable shape. Strict schemas default to `additionalProperties: false` — unknown params reject.

Common codes and recovery:

- `connection_selection_required` — retry with `arguments.connection.targetId` or exact `arguments.connection.uri` from `app.debugPort.wsUri`.
- `target_not_found` — refresh targets, then prefer exact `arguments.connection.uri`.
- `stale_snapshot` — call `fmt_semantic_snapshot` again, then retry the action with the new `snapshot_id`.
- `tool_not_found` — confirm the prefixed name (`fmt_<tool>`); v3.0.0 dropped legacy unprefixed names.
- Empty screenshot output — verify the server was not started with `--no-images`.
- Missing view resource/tool — verify the server was not started with `--no-resources`.

## Visual QA

- Before/after screenshots are the proof artifact for any UI claim. Capture before with `fmt_capture_ui_snapshot` (or one of the `visual://localhost/...` resources), edit, `fmt_hot_reload_and_capture`, compare.
- For each reported visual issue, attach coordinate + `fmt_inspect_widget_at_point` output.
- Map defects to source via `fmt_get_app_errors` top stack frame (`file`, `line`, `column`) when available.
- Do **not** use `fmt_debug_dump_*` unless explicitly requested (server must be started with `--dumps`; high token cost).

## Permissions (macOS)

Screen Recording permission belongs to the process running `flutter_mcp_cli` (or the MCP server host). If visual capture is denied:

```bash
flutter_mcp_cli permissions status
flutter_mcp_cli permissions request
flutter_mcp_cli permissions open-settings
```

## Non-modifiable apps

If the target app cannot be instrumented (third-party binary, restricted env), report flutter-mcp as unavailable for that app. Do **not** claim screenshot/layout/error inspection success.

## Related

- For the dynamic-tools side (registering custom MCP tools from inside the Flutter app), see the `custom-toolkit-tools` skill.
- For a guided live-edit refinement session, use the `/flutter-live-edit` command.
