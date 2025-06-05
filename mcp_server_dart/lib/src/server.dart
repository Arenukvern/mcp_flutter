// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/dynamic_registry_integration.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/flutter_inspector.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/vm_service_support.dart';
import 'package:stream_channel/stream_channel.dart';

// ignore: do_not_use_environment
const kDebugMode = bool.fromEnvironment('kDebugMode');

/// Flutter Inspector MCP Server
///
/// Provides tools and resources for Flutter app inspection and debugging
final class MCPToolkitServer extends BaseMCPToolkitServer
    with VMServiceSupport, DynamicRegistryIntegration, FlutterInspector {
  MCPToolkitServer.fromStreamChannel(
    super.channel, {
    required super.configuration,
  }) : super.fromStreamChannel(
         implementation: ServerImplementation(
           name: 'flutter-inspector',
           version: '1.0.0',
         ),
         instructions: '''
Flutter Inspector MCP Server - AI Agent Guide

This server provides comprehensive tools for inspecting, debugging, and dynamically interacting with Flutter applications. It supports both static tools and **dynamic runtime tool registration** for advanced debugging workflows.

## Core Static Tools

**Essential Tools:**
- hot_reload_flutter: Hot reload the Flutter app for instant UI updates
- get_vm: Get VM information and connection status  
- get_extension_rpcs: List available extension RPCs in the Flutter app

${configuration.dumpsSupported ? '''
**Debug Dump Tools (Heavy Operations - Use Sparingly):**
- debug_dump_layer_tree: Dump complete layer tree structure
- debug_dump_semantics_tree: Dump accessibility tree structure  
- debug_dump_semantics_tree_inverse: Dump semantics tree in inverse order
- debug_dump_render_tree: Dump render tree for layout debugging
- debug_dump_focus_tree: Dump focus tree for navigation debugging
- get_active_ports: Get list of active Flutter/Dart process ports
''' : ''}

${configuration.resourcesSupported ? '''
**Resources:**
- visual://localhost/app/errors/latest: Get latest app errors with stack traces
- visual://localhost/app/errors/{count}: Get specific number of recent errors
- visual://localhost/view/details: Get comprehensive view details and properties
- visual://localhost/view/screenshots: Get screenshots of all app views
''' : '''
**Error & View Tools:**
- get_view_errors: Get view errors with diagnostic information
- get_view_details: Get detailed view information and widget tree
- get_screenshots: Get screenshots of all views for visual debugging
'''}

${configuration.dynamicRegistrySupported ? r'''

## Dynamic Runtime Tools - AI Agent Workflow

**The dynamic registry enables you to interact with Flutter apps that register tools at runtime. This is particularly powerful for debugging and experimentation.**

### 1. Discovery Phase - Find Available Dynamic Tools

**Use `listClientToolsAndResources` first to discover what's available:**

Example: List all dynamic tools and resources registered by the Flutter app
```json
{"name": "listClientToolsAndResources", "arguments": {}}
```

### 2. Execution Phase - Run Dynamic Tools

**Execute discovered tools using `runClientTool`:**

Example: Execute a Fibonacci calculator tool
```json
{
  "name": "runClientTool",
  "arguments": {
    "toolName": "calculate_fibonacci",
    "arguments": {"n": 10}
  }
}
```

**Access dynamic resources using `runClientResource`:**

Example: Get current app state
```json
{
  "name": "runClientResource", 
  "arguments": {"resourceUri": "visual://localhost/app/state"}
}
```

### 2.5. Creating Custom Tools (AI Agent Generates Dart Code for the Flutter App)

**As an AI Agent, you can design custom debugging tools by generating the necessary Dart code. This Dart code, defining an `MCPCallEntry` and registering it with `addMcpTool()`, must then be integrated into the target Flutter application's source code (e.g., by a developer, or by you using file editing tools if available and appropriate).**

**Step-by-step AI Workflow for Creating and Using a New Dynamic Tool:**
1.  **Design & Generate Dart Code:**
    *   Identify a need for a custom tool.
    *   Generate the Dart code snippet that defines an `MCPCallEntry.tool(...)`. This includes its unique `name`, `description`, `inputSchema`, and the `handler` function (the tool's logic).
    *   The generated code must also include the `addMcpTool(yourToolEntry)` call to register it with the `mcp_toolkit`.
    *   *Example AI-Generated Dart Code Snippet (ensure necessary imports like `package:mcp_toolkit/mcp_toolkit.dart` are handled):*
      ```dart
      // This Dart code defines and registers a new dynamic tool.
      // It needs to be added to a relevant Dart file within the Flutter application's source
      // (e.g., inside main.dart during initialization, or a dedicated debug utilities file)
      // and ensured it runs when the app starts or when dynamic tools are set up.

      // Ensure necessary imports from mcp_toolkit:
      // import 'package:mcp_toolkit/mcp_toolkit.dart';

      final MCPCallEntry myAICustomTool = MCPCallEntry.tool(
        handler: (request_params) {
          // Tool logic: access request_params['argument_name']
          // Perform actions, gather data...
          return MCPCallResult(
            message: 'AI custom tool executed successfully!',
            parameters: {'result_key': 'some_value_from_tool'},
          );
        },
        definition: MCPToolDefinition(
          name: 'ai_custom_tool_unique_name', // IMPORTANT: Must be unique
          description: 'An AI-generated tool that performs a specific debug action.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'argument_name': {'type': 'string', 'description': 'Description of argument'},
              // Add other arguments as needed
            },
            // 'required': ['argument_name'], // If arguments are required
          },
        ),
      );

      // This line makes the tool discoverable by the MCP server:
      addMcpTool(myAICustomTool);
      ```
2.  **Integrate and Ensure Execution:**
    *   **Option A (AI integrates via `edit_file` - Preferred if capable):**
        *   Use the `edit_file` tool to add the generated Dart code snippet into an appropriate file in the Flutter application's source code (e.g., `lib/main.dart` before `runApp()`, or a dedicated debug utilities file like `lib/debug_tools.dart` which is then imported and called during app initialization).
        *   **Crucially, ensure the placement guarantees that the `addMcpTool(myAICustomTool);` line (or the function containing it) will be executed by the Flutter app *after* `MCPToolkitBinding.instance.initialize()` and (if used) `MCPToolkitBinding.instance.initializeFlutterToolkit()` have been called, and typically within a `if (kDebugMode) { ... }` block.**
        *   You may need to define a new function in the Flutter code (e.g., `void registerMyAICustomTools() { ... }`) that contains your `MCPCallEntry` definitions and `addMcpTool` calls, and then use `edit_file` to ensure this new function is called from an existing part of the app's initialization sequence.
    *   **Option B (Present for manual integration by a developer):**
        *   Present the generated Dart code snippet to the user.
        *   Clearly instruct the user where to add this code (e.g., `lib/main.dart` or a debug utilities file) and how to ensure it's called during app initialization, respecting the order relative to `MCPToolkitBinding` initialization and preferably within a `kDebugMode` check.
3.  **Activate via Hot Reload:**
    *   Once the code is integrated into the Flutter app (either by you via `edit_file` or manually by a developer), call the `hot_reload_flutter` tool. This allows the running Flutter app to execute the new `addMcpTool()` call, making the tool available to the server.
4.  **Verify Registration:**
    *   Use `listClientToolsAndResources` to check if your newly defined tool (e.g., 'ai_custom_tool_unique_name') now appears in the list of available dynamic tools.
5.  **Execute the New Tool:**
    *   Use `runClientTool` with the `toolName` matching your tool's definition and provide any necessary `arguments` according to its `inputSchema`.

**Example Scenario: AI creates a simple widget property inspector**
*AI generates the following Dart code and instructs it to be added to the Flutter app (e.g., in `main.dart` before `runApp` or in a debug initialization function):*
```dart
// In the Flutter app's Dart code:
// import 'package:mcp_toolkit/mcp_toolkit.dart';
// import 'package:flutter/widgets.dart'; // For Element, BuildContext etc. if needed for complex tools

void registerAIWidgetInspector() { // Helper function for organization
  final aiWidgetInspector = MCPCallEntry.tool(
    handler: (request_params) {
      // final String widgetKeyString = request_params['widgetKey'] as String? ?? '';
      // In a real scenario, you'd use the widgetKeyString to find a widget
      // and inspect its properties. This is a placeholder.
      // IMPORTANT: Accessing widget tree details might require context or specific Flutter knowledge.
      return MCPCallResult(
        message: 'AI Inspector: Info for widget key "${request_params['widgetKey'] ?? ''}". (Actual inspection logic TBD)',
        parameters: {'widgetKey': request_params['widgetKey'] ?? '', 'details': 'Placeholder details'},
      );
    },
    definition: MCPToolDefinition(
      name: 'ai_inspect_widget_properties',
      description: 'AI-generated tool to inspect basic properties of a widget by its key.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'widgetKey': {'type': 'string', 'description': 'The string representation of the widget Key to inspect.'},
        },
        'required': ['widgetKey'],
      },
    ),
  );
  addMcpTool(aiWidgetInspector);
  debugPrint('AI Widget Inspector tool registered with MCP toolkit.');
}

// This function (registerAIWidgetInspector) would need to be called from somewhere
// in the Flutter app's initialization sequence, for example:
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   MCPToolkitBinding.instance
//    ..initialize()
//    ..initializeFlutterToolkit(); // Includes standard Flutter tools
//   c
//   if (kDebugMode) { // Good practice to only register debug tools in debug mode
//     registerAIWidgetInspector();
//   }
//
//   runApp(const MyApp());
// }
```
*After the developer (or AI via `edit_file`) adds this to the Flutter app, the AI uses `hot_reload_flutter`, then `listClientToolsAndResources` to verify, then `runClientTool` to use `ai_inspect_widget_properties`.*

### 3. AI Agent Best Practices

**For Runtime Debugging:**
1. Always start with `listClientToolsAndResources` to see what's available
2. Use `get_view_errors` if encountering UI issues
3. Take `get_screenshots` for visual debugging before and after changes
4. Use `hot_reload_flutter` after making code changes

**For Dynamic Experimentation:**
1. Flutter apps can register new tools dynamically using `addMcpTool()`
2. These tools appear automatically in `listClientToolsAndResources`
3. Execute them immediately with `runClientTool` - no server restart needed
4. Perfect for testing new features, state inspection, or runtime modifications

**Creating Custom Tools (When Working with Flutter Codebase):**
1. AI agents can write Dart code to create new MCP tools for specific debugging needs
2. Add tools using `addMcpTool(MCPCallEntry.tool(...))` in the Flutter app code
3. Use `hot_reload_flutter` to register the new tools without app restart
4. Execute the custom tools immediately with `runClientTool`

**Common Debugging Workflow:**
```
1. listClientToolsAndResources → discover available tools
2. get_screenshots → visual state before changes  
3. runClientTool → execute debugging tool
4. hot_reload_flutter → apply any code changes
5. get_screenshots → visual state after changes
6. get_view_errors → check for any new issues
```

**Custom Tool Creation Workflow (When Working with Flutter Codebase):**
```
1. listClientToolsAndResources → check existing tools
2. [Write Dart code to create custom MCPCallEntry.tool()]
3. [Add addMcpTool(customTool) to Flutter app code]
4. hot_reload_flutter → register new tool
5. listClientToolsAndResources → verify tool appeared
6. runClientTool → execute custom tool
7. [Iterate: modify tool logic if needed, hot reload, test]
```

## Connection Requirements

- Flutter app must be running in **debug mode** with `--enable-vm-service` 
`--host-vmservice-port=8182 --dds-port=8181 --disable-service-auth-codes` flags.
- Default connection: localhost:8181 (Dart VM port)
- Dynamic tools register automatically when app calls `addMcpTool()`
- No server restart needed when new tools are registered

## Pro Tips for AI Agents

- **Dynamic tools are ephemeral** - they disappear when the Flutter app restarts
- **Always check tool availability** before execution with `listClientToolsAndResources` 
- **Combine static and dynamic tools** for comprehensive debugging
- **Use hot reload liberally** - it's fast and preserves app state
- **Screenshot before/after** any significant changes for visual verification

Connect to a running Flutter app on debug mode to use these features.
''' : ''}
''',
       );

  /// Create and connect a Flutter Inspector MCP Server
  factory MCPToolkitServer.connect(
    final StreamChannel<String> channel, {
    required final VMServiceConfigurationRecord configuration,
  }) =>
      MCPToolkitServer.fromStreamChannel(channel, configuration: configuration);

  @override
  FutureOr<InitializeResult> initialize(final InitializeRequest request) async {
    log(
      LoggingLevel.info,
      'Initializing Flutter Inspector MCP Server',
      logger: 'MCPToolkitServer',
    );

    // Call parent initialize first which will trigger the mixin's initialize
    // This registers tools and resources regardless of VM service connection
    final result = await super.initialize(request);

    log(
      LoggingLevel.debug,
      () => 'Server capabilities: ${result.capabilities}',
      logger: 'MCPToolkitServer',
    );

    // Try to initialize VM service connection (non-blocking)
    // This allows tools to be available even if no Flutter app is running
    unawaited(
      _initializeVMServiceAsync()
          .then((_) {
            log(
              LoggingLevel.info,
              'VM service connected successfully',
              logger: 'VMService',
            );
          })
          .catchError((final e, final s) {
            // Log but don't fail - tools should still be available
            log(
              LoggingLevel.warning,
              'VM service initialization failed (this is normal if no '
              'Flutter app is running): $e',
              logger: 'VMService',
            );
          }),
    );

    log(
      LoggingLevel.info,
      'Flutter Inspector MCP Server initialized successfully',
      logger: 'MCPToolkitServer',
    );
    return result;
  }

  /// Initialize VM service connection asynchronously without blocking
  Future<void> _initializeVMServiceAsync() async {
    log(
      LoggingLevel.debug,
      'Attempting VM service connection...',
      logger: 'VMService',
    );

    try {
      await initializeVMService();
      await startRegistryDiscovery(mcpToolkitServer: this);
      log(
        LoggingLevel.info,
        'VM service initialization completed',
        logger: 'VMService',
      );
    } on Exception catch (e, s) {
      // Log but don't fail - tools should still be available
      log(
        LoggingLevel.error,
        'VM service initialization failed: $e',
        logger: 'VMService',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
    }
  }

  @override
  Future<void> shutdown() async {
    log(
      LoggingLevel.info,
      'Shutting down Flutter Inspector MCP Server',
      logger: 'MCPToolkitServer',
    );

    try {
      await disconnectVMService();
      await disposeDynamicRegistry();
      log(LoggingLevel.debug, 'VM service disconnected', logger: 'VMService');
    } on Exception catch (e) {
      log(
        LoggingLevel.warning,
        'Error during VM service disconnect: $e',
        logger: 'VMService',
      );
    }

    await super.shutdown();
    log(
      LoggingLevel.info,
      'Server shutdown complete',
      logger: 'MCPToolkitServer',
    );
  }
}
