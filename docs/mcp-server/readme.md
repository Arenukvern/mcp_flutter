# MCP Toolkit Server (Dart) (beta)

This is a beta version of MCP Toolkit Server (Dart) that will replace the deprecated [mcp_server](https://github.com/Arenukvern/mcp_flutter/tree/main/mcp_server/README.md) server.

## Quick Start

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
     mcp_toolkit: ^0.1.2
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

   # ⚠️ Resources Limitations ⚠️

   - Current server has problems with resources. If you see no resources in your AI tool, try to pass `--no-resources` as an argument.

   **Note for Local Development (GitHub Install):**

   If you installed the Flutter Inspector from GitHub and built it locally, you need to adjust the paths in the AI tool configurations to point to your local `build/flutter_inspector_mcp` file. Refer to the "Installation from GitHub" section for instructions on cloning and building the project.

   #### Cline Setup

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
   4. You're ready! Try commands like "Please get screenshot of my app"

   #### Cursor Setup

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
            "disabled": false,
            "autoApprove": []
          }
        }
      }
      ```
   4. Restart Cursor
   5. Open Agent Panel (cmd + L on macOS)
   6. You're ready! Try commands like "Please get screenshot of my app"

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
            "disabled": false,
            "autoApprove": []
          }
        }
      }
      ```
   2. Restart Claude
   3. The Flutter inspector tools will be automatically available
   4. You're ready! Try commands like "Please get screenshot of my app"

# Development

### Command Line Options

```bash
./build/flutter_inspector_mcp_server [options]

Options:
  --dart-vm-host                Host for Dart VM connection (default: localhost)
  --dart-vm-port                Port for Dart VM connection (default: 8181)
  --resources                   Enable resources support (default: true)
  --images                      Enable images support (default: true)
  --dumps                       Enable dumps support (default: false)
  --log-level                   Logging level (default: critical)
  --environment                 Environment (default: production)
  -h, --help                    Show usage text
```

### Basic Usage

1. Start your Flutter app in debug mode:

   ```bash
   flutter run --debug --dart-vm-host=localhost --dart-vm-port=8181
   ```

2. Run the MCP server:

   ```bash
   ./build/flutter_inspector_mcp_server
   ```
