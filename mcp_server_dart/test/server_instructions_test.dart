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
  });

  test('dynamicRegistrySupported parameter changes instructions', () {
    final on = buildMcpToolkitServerInstructions(
      _minimalConfig(dynamicRegistrySupported: true),
    );
    final off = buildMcpToolkitServerInstructions(
      _minimalConfig(dynamicRegistrySupported: false),
    );
    expect(on, isNot(equals(off)));
    expect(on, contains('fmt_client_tool'));
  });
}