import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';

String buildMcpToolkitServerInstructions(
  VMServiceConfigurationRecord configuration,
) =>
    '''
Flutter MCP Toolkit Server — agent guide

Inspect and drive a **debug** Flutter app over the VM service. MCP tool names use the `fmt_*` prefix.

## Default workflow (core loop)

1. **Discover / connect** — `fmt_discover_debug_apps`, `fmt_connect_debug_app` (use `connection.uri` or `targetId` when multiple apps run).
2. **See the UI** — `fmt_semantic_snapshot`, `fmt_get_screenshots`, `fmt_capture_ui_snapshot`, `fmt_get_app_errors`.
   On macOS / iOS Simulator, if host `desktop_window` capture fails, pass `screenshotMode: flutter_layer` in tool args for a reliable Flutter-layer shot.
3. **Act** — `fmt_tap_widget`, `fmt_enter_text`, `fmt_scroll`, `fmt_wait_for` (stable predicate after reload).
4. **Reload + verify** — `fmt_hot_reload_flutter`, `fmt_hot_reload_and_capture`.
${configuration.dynamicRegistrySupported ? '''5. **Dynamic tools** (when the app registers AgentCallEntry surfaces) — `fmt_list_client_tools_and_resources`, `fmt_client_tool`, `fmt_client_resource`; hot reload after code changes.
''' : ''}
Supporting tools include `fmt_get_vm`, `fmt_get_view_details`, navigation/dialog helpers, and interaction catalog entries (`fmt_drag`, `fmt_swipe`, …). Install the `flutter-mcp-toolkit-*` skills or call `tools/list` for the live catalog.

${configuration.dumpsSupported ? '''
## Debug dump tools (`--dumps` only)

Heavy tree dumps — use sparingly:

- `fmt_debug_dump_layer_tree`
- `fmt_debug_dump_semantics_tree`
- `fmt_debug_dump_render_tree`
- `fmt_debug_dump_focus_tree`
''' : ''}

${configuration.resourcesSupported ? '''
## Static resources

- `visual://localhost/app/errors/latest`
- `visual://localhost/app/errors/{count}`
- `visual://localhost/view/details`
- `visual://localhost/view/screenshots`
''' : '''
## Error and view tools (when resources are disabled)

- `fmt_get_app_errors`, `fmt_get_view_details`, `fmt_get_screenshots`
'''}

## Requirements

- App runs in **debug** with VM service enabled.
- App calls `mcp_toolkit` bootstrap (`MCPToolkitBinding` / `bootstrapFlutter`) before `runApp`.
- Flutter-layer screenshots work with the app window in the background; host `desktop_window` capture may need foreground focus.

Connect to a running instrumented app to use these tools.
''';