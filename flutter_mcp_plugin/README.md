# flutter-mcp (Claude Code plugin)

Package for driving a live Flutter app from Claude Code: inspect widgets, capture screenshots, hot-reload, and register app-specific MCP tools at runtime.

This plugin bundles:

| Surface | What it does |
|---------|--------------|
| **MCP server** (`.mcp.json`) | Registers the `flutter-inspector` MCP server so tools like `core_semantic_snapshot`, `core_tap_widget`, `core_hot_reload_and_capture`, `core_inspect_widget_at_point` are callable from any session. (v3.0.0+ surfaces tools under the `core_` capability prefix; legacy unprefixed names return `tool_not_found`.) |
| **Skill: `flutter-mcp`** | Teaches Claude when and how to use the server — preflight, snapshot/tap/enter loop, error envelope, permissions. |
| **Skill: `custom-toolkit-tools`** | Teaches Claude how to register app-specific tools from inside the Flutter app via `MCPCallEntry` + `addEntries`. Use when built-in tools aren't enough. |
| **Command: `/flutter-live-edit`** | One-call kickoff for a live-edit session (preflight → connect → baseline → edit loop). |
| **Agent: `flutter-inspector`** | Specialist subagent for Flutter runtime work. Auto-invoked when the user references a running Flutter debug app or a VM service URI. |

## Prerequisites

- Dart SDK on PATH.
- The `flutter_inspector_mcp` binary (built from https://github.com/Arenukvern/mcp_flutter).
- Target Flutter app running in **debug mode** with `mcp_toolkit` initialized.

## Install

```bash
# 1. Build the server binary
git clone https://github.com/Arenukvern/mcp_flutter
cd mcp_flutter
make install && make build

# 2. Put the binary on PATH OR export its location
export FLUTTER_MCP_BIN="$(pwd)/mcp_server_dart/build/flutter_inspector_mcp"

# 3. Run the plugin installer (verifies prerequisites)
bash flutter_mcp_plugin/install.sh
```

The plugin's `.mcp.json` resolves `${FLUTTER_MCP_BIN:-flutter_inspector_mcp}` — either works.

## Instrument your Flutter app

```bash
cd /your/flutter/app
flutter pub add mcp_toolkit
```

In `main.dart`, before `runApp`:

```dart
MCPToolkitBinding.instance
  ..initialize()
  ..initializeFlutterToolkit();
```

Run in debug with VM service on 8181:

```bash
flutter run --debug --host-vmservice-port=8182 --dds-port=8181 --enable-vm-service
```

## Use

- Ask Claude: *"inspect the running Flutter app and screenshot the home screen"* → agent auto-invokes, runs preflight, captures.
- `/flutter-live-edit` → enters the preflight + baseline + edit loop.
- *"register a custom MCP tool that returns my current cart total"* → the `custom-toolkit-tools` skill kicks in and walks through `MCPCallEntry` + `addEntries`.

## Non-obvious gotchas

- **Error envelope**: errors are `{code, message, details, descriptor, recovery}`. Parse `error.descriptor`, not the top-level.
- **Strict schemas**: `additionalProperties: false` by default. Unknown params reject — good, catches typos early.
- **`snapshotId` is not optional in practice**: always pass it to interaction calls so `stale_snapshot` fires instead of a silent wrong tap.
- **Hot reload ≠ hot restart**: extensions/registrations may need a full restart to re-emit DTD events.
- **Dump RPCs are off by default** (token cost). Opt in with server flag `--dumps`.
- **macOS screen recording** belongs to the process invoking visual capture — not Claude Code itself.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `connection_selection_required` | >1 debug app, or no target given | Pass `arguments.connection.uri` or `targetId`. |
| `target_not_found` | Stale target list | Refresh targets; use exact `app.debugPort.wsUri`. |
| Empty screenshots | Server started with `--no-images`, or macOS Screen Recording denied | Remove flag; `flutter_mcp_cli permissions request`. |
| Missing `ext.mcp.toolkit.*` | Toolkit not initialized or initialized too late | Initialize before `runApp`, then hot **restart**. |
| Registered tool not visible | `addEntries` ran inside widget lifecycle or not awaited | Register once at bootstrap; `await` the call; hot restart. |

## Layout

```
flutter_mcp_plugin/
├── .claude-plugin/plugin.json
├── .mcp.json
├── install.sh
├── README.md
├── skills/
│   ├── flutter-mcp/SKILL.md
│   └── custom-toolkit-tools/SKILL.md
├── commands/
│   └── flutter-live-edit.md
└── agents/
    └── flutter-inspector.md
```

## License

MIT (matches parent `mcp_flutter` repo).
