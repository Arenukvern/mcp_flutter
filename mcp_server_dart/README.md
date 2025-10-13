## Core Static Tools

**Essential Tools:**
 - hot_reload_flutter: Hot reload the Flutter app for instant UI updates
 - hot_restart_flutter: Hot restart the Flutter app (full app restart without reinstall) – useful when state corruption occurs or after adding new VM service extensions
 - get_vm: Get VM information and connection status  
 - get_extension_rpcs: List available extension RPCs in the Flutter app
6. You're ready! Try commands like "Please get screenshot of my app"

### Hot Restart Tool Usage

The server now provides a dedicated hot restart tool for situations where hot reload isn't sufficient (for example after adding service extensions or when the app state is corrupted):

```json
{
  "name": "hot_restart_flutter",
  "arguments": {}
}
```

Expected result:

```json
{
  "message": "{\"report\":{\"type\":\"Success\",\"success\":true}}"
}
```

Notes:
 - Requires a connected Flutter app in debug mode with VM service enabled (see the run flags above).
 - If VM service is not connected, the tool returns an error message instead of failing the whole request.
# MCP Toolkit Server (Dart) (beta)

This is a beta version of MCP Toolkit Server (Dart) that will replace the deprecated [mcp_server](../mcp_server/README.md) server.

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
  --save-images        Save captured images as files in temporal folder instead of returning base64 data (default: false)
  --dumps                       Enable dumps support (default: false)
  --await-dnd                   Wait until DND connection is established (default: false). Do not use with Windsurf. Workaround for MCP Clients which don't support tools updates. Important: some clients doesn't support it. Use with caution. (disable for Windsurf, works with Cursor)
  --log-level                   Logging level (default: critical)
  --environment                 Environment (default: production)
  -h, --help                    Show usage text
```

#### Image File Saving Mode

When `--save-images` is enabled, the server will:

- Save all captured screenshots as PNG files in a `.mcp_screenshots` folder in the current working directory
- Return file URLs (`file://`) instead of base64 encoded image data
- Automatically clean up screenshots older than 24 hours
- Use timestamped filenames like `screenshot-2025-01-27T10-30-15.123Z.png`

This mode is useful when:

- Working with AI tools that prefer file references over base64 data
- Needing to persist screenshots for later analysis
- Reducing memory usage by avoiding large base64 strings in responses

### Basic Usage

1. Start your Flutter app in debug mode:

   ```bash
   flutter run --debug --dart-vm-host=localhost --dart-vm-port=8181
   ```

2. Run the MCP server:

   ```bash
   ./build/flutter_inspector_mcp_server
   ```
