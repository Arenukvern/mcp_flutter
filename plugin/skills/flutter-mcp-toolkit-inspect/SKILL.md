---
name: flutter-mcp-toolkit-inspect
description: Read state from a running Flutter app — semantic snapshot, view details, errors, screenshots, VM info. Use when you need to understand what the app is showing.
---

<!-- @FMT_MODE_PRELUDE -->

## When to use

Use this skill for read-only state inspection of a running Flutter app: what is shown on screen, recent errors, available debug targets, VM metadata, and widget tree details. Do not use for driving interaction — that is the interact skill. Start with `discover_debug_apps` when no connection target is established. Start with `semantic_snapshot` when you need to know which widgets are on screen.

## Recipes

### Fast inspect cycle (prefer `batch`)

```bash
flutter-mcp-toolkit batch --steps '[
  {"name":"semantic_snapshot"},
  {"name":"get_app_errors","args":{"count":5}},
  {"name":"get_screenshots","args":{"mode":"flutter_layer","compress":true}}
]'
```

Use `mode: flutter_layer` on `get_screenshots` on macOS to avoid Screen
Recording permission failures. `capture_ui_snapshot` uses the separate
`screenshotMode` field.

### Snapshot the visible UI

1. Call `semantic_snapshot()`.
2. Read `interactionSurface`: `flutter_widgets` (tap-by-ref works), `hybrid` (sparse semantics), `game_canvas` (use `evaluate_dart_expression` + screenshots).
3. Each interactive node has a stable `ref` (`s_0`, `s_1`, …) and the response includes a `snapshot_id`.
4. Pass refs to interaction tools; pass the `snapshot_id` value as `snapshotId` to detect staleness.

### After a code edit

Prefer `hot_reload_and_capture` over separate reload + snapshot + screenshot calls.

### Find an error by message

1. Call `get_app_errors(count: 10)`.
2. Inspect the `errors` array — each entry has message, stack trace, and timestamp.
3. Match on message text to find the source.

### List debug-mode apps

1. Call `discover_debug_apps()`.
2. Read the `targetId` (canonical WebSocket URI) for each active target.
3. Pass the chosen URI as `connection.targetId` on subsequent tool calls.

### Get widget at coordinates

1. Call `inspect_widget_at_point(x: 200, y: 400)`.
2. The response identifies the deepest widget and render node at those global logical pixel coordinates.

### Save a screenshot to a file

1. Call `get_screenshots()`.
2. If `meta.fileUrls` is non-empty, screenshots are on disk at those paths. Otherwise the response contains base64 `ImageContent` blocks — extract and write manually.
3. To force file output, configure an images output directory on the server before calling.

## Tool reference

### discover_debug_apps

List all active Flutter debug targets with canonical WebSocket URIs.

- `connection` (object, optional) — accepted by schema, ignored by executor; discovery is always local.

```
discover_debug_apps()
```

Returns: `{"targets": [{"targetId": "ws://127.0.0.1:8181/<token>/ws", "host": "...", "port": 8181}]}`

- `vm_service_unavailable` — no debug-mode Flutter process found.
- `tool_not_found` — binary predates v3.0.0; run `make build`.

### get_app_errors

Retrieve the most recent application errors from the Dart VM.

- `count` (integer, optional, default: 4) — number of errors to return.
- `connection` (object, optional) — connection override.

```
get_app_errors(count: 5)
```

Returns: `{"message": "2 errors found", "errors": [{"message": "...", "stack": "..."}]}`

- `vm_service_unavailable` — app not reachable.
- `connection_selection_required` — multiple targets; supply `connection.targetId`.

### get_screenshots

Capture screenshots of all views.

- `compress` (boolean, optional, default: true) — compress PNG output.
- `mode` (string, optional, default: `auto`) — `auto`, `flutter_layer`, or `desktop_window`.
- `permissionPolicy` (string, optional, default: `check_only`) — `check_only`, `auto_request_once`, or `request_always`.
- `connection` (object, optional) — connection override.

```
get_screenshots(mode: "flutter_layer", compress: false)
```

Returns: `ImageContent` blocks (base64 PNG) when no output dir configured, or `TextContent` URL refs + `meta.fileUrls` when file output is enabled.

- `permission_denied` — retry with `permissionPolicy: "auto_request_once"`.
- `vm_service_unavailable` — app not reachable.

### get_view_details

Get dimensions, device pixel ratio, and display ID for all views.

- `connection` (object, optional) — connection override.

```
get_view_details()
```

Returns: `{"views": [{"id": 0, "width": 1280, "height": 800, "devicePixelRatio": 2.0}]}`

- `vm_service_unavailable` — app not running.
- `connection_selection_required` — multiple targets; supply `connection.targetId`.

### get_vm

Return Dart VM metadata: version, isolates list, pid, and architecture.

- `connection` (object, optional) — connection override.

```
get_vm()
```

Returns: `{"type": "VM", "name": "vm", "version": "3.x.x", "isolates": [...]}`

- `vm_service_unavailable` — app not reachable.
- `connection_selection_required` — multiple targets active.

### get_extension_rpcs

List all registered VM service extension RPCs in the running app.

- `isolateId` (string, optional) — schema-declared but not read by executor; checks all isolates when omitted.
- `isRawResponse` (boolean, optional) — schema-declared but not read by executor.
- `connection` (object, optional) — connection override.

```
get_extension_rpcs()
```

Returns: `{"extensionRPCs": ["ext.flutter.inspector.getRootWidget", "ext.mcp.toolkit.semantic_snapshot"]}`

- `vm_service_unavailable` — app not running.
- `connection_selection_required` — multiple targets.

### semantic_snapshot

Return a compact accessibility tree of interactive widgets with stable `ref` strings and a `snapshot_id`.

- `connection` (object, optional) — connection override.

```
semantic_snapshot()
```

Returns: `{"snapshot_id": 3, "nodes": [{"ref": "s_0", "label": "Increment", "actions": ["tap"]}]}`

- `vm_service_unavailable` — app not running or `MCPToolkitBinding.initialize()` not called.
- `connection_selection_required` — multiple targets; supply `connection.targetId`.

### inspect_widget_at_point

Identify the deepest widget and render node at a global logical coordinate.

- `x` (integer, required) — global logical X coordinate.
- `y` (integer, required) — global logical Y coordinate.
- `viewId` (integer, optional) — FlutterView ID for multi-view apps.
- `connection` (object, optional) — connection override.

```
inspect_widget_at_point(x: 200, y: 400)
```

Returns: `{"widget": {"type": "ElevatedButton", "rect": {"left": 180, "top": 380, "right": 280, "bottom": 420}}}`

- `vm_service_unavailable` — app not reachable.
- `invalid_argument` — coordinates out of view bounds.

### capture_ui_snapshot

Capture screenshots, view details, and app errors in one bundled response.

- `errorsCount` (integer, optional, default: 4) — errors to include.
- `compress` (boolean, optional, default: true) — compress screenshots.
- `includeViewDetails` (boolean, optional, default: true) — include view data.
- `includeErrors` (boolean, optional, default: true) — include app errors.
- `screenshotMode` (string, optional, default: `auto`) — `auto`, `flutter_layer`, or `desktop_window`.
- `permissionPolicy` (string, optional, default: `check_only`) — `check_only`, `auto_request_once`, or `request_always`.
- `connection` (object, optional) — connection override.

```
capture_ui_snapshot(errorsCount: 2, includeViewDetails: false)
```

Returns: single `TextContent` JSON block with `screenshots`, `viewDetails`, and `errors` keys.

- `vm_service_unavailable` — app not running.
- `permission_denied` — retry with `permissionPolicy: "auto_request_once"`.

### connect_debug_app

Explicitly select and connect to a Flutter debug VM target. Use when multiple apps are running or to pin a specific target for the session.

- `connection` (object, optional) — pass `connection.targetId` with a WebSocket URI from `discover_debug_apps`.

```
connect_debug_app(connection: {targetId: "ws://127.0.0.1:8181/<token>/ws"})
```

Returns: `{"connected": true, "targetId": "ws://127.0.0.1:8181/<token>/ws", "isolates": [...]}`

- `target_not_found` — URI doesn't match a running app; re-run `discover_debug_apps` for the exact URI.
- `connection_failed` — VM refused connection; verify the app is still running in debug mode.
