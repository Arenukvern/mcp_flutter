import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/server_instructions.dart';
import 'package:test/test.dart';

VMServiceConfigurationRecord _minimalConfig({
  bool dumpsSupported = false,
  bool resourcesSupported = true,
  bool dynamicRegistrySupported = true,
}) => (
  vmHost: 'localhost',
  vmPort: 8181,
  resourcesSupported: resourcesSupported,
  imagesSupported: true,
  dumpsSupported: dumpsSupported,
  dynamicRegistrySupported: dynamicRegistrySupported,
  logLevel: 'warning',
  environment: 'development',
  awaitDndConnection: false,
  saveImagesToFiles: false,
  flutterProjectDir: null,
  flutterDevice: null,
  flutterDiscoveryTimeoutMs: 3000,
  scanPorts: const <int>[],
  preferredTargetLabel: null,
);

void main() {
  test('server instructions title reflects flutter-mcp-toolkit branding', () {
    final text = buildMcpToolkitServerInstructions(_minimalConfig());
    expect(text, contains('Flutter MCP Toolkit Server'));
    expect(text, isNot(contains('Flutter Inspector MCP Server')));
    expect(text, contains('fmt_discover_debug_apps'));
    expect(text, contains('fmt_semantic_snapshot'));
    expect(text, contains('screenshotMode: flutter_layer'));
    expect(text, contains('errors/{count}'));
    expect(text, isNot(contains('fmt_debug_dump_render_tree')));
  });

  test('dump tools section appears only when dumps enabled', () {
    final withDumps = buildMcpToolkitServerInstructions(
      _minimalConfig(dumpsSupported: true),
    );
    expect(withDumps, contains('fmt_debug_dump_render_tree'));
  });

  test('dynamic registry section omitted when dynamics disabled', () {
    final text = buildMcpToolkitServerInstructions(
      _minimalConfig(dynamicRegistrySupported: false),
    );
    expect(text, isNot(contains('fmt_client_tool')));
    expect(text, isNot(contains('fmt_list_client_tools_and_resources')));
    expect(text, isNot(contains('flutter-mcp-toolkit-custom-tools')));
  });

  test('dynamicRegistrySupported parameter changes instructions', () {
    final on = buildMcpToolkitServerInstructions(_minimalConfig());
    final off = buildMcpToolkitServerInstructions(
      _minimalConfig(dynamicRegistrySupported: false),
    );
    expect(on, isNot(equals(off)));
    expect(on, contains('fmt_client_tool'));
    expect(on, contains('fmt_hot_restart_flutter'));
    expect(on, contains('flutter-mcp-toolkit-custom-tools'));
  });

  test('resources section uses tools when resources disabled', () {
    final withResources = buildMcpToolkitServerInstructions(_minimalConfig());
    final text = buildMcpToolkitServerInstructions(
      _minimalConfig(resourcesSupported: false),
    );
    expect(withResources, contains('## Static resources'));
    expect(text, isNot(contains('## Static resources')));
    expect(text, contains('## Error and view tools'));
    expect(text, isNot(contains('visual://localhost/app/errors/latest')));
    expect(text, contains('fmt_get_app_errors'));
    expect(text, contains('fmt_get_view_details'));
  });
}
