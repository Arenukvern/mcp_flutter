# LLM Installation Guide: MCP Flutter Inspector

This is the canonical agent-facing install runbook for MCP Flutter.

## New Documentation Structure

- AI agent docs hub (includes `flutter-mcp-toolkit init <agent>` wiring): [docs/ai_agents/overview.mdx](docs/ai_agents/overview.mdx)
- Agent execution playbook: [docs/ai_agents/execution_playbook.mdx](docs/ai_agents/execution_playbook.mdx)
- AI troubleshooting: [docs/ai_agents/troubleshooting.mdx](docs/ai_agents/troubleshooting.mdx)
- CLI vs MCP decision guide: [docs/start_here/cli_vs_mcp.mdx](docs/start_here/cli_vs_mcp.mdx)

## 0. AI Agent Instructions

Your role:

1. Collect required paths from the user before making changes.
2. Build the server, instrument the Flutter app, and configure the client safely.
3. Validate tool execution.

## 1. Required Inputs

Ask for and confirm both absolute paths:

- `[MCP_SERVER_BASE_PATH]`: folder where `mcp_flutter` should be cloned.
- `[FLUTTER_APP_PATH]`: target Flutter app to instrument.

Do not proceed until both are known.

## 2. Clone And Build

```bash
cd [MCP_SERVER_BASE_PATH]
git clone https://github.com/Arenukvern/mcp_flutter
cd mcp_flutter
make install
```

Expected binary:

- `[MCP_SERVER_BASE_PATH]/mcp_flutter/mcp_server_dart/build/flutter-mcp-toolkit-server`

v2 → v3 (MCP `fmt_*` names, `mcpServers` keys): [docs/start_here/migration_v2_to_v3.mdx](docs/start_here/migration_v2_to_v3.mdx).

## 3. Add Toolkit To Flutter App

```bash
cd [FLUTTER_APP_PATH]
flutter pub add mcp_toolkit
flutter pub get
```

Ensure app initialization includes:

```dart
MCPToolkitBinding.instance
  ..initialize()
  ..initializeFlutterToolkit();

MCPToolkitBinding.instance.handleZoneError(error, stack);
```

## 4. Run Flutter In Debug Mode

```bash
flutter run --debug --machine --host-vmservice-port=8181 -d macos
```

(Adjust `-d` for your device; use `app.debugPort.wsUri` from machine output for explicit MCP connections.)

## 5. Configure The AI Client

Pick one and merge a **`flutter-mcp-toolkit`** server entry under `mcpServers` (do not delete existing servers). The legacy key **`flutter-inspector`** still works if your config predates the rename.

> **IDs:** **`flutter-inspector`** in `mcpServers` is only the **legacy registry key** for this server. The optional Claude Code subagent shipped in the repo plugin is **`flutter-mcp-toolkit-runtime`** (`plugin/agents/flutter-mcp-toolkit-runtime.md`) — not `flutter-inspector`.

- Codex / Cursor / Claude: [docs/ai_agents/overview.mdx](docs/ai_agents/overview.mdx)

## 6. Validate

Run these checks in the assistant:

1. List tools from **`flutter-mcp-toolkit`** (or **`flutter-inspector`** if that is your registry key)
2. Get extension RPCs and verify:
   - `ext.mcp.toolkit.app_errors`
   - `ext.mcp.toolkit.view_details`
   - `ext.mcp.toolkit.view_screenshots`
3. Take a screenshot
4. Get view details (layout metadata)
5. Get app errors

If response is `connection_selection_required`, retry with `arguments.connection.targetId` from `availableTargets`.

If toolkit extension RPCs are missing, do not claim app-level inspection success:

- Ensure `mcp_toolkit` is installed and initialized in app startup.
- Restart debug app and retry `get_extension_rpcs`.
- If app cannot be modified, report that Flutter MCP cannot plug into this app for screenshots/layout/errors.

## 7. Escalation

If setup fails, use:

- [docs/ai_agents/troubleshooting.mdx](docs/ai_agents/troubleshooting.mdx)
