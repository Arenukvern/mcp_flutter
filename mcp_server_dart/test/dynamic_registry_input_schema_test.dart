import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/dynamic_registry.dart';
import 'package:test/test.dart';

void main() {
  group('inputSchemaFromMcpTool', () {
    test('copies required and properties from Tool.inputSchema', () {
      final tool = Tool(
        name: 'tap_widget',
        description: 'Tap by ref',
        inputSchema: ObjectSchema(
          required: ['ref'],
          properties: {'ref': StringSchema(description: 'Semantic ref')},
        ),
      );

      final schema = inputSchemaFromMcpTool(tool);
      expect(schema['type'], 'object');
      expect(schema['required'], ['ref']);
      final properties = schema['properties']! as Map<String, Object?>;
      expect((properties['ref']! as Map)['type'], 'string');
    });
  });

  group('dynamic registry intent validation', () {
    test('RegisteredAgentIntent rejects missing required fields', () {
      final tool = Tool(
        name: 'tap_widget',
        description: 'Tap by ref',
        inputSchema: ObjectSchema(
          required: ['ref'],
          properties: {'ref': StringSchema()},
        ),
      );
      final schema = inputSchemaFromMcpTool(tool);
      final intent = RegisteredAgentIntent(
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: tool.name,
          description: tool.description ?? '',
          kind: AgentIntentKind.tool,
          inputSchema: schema,
        ),
        execute: (_) async => AgentResult.success(),
      );

      expect(
        () => intent.validate(const <String, Object?>{}),
        throwsA(isA<AgentValidationException>()),
      );
      expect(() => intent.validate({'ref': 's_0'}), returnsNormally);
    });
  });
}
