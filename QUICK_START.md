# 🚀 MCP Flutter - Quick Start Guide

This guide walks you through setting up the MCP Flutter toolkit to enable AI assistants to interact with Flutter applications.

## Overview

MCP Flutter provides a bridge between AI assistants and Flutter applications through the Model Context Protocol (MCP). The system uses **Flutter's native service extension mechanism** to enable real-time communication and **dynamic tools registration** for registering client side (Flutter App) tools and resources.

**Architecture**: `AI Assistant ↔ MCP Server (Dart) ↔ Dart VM ↔ Flutter Service Extensions`

![Flutter Inspector Architecture](./docs/core/architecture.png)

## 📦 Prerequisites

- Flutter SDK (3.0.0 or later)
- Dart SDK (included with Flutter)
- A Flutter app running in debug mode
- One of: Cursor, Claude, Cline AI, Windsurf, RooCode, or any other AI assistant that supports MCP server

## 📺 Video Tutorial

- using Cursor: https://www.youtube.com/watch?v=pyDHaI81uts
- using VSCode + Cline: (Soon)

## 📦 Installation from GitHub (Currently Recommended)

For developers who want to contribute to the project or run the latest version directly from source, follow these steps:

1. **Clone the repository:**

   ```bash
   git clone https://github.com/Arenukvern/mcp_flutter
   cd mcp_flutter
   ```

2. **Install and build dependencies:**

   ```bash
   make install
   ```

   This command installs all necessary dependencies listed in `pubspec.yaml` and then builds the MCP server.

3. **Add `mcp_toolkit` Package to Your Flutter App:**

   The `mcp_toolkit` package provides the necessary service extensions within your Flutter application. You need to add it to your app's `pubspec.yaml`.

   Run this command in your Flutter app's directory to add the `mcp_toolkit` package:

   ```bash
   flutter pub add mcp_toolkit
   ```

   or add it to your `pubspec.yaml` manually:

   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     # ... other dependencies
     mcp_toolkit: ^0.4.0 # Use the latest version
   ```

   Then run `flutter pub get` in your Flutter app's directory.

4. **Initialize in Your App**:
   In your Flutter application's `main.dart` file (or equivalent entry point), initialize the bridge binding:

   ```dart
   import 'package:flutter/material.dart';
   import 'package:mcp_toolkit/mcp_toolkit.dart'; // Import the package
   import 'dart:async';

   Future<void> main() async {
     runZonedGuarded(
       () async {
         WidgetsFlutterBinding.ensureInitialized();
         MCPToolkitBinding.instance
            ..initialize() // Initializes the Toolkit
            ..initializeFlutterToolkit(); // Adds Flutter related methods to the MCP server
         runApp(const MyApp());
       },
       (error, stack) {
         // You can place it in your error handling tool, or directly in the zone. The most important thing is to have it - otherwise the errors will not be captured and MCP server will not return error results.
         MCPToolkitBinding.instance.handleZoneError(error, stack);
       },
     );
   }

   // ... rest of your app code
   ```

5. **Start your Flutter app in debug mode**

   ! Current workaround for security reasons is to run with `--disable-service-auth-codes`. If you know how to fix this, please let me know!

   ```bash
   flutter run --debug --host-vmservice-port=8182 --dds-port=8181 --enable-vm-service --disable-service-auth-codes
   ```

6. **🛠️ Add Flutter Inspector to your AI tool**

   **Note for Local Development (GitHub Install):**

   If you installed the Flutter Inspector from GitHub and built it locally, you need to adjust the paths in the AI tool configurations to point to your local `build/flutter_inspector_mcp` file. Refer to the "Installation from GitHub" section for instructions on cloning and building the project.

   #### Cline Setup

   > Note: please use `--no-resources` flag to disable resources support - for unknown reason it doesn't work with Cline.

   1. Add to your `.cline/config.json`:
      ```json
      {
        "mcpServers": {
          "flutter-inspector": {
            "command": "/path/to/your/cloned/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp",
            "args": [
              "--dart-vm-host=localhost",
              "--dart-vm-port=8181",
              "--no-resources",
              "--images"
            ],
            "env": {},
            "disabled": false,
            "autoApprove": []
          }
        }
      }
      ```
   2. Restart Cline
   3. The Flutter inspector will be automatically available in your conversations
   4. You're ready! Try commands like "Please get screenshot of my app" or "List all available tools from my Flutter app"

   #### Cursor Setup

   # ⚠️ Resources Limitations ⚠️

   - Since Cursor doesn't support resources, you need to pass `--no-resources` as an argument. It will make all resources to be displayed as tools instead.

   ##### Badge

   You can use this badge to add Flutter Inspector to Cursor:

   [![Install MCP Server](https://cursor.com/deeplink/mcp-install-dark.svg)](https://cursor.com/install-mcp?name=flutter-inspector&config=eyJjb21tYW5kIjoiL3BhdGgvdG8veW91ci9jbG9uZWQvbWNwX2ZsdXR0ZXIvbWNwX3NlcnZlcl9kYXJ0L2J1aWxkL2ZsdXR0ZXJfaW5zcGVjdG9yX21jcCAtLWRhcnQtdm0taG9zdD1sb2NhbGhvc3QgLS1kYXJ0LXZtLXBvcnQ9ODE4MSAtLW5vLXJlc291cmNlcyAtLWltYWdlcyIsImVudiI6e30sImRpc2FibGVkIjpmYWxzZX0%3D)
   <!-- to update use: https://docs.cursor.com/deeplinks#markdown -->

   Note: fix path after installation.

   ##### Manual Setup

   1. Open Cursor's settings
   2. Go to the Features tab
   3. Under "Model Context Protocol", add the server:
      ```json
      {
        "mcpServers": {
          "flutter-inspector": {
            "command": "/path/to/your/cloned/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp",
            "args": [
              "--dart-vm-host=localhost",
              "--dart-vm-port=8181",
              "--no-resources",
              "--images"
            ],
            "env": {},
            "disabled": false
          }
        }
      }
      ```
   4. Restart Cursor
   5. Open Agent Panel (cmd + L on macOS)
   6. You're ready! Try commands like "List all available tools from my Flutter app" or "Take a screenshot of my app"

   #### Claude Setup

   1. Add to your Claude configuration file:
      ```json
      {
        "mcpServers": {
          "flutter-inspector": {
            "command": "/path/to/your/cloned/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp",
            "args": [
              "--dart-vm-host=localhost",
              "--dart-vm-port=8181",
              "--resources",
              "--images"
            ],
            "env": {},
            "disabled": false
          }
        }
      }
      ```
   2. Restart Claude
   3. The Flutter inspector tools will be automatically available
   4. You're ready! Try commands like "Show me all tools available in my Flutter app"

   #### RooCode Setup

   > Note: It seems that RooCode doesn't support images in MCP server responses as it was earlier with Cline and Cursor. So as a workaround you can use `--save-images` flag to save images to files.

   > Note: Also, please use `--no-resources` flag to disable resources support - for unknown reason it doesn't work with RooCode.

   1. Add to your RooCode configuration file:

   ```json
   {
     "mcpServers": {
       "flutter-inspector": {
         "command": "/path/to/your/cloned/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp",
         "args": [
           "--dart-vm-host=localhost",
           "--dart-vm-port=8181",
           "--no-resources",
           "--images",
           "--save-images"
         ],
         "env": {},
         "disabled": false
       }
     }
   }
   ```

## Connection Selection Behavior

MCP server startup is non-blocking and does not require selecting a VM target upfront.

On the first VM-dependent tool/resource call, the server resolves the target automatically:

1. Reuse active connection if healthy.
2. Reuse sticky target if still discoverable.
3. Auto-attach if only one target is available.
4. Return `connection_selection_required` if multiple targets exist and no explicit target is provided.

When you receive `connection_selection_required`, retry the same call with:

```json
{
  "connection": {
    "targetId": "ws://127.0.0.1:59490/<token>/ws"
  }
}
```

You can also call `connect_debug_app` with the same nested `connection` object.

Resource reads support explicit targeting via URI query params (`targetId`, `mode`, `host`, `port`, `uri`, `forceReconnect`), for example:

- `visual://localhost/view/details?targetId=ws%3A%2F%2F127.0.0.1%3A59490%2F%3Ctoken%3E%2Fws`

### CLI/Daemon Targeting Parity

The same `connection` contract is supported in CLI v2 and daemon JSON-RPC:

- one-shot `exec`: `--args '{"connection":{"targetId":"ws://127.0.0.1:59490/<token>/ws"}}'`
- daemon `command/execute`: `params.args.connection`
- daemon `watch/start`: `params.args.connection` (applied once before watch loop)
- `snapshot create`: per-step `args.commands[i].args.connection`

Selector commands keep explicit native fields (`mode`, `targetId`, `host`, `port`, `uri`, `force`).  
Do not mix these native selector fields with nested `connection` in `connect` or `session_start` requests.

### Flutter Web (Auto Discovery + Fallback)

For Flutter web targets, the server/CLI now discover full VM websocket URIs first (`flutter attach --machine`) and then fall back to port scanning.

- CLI discovery context flags:
  - `--flutter-project-dir`
  - `--flutter-device` (for example `chrome`)
  - `--flutter-discovery-timeout-ms`
- MCP server has the same runtime flags.
- `connection.targetId` must be full VM WS URI (`ws://.../ws`), not `host:port`.
- Manual fallback remains available:
  - CLI: `--vm-service-uri ws://127.0.0.1:59490/<token>/ws`
  - MCP tools/resources: `arguments.connection.uri`

## Dynamic Tools Registration

One of the key features of v2.2.0 is the ability to register custom tools and resources from your Flutter app at runtime:

### Basic Example

```dart
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:dart_mcp/client.dart';

// Register a custom tool in your Flutter App (!).
final customTool = MCPCallEntry.tool(
  handler: (request) {
    final name = request['name'] ?? 'World';
    return MCPCallResult(
      message: 'Hello, $name!',
      parameters: {'greeting': 'Hello, $name!'},
    );
  },
  definition: MCPToolDefinition(
    name: 'say_hello',
    description: 'Say hello to someone',
    inputSchema: ObjectSchema(
      required: ['name'],
      properties: {
        'name': StringSchema(
          description: 'Name to greet',
        ),
      },
    ),
  ),
);

// Register the tool
await MCPToolkitBinding.instance.addEntries(entries: {customTool});
```

### Using Dynamic Tools

The tools should be registered automatically in MCP server. However, since most clients doesn't support tools/change feature, you have two options:

1. Reload MCP server (from interface).
2. Use `listClientToolsAndResources` to see all available tools and resources and then call `runClientTool` or `runClientResource` to execute them.

## 📦 Installation via Smithery (🚧 WIP 🚧)

To install Flutter Inspector for Claude Desktop automatically via [Smithery](https://smithery.ai/server/@Arenukvern/mcp_flutter):

```bash
npx -y @smithery/cli install @Arenukvern/mcp_flutter --client claude
```
