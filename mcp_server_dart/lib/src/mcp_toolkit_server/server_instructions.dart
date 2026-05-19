import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';

String buildMcpToolkitServerInstructions(
  final VMServiceConfigurationRecord configuration,
) =>
    '''
Flutter Inspector MCP Server - AI Agent Guide

This server provides Flutter app inspection/debugging tools and dynamic runtime tool registration.

## Core Static Tools

**Essential Tools:**
- connect_debug_app: Explicitly connect/select a target Flutter debug VM
- discover_debug_apps: Discover running Flutter targets with canonical ws URIs
- hot_reload_flutter: Hot reload the Flutter app for instant UI updates
- get_vm: Get VM information and connection status
- get_extension_rpcs: List available extension RPCs in the Flutter app
- inspect_widget_at_point: Map screenshot coordinates to widget/render node
- capture_ui_snapshot: Capture screenshots + layout + errors in one bundle
  (on macOS / iOS Simulator, if host `desktop_window` capture fails, use
  `screenshotMode: flutter_layer` in tool args for a reliable Flutter-layer shot)

${configuration.dumpsSupported ? '''
**Debug Dump Tools (Heavy Operations - Use Sparingly):**
- debug_dump_layer_tree: Dump complete layer tree structure
- debug_dump_semantics_tree: Dump accessibility tree structure
- debug_dump_render_tree: Dump render tree for layout debugging
- debug_dump_focus_tree: Dump focus tree for navigation debugging
''' : ''}

${configuration.resourcesSupported ? '''
**Resources:**
- visual://localhost/app/errors/latest: Get latest app errors with stack traces
- visual://localhost/app/errors/{count}: Get specific number of recent errors
- visual://localhost/view/details: Get comprehensive view details and properties
- visual://localhost/view/screenshots: Get screenshots of all app views
''' : '''
**Error & View Tools:**
- get_app_errors: Get app errors with diagnostic information
- get_view_details: Get detailed view information and widget tree
- get_screenshots: Get screenshots of all views for visual debugging
'''}

${configuration.dynamicRegistrySupported ? '''
## Dynamic Runtime Tools - AI Agent Workflow

1. Discovery: call `fmt_list_client_tools_and_resources` first.
2. Execution: use `fmt_client_tool` for dynamic tools.
3. Resources: use `fmt_client_resource` for dynamic resources.
4. Activation: call `fmt_hot_reload_flutter` after app-side tool code changes.
5. Verification: re-run `fmt_list_client_tools_and_resources` after reload/restart.

For detailed dynamic/tool-creation flows, rely on skill docs to avoid prompt duplication:
- flutter-mcp-toolkit-custom-tools (register MCPCallEntry / addMcpTool in the app)
- flutter-mcp-toolkit-debug
- flutter-mcp-toolkit-control
''' : ''}

## Connection Requirements

- Flutter app must run in debug mode with VM service enabled.
- Flutter app must initialize `mcp_toolkit`; otherwise app-level tools cannot work.
- Default connection mode: auto-discover active Flutter debug targets.
- Explicit selection: use `connection.targetId` with full VM websocket URI or `connection.uri`.
- Dynamic tools register automatically when app calls `addMcpTool()`.

Connect to a running Flutter app in debug mode to use these features.
''';
