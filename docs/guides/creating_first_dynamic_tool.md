# Creating Your First Dynamic Tool

This guide will walk you through the process of creating and registering your first dynamic tool.

### 1. Set Up Your Project

Make sure you have followed the [Quick Start](Quick_Start.md) guide and have the MCP server and a Flutter app running.

### 2. Create the Tool

In your Flutter app, create a new file called `lib/my_tools.dart` and add the following code:

```dart
import 'package:mcp_toolkit/mcp_toolkit.dart';

void registerMyTools() {
  final helloTool = MCPCallEntry.tool(
    handler: (params) {
      return MCPCallResult(message: 'Hello from a dynamic tool!');
    },
    definition: MCPToolDefinition(
      name: 'hello',
      description: 'A simple tool that says hello.',
    ),
  );

  addMcpTool(helloTool);
}
```

### 3. Register the Tool

In your `lib/main.dart` file, import `my_tools.dart` and call `registerMyTools()` in your `main` function:

```dart
import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'my_tools.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MCPToolkitBinding.instance.initialize();
  registerMyTools();
  runApp(const MyApp());
}
```

### 4. Hot Reload and Use the Tool

Save your changes and hot reload the app. Now, you can ask your AI assistant to run the `hello` tool. It should respond with "Hello from a dynamic tool!".
