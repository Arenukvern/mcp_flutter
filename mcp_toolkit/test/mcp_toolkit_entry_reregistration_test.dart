// ignore_for_file: invalid_use_of_protected_member, lines_longer_than_80_chars

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intentcall_core/intentcall_core.dart';
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

    test(
      'a new binding instance starts with an empty extension registry (unit stand-in, not a hot restart)',
      () {
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
      },
    );
  });

  group('service extension name collisions', () {
    test('default tools use registry key equal to service extension name', () {
      final entry = _pingTool(revision: 1);
      expect(entry.key, entry.serviceExtensionName);
      expect(entry.key, 'ping');
    });

    test('duplicate tool name across namespaces fails closed', () {
      final binding = _CapturingToolkitBinding();
      binding.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {
          _pingTool(revision: 1, namespace: 'team_a'),
        },
      );

      expect(
        () => binding.initializeServiceExtensions(
          errorMonitor: _TestErrorMonitor(),
          entries: {
            _pingTool(revision: 2, namespace: 'team_b'),
          },
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('Duplicate tool name'),
          ),
        ),
      );
    });

    test('duplicate VM extension from different registry keys fails closed', () {
      final binding = _CapturingToolkitBinding();

      expect(
        () => binding.initializeServiceExtensions(
          errorMonitor: _TestErrorMonitor(),
          entries: {
            AgentCallEntry.tool(
              namespace: 'a',
              name: 'wire_a',
              description: 'a',
              inputSchema: _emptyObjectSchema,
              methodName: 'shared_vm_ext',
              handler: (_) async => AgentResult.success(),
            ),
            AgentCallEntry.tool(
              namespace: 'b',
              name: 'wire_b',
              description: 'b',
              inputSchema: _emptyObjectSchema,
              methodName: 'shared_vm_ext',
              handler: (_) async => AgentResult.success(),
            ),
          },
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('Duplicate VM service extension'),
          ),
        ),
      );
    });

    test(
      'VM extension collision throw leaves prior registry and VM table intact',
      () async {
        final binding = _CapturingToolkitBinding();
        binding.initializeServiceExtensions(
          errorMonitor: _TestErrorMonitor(),
          entries: {
            _pingTool(
              revision: 1,
              handler: (_) async => MCPCallResult(
                message: 'pong',
                parameters: {'rev': 1},
              ),
            ),
          },
        );

        expect(
          () => binding.initializeServiceExtensions(
            errorMonitor: _TestErrorMonitor(),
            entries: {
              AgentCallEntry.tool(
                namespace: 'demo',
                name: 'pong',
                description: 'collides on VM extension ping',
                inputSchema: _emptyObjectSchema,
                methodName: 'ping',
                handler: (_) async => AgentResult.success(
                  data: {'rev': 2},
                ),
              ),
            },
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.toString(),
              'message',
              contains('Duplicate VM service extension'),
            ),
          ),
        );

        final vm = await binding.callbacks['ping']!({});
        expect(vm['rev'], 1);

        final invokePing = await binding.callbacks['agent_invoke']!({
          'name': 'ping',
          'json': '{}',
        });
        expect(invokePing['rev'], 1);

        final invokePong = await binding.callbacks['agent_invoke']!({
          'name': 'pong',
          'json': '{}',
        });
        expect(invokePong['success'], isFalse);
        expect(invokePong['error'], contains('unknown registry action'));
      },
    );

    test('VM and agent_invoke agree on handler for custom methodName', () async {
      final binding = _CapturingToolkitBinding();
      binding.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {
          AgentCallEntry.tool(
            namespace: 'demo',
            name: 'catalog_name',
            description: 'test',
            inputSchema: _emptyObjectSchema,
            methodName: 'vm_ext_name',
            handler: (_) async => AgentResult.success(
              data: {'via': 'catalog'},
            ),
          ),
        },
      );

      final vm = await binding.callbacks['vm_ext_name']!({});
      expect(vm['via'], 'catalog');

      final invoke = await binding.callbacks['agent_invoke']!({
        'name': 'vm_ext_name',
        'json': '{}',
      });
      expect(invoke['via'], 'catalog');
    });
  });
}

AgentCallEntry _pingTool({
  required int revision,
  String namespace = 'demo',
  MCPCallHandler? handler,
}) {
  return mcpToolkitTool(
    namespace: namespace,
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

const _emptyObjectSchema = {
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{},
};
