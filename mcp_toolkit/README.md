# MCP Toolkit for Flutter

[![pub package](https://img.shields.io/pub/v/mcp_toolkit.svg?include_prereleases)](https://pub.dev/packages/mcp_toolkit)
[![pub points](https://img.shields.io/pub/points/mcp_toolkit.svg)](https://pub.dev/packages/mcp_toolkit/score)
[![skills.sh](https://skills.sh/b/arenukvern/mcp_flutter)](https://skills.sh/arenukvern/mcp_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)

Flutter-side library for [flutter-mcp-toolkit](https://github.com/Arenukvern/mcp_flutter): VM service extensions so the MCP server can read errors, capture UI, and run **your** tools at runtime.

**Not** the [Dart MCP server](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server) (analyzer/tooling). This package targets a **running debug app**.

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
import 'package:intentcall_schema/intentcall_schema.dart';

await binding.addEntries(
  entries: {
    AgentCallEntry.tool(
      namespace: 'demo',
      name: 'ping',
      description: 'Health check',
      inputSchema: ObjectSchema(properties: {}),
      handler: (args) async => AgentResult.success(message: 'pong'),
    ),
  },
);
await binding.bootstrapFlutter(runApp: () => runApp(const MyApp()));
```

Full example with `inputSchema`: [fibonacci_tool_example.dart](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_toolkit/example/fibonacci_tool_example.dart).

Agent discovery: `fmt_list_client_tools_and_resources` / `fmt_client_tool`.

Migrations: [projections](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/migration/migration_toolkit_projections.mdx), [AgentCallEntry](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/migration/migration_mcp_call_entry_to_agent_call_entry.md).

## Server pairing

Install `flutter-mcp-toolkit-server` ([install script](https://github.com/Arenukvern/mcp_flutter/blob/main/install.sh)) and point your MCP client at it. Verify with `flutter-mcp-toolkit doctor`.

## Version

Pin with the server release you install (see [VERSION](https://github.com/Arenukvern/mcp_flutter/blob/main/VERSION)). Check [CHANGELOG](https://github.com/Arenukvern/mcp_flutter/blob/main/CHANGELOG.md) before upgrading.

## Examples

- [example/](https://github.com/Arenukvern/mcp_flutter/tree/main/mcp_toolkit/example)
- [showcase/flutter_test_app](https://github.com/Arenukvern/mcp_flutter/tree/main/showcase/flutter_test_app)

## Develop

```bash
cd mcp_toolkit && flutter pub get && flutter test
```

Package changelog history: [mcp_server_dart/CHANGELOG.md](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_server_dart/CHANGELOG.md). Train releases: [CHANGELOG.md](https://github.com/Arenukvern/mcp_flutter/blob/main/CHANGELOG.md).