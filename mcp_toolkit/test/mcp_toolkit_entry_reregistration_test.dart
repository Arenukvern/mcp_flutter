// ignore_for_file: invalid_use_of_protected_member, lines_longer_than_80_chars

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  group('addEntries after VM extension registration (hot reload)', () {
    test('second addEntries for the same tool does not throw', () {
      final binding = _CapturingToolkitBinding();

      final tool = _pingTool(revision: 1);
      binding.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {tool},
      );

      expect(
        () => binding.initializeServiceExtensions(
          errorMonitor: _TestErrorMonitor(),
          entries: {_pingTool(revision: 2)},
        ),
        returnsNormally,
      );
    });

    test(
      're-add with a new handler dispatches the latest handler without re-registering',
      () async {
        final binding = _CapturingToolkitBinding();

        binding.initializeServiceExtensions(
          errorMonitor: _TestErrorMonitor(),
          entries: {_pingTool(revision: 1)},
        );

        var secondCallCount = 0;
        binding.initializeServiceExtensions(
          errorMonitor: _TestErrorMonitor(),
          entries: {
            _pingTool(
              revision: 2,
              handler: (_) async {
                secondCallCount += 1;
                return MCPCallResult(
                  message: 'pong',
                  parameters: {'rev': 2},
                );
              },
            ),
          },
        );

        expect(binding.callbacks.keys, contains('ping'));
        final result = await binding.callbacks['ping']!({});
        expect(result['rev'], 2);
        expect(secondCallCount, 1);
      },
    );

    test('agent_invoke uses the latest handler after re-add', () async {
      final binding = _CapturingToolkitBinding();
      binding.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {_pingTool(revision: 1)},
      );
      binding.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {
          _pingTool(
            revision: 2,
            handler: (_) async => MCPCallResult(
              message: 'pong',
              parameters: {'rev': 2},
            ),
          ),
        },
      );

      final invoke = await binding.callbacks['agent_invoke']!({
        'name': 'ping',
        'json': '{}',
      });
      expect(invoke['rev'], 2);
    });

    test('fresh binding re-registers every extension (hot restart)', () {
      final first = _CapturingToolkitBinding();
      first.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {_pingTool(revision: 1)},
      );

      final second = _CapturingToolkitBinding();
      second.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {_pingTool(revision: 2)},
      );

      expect(first.callbacks, isNot(same(second.callbacks)));
      expect(second.callbacks.keys, contains('ping'));
    });
  });
}

AgentCallEntry _pingTool({
  required int revision,
  MCPCallHandler? handler,
}) {
  return mcpToolkitTool(
    namespace: 'demo',
    definition: MCPToolDefinition(
      name: 'ping',
      description: 'Health check rev $revision',
      inputSchema: ObjectSchema(properties: const {}),
    ),
    handler: handler ??
        (_) async => MCPCallResult(
              message: 'pong',
              parameters: {'rev': revision},
            ),
  );
}

final class _CapturingToolkitBinding extends MCPToolkitBindingBase
    with MCPToolkitExtensions {
  final callbacks = <String, ServiceExtensionCallback>{};

  @override
  void registerServiceExtension({
    required String name,
    required ServiceExtensionCallback callback,
  }) {
    callbacks[name] = callback;
  }
}

final class _TestErrorMonitor with ErrorMonitor {}