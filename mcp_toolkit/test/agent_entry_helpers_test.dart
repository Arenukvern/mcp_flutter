import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  group('mcpToolkitTool inputSchema', () {
    test('forwards ObjectSchema from MCPToolDefinition', () {
      final entry = mcpToolkitTool(
        definition: MCPToolDefinition(
          name: 'calculate_fibonacci',
          description: 'Nth Fibonacci number',
          inputSchema: ObjectSchema(
            properties: {
              'n': IntegerSchema(
                description: 'Position in sequence (0-100)',
                minimum: 0,
                maximum: 100,
              ),
            },
            required: ['n'],
          ),
        ),
        handler: (_) => MCPCallResult(message: 'ok', parameters: {}),
      );

      final schema = entry.toRegistration().descriptor.inputSchema;
      expect(schema['type'], 'object');
      expect(schema['required'], ['n']);
      final properties = schema['properties']! as Map<String, Object?>;
      expect(properties['n'], isA<Map<String, Object?>>());
      expect((properties['n']! as Map)['type'], 'integer');
    });

    test('json-encodes object-typed args for legacy handlers', () async {
      String? capturedPredicate;
      final entry = mcpToolkitTool(
        definition: MCPToolDefinition(
          name: 'wait_for',
          description: 'wait',
          inputSchema: ObjectSchema(
            properties: {
              'predicate': ObjectSchema(),
            },
            required: ['predicate'],
          ),
        ),
        handler: (final request) async {
          capturedPredicate = request['predicate'];
          return MCPCallResult(message: 'ok', parameters: {});
        },
      );

      await entry.invokeDirect({
        'predicate': {'kind': 'time', 'ms': 50},
      });
      expect(capturedPredicate, contains('"kind"'));
      expect(capturedPredicate, contains('time'));
    });

    test('forwards empty ObjectSchema properties map', () {
      final entry = mcpToolkitTool(
        definition: MCPToolDefinition(
          name: 'semantic_snapshot',
          description: 'Semantic tree',
          inputSchema: ObjectSchema(properties: {}),
        ),
        handler: (_) => MCPCallResult(message: 'ok', parameters: {}),
      );

      final schema = entry.toRegistration().descriptor.inputSchema;
      expect(schema['type'], 'object');
      expect(schema['properties'], isA<Map>());
    });
  });

  group('interaction_toolkit discovery payload', () {
    test('tap_widget registerDynamics shape includes required ref', () {
      final tapEntry = getInteractionToolkitEntries().byName('tap_widget');
      final descriptor = tapEntry.toRegistration().descriptor;

      expect(descriptor.name, 'tap_widget');
      expect(descriptor.inputSchema['required'], ['ref']);

      final properties = descriptor.inputSchema['properties']! as Map;
      expect(properties.containsKey('ref'), isTrue);
      expect((properties['ref'] as Map)['type'], 'string');

      // Same shape as ext.mcp.toolkit.registerDynamics (mcp_toolkit_extensions).
      final registerDynamicsTool = {
        'name': descriptor.effectiveMethodName,
        'description': descriptor.description,
        'inputSchema': descriptor.inputSchema,
      };
      expect(registerDynamicsTool['name'], 'tap_widget');
      expect((registerDynamicsTool['inputSchema']! as Map)['required'], [
        'ref',
      ]);
    });
  });
}
