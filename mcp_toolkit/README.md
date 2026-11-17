# MCP Toolkit for Flutter

[![pub package](https://img.shields.io/pub/v/mcp_toolkit.svg?include_prereleases)](https://pub.dev/packages/mcp_toolkit)
[![pub points](https://img.shields.io/pub/points/mcp_toolkit.svg)](https://pub.dev/packages/mcp_toolkit/score)
[![skills.sh](https://skills.sh/b/arenukvern/mcp_flutter)](https://skills.sh/arenukvern/mcp_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)

<p align="center">
  <img src="https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/docs/assets/logo.png" alt="flutter-mcp-toolkit logo" width="160" />
</p>

Flutter-side library for [flutter-mcp-toolkit](https://github.com/Arenukvern/mcp_flutter): VM service extensions so the MCP server can read errors, capture UI, and run **your** tools at runtime.

**Not** the [Dart MCP server](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server) (analyzer/tooling). This package targets a **running debug app**.

![View Screenshots](https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/docs/view_screenshots.gif)

See dynamic tools registration in this [short YouTube video](https://www.youtube.com/watch?v=Qog3x2VcO98).

Docs: [docs.page/arenukvern/mcp_flutter](https://docs.page/arenukvern/mcp_flutter/) · [quickstart](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/quickstart.mdx)

## Add to your app

```bash
flutter pub add mcp_toolkit
# or: flutter-mcp-toolkit codegen-init
```

```dart
import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

Future<void> main() async {
  final binding = MCPToolkitBinding.instance;
  await binding.bootstrapFlutter(runApp: () => runApp(const MyApp()));
}
```

Debug mode only (assert-guarded). After changing bootstrap code, **hot restart** — not just hot reload.

## Custom tools

```dart
await binding.addEntries(
  entries: {
    AgentCallEntry.tool(
      namespace: 'demo',
      name: 'ping',
      description: 'Health check',
      inputSchema: const {
        'type': 'object',
        'additionalProperties': false,
        'properties': {},
      },
      handler: (args) async => AgentResult.success(message: 'pong'),
    ),
  },
);
await binding.bootstrapFlutter(runApp: () => runApp(const MyApp()));
```

Full example: [fibonacci_tool_example.dart](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_toolkit/example/fibonacci_tool_example.dart).

Agent discovery: `fmt_list_client_tools_and_resources` / `fmt_client_tool`.

Migrations: [projections](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/migration/migration_toolkit_projections.mdx), [AgentCallEntry](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/migration/migration_mcp_call_entry_to_agent_call_entry.md).

## Server pairing

Run the [flutter-mcp-toolkit-server](https://github.com/Arenukvern/mcp_flutter/tree/main/mcp_server_dart) MCP entry (`flutter-mcp-toolkit-server` on stdio) with the app in **debug** and `mcp_toolkit` initialized in `main()`.