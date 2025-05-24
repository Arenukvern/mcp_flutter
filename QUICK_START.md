# 🚀 Quick Start

## 📺 Video Tutorial

A small video tutorial how to setup mcp server on macOS with Cursor - https://www.youtube.com/watch?v=NBY2p7XIass

## 📦 Prerequisites

- Node.js (v14 or later)
- A Flutter app running in debug mode
- One of: Cursor, Claude, Cline AI, Windsurf, RooCode, or any other AI assistant that supports MCP server

## 📦 Installation via Smithery (🚧 WIP 🚧)

To install Flutter Inspector for Claude Desktop automatically via [Smithery](https://smithery.ai/server/@Arenukvern/mcp_flutter):

```bash
npx -y @smithery/cli install @Arenukvern/mcp_flutter --client claude
```

## 📦 Installation from GitHub (Currently Recommended)

For developers who want to contribute to the project or run the latest version directly from source, follow these steps:

1. **Clone the repository:**

   ```bash
   git clone https://github.com/Arenukvern/mcp_flutter
   cd flutter-inspector
   ```

2. **Install and build dependencies:**

   ```bash
   make install
   ```

   This command installs all necessary dependencies listed in `package.json` and then builds the MCP server.

3. **Add `mcp_toolkit` Package to Your Flutter App:**

   The `mcp_toolkit` package provides the necessary service extensions within your Flutter application. You need to add it to your app's `pubspec.yaml`.

   Run this command in your Flutter app's directory to add the `mcp_toolkit` package:

   ```bash
   flutter pub add mcp_toolkit
   ```

   or add it to your `pubspec.yaml` manually:

   ```yaml
   dev_dependencies:
     flutter_test:
       sdk: flutter
     # ... other dev_dependencies
     mcp_toolkit: ^0.1.1
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
   flutter run --debug --host-vmservice-port=8181 --enable-vm-service --disable-service-auth-codes
   ```

6. **🛠️ Add Flutter Inspector to your AI tool**

   **Note for Local Development (GitHub Install):**

   If you installed the Flutter Inspector from GitHub and built it locally, you need to adjust the paths in the AI tool configurations to point to your local `build/index.js` file. Refer to the "Installation from GitHub" section for instructions on cloning and building the project.

   #### Cline Setup

   1. Add to your `.cline/config.json`:
      ```json
      {
        "mcpServers": {
          "flutter-inspector": {
            "command": "node",
            "args": [
              "/path/to/your/cloned/mcp_flutter/mcp_server/build/index.js"
            ],
            "env": {
              "PORT": "3334",
              "LOG_LEVEL": "critical",
              "RESOURCES_SUPPORTED": "true",
              "IMAGES_SUPPORTED": "true"
            },
            "disabled": false,
            "autoApprove": []
          }
        }
      }
      ```
   2. Restart Cline
   3. The Flutter inspector will be automatically available in your conversations

   #### Cursor Setup

   # ⚠️ Resources Limitations ⚠️

   - Since Cursor doesn't support resources, make sure you passed `RESOURCES_SUPPORTED=false` as environment variable. It will make some resources to be displayed as tools.

   1. Open Cursor's settings
   2. Go to the Features tab
   3. Under "Model Context Protocol", add the server:
      ```json
      {
        "mcpServers": {
          "flutter-inspector": {
            "command": "node",
            "args": [
              "/path/to/your/cloned/mcp_flutter/mcp_server/build/index.js"
            ],
            "env": {
              "RESOURCES_SUPPORTED": "false",
              "IMAGES_SUPPORTED": "true",
              "LOG_LEVEL": "critical"
            },
            "disabled": false
          }
        }
      }
      ```
   4. Restart Cursor
   5. Open Agent Panel (cmd + L on macOS)
   6. You're ready! Try commands like "analyze my Flutter app's widget tree"

   #### Claude Setup

   1. Add to your Claude configuration file:
      ```json
      {
        "mcpServers": {
          "flutter-inspector": {
            "command": "node",
            "args": [
              "/path/to/your/cloned/mcp_flutter/mcp_server/build/index.js"
            ],
            "env": {
              "PORT": "3334",
              "LOG_LEVEL": "critical"
            },
            "disabled": false
          }
        }
      }
      ```
   2. Restart Claude
   3. The Flutter inspector tools will be automatically available
