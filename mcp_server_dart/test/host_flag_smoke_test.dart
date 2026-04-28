// Smoke test for the --use-capability-kernel flag wiring.
//
// Verifies that:
// 1. An McpHost constructed with the flag on starts empty (no capabilities
//    registered yet — T4/T5 will add them).
// 2. A fake capability can be registered and its prefixed tool names appear.
// 3. The legacy path (McpHost null / flag off) is represented by not creating
//    a host at all — tested implicitly by the existing host_test.dart and the
//    full flutter test suite.
//
// The full server constructor (MCPToolkitServer.fromStreamChannel) requires a
// live StreamChannel, which is out of scope for a unit smoke test. The
// plan explicitly licenses this smaller check. See clean_mcp_test.dart for
// the integration-level binary test.

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
  group('McpHost smoke (--use-capability-kernel flag=true)', () {
    test('host starts empty when no capabilities registered', () {
      // Mimics the server constructor body when useCapabilityKernel = true
      // and no capabilities have been added yet (T2 state).
      final host = McpHost();
      expect(host.toolNames, isEmpty);
    });

    test('host correctly prefixes tools from a registered capability', () async {
      final host = McpHost();
      await host.registerCapability(_PingCapability());
      expect(host.toolNames, contains('ping_pong'));
    });

    test('dispose clears the host state', () async {
      final host = McpHost();
      await host.registerCapability(_PingCapability());
      expect(host.toolNames, isNotEmpty);
      await host.dispose();
      expect(host.toolNames, isEmpty);
    });
  });
}
