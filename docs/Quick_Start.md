# Quick Start

This guide will walk you through the process of setting up the MCP server and connecting it to a Flutter application.

### Prerequisites

- Flutter SDK installed
- Dart SDK (included with Flutter)
- An AI assistant that supports MCP (e.g., Cursor, Cline)

### 1. Clone the Repository

```bash
git clone https://github.com/Arenukvern/mcp_flutter.git
cd mcp_flutter
```

### 2. Build and Run the MCP Server

The MCP server is a Dart application located in the `mcp_server_dart` directory. It is recommended to build a compiled binary for production use.

First, build the server binary from the project root:

```bash
make install
```

This command installs all necessary dependencies and builds the MCP server binary, typically located at `mcp_server_dart/build/flutter_inspector_mcp`.

Then, run the compiled server binary:

```bash
./mcp_server_dart/build/flutter_inspector_mcp
```

By default, the server will listen for connections from the AI assistant on `stdin`/`stdout` and from the Flutter app on port `8181`.

### 3. Add `mcp_toolkit` to Your Flutter App

The `mcp_toolkit` package provides the necessary service extensions within your Flutter application. You need to add it to your app's `pubspec.yaml`.

Run this command in your Flutter app's directory to add the `mcp_toolkit` package:

```bash
flutter pub add mcp_toolkit
```

Or add it to your `pubspec.yaml` manually:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... other dependencies
  mcp_toolkit: ^0.2.0 # Use the latest version
```

Then run `flutter pub get` in your Flutter app's directory.

### 4. Initialize `mcp_toolkit` in Your App

In your Flutter application's `main.dart` file (or equivalent entry point), initialize the `mcp_toolkit` binding. This is crucial for the toolkit to register its tools and handle errors.

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
      // Optionally, you can also use the bridge's error handling for zone errors
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    },
  );
}

// ... rest of your app code
```

### 5. Start your Flutter app in debug mode

```bash
flutter run --debug --host-vmservice-port=8182 --dds-port=8181 --enable-vm-service --disable-service-auth-codes
```

### 6. Configure Your AI Assistant

Follow the instructions in the [AI Assistant Setup](AI_Assistant_Setup.md) guide to connect your AI assistant to the running MCP server.

### 7. You're Ready!

Once the server, app, and AI assistant are all running and connected, you can start using the built-in tools. Try asking your AI assistant to:

- "Take a screenshot of the app."
- "Are there any errors in the app?"
- "Hot reload the app."
