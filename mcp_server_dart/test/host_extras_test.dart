// Complementary unit-level coverage for `McpHost`.
//
// This file contains non-redundant tests not covered by host_test.dart.
// Currently: dispose clearing state (covered here because it uses an
// independent capability instance and doesn't need the rollback/seal
// machinery tested in host_test.dart).

import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/host.dart';
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
        handler: (_) async => AgentResult.success(
          data: const <String, Object?>{'text': 'pong'},
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {}
}

final class _DualToolCapability implements Capability {
  _DualToolCapability({required this.tools, this.failOnLast = false});
  final List<String> tools;
  final bool failOnLast;

  @override
  String get id => 'core';
  @override
  String get description => 'dual tool';
  @override
  String get version => '0.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    for (var i = 0; i < tools.length; i++) {
      context.registerTool(
        ToolRegistration(
          name: tools[i],
          description: 'd',
          inputSchema: const {'type': 'object'},
        handler: (_) async => AgentResult.success(
          data: const <String, Object?>{'text': 'ok'},
        ),
        ),
      );
    }
    if (failOnLast) {
      throw StateError('boom');
    }
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

    test(
      'dispatch bridge publishes prefixed tools and unpublishes on dispose',
      () async {
        final published = <String>[];
        final unpublished = <String>[];
        final host = McpHost(
          dispatchBridge: DartMcpDispatchBridge(
            publish: (final tool, final _) => published.add(tool.name),
            unpublish: unpublished.add,
          ),
        );
        await host.registerCapability(_PingCapability());
        expect(published, equals(<String>['ping_pong']));
        expect(unpublished, isEmpty);

        await host.dispose();
        expect(unpublished, equals(<String>['ping_pong']));
      },
    );

    test(
      'dispatch bridge unpublishes when capability register throws',
      () async {
        final published = <String>[];
        final unpublished = <String>[];
        final host = McpHost(
          dispatchBridge: DartMcpDispatchBridge(
            publish: (final tool, final _) => published.add(tool.name),
            unpublish: unpublished.add,
          ),
        );
        await expectLater(
          host.registerCapability(
            _DualToolCapability(tools: ['a', 'b'], failOnLast: true),
          ),
          throwsA(isA<StateError>()),
        );
        expect(published, equals(<String>['core_a', 'core_b']));
        expect(unpublished, equals(<String>['core_a', 'core_b']));
        expect(host.toolNames, isEmpty);
      },
    );
  });
}
