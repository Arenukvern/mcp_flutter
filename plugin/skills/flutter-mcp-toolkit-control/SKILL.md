---
name: flutter-mcp-toolkit-control
description: Drive a running Flutter app — tap, scroll, type, fill forms, hot-reload, navigate. Use when you need to interact with the UI.
---

<!-- @FMT_MODE_PRELUDE -->

## When to use

Use this skill when you need to drive a running Flutter app as a user would:
- Tap buttons, icons, list items, or any interactive widget.
- Type text into fields, submit forms, clear inputs.
- Scroll or swipe to reveal off-screen content.
- Navigate between routes programmatically (push, pop, popUntil).
- Dismiss dialogs and bottom sheets.
- Press keyboard keys (Enter, Escape, Tab, arrows, ASCII chars).
- Hot-reload or hot-restart after editing Dart source files.
- Combine reload + screenshot + semantics in one round-trip for fast iteration.

## Selectors

Every interaction tool targets a widget by **ref** — a short string like `"s_0"` returned by `semantic_snapshot`. There is no by-text or by-type selector syntax on the tool itself. The workflow is: call `semantic_snapshot`, scan the returned nodes, find the right ref, then pass it.

Snapshot node fields to filter on:

| Want to find | Scan field | Example value |
|---|---|---|
| By visible label / text | `label` | `"Login"` |
| By value or hint | `value` / `hint` | `"user@example.com"` |
| By tooltip | `tooltip` | `"Close"` |
| By widget key | `key` | `"[<'submitBtn'>]"` |
| By semantic role / type | `flags` or `actions` | `["tap"]` |

Example — find the "Login" button ref:
```
semantic_snapshot()
→ nodes: [{ref:"s_0", label:"Login", actions:["tap"]}, ...]
tap_widget(ref: "s_0")
```

Pass `snapshotId` (from the snapshot response) to any interaction call. If the tree has changed, the call returns `stale_snapshot` with both IDs so you know to re-snapshot. Refs are only valid against the most recent snapshot.

## Recipes

### Tap a widget by text
```
semantic_snapshot()
→ find node where label == "Submit" → ref "s_3"
tap_widget(ref: "s_3", snapshotId: <id>)
```

### Fill a login form
```
semantic_snapshot() → email ref "s_1", password ref "s_2"
fill_form(fields: [{ref:"s_1", text:"user@example.com"}, {ref:"s_2", text:"secret"}], snapshotId: <id>)
→ one round-trip; stops on first failure
```

### Scroll to find an item
```
scroll(direction: "down", distance: 300)
semantic_snapshot() → item now visible → ref "s_5"
tap_widget(ref: "s_5")
```

### Wait for a widget to appear
```
wait_for(predicate: {kind: "text", text: "Welcome"}, timeoutMs: 8000)
→ returns fresh snapshot when text appears
tap_widget(ref: <ref from wait_for snapshot>)
```

### Navigate to a route
```
navigate(action: "push", route: "/settings", arguments: {tab: "account"})
semantic_snapshot() → fresh refs in the new screen
```

### Hot reload after a code change
```
hot_reload_and_capture()
→ screenshot + semantic snapshot + errors in one call
```

### Press the back hardware button

`press_key` has no `Back` key. Use `navigate(action: "pop")` for Navigator pop; `handle_dialog(action: "dismiss")` for dialogs; `press_key(key: "Escape")` on desktop.

```
navigate(action: "pop")
```

## Tool reference

### tap_widget
Tap a widget by ref. `ref` • string • required. `snapshotId` • integer • optional. `connection` • object • optional.
```json
{"name": "tap_widget", "arguments": {"ref": "s_3", "snapshotId": 7}}
```
Returns: `{"via": "semantic_action", "ref": "s_3"}` — Failures: `stale_snapshot`, `ref_not_found`

### long_press
Long-press a widget by ref. `ref` • string • required. `snapshotId` • integer • optional. `connection` • object • optional.
```json
{"name": "long_press", "arguments": {"ref": "s_2"}}
```
Returns: `{"via": "semantic_action"}` — Failures: `stale_snapshot`, `ref_not_found`

### enter_text
Enter text into a text field; taps to focus before typing. `ref` • string • required. `text` • string • required. `snapshotId` • integer • optional. `connection` • object • optional.
```json
{"name": "enter_text", "arguments": {"ref": "s_1", "text": "hello@example.com"}}
```
Returns: `{"via": "editable_state"}` — Failures: `stale_snapshot`, `ref_not_found`

### fill_form
Batch text entry: fills multiple fields in one call. Stops on first failure. `snapshotId` validated on first field only. `fields` • array of `{ref, text}` • required. `snapshotId` • integer • optional. `connection` • object • optional.
```json
{"name": "fill_form", "arguments": {"fields": [{"ref":"s_1","text":"user"},{"ref":"s_2","text":"pass"}], "snapshotId": 5}}
```
Returns: `{"filled": 2}` — Failures: `stale_snapshot`, `ref_not_found`

### scroll
Scroll to reveal content. `"down"` reveals content below (finger swipes up). `direction` • string • required (`up|down|left|right`). `ref` • string • optional (falls back to screen center). `distance` • number • optional • default 300. `snapshotId` • integer • optional. `connection` • object • optional.
```json
{"name": "scroll", "arguments": {"direction": "down", "ref": "s_0", "distance": 500}}
```
Returns: `{"via": "semantic_action"}` — Failures: `ref_not_found`, `stale_snapshot`

### swipe
High-velocity fling. Same direction model as `scroll`. Always Tier 2 pointer events. `direction` • string • required. `ref` • string • optional. `distance` • number • optional • default 300. `snapshotId` • integer • optional. `connection` • object • optional.
```json
{"name": "swipe", "arguments": {"direction": "left", "ref": "s_4"}}
```
Returns: `{"via": "pointer_events"}` — Failures: `ref_not_found`, `web_gesture_not_supported`

### drag
Drag from one widget to another. Always Tier 2. `fromRef` • string • required. `toRef` • string • required. `snapshotId` • integer • optional. `connection` • object • optional.
```json
{"name": "drag", "arguments": {"fromRef": "s_2", "toRef": "s_7"}}
```
Returns: `{"via": "pointer_events"}` — Failures: `ref_not_found`, `web_gesture_not_supported`

### hover
Synthesize a mouse hover. Desktop/web only — no hover concept on mobile. `ref` • string • required. `snapshotId` • integer • optional. `connection` • object • optional.
```json
{"name": "hover", "arguments": {"ref": "s_5"}}
```
Returns: `{"via": "pointer_events"}` — Failures: `ref_not_found`, platform error on mobile

### press_key
Synthesize key press (down+up). Accepted: `Enter Escape Tab Backspace Delete Space ArrowUp ArrowDown ArrowLeft ArrowRight` plus single ASCII (`a-z` `0-9`). `key` • string • required. `ctrl/shift/alt/meta` • boolean • optional • default false. `connection` • object • optional.
```json
{"name": "press_key", "arguments": {"key": "Enter"}}
```
Returns: `{"key": "Enter"}` — Failures: `unsupported_key`, `no_focus`

### wait_for
Wait for a UI predicate; returns fresh semantic snapshot. Predicates: `{kind:"text",text}` | `{kind:"noText",text}` | `{kind:"time",ms}` | `{kind:"stable",stableWindowMs}`. `predicate` • object • required. `timeoutMs` • integer • optional • default 5000 • max 30000. `connection` • object • optional.
```json
{"name": "wait_for", "arguments": {"predicate": {"kind": "text", "text": "Dashboard"}, "timeoutMs": 8000}}
```
Returns: fresh semantic snapshot — Failures: `timeout`, `invalid_predicate`

### navigate
Drive the registered Navigator. Requires `MCPToolkitBinding.instance.navigatorKey = key` in the app. `action` • string • required (`push|pop|popUntil`). `route` • string • required for push/popUntil. `arguments` • object • optional (for push). `connection` • object • optional.
```json
{"name": "navigate", "arguments": {"action": "push", "route": "/profile", "arguments": {"userId": "42"}}}
```
Returns: `{"action": "push", "route": "/profile"}` — Failures: `navigator_not_configured`, `route_not_found`

### handle_dialog
Dismiss the topmost popup/dialog route. Only `action: "dismiss"` supported. Requires `navigatorKey = key` on `MCPToolkitBinding.instance` in the app. `action` • string • required (must be `"dismiss"`). `connection` • object • optional.
```json
{"name": "handle_dialog", "arguments": {"action": "dismiss"}}
```
Returns: `{"dismissed": true}` — Failures: `navigator_not_configured`, `no_dialog`

### hot_reload_flutter
Hot reload the app. Preserves state. `force` • boolean • optional • default false (reload even without source changes). `connection` • object • optional.
```json
{"name": "hot_reload_flutter", "arguments": {}}
```
Returns: `"Hot reload completed"` + report JSON — Failures: `vm_not_connected`, `compilation_error`

### hot_restart_flutter
Full restart. App state not preserved. No required params. `connection` • object • optional.
```json
{"name": "hot_restart_flutter", "arguments": {}}
```
Returns: `{"report": {"type": "Success", "success": true}}` — Failures: `vm_not_connected`

### hot_reload_and_capture
Hot reload then capture screenshot + semantics + errors in one call. `compress` • boolean • default true. `includeSemantics` • boolean • default true. `includeErrors` • boolean • default true. `errorsCount` • integer • default 4. `connection` • object • optional.
```json
{"name": "hot_reload_and_capture", "arguments": {"includeErrors": true}}
```
Returns: screenshot (base64) + semantic snapshot + errors — Failures: `vm_not_connected`, `compilation_error`

## Patterns

### Always `wait_for` before `tap_widget` after navigation

After `navigate(action: "push")` the new route's widgets are not in the tree yet. Use `wait_for` with a text predicate to confirm the destination has rendered, then snapshot and act.

```
navigate(action: "push", route: "/checkout")
wait_for(predicate: {kind: "text", text: "Order Summary"}, timeoutMs: 5000)
semantic_snapshot() → tap target widgets
```

### Prefer `fill_form` over multiple `enter_text` calls

Each `enter_text` is a separate VM round-trip. `fill_form` sends all field/text pairs in one call; `snapshotId` is checked once (on the first field). For any form with 2+ fields, always prefer `fill_form`.

```
# Avoid: 2 round-trips
enter_text(ref: "s_1", text: "Alice")
enter_text(ref: "s_2", text: "secret")

# Prefer: 1 round-trip
fill_form(fields: [{ref: "s_1", text: "Alice"}, {ref: "s_2", text: "secret"}])
```

### After `hot_reload_*`, wait for the new tree before continuing

Hot reload completes asynchronously. Use `wait_for(predicate: {kind:"stable", stableWindowMs:300})` to confirm the tree has settled before calling `semantic_snapshot`. Or use `hot_reload_and_capture` which returns a post-reload snapshot directly.

```
hot_reload_flutter()
wait_for(predicate: {kind: "stable", stableWindowMs: 300})
semantic_snapshot() → interact with reloaded widgets

# Or in one call (preferred):
hot_reload_and_capture() → screenshot + semantics + errors already post-reload
```
