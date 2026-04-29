---
name: flutter-mcp-toolkit-setup
description: Verify the flutter-mcp-toolkit install, run doctor preflight, troubleshoot connection issues. Use when the toolkit isn't responding or first-time setup.
---

<!-- @FMT_MODE_PRELUDE -->

## When to use

Use this skill when:
- First-time install: `flutter_mcp_cli` is not yet on PATH.
- `doctor --json` returns any check with `"status": "fail"`.
- MCP server fails to connect or tools return `vm_not_connected` / `connect_failed`.
- Visual capture or toolkit-bridge commands are returning unexpected errors.

---

## Verify install

Run:

```bash
flutter_mcp_cli --help
```

Expected output: prints the usage header `flutter_mcp_cli v<version>` plus command list.

If you get `command not found`, the binary is not on PATH. Fix:

```bash
# Binary is built to mcp_server_dart/build/ inside the repo
export PATH="$PATH:/path/to/mcp_flutter/mcp_server_dart/build"
# Or rebuild from source
cd /path/to/mcp_flutter && make build
```

Then verify:

```bash
flutter_mcp_cli --help
```

---

## Run doctor

Always run doctor before any VM-dependent command:

```bash
flutter_mcp_cli doctor --json
```

Flags:
- `--json` — emit machine-readable JSON (required for agent parsing).
- `--target <ws_uri>` — test a specific websocket URI instead of auto-discovery.
- `--timeout-ms <n>` — per-check timeout in ms (default: 2500).

Sample green output:

```json
{
  "summary": { "status": "ok", "criticalFailures": 0 },
  "checks": [
    { "id": "vm_reachability", "status": "pass", "critical": true },
    { "id": "mcp_toolkit_extensions", "status": "pass", "critical": true },
    { "id": "dynamic_registry", "status": "pass", "critical": false }
  ]
}
```

Sample red output (error envelope shape):

```json
{
  "summary": { "status": "error", "criticalFailures": 1 },
  "checks": [
    { "id": "vm_reachability", "status": "fail", "critical": true,
      "error": {
        "code": "connect_failed",
        "message": "VM target connection failed.",
        "details": {},
        "descriptor": { "category": "connection", "retryable": true, "exitCode": 67 },
        "recovery": { "summary": "Retry with explicit URI", "fix_command": "flutter_mcp_cli exec --name get_vm --args '{\"connection\":{\"uri\":\"ws://127.0.0.1:8181/<token>/ws\"}}'" }
      }
    }
  ]
}
```

Read `error.descriptor` (not top-level) for retry policy and exit codes. `recovery.fix_command` is always present — run it directly.

---

## Recover by error code

### `binary_not_found`

**Meaning**: CLI binary is missing or not on PATH.
**Cause**: Binary was never built, or `mcp_server_dart/build/` is not in PATH.
**Recovery**:

```bash
cd /path/to/mcp_flutter && make build
export PATH="$PATH:/path/to/mcp_flutter/mcp_server_dart/build"
flutter_mcp_cli --help
```

---

### `vm_not_connected`

**Meaning**: A VM-dependent command was called without an active connection.
**Cause**: Flutter app not running, or connection URI not resolved yet.
**Recovery**:

```bash
flutter_mcp_cli exec --name status --args '{}'
# If that fails, run doctor to see what's wrong:
flutter_mcp_cli doctor --json
```

---

### `connect_failed`

**Meaning**: Connection attempt to the VM service target failed.
**Cause**: Wrong port, app not started yet, or token in URI is stale.
**Recovery**:

```bash
# Use explicit URI from Flutter output (app.debugPort.wsUri):
flutter_mcp_cli exec --name get_vm --args '{"connection":{"uri":"ws://127.0.0.1:8181/<token>/ws"}}'
```

---

### `connection_selection_required`

**Meaning**: Multiple debug targets detected; the CLI cannot pick one automatically.
**Cause**: More than one Flutter app is running in debug mode on the same machine.
**Recovery**:

```bash
# List available targets and pick the correct one:
flutter_mcp_cli exec --name discover_debug_apps --args '{}'
# Then pass the chosen target explicitly:
flutter_mcp_cli exec --name get_vm --args '{"connection":{"uri":"ws://127.0.0.1:8181/<token>/ws"}}'
```

The error envelope `details` field includes `availableTargets` — use the exact `uri` value from that list.

---

### `hot_reload_failed`

**Meaning**: Hot reload execution failed on the connected VM target.
**Cause**: Dart compilation error in the app code, or VM target disconnected mid-reload.
**Recovery**:

```bash
# Check app errors first:
flutter_mcp_cli exec --name get_app_errors --args '{}'
# Then run doctor to confirm VM is still reachable:
flutter_mcp_cli doctor --json
```

Fix any Dart errors in the app, then retry the reload.

---

### `visual_capture_unsupported`

**Meaning**: Visual capture (screenshot) is not supported on this target or OS mode.
**Cause**: Running on a device/platform that does not support capture, or macOS screen recording permission not granted.
**Recovery**:

```bash
# Check permission status:
flutter_mcp_cli permissions status --kind visual_capture
# Request the permission:
flutter_mcp_cli permissions request --kind visual_capture
# Or open system settings:
flutter_mcp_cli permissions open-settings --kind visual_capture
# Then re-run doctor to confirm:
flutter_mcp_cli doctor --json
```

---

## Connection issues (deeper troubleshooting)

**Port conflicts**: The VM service defaults to port 8181. If another process holds that port, Flutter will fail to bind it. Override:

```bash
flutter run --debug --host-vmservice-port=8182 --dds-port=8183 --enable-vm-service
# Then tell the CLI:
flutter_mcp_cli --dart-vm-port 8183 doctor --json
```

**Flutter app not in debug mode**: Release and profile builds do not expose the VM service. Always run:

```bash
flutter run --debug
```

**`mcp_toolkit` not initialized in `main.dart`**: Doctor's `mcp_toolkit_extensions` check will fail. Add the initialization before `runApp`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();
      runApp(const MyApp());
    },
    (error, stack) {
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    },
  );
}
```

After adding this, hot restart the app (not hot reload — binding init requires a full restart).

**Multiple apps / wrong target**: Pass `--target` with the exact websocket URI from `flutter attach` or `app.debugPort.wsUri`:

```bash
flutter_mcp_cli doctor --json --target ws://127.0.0.1:8181/<token>/ws
```

---

## CLI surface

The binary is `flutter_mcp_cli` (built to `mcp_server_dart/build/`).

| Subcommand | Purpose | Minimal example |
|---|---|---|
| `exec` | Run a single named command against the VM | `flutter_mcp_cli exec --name get_vm --args '{}'` |
| `batch` | Run multiple commands in one call | `flutter_mcp_cli batch --steps '[{"name":"get_vm"},{"name":"status"}]'` |
| `schema` | Print the JSON schema for a named command | `flutter_mcp_cli schema --name hot_reload_flutter` |
| `capabilities` | List all registered capabilities | `flutter_mcp_cli capabilities` |
| `serve` | Start the MCP server (stdio transport) | `flutter_mcp_cli serve` |
| `snapshot create` | Capture and save a named snapshot | `flutter_mcp_cli snapshot create --name baseline --args '{}'` |
| `snapshot diff` | Diff two snapshots | `flutter_mcp_cli snapshot diff --from baseline --to current` |
| `bundle create` | Package a snapshot into a publishable bundle | `flutter_mcp_cli bundle create --from-snapshot baseline --output ./out` |
| `doctor` | Run preflight checks (VM + toolkit + registry) | `flutter_mcp_cli doctor --json` |
| `permissions status` | Check a permission (e.g. visual_capture) | `flutter_mcp_cli permissions status --kind visual_capture` |
| `permissions request` | Request a permission | `flutter_mcp_cli permissions request --kind visual_capture` |
| `permissions open-settings` | Open OS settings for a permission | `flutter_mcp_cli permissions open-settings --kind visual_capture` |
| `validate-runtime` | End-to-end VM + toolkit + capture smoke test | `flutter_mcp_cli validate-runtime --target ws://127.0.0.1:8181/<token>/ws` |

Global flags (before the subcommand):
- `--dart-vm-port <n>` — override VM service port (default: 8181).
- `--dart-vm-host <host>` — override VM service host (default: localhost).
- `--vm-service-uri <ws_uri>` — full websocket URI, applied before session attach.
- `--log-level <level>` — `debug|info|notice|warning|error|critical` (default: error).
- `--dumps` — enable dump RPCs (disabled by default; high token cost).
- `-h`, `--help` — show usage.

---

## Reinstall / upgrade

The install script is idempotent — re-running it replaces the binary in place:

```bash
curl -fsSL https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/install.sh | bash
```

After reinstall, verify with `flutter_mcp_cli --help` and confirm the version matches the expected release.
