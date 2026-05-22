# Flutter MCP Toolkit — North Star

**Repository:** This repo (`mcp_flutter`) **is** the Flutter MCP Toolkit product — `mcp_server_dart`, capability kernel/core, `mcp_toolkit`, plugin skills, release binaries.

**Maintainer docs (repo root, not under `docs/`):** `plans/`, `specs/`, `decisions/` (ADRs symlinked as `docs/decisions/` for docs.page).

---

## What this repo owns

1. **Connection** — VM discovery, sticky sessions, `doctor`, envelopes (`exec` / `batch` / `serve`).
2. **`fmt_*` capability** — inspect and control a debug Flutter app.
3. **Dynamic tooling** — `fmt_list_client_tools_and_resources`, `fmt_client_tool`, `fmt_client_resource`; app `addMcpTool()`.
4. **Agent onboarding** — plugin skills: guide, setup, inspect, control, debug, custom-tools (`flutter-mcp-toolkit init`).

## Extension model

1. **App:** `addMcpTool()` (preferred).
2. **Host:** new `Capability` wired in server `main`.
3. **Files:** HS via **flutter-harness** CLI (other repo).

## Distribution

- **Ship:** `install.sh` → `flutter-mcp-toolkit` + `flutter-mcp-toolkit-server`.
- **pub.dev:** `mcp_toolkit` for Flutter apps; kernel/core packages deferred.

## Local dev with harness

```bash
# Toolkit (this repo)
cd mcp_server_dart && dart test

# Harness (sibling clone)
cd ../flutter_harness
cp pubspec_overrides.yaml.example pubspec_overrides.yaml   # path → this repo
dart pub get && dart test
export FLUTTER_MCP_TOOLKIT_ROOT="$(cd ../mcp_flutter && pwd)"
bash tool/harness/check_hs_fixtures.sh
```
