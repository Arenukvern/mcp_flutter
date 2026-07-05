# MCP Toolkit for Flutter

[![pub package](https://img.shields.io/pub/v/mcp_toolkit.svg?include_prereleases)](https://pub.dev/packages/mcp_toolkit)
[![pub points](https://img.shields.io/pub/points/mcp_toolkit.svg)](https://pub.dev/packages/mcp_toolkit/score)
[![skills.sh](https://skills.sh/b/arenukvern/mcp_flutter)](https://skills.sh/arenukvern/mcp_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![smithery badge](https://smithery.ai/badge/@Arenukvern/mcp_flutter)](https://smithery.ai/server/@Arenukvern/mcp_flutter)
[![All Contributors](https://img.shields.io/github/all-contributors/Arenukvern/mcp_flutter?color=ee8449&style=flat-square)](https://github.com/Arenukvern/mcp_flutter#contributors-)
<a title="Discord" href="https://discord.com/invite/y54DpJwmAn" ><img src="https://img.shields.io/discord/696688204476055592.svg" /></a>
[![maintained with Skill Steward](https://raw.githubusercontent.com/Arenukvern/skill_steward/main/docs/brand/assets/svg/badge-light.svg)](https://github.com/Arenukvern/skill_steward)

> [!NOTE]
> Hi! This is not official package - it's a personal project.
>
> For official package - please see [ai repository](https://github.com/dart-lang/ai/tree/main/pkgs/dart_tooling_mcp_server)
>
> This package is a core component of the [flutter-mcp-toolkit](https://github.com/Arenukvern/mcp_flutter) project. It acts as the "client-side" library within your Flutter application, enabling the Model Context Protocol (MCP) `MCP Server` to perform Flutter-specific operations like retrieving application errors, capturing screenshots, and getting view details.
>
> - 📖 **Docs:** [docs.page/arenukvern/mcp_flutter](https://docs.page/arenukvern/mcp_flutter/)
>
> `flutter-mcp-toolkit` is a Dart MCP server + Flutter package that lets AI Agents (Codex, Zed, Cursor, Intent, Claude Code, Cline, etc..) take (semantic snapshots, tap widgets, type into forms, hot-reload, and read logs from a Flutter app) or create **its own tools and resources at runtime** using MCP Toolkit — without leaving the conversation and work with Flutter apps in closed feedback loop - see example of it described in [OpenAI Agentic Harness](https://openai.com/index/harness-engineering/).
>
> [!NOTE]
>
> - The architecture of package may change significantly.

![View Screenshots](https://github.com/Arenukvern/mcp_flutter/blob/6a0a83b8df2cf364b8d535cb382068ed0f4259ff/docs/view_screenshots.gif)

## Data Transparency

This package is designed to be transparent and easy to understand. It is built on top of the Dart VM Service Protocol, which is a public protocol for interacting with the Dart VM.

To make it simple and customizable - it divided into groups of methods which acts as method handlers.

For example, the default first-pass path is `bootstrapFlutter()`.

All methods are available only in debug mode and wrapped in assert statements.

Register custom surfaces with **`AgentCallEntry`** (re-exported from `intentcall_core`):

```dart
await MCPToolkitBinding.instance.bootstrapFlutter(
  additionalEntries: {
    AgentCallEntry.resource(
      namespace: 'app',
      name: 'app_runtime_status',
      description: 'Read-only app diagnostics',
      mimeType: 'application/json',
      handler: (final args) async => AgentResult.success(
        message: 'App runtime diagnostics',
        data: {'ready': true},
      ),
    ),
  },
  runApp: () => runApp(const MyApp()),
);
```

Or use **`mcpToolkitTool`** / **`mcpToolkitResource`** when you already have
`MCPToolDefinition` + `MCPCallResult` handlers (see [example/fibonacci_tool_example.dart](example/fibonacci_tool_example.dart)). These helpers are compatibility bridges; new reusable registry, session, and result behavior belongs in IntentCall packages.

App-side permission bridging is separate and opt-in:

```dart
MCPToolkitBinding.instance
  ..initialize()
  ..initializeFlutterToolkit()
  ..initializeFlutterPermissionToolkit(delegate: MyPermissionDelegate());
```

## Features

- Auto register tools and resources in MCP server:

```dart
addMcpTool(
  mcpToolkitTool(
    namespace: 'app',
    definition: MCPToolDefinition(
      name: 'calculate_fibonacci',
      description: 'Calculate the nth Fibonacci number and return the sequence',
      inputSchema: ObjectSchema(
        required: ['n'],
        properties: {
          'n': IntegerSchema(
            description: 'The position in the Fibonacci sequence (0-100)',
            minimum: 0,
            maximum: 100,
          ),
        },
      ),
    ),
    handler: (final request) {
      final n = int.tryParse(request['n'] ?? '0') ?? 0;
      return MCPCallResult(
        message: 'Fibonacci number at position $n is ${fibonacci(n)}',
        parameters: {'result': fibonacci(n)},
      );
    },
  ),
);
```

- **VM Service Extensions**: Registers a set of custom VM service extensions (e.g., `ext.mcp.toolkit.app_errors`, `ext.mcp.toolkit.view_screenshots`, `ext.mcp.toolkit.view_details`, `ext.mcp.toolkit.semantic_snapshot`, `ext.mcp.toolkit.reveal_search`, `ext.mcp.toolkit.tap_widget`, …).
- **Error Reporting**: Captures and makes available runtime errors from the Flutter application.
- **Screenshot Capability**: Allows external tools to request screenshots of the application's views.
- **Application Details**: Provides a mechanism to fetch basic details about the application's views.
- **Semantic Snapshot + Gestures** (`SemanticSnapshotService`, `RevealSearchService`, `GestureInteractionService`): Compact JSON snapshot of interactive widgets with stable refs, bounded reveal/search for off-screen semantic targets, plus ref-driven `tap`/`long_press`/`enter_text`/`scroll`/`swipe`/`drag` using a two-tier (semantic-action → pointer-event) dispatch.
- **Log Capture** (`LogCaptureService`): Ring buffer of recent `print`/`debugPrint` output surfaced via `get_recent_logs`.
- **Optional Permission Bridge**: Lets the app expose permission status/request/open-settings handlers only when you register a delegate.
- **Capture hints for hybrid rendering**: `view_details` and `view_screenshots` expose `captureHints` when native platform views or external `Texture` widgets are detected. Apps that render via WGPU/Metal/Vulkan without platform views can opt in:

```dart
MCPToolkitBinding.instance.captureHintsContributor = () {
  return const PlatformViewHints(
    platformViewsDetected: true,
    matches: [],
    recommendedMode: kCaptureHintRecommendedDesktopWindow,
    warning: kPlatformViewWarning,
  );
};
```

Import `PlatformViewHints` and constants from `package:mcp_toolkit/mcp_toolkit.dart` (re-exported from `flutter_mcp_toolkit_core`).

## Integration

1.  **Add as a Dependency**:
    Add `mcp_toolkit` to your Flutter project's `pubspec.yaml` file.

    If you have the `mcp_flutter` repository cloned locally, you can use a path dependency:

    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      # ... other dependencies
      # Stable users: stay on the latest 3.x release.
      # v4 prerelease adopters: use the current 4.0.0-dev.x train intentionally.
      mcp_toolkit: ^4.0.0-dev.5
    ```

    Then, run `flutter pub get` in your Flutter project's directory.

2.  **Initialize in Your App**:
    In your Flutter application's `main.dart` file, use the canonical bootstrap path:

    ```dart
    import 'package:flutter/material.dart';
    import 'dart:async';
    import 'package:mcp_toolkit/mcp_toolkit.dart';

    Future<void> main() async {
      await MCPToolkitBinding.instance.bootstrapFlutter(
        additionalEntries: {
          AgentCallEntry.tool(
            namespace: 'app',
            name: 'calculate_fibonacci',
            description: 'Calculate the nth Fibonacci number',
            inputSchema: const {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'n': {'type': 'string'},
              },
              'required': ['n'],
            },
            handler: (final args) async {
              final n = int.tryParse(args['n']?.toString() ?? '') ?? 0;
              return AgentResult.success(
                message: 'Calculated Fibonacci number for position $n',
                data: {'result': fibonacci(n)},
              );
            },
          ),
          AgentCallEntry.resource(
            namespace: 'app',
            name: 'app_runtime_status',
            description: 'Read-only runtime diagnostics',
            mimeType: 'application/json',
            handler: (final args) async => AgentResult.success(
              message: 'Runtime diagnostics',
              data: {'ready': true, 'screen': 'home'},
            ),
          ),
        },
        runApp: () => runApp(const MyApp()),
      );
    }

    // ... rest of your app code
    ```

    `bootstrapFlutter()` does the boring parts in one place:
    `WidgetsFlutterBinding.ensureInitialized()`,
    `initialize()`,
    `initializeFlutterToolkit()`,
    optional app entry registration,
    and zone error forwarding via `handleZoneError`.

    Keep the older low-level calls only when you need custom startup choreography.

    **Migrating from `MCPCallEntry`:** use
    `flutter-mcp-toolkit migrate agent-entries` — see
    [migration_mcp_call_entry_to_agent_call_entry.md](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/start_here/migration_mcp_call_entry_to_agent_call_entry.md).

    **When to touch IntentCall directly:** ordinary Flutter apps should import
    `package:mcp_toolkit/mcp_toolkit.dart` and use its `AgentCallEntry` /
    `AgentResult` re-exports. Depend on `intentcall_*` packages directly only
    when you are building reusable registry/session/platform behavior outside
    Flutter MCP Toolkit's app instrumentation layer.

3.  **Optional: Register an App-Side Permission Delegate**:
    Keep `initializeFlutterToolkit()` unchanged and add the permission bridge only if the app owns the relevant permission flow.

    ```dart
    final class MyPermissionDelegate implements MCPPermissionDelegate {
      @override
      Iterable<String> listSupportedPermissionKinds() => const <String>[
        'visual_capture',
      ];

      @override
      Future<MCPPermissionResult> getPermissionStatus({
        required final String kind,
      }) async => const MCPPermissionResult(
        kind: 'visual_capture',
        status: 'granted',
        canRequest: false,
        canOpenSettings: false,
      );

      @override
      Future<MCPPermissionResult> requestPermission({
        required final String kind,
      }) async => await getPermissionStatus(kind: kind);

      @override
      Future<MCPPermissionResult> openPermissionSettings({
        required final String kind,
      }) async => await getPermissionStatus(kind: kind);
    }

    MCPToolkitBinding.instance.initializeFlutterPermissionToolkit(
      delegate: MyPermissionDelegate(),
    );
    ```

    When the delegate is present, `mcp_toolkit` registers:
    `permissions_supported_kinds`, `permission_status`,
    `request_permission`, and `open_permission_settings`.
    Without a delegate, those entries are not exposed.

## Golden Path

1. Add `mcp_toolkit` to your app.
2. Call `bootstrapFlutter(...)` in `main()`.
3. Launch the app in debug mode.
4. Run `flutter-mcp-toolkit validate-runtime` (pass `--target` or global `--vm-service-uri` with `app.debugPort.wsUri`; host `desktop_window` failures retry once with `flutter_layer` — see `data.summary.captureFallbackUsed`).
5. Then use dynamic registry commands in this order:
   `fmt_list_client_tools_and_resources`,
   `fmt_client_resource`,
   `fmt_client_tool`.

Use resources for read-only state, tools for actions, and prefer lowercase underscore names.

### Agent authoring (skills)

End-user docs for AI assistants live in the **`mcp_flutter`** repo:

- Cursor / Codex plugin (`plugin/skills/`): start with **`flutter-mcp-toolkit-guide`**, then **`flutter-mcp-toolkit-custom-tools`** when registering **`AgentCallEntry`** tools or resources from app code.
- **`flutter-mcp-toolkit-intentcall-migration`** when upgrading from removed `MCPCallEntry` APIs.
- Claude Code marketplace plugin (`plugin/skills/`): **`flutter-mcp`** for driving the app; **`flutter-mcp-toolkit-custom-tools`** for the same registration workflow.

Run `make sync-skills` after editing plugin skills so `mcp_server_dart/lib/src/skill_assets.g.dart` stays in sync.

## Role in `mcp_flutter`

For the full setup and more details on the `MCP Server` and AI tool integration, please refer to the main [QUICK_START.md](https://github.com/Arenukvern/mcp_flutter/blob/main/QUICK_START.md) in the root of the `mcp_flutter` repository.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or report issues on the [GitHub repository](https://github.com/Arenukvern/mcp_flutter).

## 📖 Learn More

- [Flutter DevTools Documentation](https://docs.flutter.dev/development/tools/devtools/overview)
- [Dart VM Service Protocol](https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md)

## 📄 License

[MIT](LICENSE) - Feel free to use in your projects!

---

_Flutter and Dart are trademarks of Google LLC._
