// ignore_for_file: invalid_use_of_protected_member, lines_longer_than_80_chars

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  group('agent invoke surface (ADR-0017 invoke tier)', () {
    test('agent_catalog lists tool entries; agent_invoke dispatches them',
        () async {
      final binding = _CapturingToolkitBinding();
      final tool = mcpToolkitTool(
        namespace: 'app',
        definition: MCPToolDefinition(
          name: 'inspect_number',
          description: 'Inspect a number',
          inputSchema: ObjectSchema(
            properties: {'x': IntegerSchema()},
            required: ['x'],
            additionalProperties: false,
          ),
        ),
        handler: (final request) => MCPCallResult(
          message: 'inspected',
          parameters: {'ok': true, 'x': request['x']},
        ),
      );

      binding.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {tool},
      );

      // The invoke tier reads the registry — no second registration API.
      expect(binding.callbacks.keys, contains('agent_catalog'));
      expect(binding.callbacks.keys, contains('agent_invoke'));

      final Map<String, Object?> catalog =
          await binding.callbacks['agent_catalog']!({});
      final actions = List<Object?>.from(catalog['actions'] as List);
      expect(actions, hasLength(1));
      final descriptor = Map<Object?, Object?>.from(actions.single as Map);
      expect(descriptor['name'], 'inspect_number');
      expect(descriptor['namespace'], 'app');
      expect(descriptor['description'], 'Inspect a number');
      expect(descriptor['inputSchema'], isNotNull);

      final Map<String, Object?> invoke =
          await binding.callbacks['agent_invoke']!({
        'name': 'inspect_number',
        'json': jsonEncode({'x': 120}),
      });
      expect(invoke['ok'], isTrue);
      // agent_invoke delivers typed JSON args to the registry handler;
      // mcpToolkitTool's legacy adapter then normalizes to its
      // string-typed service-extension map ('120'), same as the MCP tier.
      expect(invoke['x'], '120');
    });

    test('agent_invoke refuses unknown names without throwing', () async {
      final binding = _CapturingToolkitBinding();
      binding.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: const {},
      );
      final Map<String, Object?> invoke =
          await binding.callbacks['agent_invoke']!({
        'name': 'nope',
        'json': '{}',
      });
      expect(invoke['success'], isFalse);
      expect(invoke['error'], contains('unknown registry action: nope'));
    });

    test('agent_invoke schema-validates before dispatch', () async {
      final binding = _CapturingToolkitBinding();
      final tool = mcpToolkitTool(
        namespace: 'app',
        definition: MCPToolDefinition(
          name: 'inspect_number',
          description: 'Inspect a number',
          inputSchema: ObjectSchema(
            properties: {'x': IntegerSchema()},
            required: ['x'],
            additionalProperties: false,
          ),
        ),
        handler: (final request) =>
            MCPCallResult(message: 'inspected', parameters: const {}),
      );
      binding.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {tool},
      );
      final Map<String, Object?> refusal =
          await binding.callbacks['agent_invoke']!({
        'name': 'inspect_number',
        'json': jsonEncode({'y': 1}),
      });
      expect(refusal['success'], isFalse);
      expect(refusal['error'], contains('inspect_number'));
      // Malformed json args get the same shape (one failure shape per
      // verb), never a raw FormatException over the wire.
      final Map<String, Object?> malformed =
          await binding.callbacks['agent_invoke']!({
        'name': 'inspect_number',
        'json': 'not-json',
      });
      expect(malformed['success'], isFalse);
      expect(malformed['error'], isNotNull);
    });
  });
}

final class _CapturingToolkitBinding extends MCPToolkitBindingBase
    with MCPToolkitExtensions {
  final callbacks = <String, ServiceExtensionCallback>{};

  @override
  void registerServiceExtension({
    required final String name,
    required final ServiceExtensionCallback callback,
  }) {
    callbacks[name] = callback;
  }
}

final class _TestErrorMonitor with ErrorMonitor {}
