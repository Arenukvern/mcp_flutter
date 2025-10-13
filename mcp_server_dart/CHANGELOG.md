# Changelog

## [unreleased]

- dockerfile for MCP Server - not tested.
  Huge thank you to [arslanmit](https://github.com/arslanmit) for PR with Dockerfile! https://github.com/Arenukvern/mcp_flutter/pull/64

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
