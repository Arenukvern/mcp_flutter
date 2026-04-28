// Complementary unit-level coverage for `McpHost`.
//
// This file contains non-redundant tests not covered by host_test.dart.
// Currently: dispose clearing state (covered here because it uses an
// independent capability instance and doesn't need the rollback/seal
// machinery tested in host_test.dart).

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/host.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:test/test.dart';

final class _PingCapability implements Capability {
  @override
  String get id => 'ping';
  @override
  String get description => 'smoke test capability';
  @override
  String get version => '0.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    context.registerTool(
      ToolRegistration(
        name: 'pong',
        description: 'replies pong',
        inputSchema: const {'type': 'object'},
        handler: (_) async => CallToolResult(
          content: [TextContent(text: 'pong')],
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('McpHost', () {
    test('dispose clears the host state', () async {
      final host = McpHost();
      await host.registerCapability(_PingCapability());
      expect(host.toolNames, isNotEmpty);
      await host.dispose();
      expect(host.toolNames, isEmpty);
    });
  });
}
