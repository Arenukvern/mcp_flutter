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
import 'package:mcp_toolkit/mcp_toolkit.dart';

Future<void> main() async {
  final binding = MCPToolkitBinding.instance;
  await binding.bootstrapFlutter(runApp: () => runApp(const MyApp()));
}
```

Debug mode only (assert-guarded). After changing bootstrap code, **hot restart** — not just hot reload.

## Custom tools

Register `AgentCallEntry` surfaces, then bootstrap:

```dart
await binding.addEntries(entries: {
  AgentCallEntry.tool(
    namespace: 'demo',
    name: 'ping',
    description: 'Health check',
    handler: (args) async => AgentResult.success(message: 'pong'),
  ),
});
await binding.bootstrapFlutter(runApp: () => runApp(const MyApp()));
```

Agent discovers them via `fmt_list_client_tools_and_resources` / `fmt_client_tool`.

Migrations: [projections](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/migration/migration_toolkit_projections.mdx), [AgentCallEntry](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/migration/migration_mcp_call_entry_to_agent_call_entry.md).

## Server pairing

Install `flutter-mcp-toolkit-server` ([install script](https://github.com/Arenukvern/mcp_flutter/blob/main/install.sh)) and point your MCP client at it. Verify with `flutter-mcp-toolkit doctor`.

## Version

Pin with the server release you install (see repo [VERSION](https://github.com/Arenukvern/mcp_flutter/blob/main/VERSION)). Example constraint: `mcp_toolkit: ^7.1.1` when matching server 7.1.x — check [CHANGELOG](https://github.com/Arenukvern/mcp_flutter/blob/main/CHANGELOG.md) before upgrading.

## Examples

- [example/](example/) — minimal bootstrap and Fibonacci tool
- Showcase: [showcase/flutter_test_app](../showcase/flutter_test_app/)

## Develop

```bash
cd mcp_toolkit && flutter pub get && flutter test
```

Changelog: [repository CHANGELOG.md](../CHANGELOG.md).