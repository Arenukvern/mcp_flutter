import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/host.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:test/test.dart';

final class _FakeCapability implements Capability {
  _FakeCapability({
    required this.id,
    required this.tools,
  });

  @override
  final String id;
  @override
  String get description => 'fake';
  @override
  String get version => '0.0.0';

  final List<String> tools;

  @override
  Future<void> register(final CapabilityContext context) async {
    for (final name in tools) {
      context.registerTool(
        ToolRegistration(
          name: name,
          description: 'fake tool $name',
          inputSchema: const {'type': 'object'},
          handler: (_) async => CallToolResult(
            content: [TextContent(text: 'ok')],
          ),
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {}
}

final class _CapturingCapability implements Capability {
  _CapturingCapability(this._capture);
  final void Function(CapabilityContext context) _capture;

  @override
  String get id => 'capture';
  @override
  String get description => 'capture';
  @override
  String get version => '0.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    _capture(context);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('McpHost', () {
    test('registers a capability and exposes prefixed tool names', () async {
      final host = McpHost();
      await host.registerCapability(
        _FakeCapability(id: 'core', tools: ['tap_widget', 'enter_text']),
      );

      expect(
        host.toolNames,
        containsAll(<String>['core_tap_widget', 'core_enter_text']),
      );
    });

    test('rejects two capabilities with the same id', () async {
      final host = McpHost();
      await host.registerCapability(_FakeCapability(id: 'core', tools: []));
      await expectLater(
        host.registerCapability(_FakeCapability(id: 'core', tools: [])),
        throwsA(isA<CapabilityAlreadyRegisteredError>()),
      );
    });

    test('rejects a capability that pre-prefixes its tool names', () async {
      final host = McpHost();
      await expectLater(
        host.registerCapability(
          _FakeCapability(id: 'core', tools: ['core_tap_widget']),
        ),
        throwsA(isA<PrePrefixedToolNameError>()),
      );
    });

    test('rejects an intra-capability tool-name collision', () async {
      final host = McpHost();
      await expectLater(
        host.registerCapability(
          _FakeCapability(id: 'core', tools: ['tap_widget', 'tap_widget']),
        ),
        throwsA(isA<ToolNameCollisionError>()),
      );
    });

    test('require<T>() throws when host service not provided', () async {
      final host = McpHost();
      late CapabilityContext capturedContext;

      final cap = _CapturingCapability((final ctx) {
        capturedContext = ctx;
      });

      await host.registerCapability(cap);
      expect(
        () => capturedContext.require<DynamicRegistryBridge>(),
        throwsA(isA<HostServiceUnavailableError>()),
      );
    });
  });
}
