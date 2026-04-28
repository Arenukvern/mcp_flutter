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

final class _DisposeTrackingCapability implements Capability {
  _DisposeTrackingCapability({required this.id, required this.onDispose});

  @override
  final String id;
  @override
  String get description => 'tracking';
  @override
  String get version => '0.0.0';

  final void Function() onDispose;

  @override
  Future<void> register(final CapabilityContext context) async {}

  @override
  Future<void> dispose() async => onDispose();
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

    test('registerTool after register() returns throws StateError', () async {
      late CapabilityContext escapedCtx;
      final cap = _CapturingCapability((final ctx) => escapedCtx = ctx);
      final host = McpHost();
      await host.registerCapability(cap);
      expect(
        () => escapedCtx.registerTool(
          ToolRegistration(
            name: 'late',
            description: 'd',
            inputSchema: const {'type': 'object'},
            handler: (_) async =>
                CallToolResult(content: [TextContent(text: 'ok')]),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('registerResource after register() returns throws StateError',
        () async {
      late CapabilityContext escapedCtx;
      final cap = _CapturingCapability((final ctx) => escapedCtx = ctx);
      final host = McpHost();
      await host.registerCapability(cap);
      // Note: registerResource currently throws UnimplementedError after the
      // seal check. We assert the seal fires FIRST (StateError before
      // UnimplementedError).
      expect(
        () => escapedCtx.registerResource(
          ResourceRegistration(
            uri: 'fake://x',
            name: 'x',
            description: 'x',
            mimeType: 'text/plain',
            handler: (_) async => ReadResourceResult(contents: const []),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('failed registration leaves no partial state; retry is clean',
        () async {
      final host = McpHost();

      // First attempt: pre-prefixed name fails.
      await expectLater(
        host.registerCapability(
          _FakeCapability(id: 'core', tools: ['core_bad']),
        ),
        throwsA(isA<PrePrefixedToolNameError>()),
      );

      // Confirm no leak: tools are empty, capability not retained.
      expect(host.toolNames, isEmpty);

      // Retry with same id and a clean tool set must succeed (would throw
      // CapabilityAlreadyRegisteredError if the failed attempt had leaked).
      await host.registerCapability(
        _FakeCapability(id: 'core', tools: ['tap_widget']),
      );
      expect(host.toolNames, contains('core_tap_widget'));
    });

    test('partial tools rolled back when later registration throws', () async {
      final host = McpHost();
      await expectLater(
        host.registerCapability(
          _FakeCapability(id: 'core', tools: ['good_one', 'core_bad']),
        ),
        throwsA(isA<PrePrefixedToolNameError>()),
      );
      // The first tool was registered, then the second threw. Roll back must
      // have removed the first.
      expect(host.toolNames, isEmpty);
    });

    test('dispose isolates per-capability failures and clears state', () async {
      final host = McpHost();
      final disposed = <String>[];
      await host.registerCapability(
        _DisposeTrackingCapability(id: 'a', onDispose: () => disposed.add('a')),
      );
      await host.registerCapability(
        _DisposeTrackingCapability(
          id: 'b',
          onDispose: () {
            disposed.add('b');
            throw StateError('b failed');
          },
        ),
      );
      await host.registerCapability(
        _DisposeTrackingCapability(id: 'c', onDispose: () => disposed.add('c')),
      );

      await expectLater(host.dispose(), throwsA(isA<StateError>()));
      // All three were attempted, even though b threw.
      expect(disposed, containsAll(<String>['a', 'b', 'c']));
      // State is cleared even after the throw.
      expect(host.toolNames, isEmpty);
    });
  });
}
