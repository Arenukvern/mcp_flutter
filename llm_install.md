# LLM Installation Guide: MCP Flutter Inspector

This is the canonical agent-facing install runbook for MCP Flutter.

## New Documentation Structure

- AI agent docs hub: [docs/ai_agents/overview.mdx](docs/ai_agents/overview.mdx)
- Agent execution playbook: [docs/ai_agents/execution_playbook.mdx](docs/ai_agents/execution_playbook.mdx)
- Codex setup: [docs/ai_agents/codex.mdx](docs/ai_agents/codex.mdx)
- Cursor setup: [docs/ai_agents/cursor.mdx](docs/ai_agents/cursor.mdx)
- Claude setup: [docs/ai_agents/claude.mdx](docs/ai_agents/claude.mdx)
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

- `[MCP_SERVER_BASE_PATH]/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp`

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
flutter run --debug --host-vmservice-port=8182 --dds-port=8181 --enable-vm-service --disable-service-auth-codes
```

## 5. Configure The AI Client

Pick one and merge a `flutter-inspector` server entry (do not delete existing servers):

- Codex: [docs/ai_agents/codex.mdx](docs/ai_agents/codex.mdx)
- Cursor: [docs/ai_agents/cursor.mdx](docs/ai_agents/cursor.mdx)
- Claude: [docs/ai_agents/claude.mdx](docs/ai_agents/claude.mdx)

## 6. Validate

Run these checks in the assistant:

1. List tools from `flutter-inspector`
2. Take a screenshot
3. Get app errors

If response is `connection_selection_required`, retry with `arguments.connection.targetId` from `availableTargets`.

## 7. Escalation

If setup fails, use:

- [docs/ai_agents/troubleshooting.mdx](docs/ai_agents/troubleshooting.mdx)
