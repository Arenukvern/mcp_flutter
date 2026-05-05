# MCP Toolkit Server (Dart)

## Migrating from v2.x

Tool names on MCP are prefixed with **`fmt_`**, binaries and `mcpServers` keys were renamed — see **[Migrating from v2.x to v3.0](../docs/start_here/migration_v2_to_v3.mdx)**.

## Architecture

This project now uses a shared core execution layer:

1. `flutter-mcp-toolkit` is the canonical command surface (connect, inspect, execute, diagnostics).
2. `flutter-mcp-toolkit-server` is a thin MCP protocol adapter that maps MCP tool/resource calls to the same core executor.
3. **MCP `tools/list` names** use the **`fmt_`** capability prefix; **CLI `exec --name`** uses bare catalog names. Resource URIs are unchanged.

The shared core module is available as `flutter_mcp_core` inside this package.

## Golden Path

Use this sequence first on macOS:

1. Add `mcp_toolkit` to the app and call `MCPToolkitBinding.instance.bootstrapFlutter(...)`.
2. Launch the app in debug mode.
3. Run `flutter-mcp-toolkit validate-runtime`.
4. Query dynamic entries in this order:
   `fmt_list_client_tools_and_resources`,
   `fmt_client_tool`,
   `fmt_client_resource`.

Treat `exec` as expert mode. `validate-runtime` is the default first-pass proof command.

## CLI v3 Surface (Hard Cut)

The CLI is now agent-first and exposes a canonical interface:

- `exec --name <command> --args <json>`
- `schema [--name <command>]`
- `capabilities`
- `serve` (JSON-RPC 2.0 over stdio)
- `snapshot create --name <id> [--args <json>]`
- `snapshot diff --from <id> --to <id>`
- `bundle create --from-snapshot <id> [--output <dir>]`
- `doctor [--json] [--target <path>] [--timeout-ms <n>]`
- `permissions status|request|open-settings [--kind visual_capture]`

Safe-write flags for write-producing commands:

- `snapshot create`: `--check --diff --backup --no-overwrite`
- `bundle create`: `--check --diff --backup --no-overwrite`

`exec` targets commands in the shared `CommandCatalog` (these are the
unprefixed catalog names; the CLI is not subject to the MCP capability
prefix):
`connect`, `session_start`, `session_exec`, `session_end`, `diagnose`, `watch`, `explain_errors`, `status`, `discover_debug_apps`, `get_vm`, `get_extension_rpcs`, `hot_reload_flutter`, `hot_restart_flutter`, `get_active_ports`, `get_app_errors`, `get_screenshots`, `get_view_details`, `inspect_widget_at_point`, `capture_ui_snapshot`, `debug_dump_layer_tree`, `debug_dump_semantics_tree`, `debug_dump_render_tree`, `debug_dump_focus_tree`, `fmt_list_client_tools_and_resources`, `fmt_client_tool`, `fmt_client_resource`, `dynamicRegistryStats`, `semantic_snapshot`, `tap_widget`, `long_press`, `enter_text`, `scroll`, `swipe`, `drag`, `hot_reload_and_capture`, `evaluate_dart_expression`, `get_recent_logs`.

> **MCP names**. When invoked via MCP `tools/call`, every catalog tool above
> surfaces under the `fmt_` capability prefix (e.g. `fmt_tap_widget`,
> `fmt_hot_reload_and_capture`). The dynamic-registry host trio
> (`fmt_list_client_tools_and_resources`, `fmt_client_tool`, `fmt_client_resource`) and
> `dynamicRegistryStats` stay unprefixed in MCP. CLI examples below use the
> catalog name unchanged.

Interaction tools (catalog names: `semantic_snapshot` → `tap_widget` / `enter_text` / `scroll` / `swipe` / `long_press` / `drag`) follow a Playwright-style ref model: take a snapshot, then pass `ref: "s_N"` (and optional `snapshotId` for staleness detection) into the interaction tool. `hot_reload_and_capture` fuses reload + screenshot + fresh snapshot + errors. `evaluate_dart_expression` runs an ad-hoc Dart expression against the app's root library. See [docs/start_here/cli_quick_recipes.mdx](../docs/start_here/cli_quick_recipes.mdx) and [docs/guides/interaction_cookbook.mdx](../docs/guides/interaction_cookbook.mdx) for the full surface and golden paths.

CLI runs the same shared command catalog/executor as MCP. Preferred debugging path:
`discover_debug_apps` -> `capture_ui_snapshot` -> `inspect_widget_at_point`.
`get_active_ports` and `dynamicRegistryStats` remain available in CLI for low-level diagnostics, but are intentionally not MCP-exposed by default.

## CLI Quick Use (v3)

```bash
# introspection
dart run bin/flutter_mcp_toolkit.dart schema
dart run bin/flutter_mcp_toolkit.dart capabilities

# one-shot execution (machine envelope)
dart run bin/flutter_mcp_toolkit.dart exec --name status --args '{}'
dart run bin/flutter_mcp_toolkit.dart exec --name get_vm --args '{}'
dart run bin/flutter_mcp_toolkit.dart exec --name get_vm --args '{"connection":{"targetId":"ws://127.0.0.1:8181/<token>/ws"}}'
dart run bin/flutter_mcp_toolkit.dart exec --name discover_debug_apps --args '{}'
dart run bin/flutter_mcp_toolkit.dart exec --name capture_ui_snapshot --args '{"connection":{"targetId":"ws://127.0.0.1:8181/<token>/ws"}}'
dart run bin/flutter_mcp_toolkit.dart exec --name inspect_widget_at_point --args '{"x":120,"y":220,"connection":{"targetId":"ws://127.0.0.1:8181/<token>/ws"}}'

# session lifecycle
dart run bin/flutter_mcp_toolkit.dart exec --name session_start --args '{"mode":"uri","uri":"ws://127.0.0.1:8181/<token>/ws"}'
dart run bin/flutter_mcp_toolkit.dart exec --name session_exec --args '{"command":"get_app_errors","arguments":{"count":4}}'
dart run bin/flutter_mcp_toolkit.dart exec --name session_end --args '{}'

# reproducible artifacts
dart run bin/flutter_mcp_toolkit.dart snapshot create --name baseline --args '{"commands":[{"name":"status","args":{}}]}' --check --diff
dart run bin/flutter_mcp_toolkit.dart snapshot diff --from baseline --to after_fix
dart run bin/flutter_mcp_toolkit.dart bundle create --from-snapshot baseline --backup

# environment preflight
dart run bin/flutter_mcp_toolkit.dart doctor --json
dart run bin/flutter_mcp_toolkit.dart permissions status
dart run bin/flutter_mcp_toolkit.dart permissions request
dart run bin/flutter_mcp_toolkit.dart permissions open-settings
dart run bin/flutter_mcp_toolkit.dart exec --name get_extension_rpcs --args '{}'

# explicit capture policy/mode
dart run bin/flutter_mcp_toolkit.dart exec --name get_screenshots --args '{"mode":"desktop_window","permissionPolicy":"auto_request_once"}'
dart run bin/flutter_mcp_toolkit.dart exec --name capture_ui_snapshot --args '{"screenshotMode":"auto","permissionPolicy":"auto_request_once"}'

# one-command runtime validation (after app launch)
dart run bin/flutter_mcp_toolkit.dart --save-images --output-dir .flutter_mcp/app validate-runtime \
  --target ws://127.0.0.1:8181/<token>/ws \
  --timeout-ms 10000 \
  --post-reload-delay-ms 500 \
  --after-reload

# same, using global VM URI (equivalent to --target when only one is passed)
dart run bin/flutter_mcp_toolkit.dart --vm-service-uri ws://127.0.0.1:8181/<token>/ws validate-runtime \
  --timeout-ms 10000

# optional: install bundled skill during runtime validation
dart run bin/flutter_mcp_toolkit.dart validate-runtime \
  --target ws://127.0.0.1:8181/<token>/ws \
  --install-skill
```

CLI runtime gate for app inspection:

- Require `ext.mcp.toolkit.app_errors`, `ext.mcp.toolkit.view_details`, `ext.mcp.toolkit.view_screenshots`, and `ext.mcp.toolkit.inspect_widget_at_point` from `get_extension_rpcs`.
- If missing, app-level screenshot/layout/error inspection is blocked until `mcp_toolkit` is installed, initialized, and the app is hot restarted or rerun.
- If screenshots are blank, ensure app window is visible/foreground and retry `get_screenshots`.
- If first explicit-URI connect times out, retry once and validate with `doctor --json --target <ws_uri> --timeout-ms 10000`.
- When `--output-dir` is set, `validate-runtime` mirrors its JSON envelope to `<output-dir>/validate-runtime.json` and screenshot files are written under `<output-dir>/.mcp_screenshots/`.
- `validate-runtime` tries host `desktop_window` first when `auto` selects it; if that screenshot step fails with a retryable `get_screenshots_failed`, it retries once with `flutter_layer`. Check `data.summary.captureFallbackUsed` in the JSON envelope.

## Visual Capture Permissions

- `doctor` stays read-only. It now reports `visual_capture_backend`, `visual_capture_permission`, `visual_capture_truth_mode`, and `app_permission_bridge`.
- Interactive CLI capture flows default to `auto_request_once` for `exec get_screenshots`, `exec capture_ui_snapshot`, and `validate-runtime`. Raw command schemas still default to `check_only`.
- macOS truthful capture is `desktop_window`. Screen Recording permission belongs to the host process running `flutter-mcp-toolkit`, not the Flutter app. Use `permissions request` for the native prompt and `permissions open-settings` after a denial.
- Web has no OS permission flow. `flutter_layer` is the supported path, `desktop_window` is unsupported, and `auto` resolves to `flutter_layer`.
- App-owned capture targets such as iOS/Android/Linux must have a reachable VM
  target selected before `permissions` or `doctor` can verify bridge-backed
  permission tools/resources. Use `--target <ws_uri>` or the global
  `--vm-service-uri <ws_uri>` when probing those platforms.
- `desktop_window` never silently falls back. `auto` may fall back to `flutter_layer`, but responses always report `requestedMode`, `actualMode`, `permissionStatus`, and `fallbackReason`.

Troubleshooting:

- If macOS capture is denied, rerun `flutter-mcp-toolkit permissions status` first. If status is still `denied`, open System Settings from the CLI and grant Screen Recording to the terminal or client process you are using.
- If `doctor --json` shows `visual_capture_truth_mode=flutter_layer` on macOS, you are not getting native window pixels yet.
- If web capture fails with `desktop_window`, switch to `flutter_layer` or keep `auto`.
- If post-reload capture fails once on macOS desktop-window mode, that is usually a host capture race rather than an app failure. `validate-runtime` retries those failures before returning red, and may also retry with `flutter_layer` after a failed `desktop_window` screenshot.

Failure matrix:

- `missing_mcp_toolkit_wiring`: app did not expose the required toolkit extensions. Fix app bootstrap and hot restart.
- `bad_target_uri_or_unreachable_vm_service`: explicit target URI is wrong or the VM service is not reachable.
- `permission_denied`: host capture backend lacks permission.
- `host_capture_backend_instability`: native capture backend flaked during desktop-window capture, usually around reload.

## Migration (v2.x -> v3.0.0)

- Error metadata moved under `error.descriptor`; do not parse legacy top-level fields.
- Typed arguments are strict. String-encoded booleans/objects/lists/integers now fail validation.
- For write-producing automation, run with `--check --diff` before actual writes.
- Handle `write_blocked` explicitly when using `--no-overwrite`.
- Add `flutter-mcp-toolkit doctor --json` as preflight before VM-dependent execution.

### Machine Envelope

One-shot commands return one JSON envelope with stable fields:

```json
{
  "ok": true,
  "data": {},
  "error": null,
  "meta": {
    "schemaVersion": "core-envelope/v1",
    "command": "status",
    "timestamp": "2026-03-03T00:00:00.000Z",
    "durationMs": 2
  }
}
```

Failures use one strict envelope in `error`:
`code`, `message`, `details`, `descriptor` (`category`, `retryable`, `exitCode`, `httpLikeStatus`), `recovery`.

The full contract table is documented in [docs/ai_agents/troubleshooting.mdx](../docs/ai_agents/troubleshooting.mdx).

### Daemon Protocol

`serve` runs JSON-RPC 2.0 over stdio. Key methods:

- requests: `initialize`, `capabilities/get`, `schema/get`, `command/execute`, `watch/start`, `watch/stop`, `snapshot/create`, `snapshot/diff`, `bundle/create`, `session/start`, `session/end`
- notifications: `watch/event`, `session/changed`

Watch notifications are NDJSON JSON-RPC notifications with monotonic `seq` per watch.

Targeting contracts:

- `command/execute`: optional `params.args.connection`
- `watch/start`: optional `params.args.connection` (applied once before watch loop starts)
- `snapshot/create`: per-step optional `args.commands[i].args.connection`

### State + Locking

- State root defaults to `.flutter_mcp/`
- state file: `.flutter_mcp/state.json`
- lock file: `.flutter_mcp/state.lock`
- snapshots: `.flutter_mcp/snapshots/`
- bundles: `.flutter_mcp/bundles/`

State operations use a lock with stale-lock TTL recovery to support concurrent agents safely.

### Connection Resolution UX

The server keeps startup non-blocking and defers target lock until a VM-dependent call is executed.

Resolution policy for VM-dependent commands/resources:

1. Reuse active connection if still healthy.
2. Else reuse sticky target if it exists in current discovery results.
3. Else auto-attach if exactly one target is discovered.
4. Else fail with `connection_selection_required` when multiple targets exist and no explicit target is provided.

Selection-required errors are returned as structured JSON so agents can retry immediately:

```json
{
  "code": "connection_selection_required",
  "message": "Multiple debug targets detected. Retry with URI connection.targetId.",
  "descriptor": {
    "category": "validation",
    "retryable": true,
    "exitCode": 64,
    "httpLikeStatus": 409
  },
  "details": {
    "reason": "multiple_targets",
    "availableTargets": [
      {
        "targetId": "ws://127.0.0.1:8181/<token>/ws",
        "host": "localhost",
        "port": 8181,
        "endpoint": "ws://127.0.0.1:8181/<token>/ws",
        "isSticky": false,
        "isCurrent": false
      }
    ],
    "suggestedAction": "retry_with_connection_target",
    "example": {
      "connection": { "targetId": "ws://127.0.0.1:8181/<token>/ws" }
    },
    "howToRetry": {
      "connection": { "targetId": "ws://127.0.0.1:8181/<token>/ws" }
    }
  },
  "recovery": {
    "summary": "Select an explicit VM target and retry the command.",
    "fix_command": "flutter-mcp-toolkit exec --name discover_debug_apps --args '{}'"
  }
}
```

CLI one-shot and daemon calls use the same handshake semantics. For ambiguous multi-target sessions, retry with an explicit selector:

```json
{
  "connection": { "targetId": "ws://127.0.0.1:8181/<token>/ws" }
}
```

All VM-dependent MCP tools now accept optional `arguments.connection`:

```json
{
  "connection": {
    "targetId": "ws://127.0.0.1:8181/<token>/ws",
    "mode": "auto",
    "host": "localhost",
    "port": 8181,
    "uri": "ws://127.0.0.1:8181/<token>/ws",
    "forceReconnect": false
  }
}
```

Notes:

- `targetId` is the preferred selector and must be full VM websocket URI.
- Legacy `host:port` target IDs are rejected; use URI target IDs or `connection.uri`.
- Safest selector is `connection.uri` with exact Flutter machine `app.debugPort.wsUri`.
- If `targetId` lookup misses but URI is a full tokenized VM path (`/<token>/ws`), server attempts direct connect fallback.
- CLI `exec --args` and daemon `command/execute` / `watch/start` accept the same optional nested `connection` object.
- `connect_debug_app` accepts the same `connection` shape.
- Dynamic registry tools (`fmt_list_client_tools_and_resources`, `fmt_client_tool`, `fmt_client_resource`) accept the same optional `connection`.
- Resource reads also support query targeting: `targetId`, `mode`, `host`, `port`, `uri`, `forceReconnect`.
- Flat top-level connection aliases like `host`/`port`/`uri` in tool arguments are intentionally rejected by strict schemas.
- For `connect` and `session_start`, native selector args (`mode`, `targetId`, `host`, `port`, `uri`, `force`) cannot be mixed with nested `connection`.

Zero-mistake recipe:

1. Read machine `app.debugPort.wsUri`.
2. Use `{"connection":{"uri":"<that exact wsUri>"}}`.
3. If using `targetId`, copy exactly from `availableTargets` / `discover_debug_apps`.

### Flutter Web Discovery

Discovery order is:

1. Flutter machine discovery (`flutter attach --machine`)
2. Port-scan fallback

Both CLI and MCP server accept:

- `--flutter-project-dir`
- `--flutter-device` (for example `chrome`)
- `--flutter-discovery-timeout-ms`

Manual fallback remains available:

- CLI: `--vm-service-uri ws://127.0.0.1:59490/<token>/ws`
- MCP tool/resource calls: `arguments.connection.uri`

## Quick Start

## 📦 Installation from GitHub (Currently Recommended)

For developers who want to contribute to the project or run the latest version directly from source, follow these steps:

1. **Clone the repository:**

   ```bash
   git clone https://github.com/Arenukvern/mcp_flutter
   cd mcp_flutter
   ```

2. **Install and build dependencies:**

   ```bash
   make install
   ```

   This command installs all necessary dependencies listed in `pubspec.yaml` and then builds the MCP server.

3. **Add `mcp_toolkit` Package to Your Flutter App:**

   The `mcp_toolkit` package provides the necessary service extensions within your Flutter application. You need to add it to your app's `pubspec.yaml`.

   Run this command in your Flutter app's directory to add the `mcp_toolkit` package:

   ```bash
   flutter pub add mcp_toolkit
   ```

   or add it to your `pubspec.yaml` manually:

   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     # ... other dependencies
     mcp_toolkit: ^3.0.0
   ```

   Then run `flutter pub get` in your Flutter app's directory.

4. **Initialize in Your App**:
   In your Flutter application's `main.dart` file (or equivalent entry point), initialize the bridge binding:

   ```dart
   import 'package:flutter/material.dart';
   import 'package:mcp_toolkit/mcp_toolkit.dart'; // Import the package
   import 'dart:async';

   Future<void> main() async {
     runZonedGuarded(
       () async {
         WidgetsFlutterBinding.ensureInitialized();
         MCPToolkitBinding.instance
            ..initialize() // Initializes the Toolkit
            ..initializeFlutterToolkit(); // Adds Flutter related methods to the MCP server
         runApp(const MyApp());
       },
       (error, stack) {
         // You can place it in your error handling tool, or directly in the zone. The most important thing is to have it - otherwise the errors will not be captured and MCP server will not return error results.
         MCPToolkitBinding.instance.handleZoneError(error, stack);
       },
     );
   }

   // ... rest of your app code
   ```

5. **Start your Flutter app in debug mode**

   ```bash
   flutter run --debug --machine --host-vmservice-port=8181 -d macos
   ```

   Adjust `-d` for your device. Prefer the exact **`app.debugPort.wsUri`** from machine output in `arguments.connection.uri` or `connection.targetId`.

6. **🛠️ Add Flutter MCP Toolkit to your AI client**

   Use registry key **`flutter-mcp-toolkit`** under `mcpServers` (canonical). The key **`flutter-inspector`** is **legacy** but still accepted if your config predates the rename. That string is **only** a `mcpServers` id — it is **not** the Claude Code subagent name. The bundled runtime subagent is **`flutter-mcp-toolkit-runtime`** (`plugin/agents/flutter-mcp-toolkit-runtime.md`).

   Recommended server args: `--resources`, `--images`, `--dynamics` (defaults are on for resources/images; `--dynamics` enables the dynamic registry).

   **Note for Local Development (GitHub Install):**

   If you installed from GitHub and built locally, point `command` at `mcp_server_dart/build/flutter-mcp-toolkit-server`. See **Installation from GitHub** above.

   #### Cline Setup
   1. Add to your `.cline/config.json`:
      ```json
      {
        "mcpServers": {
          "flutter-mcp-toolkit": {
            "command": "/path/to/your/cloned/mcp_flutter/mcp_server_dart/build/flutter-mcp-toolkit-server",
            "args": [
              "--dart-vm-host=localhost",
              "--dart-vm-port=8181",
              "--resources",
              "--images",
              "--dynamics"
            ],
            "env": {},
            "disabled": false,
            "autoApprove": []
          }
        }
      }
      ```
   2. Restart Cline
   3. The Flutter MCP toolkit tools will be available in your conversations
   4. Try: "Please get a screenshot of my app" (MCP tools use the `fmt_` prefix, e.g. `fmt_get_screenshots`)

   #### Cursor Setup

   ##### Badge

   Install the server (edit the path in Cursor after clicking):

   [![Install MCP Server](https://cursor.com/deeplink/mcp-install-dark.svg)](https://cursor.com/install-mcp?name=flutter-mcp-toolkit&config=eyJjb21tYW5kIjoiL3BhdGgvdG8veW91ci9jbG9uZWQvbWNwX2ZsdXR0ZXIvbWNwX3NlcnZlcl9kYXJ0L2J1aWxkL2ZsdXR0ZXItbWNwLXRvb2xraXQtc2VydmVyIiwiYXJncyI6WyItLWRhcnQtdm0taG9zdD1sb2NhbGhvc3QiLCItLWRhcnQtdm0tcG9ydD04MTgxIiwiLS1yZXNvdXJjZXMiLCItLWltYWdlcyIsIi0tZHluYW1pY3MiXSwiZW52Ijp7fSwiZGlzYWJsZWQiOmZhbHNlfQ%3D%3D)
   <!-- Regenerate: https://docs.cursor.com/deeplinks#markdown — config must reference flutter-mcp-toolkit-server -->

   Note: fix `command` path after installation.

   ##### Manual Setup
   1. Open Cursor's settings
   2. Go to the Features tab
   3. Under "Model Context Protocol", add the server:

      ```json
      {
        "mcpServers": {
          "flutter-mcp-toolkit": {
            "command": "/path/to/your/cloned/mcp_flutter/mcp_server_dart/build/flutter-mcp-toolkit-server",
            "args": [
              "--dart-vm-host=localhost",
              "--dart-vm-port=8181",
              "--resources",
              "--images",
              "--dynamics"
            ],
            "env": {},
            "disabled": false,
            "autoApprove": []
          }
        }
      }
      ```

   4. Restart Cursor
   5. Open Agent Panel (cmd + L on macOS)
   6. Tool calls use **`fmt_*`** names on the MCP wire (e.g. `fmt_capture_ui_snapshot`).

   #### Claude Setup
   1. Add to your Claude configuration file:
      ```json
      {
        "mcpServers": {
          "flutter-mcp-toolkit": {
            "command": "/path/to/your/cloned/mcp_flutter/mcp_server_dart/build/flutter-mcp-toolkit-server",
            "args": [
              "--dart-vm-host=localhost",
              "--dart-vm-port=8181",
              "--resources",
              "--images",
              "--dynamics"
            ],
            "env": {},
            "disabled": false,
            "autoApprove": []
          }
        }
      }
      ```
   2. Restart Claude
   3. The Flutter MCP toolkit tools will be available
   4. Try: "Please get screenshot of my app"

# Development

### Command Line Options

```bash
./build/flutter-mcp-toolkit-server [options]

Options:
  --dart-vm-host                Host for Dart VM connection (default: localhost)
  --dart-vm-port                Port for Dart VM connection (default: 8181)
  --resources                   Enable resources support (default: true)
  --images                      Enable images support (default: true)
  --save-images        Save captured images as files in temporal folder instead of returning base64 data (default: false)
  --dumps                       Enable dumps support (default: false)
  --await-dnd                   Wait until DND connection is established (default: false). Do not use with Windsurf. Workaround for MCP Clients which don't support tools updates. Important: some clients doesn't support it. Use with caution. (disable for Windsurf, works with Cursor)
  --log-level                   Logging level (default: critical)
  --environment                 Environment (default: production)
  -h, --help                    Show usage text
```

#### Image File Saving Mode

When `--save-images` is enabled, the server will:

- Save all captured screenshots as PNG files in a `.mcp_screenshots` folder in the current working directory
- Return file URLs (`file://`) instead of base64 encoded image data
- Automatically clean up screenshots older than 24 hours
- Use timestamped filenames like `screenshot-2025-01-27T10-30-15.123Z.png`

This mode is useful when:

- Working with AI tools that prefer file references over base64 data
- Needing to persist screenshots for later analysis
- Reducing memory usage by avoiding large base64 strings in responses

### Basic Usage

1. Start your Flutter app in debug mode:

   ```bash
   flutter run --debug --dart-vm-host=localhost --dart-vm-port=8181
   ```

2. Run the MCP server:

   ```bash
   ./build/flutter-mcp-toolkit-server
   ```
