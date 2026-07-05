import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/server.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_mcp/intentcall_mcp.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:stream_channel/stream_channel.dart';
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

  group('inputSchemaFromDynamicRegistrationMap', () {
    test('defaults to clientResourceReadInputSchema', () {
      expect(
        inputSchemaFromDynamicRegistrationMap(const {}),
        clientResourceReadInputSchema(),
      );
    });

    test('copies inputSchema from registration payload', () {
      final schema = inputSchemaFromDynamicRegistrationMap({
        'inputSchema': {
          'type': 'object',
          'required': ['uri', 'mode'],
          'properties': {
            'uri': {'type': 'string'},
            'mode': {'type': 'string'},
          },
        },
      });
      expect(schema['required'], ['uri', 'mode']);
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

    test('resource intent rejects missing uri', () {
      final intent = RegisteredAgentIntent(
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: 'visual_capture',
          description: 'Bridge resource',
          kind: AgentIntentKind.resource,
          inputSchema: clientResourceReadInputSchema(),
          resourceUri: 'visual://localhost/capture',
        ),
        execute: (_) async => AgentResult.success(),
      );

      expect(
        () => intent.validate(const <String, Object?>{}),
        throwsA(isA<AgentValidationException>()),
      );
      expect(
        () => intent.validate({'uri': 'visual://localhost/capture'}),
        returnsNormally,
      );
    });
  });

  group('forwardToolCall coercion', () {
    late MCPToolkitServer server;
    late DynamicRegistry registry;

    setUp(() {
      server = MCPToolkitServer.fromStreamChannel(
        StreamChannel.withCloseGuarantee(
          const Stream.empty(),
          StreamController<String>().sink,
        ),
        configuration: (
          vmHost: 'localhost',
          vmPort: 8181,
          awaitDndConnection: false,
          resourcesSupported: true,
          imagesSupported: false,
          dumpsSupported: false,
          logLevel: 'error',
          environment: 'test',
          dynamicRegistrySupported: true,
          saveImagesToFiles: false,
          flutterProjectDir: null,
          flutterDevice: null,
          flutterDiscoveryTimeoutMs: 2500,
        ),
      );
      // ignore: invalid_use_of_protected_member
      server.initializeDynamicRegistry(mcpToolkitServer: server);
      registry = server.dynamicRegistryForTesting!;
    });

    test('coerces wire strings before validate (not invalidCommand)', () async {
      registry.registerTool(
        Tool(
          name: 'tap_widget',
          description: 'Tap by ref',
          inputSchema: ObjectSchema(
            required: ['ref'],
            properties: {'ref': StringSchema(), 'snapshotId': IntegerSchema()},
          ),
        ),
        const DynamicAppId('test_app'),
      );

      final result = await registry.forwardToolCall('tap_widget', {
        'ref': 's_0',
        'snapshotId': '42',
      });

      expect(result, isNotNull);
      final agentResult = mcpResultToAgentResult(result!);
      expect(agentResult.ok, isFalse);
      expect(agentResult.message, isNot(contains('must be an integer')));
      expect(agentResult.message, isNot(contains('Missing required')));
    });
  });
}
