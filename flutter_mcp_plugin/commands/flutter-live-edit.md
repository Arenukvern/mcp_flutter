---
description: Start a live-edit session against a running Flutter app — preflight, connect, snapshot, and enter the edit→reload→verify loop.
---

# /flutter-live-edit

Kick off a live-edit session against a running Flutter app. Runs preflight, connects to the VM service, captures a baseline, then hands control back for the edit loop.

## Arguments

Optional VM service URI can be passed as the first argument (e.g. `/flutter-live-edit ws://127.0.0.1:8181/abc/ws`). If omitted, the agent should discover targets via the MCP server.

## Procedure

1. **Preflight.** Call the `doctor` MCP tool (or `flutter_mcp_cli doctor --json`). If any critical check fails, stop and report — do not attempt to capture state from an unreachable app.

2. **Connect.** If a URI was provided, use it as `arguments.connection.uri`. Otherwise list debug apps via the MCP server and pick the target (if >1, ask the user).

3. **Verify instrumentation.** Confirm these extensions are registered:
   - `ext.mcp.toolkit.app_errors`
   - `ext.mcp.toolkit.view_details`
   - `ext.mcp.toolkit.view_screenshots`
   - `ext.mcp.toolkit.inspect_widget_at_point`

   If any are missing, stop and report the instrumentation gap (see the `flutter-mcp` skill for the exact fix).

4. **Baseline capture.** Run `core_capture_ui_snapshot` with `{"errorsCount":4,"compress":true,"includeViewDetails":true,"includeErrors":true}`. Save the screenshot path and snapshot_id.

5. **Announce readiness.** Report to the user: target URI, baseline screenshot path, and any pre-existing errors. Then ask what they want to edit or inspect.

6. **Edit loop** (after user instruction):
   - Make the code change.
   - `core_hot_reload_and_capture` — returns reload status + fresh screenshot + snapshot + errors.
   - If errors regressed, surface the top stack frame (`file:line:col`) before proposing a fix.
   - Compare before/after screenshots and describe the visual delta in one or two sentences.

7. **Exit criteria.** Stop the loop when the user says so, or when three consecutive reloads fail with the same error (escalate).

## Notes

- Hot **reload** is the default. Only hot **restart** (full rerun) when extensions go missing or state needs to reset.
- If the user is iterating on live-edit overlay widgets themselves (bubble, panel, chips), suggest they run the `live_edit_tooling_ui_kit` app — it renders the tool layer with prefilled data so they can iterate without the MCP roundtrip.
- Honor the error envelope contract: parse `error.descriptor`, not the top-level.
