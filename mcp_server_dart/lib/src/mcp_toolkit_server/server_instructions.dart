import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';

String buildMcpToolkitServerInstructions(
  final VMServiceConfigurationRecord configuration,
) =>
    '''
Flutter Inspector MCP Server - AI Agent Guide

This server provides Flutter app inspection/debugging tools and dynamic runtime tool registration.

## Core Static Tools

**Essential Tools (wire names use `fmt_*` prefix):**
- fmt_connect_debug_app: Connect/select a target Flutter debug VM
- fmt_discover_debug_apps: Discover running Flutter targets with canonical ws URIs
- fmt_hot_reload_flutter: Hot reload the Flutter app for instant UI updates
- fmt_get_vm: VM information and connection status
- fmt_get_extension_rpcs: Extension RPCs available in the Flutter app
- fmt_inspect_widget_at_point: Map screenshot coordinates to widget/render node
- fmt_capture_ui_snapshot: Screenshots + layout + errors in one bundle
  (on macOS / iOS Simulator, if host `desktop_window` capture fails, use
  `screenshotMode: flutter_layer` in tool args for a reliable Flutter-layer shot)

${configuration.dumpsSupported ? '''
**Debug Dump Tools (Heavy Operations - Use Sparingly):**
- fmt_debug_dump_layer_tree: Dump complete layer tree structure
- fmt_debug_dump_semantics_tree: Dump accessibility tree structure
- fmt_debug_dump_render_tree: Dump render tree for layout debugging
- fmt_debug_dump_focus_tree: Dump focus tree for navigation debugging
''' : ''}

${configuration.resourcesSupported ? '''
**Resources:**
- visual://localhost/app/errors/latest: Get latest app errors with stack traces
- visual://localhost/app/errors/{count}: Get specific number of recent errors
- visual://localhost/view/details: Get comprehensive view details and properties
- visual://localhost/view/screenshots: Get screenshots of all app views
''' : '''
**Error & View Tools:**
- fmt_get_app_errors: App errors with diagnostic information
- fmt_get_view_details: Detailed view information and widget tree
- fmt_get_screenshots: Screenshots of all views for visual debugging
'''}

${configuration.dynamicRegistrySupported ? '''
## Dynamic Runtime Tools - AI Agent Workflow

1. Discovery: call `fmt_list_client_tools_and_resources` first.
2. Execution: use `fmt_client_tool` for dynamic tools.
3. Resources: use `fmt_client_resource` for dynamic resources.
4. Activation: call `fmt_hot_reload_flutter` after app-side tool code changes.
5. Verification: re-run `fmt_list_client_tools_and_resources` after reload/restart.

For detailed dynamic/tool-creation flows, rely on skill docs to avoid prompt duplication:
- flutter-mcp-toolkit-custom-tools (register AgentCallEntry / addMcpTool in the app)
- flutter-mcp-toolkit-intentcall-migration (MCPCallEntry → AgentCallEntry CLI migrate)
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
