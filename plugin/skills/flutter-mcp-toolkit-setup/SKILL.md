---
name: flutter-mcp-toolkit-setup
description: Verify the flutter-mcp-toolkit install, run doctor preflight, troubleshoot connection issues. Use when the toolkit isn't responding or first-time setup.
---

<!-- @FMT_MODE_PRELUDE -->

## When to use

Use this skill when:

- First-time install: `flutter-mcp-toolkit` or its short alias `fmtk` is not yet on PATH.
- `doctor --json` returns any check with `"status": "fail"`.
- MCP server fails to connect or tools return `vm_not_connected` / `connect_failed`.
- Visual capture or toolkit-bridge commands are returning unexpected errors.

---

## Verify install

```bash
flutter-mcp-toolkit --help
fmtk --help
```

Expected output: command help from both names. `flutter-mcp-toolkit` is the canonical long name; `fmtk` is the compact alias for day-to-day terminal loops.

If you get `command not found`, the binary is not on PATH:

```bash
# Binary is built to mcp_server_dart/build/ inside the repo
export PATH="$PATH:/path/to/mcp_flutter/mcp_server_dart/build"
# Or rebuild from source
cd /path/to/mcp_flutter && make build
```

Then verify with `flutter-mcp-toolkit --help` and `fmtk --help`.

---

## Run doctor

Always run doctor before any VM-dependent command:

```bash
fmtk doctor --json
```

Flags: `--target <ws_uri>` (test a specific URI), global `--vm-service-uri <ws_uri>` (same as `--target` when omitted on `doctor`), `--timeout-ms <n>` (default: 2500).

```bash
# Global URI works for doctor (same as validate-runtime)
fmtk --vm-service-uri 'ws://127.0.0.1:8181/<token>/ws' doctor --json
```

Sample green output:

```json
{
  "summary": { "criticalFailures": 0 },
  "checks": [
    { "id": "vm_target_reachable", "status": "pass", "critical": true },
    { "id": "mcp_toolkit_extensions", "status": "pass", "critical": true },
    { "id": "dynamic_registry_available", "status": "pass", "critical": false }
  ]
}
```

**Triage:** `criticalFailures > 0` means VM/setup is blocked — not that every tool is broken. `dynamic_registry_available: pass` with `vm_target_reachable: fail` usually means a stale URI after hot restart; run `discover_debug_apps` and pass the new `targetId`.

Read `error.descriptor` (not top-level) for retry policy and exit codes. Each check includes `fix_command` — run it directly.

---

## Recover by error code

### `binary_not_found`

Binary missing or not on PATH. Rebuild and add to PATH:

```bash
cd /path/to/mcp_flutter && make build
export PATH="$PATH:/path/to/mcp_flutter/mcp_server_dart/build"
```

### `vm_not_connected`

Flutter app not running, stale token after restart, or URI not resolved:

```bash
fmtk exec --name discover_debug_apps --args '{}'
fmtk exec --name status --args '{}'
fmtk doctor --json --target ws://127.0.0.1:8181/<new-token>/ws
```

After a successful auto re-attach, `meta.recovery.reattachedTo` shows the new endpoint.

### `connect_failed`

Wrong port, app not started, or stale token. Pass explicit URI from `app.debugPort.wsUri`:

```bash
fmtk exec --name get_vm --args '{"connection":{"uri":"ws://127.0.0.1:8181/<token>/ws"}}'
```

### `connection_selection_required`

Multiple debug targets detected. List with `discover_debug_apps`, then pass the chosen URI from `details.availableTargets` explicitly to `get_vm`.

### `hot_reload_failed`

Dart compilation error or VM disconnected. Check errors, fix, then retry:

```bash
fmtk exec --name get_app_errors --args '{}'
```

### `visual_capture_unsupported`

macOS screen recording permission not granted or unsupported platform:

```bash
fmtk permissions request --kind visual_capture
```

---

## Connection issues (deeper troubleshooting)

**Port conflicts**: VM service defaults to 8181. Override if another process holds it:

```bash
flutter run --debug --host-vmservice-port=8182 -d macos
fmtk --dart-vm-port 8182 doctor --json
```

Use `flutter run --machine` and copy `app.debugPort.wsUri` when you need the exact websocket URI (recommended for `validate-runtime` and `exec`).

**Flutter app not in debug mode**: Release/profile builds don't expose the VM service. Always use `flutter run --debug`.

**`mcp_toolkit` not initialized**: Doctor's `mcp_toolkit_extensions` check will fail. Add before `runApp` — use `flutter-mcp-toolkit codegen-init` to generate the boilerplate (see CLI surface below). After adding, hot restart (not hot reload — binding init requires a full restart).

**Multiple apps / wrong target**: Pass `--target` with the exact websocket URI:

```bash
fmtk doctor --json --target ws://127.0.0.1:8181/<token>/ws
```

---

## CLI surface

The canonical binary is `flutter-mcp-toolkit` (built to `mcp_server_dart/build/`). Packaged installs also include `fmtk`, a short alias to the same entrypoint. Use `fmtk` in quick loops; keep the long name in install, onboarding, PATH, and MCP configuration docs.

| Subcommand                  | Purpose                                                 | Minimal example                                                                |
| --------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `exec`                      | Run a single named command against the VM               | `fmtk exec --name get_vm --args '{}'`                                          |
| `batch`                     | Run multiple commands in one call                       | `fmtk batch --steps '[{"name":"get_vm"},{"name":"status"}]'`                   |
| `schema`                    | Print the JSON schema for a named command               | `fmtk schema --name hot_reload_flutter`                                        |
| `capabilities`              | List all registered capabilities                        | `fmtk capabilities`                                                            |
| `serve`                     | Start the MCP server (stdio transport)                  | `fmtk serve`                                                                   |
| `snapshot create`           | Capture and save a named snapshot                       | `fmtk snapshot create --name baseline --args '{}'`                             |
| `snapshot diff`             | Diff two snapshots                                      | `fmtk snapshot diff --from baseline --to current`                              |
| `bundle create`             | Package a snapshot into a publishable bundle            | `fmtk bundle create --from-snapshot baseline --output ./out`                   |
| `doctor`                    | Run preflight checks (VM + toolkit + registry)          | `fmtk doctor --json`                                                           |
| `permissions status`        | Check a permission (e.g. visual_capture)                | `fmtk permissions status --kind visual_capture`                                |
| `permissions request`       | Request a permission                                    | `fmtk permissions request --kind visual_capture`                               |
| `permissions open-settings` | Open OS settings for a permission                       | `fmtk permissions open-settings --kind visual_capture`                         |
| `validate-runtime`          | End-to-end VM + toolkit + capture smoke test            | `fmtk validate-runtime --target ws://127.0.0.1:8181/<token>/ws`                |
| `init <agent>`              | Install skills + MCP server config for an AI agent      | `flutter-mcp-toolkit init claude-code`                                         |
| `codegen-init`              | Add toolkit dependency and emit `main.dart` boilerplate | `flutter-mcp-toolkit codegen-init`                                             |

Global flags (before the subcommand): `--dart-vm-port <n>`, `--dart-vm-host <host>`, `--vm-service-uri <ws_uri>`, `--log-level <level>`, `--dumps`, `-h/--help`.

**VM targeting:** Global `--vm-service-uri` applies to `doctor` and `validate-runtime` when subcommand `--target` is omitted. If both are set and differ, `--target` wins (stderr warning).

**`validate-runtime` screenshots:** the first capture uses `auto` (often `desktop_window` on macOS). If that step fails with a retryable `get_screenshots_failed`, the CLI retries once with `flutter_layer`. On success, `data.summary.captureFallbackUsed` is `true` in the JSON envelope.

**Debug/eval batteries:** keep repeated checks as scripts or `batch` calls over existing primitives first: `--log-level debug`, `--output-dir`, `--save-images`, `doctor --json`, `validate-runtime`, `batch`, and `exec --name diagnose`. Do not expose a generic MCP `run_tool`; MCP remains the typed `fmt_*` tool surface. If a flow becomes reusable across projects as a scenario, graduate it to `flutter_harness` HS docs/examples instead of adding a toolkit-only scenario language.

---

### `init <agent>`

Install the flutter-mcp-toolkit skills + MCP server config for an AI agent.

Targets: `claude-code` | `cursor` | `codex` | `cline` | `agents-skills` | `all`.

```bash
flutter-mcp-toolkit init claude-code        # install for Claude Code (project-scoped)
flutter-mcp-toolkit init cursor --scope user # install user-globally for Cursor
flutter-mcp-toolkit init all --mode cli      # install for every detected agent in CLI mode
```

Mode auto-detects (MCP if registered, else CLI). Override with `--mode mcp|cli|auto`.

**Alternative (skills only, open ecosystem):** `npx skills add Arenukvern/mcp_flutter -a cursor -y` installs the same `SKILL.md` bundles via [skills.sh](https://skills.sh); it does not write `mcp.json` — run `init` afterward or configure `mcpServers` manually. See [AI agent overview](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/ai_agents/overview.mdx).

---

### `codegen-init`

From a Flutter project root, add `mcp_toolkit` as a dependency and emit
the boilerplate snippet for `lib/main.dart`.

```bash
cd my-flutter-app
flutter-mcp-toolkit codegen-init             # runs `flutter pub add` + prints snippet
flutter-mcp-toolkit codegen-init --no-pub-add  # snippet only, skip pub add
```

---

## Reinstall / upgrade

The install script is idempotent — re-running it replaces the binary in place:

```bash
curl -fsSL https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/install.sh | bash
```

After reinstall, verify with `flutter-mcp-toolkit --help` and `fmtk --help`.
