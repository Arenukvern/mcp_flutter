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

## Distribution

- **Ship:** `install.sh` → `flutter-mcp-toolkit` + short alias `fmtk` + `flutter-mcp-toolkit-server`.
- **pub.dev:** Flutter MCP Toolkit packages ship on one version train. `VERSION`, `mcp_toolkit`, `mcp_server_dart`, capability/core packages, runtime metadata, and plugin manifests must agree (currently `4.0.0-dev.5` for the breaking prerelease train).
