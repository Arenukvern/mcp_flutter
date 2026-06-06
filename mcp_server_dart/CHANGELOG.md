# Changelog

## [unreleased]

### Changed

- Raised workspace Dart SDK floor to `>=3.12.0 <4.0.0` for the MCP server package and aligned Docker examples with Dart `3.12.0`.
- `validate-runtime`: after a failed host `desktop_window` screenshot (`get_screenshots_failed`, retryable), automatically retries `capture_ui_snapshot` with `flutter_layer`. Summary includes `captureFallbackUsed` when the retry succeeds.
- Global `--vm-service-uri` is accepted as the VM target for `validate-runtime` (and warns if both `--target` and `--vm-service-uri` differ; `--target` wins).
- Renamed dynamic-registry MCP tools for consistent `fmt_` naming:
  `listClientToolsAndResources` → `fmt_list_client_tools_and_resources`,
  `runClientTool` → `fmt_client_tool`, `runClientResource` → `fmt_client_resource`
  (same strings for `flutter-mcp-toolkit exec --name`).

## [3.0.0]

Strict hard-cut release focused on reliability and machine contracts.

### BREAKING: MCP tool names now carry the `fmt_` capability prefix

All MCP tools surface as `fmt_<bare-name>` (e.g. `fmt_tap_widget`,
`fmt_hot_reload_and_capture`). Legacy unprefixed names return
`tool_not_found`. The CLI catalog (`flutter-mcp-toolkit exec --name <name>`)
keeps the bare names for intrinsic tools — only the MCP wire surface adds
`fmt_` there. Dynamic-registry host tools use `fmt_list_client_tools_and_resources`,
`fmt_client_tool`, and `fmt_client_resource` on both MCP and CLI. `visual://`
resource URIs are unchanged.

The server composes its tool surface from `Capability` instances loaded
into an `McpHost` registry; the host applies the prefix and forwards every
registration to `dart_mcp`'s `ToolsSupport` via `DartMcpDispatchBridge`.
The locked v3.0.0 surface lives at
`tool/contracts/expected_tool_surface.txt` and is enforced by
`test/tool_surface_snapshot_test.dart`.

See the root `CHANGELOG.md` for the full v2→v3 rename table.

### Other v3.0.0 changes

- Added `flutter-mcp-toolkit doctor [--json] [--target <path>] [--timeout-ms <n>]`.
- Added safe-write flags for `snapshot create` and `bundle create`:
  `--check`, `--diff`, `--backup`, `--no-overwrite`.
- Replaced destructive bundle overwrite flow with staged atomic publish.
- Unified error envelopes across CLI/MCP/daemon with:
  `code`, `message`, `details`, `descriptor`, `recovery`.
- Enforced strict typed parsing and removed implicit coercions.
- Defaulted command schemas to strict (`additionalProperties: false`) with explicit opt-in openings.
- Unified runtime/protocol metadata via shared version constants.
- Bumped package version to `3.0.0`.

### Migration: v2.x -> v3.0.0

- Parse descriptor fields from `error.descriptor`.
- Stop sending string-encoded booleans/objects/lists/integers.
- Prefer `doctor --json` preflight in automation.
- Update write flows to handle `write_blocked` and safe-write statuses.

- dockerfile for MCP Server - not tested.
  Huge thank you to [arslanmit](https://github.com/arslanmit) for PR with Dockerfile! https://github.com/Arenukvern/mcp_flutter/pull/64
- connection UX redesign for VM-dependent operations:
  - startup remains non-blocking (no forced VM target lock)
  - first VM-dependent call auto-attaches if target is unambiguous
  - ambiguous multi-target selection returns `connection_selection_required` with structured details:
    `reason`, `availableTargets`, `suggestedAction`, `example`, `howToRetry`
- added strict optional nested `arguments.connection` support across VM-dependent MCP tools:
  `targetId`, `mode`, `host`, `port`, `uri`, `forceReconnect`
- `connect_debug_app` now accepts the same `connection` object contract
- dynamic registry parity:
  - added optional `connection` to `fmt_list_client_tools_and_resources`, `fmt_client_tool`, `fmt_client_resource`
  - unified pre-connect flow and ambiguity/error semantics
- resource read targeting now supports URI query params:
  `targetId`, `mode`, `host`, `port`, `uri`, `forceReconnect`
- strict schema change: legacy flat top-level connection aliases (`host` / `port` / `uri`) are rejected in MCP tool inputs
- target identity migration (hard break):
  - `connection.targetId` and `availableTargets[].targetId` now use full VM websocket URI IDs
  - legacy `host:port` target IDs are rejected with migration hints (`connection.uri` fallback remains supported)
- Flutter web connectivity upgrade:
  - added `flutter attach --machine` discovery provider with `app.debugPort.wsUri` parsing
  - merged machine discovery and port-scan fallback before VM-dependent auto-attach
- new runtime discovery flags:
  - `--flutter-project-dir`
  - `--flutter-device`
  - `--flutter-discovery-timeout-ms`
- CLI UX alignment with MCP connection policy:
  - one-shot `exec` now supports strict optional `args.connection` with shared parser
  - daemon `command/execute` and `watch/start` accept the same `params.args.connection` targeting contract
  - snapshot `create` supports per-step `args.connection` targeting before each step executes
  - `exec` preconnect no longer emits synthetic `vm_not_connected` for VM-required ambiguity paths; executor auto policy returns `connection_selection_required`
  - explicit session attach remains strict, while implicit stale active-session attach now falls back to executor auto connection policy
  - conflict guard: `connect` / `session_start` reject mixed native selector fields and nested `args.connection`

## 0.2.0

Huge thank you to [CommentakMedia](https://github.com/CommentakMedia) for PR with Hot Restart tool and docs! https://github.com/Arenukvern/mcp_flutter/pull/67

### Added

- new tool: `hot_restart_flutter` to perform VM Service Hot Restart from MCP.
- VM service integration method `hotRestart()` with namespaced service discovery fallback.

- chore: xsoulspace_lints: ^0.1.2
- chore: lints: ^6.0.0

## Summary

Adds a new MCP tool `hot_restart_flutter` to trigger a VM Service Hot Restart for a connected Flutter app. This complements existing `hot_reload_flutter` and helps recover from corrupted state or apply changes that require a restart. Documentation and changelog updated.

## Motivation

- Some debugging workflows require a full app restart (without reinstall) rather than hot reload.
- After adding new VM service extensions or MCP dynamic tools, a restart is sometimes necessary to stabilize runtime state.

## Changes

- server: Implemented `hotRestart()` in VM service support with namespaced service discovery and safe fallbacks.
- tooling: Registered `hot_restart_flutter` as a first-class MCP tool alongside hot reload.
- docs: Updated README with usage notes and added a dedicated section for Hot Restart.
- docs: Added CHANGELOG entry (Unreleased).

## Backwards Compatibility

- No breaking changes. Existing tools and APIs remain unchanged.
- The new tool is additive and only runs when VM service is connected.

## How it works

- Discovers a namespaced `hotRestart` service via `EventStreams.kService`; falls back to calling the default `hotRestart` method when needed.
- Returns a Success report payload on completion; returns an error object if VM is not connected.

## Testing & Quality

- Code formatted and static analysis is clean (`dart analyze`: 0 issues).
- Manual sanity checks against a local Flutter debug app. Automated tests can be added by maintainers as needed.

## Usage

Example MCP call:

```jsonc
{
  "name": "hot_restart_flutter",
  "arguments": {}
}
```

Example result:

```jsonc
{
  "message": "{\"report\":{\"type\":\"Success\",\"success\":true}}"
}
```

## [0.1.0] - Initial

- Initial beta release.
