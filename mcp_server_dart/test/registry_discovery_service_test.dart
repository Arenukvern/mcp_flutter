import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/server.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

MCPToolkitServer _createDiscoveryTestServer() =>
    MCPToolkitServer.fromStreamChannel(
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

Map<String, dynamic> _registrationPayload({
  required final List<Map<String, dynamic>> tools,
  final List<Map<String, dynamic>> resources = const [],
}) => {'appId': 'test_app', 'tools': tools, 'resources': resources};

Map<String, dynamic> _validToolMap({final String name = 'custom_tool'}) => {
  'name': name,
  'description': 'A custom tool',
  'inputSchema': {'type': 'object', 'properties': <String, Object?>{}},
};

void main() {
  group('parseRegisterDynamicsPayload', () {
    test('parses valid tools and resources', () {
      final parsed = parseRegisterDynamicsPayload(
        _registrationPayload(
          tools: [_validToolMap()],
          resources: [
            {
              'uri': 'visual://localhost/capture',
              'name': 'capture',
              'description': 'capture',
              'mimeType': 'application/json',
            },
          ],
        ),
      );

      expect(parsed.appId, const DynamicAppId('test_app'));
      expect(parsed.tools, hasLength(1));
      expect(parsed.tools.first.name, 'custom_tool');
      expect(parsed.resources, hasLength(1));
      expect(parsed.resources.first.resource.uri, 'visual://localhost/capture');
    });

    test('throws RegisterDynamicsPayloadException on invalid tool', () {
      expect(
        () => parseRegisterDynamicsPayload(
          _registrationPayload(
            tools: [
              _validToolMap(),
              const {'not_a_tool': true},
            ],
          ),
        ),
        throwsA(
          isA<RegisterDynamicsPayloadException>().having(
            (final e) => e.failures.length,
            'failure count',
            1,
          ),
        ),
      );
    });

    test('throws RegisterDynamicsPayloadException on invalid resource', () {
      expect(
        () => parseRegisterDynamicsPayload(
          _registrationPayload(
            tools: [_validToolMap()],
            resources: [
              const {'uri': 'visual://localhost/ok', 'name': 'ok'},
              const {'bad': true},
            ],
          ),
        ),
        throwsA(isA<RegisterDynamicsPayloadException>()),
      );
    });
  });

  group('RegistryDiscoveryService processRegistrationResponse', () {
    late MCPToolkitServer server;
    late DynamicRegistry registry;
    late RegistryDiscoveryService discovery;

    setUp(() {
      server = _createDiscoveryTestServer();
      // ignore: invalid_use_of_protected_member
      server.initializeDynamicRegistry(mcpToolkitServer: server);
      registry = server.dynamicRegistryForTesting!;
      discovery = RegistryDiscoveryService(
        dynamicRegistry: registry,
        server: server,
      );
    });

    test(
      'parse failure unregisters stale dynamic app from all registries',
      () async {
        server.registerDynamicTool(
          Tool(
            name: 'stale_tool',
            description: 'previously registered',
            inputSchema: ObjectSchema(),
          ),
          'stale_app',
        );
        server.registerDynamicResource(
          Resource(
            uri: 'visual://localhost/stale',
            name: 'stale_resource',
            description: 'previously registered',
            mimeType: 'application/json',
          ),
          'stale_app',
        );
        expect(registry.appInfo?.toolCount, 1);
        expect(registry.appInfo?.resourceCount, 1);

        final events = <DynamicRegistryEvent>[];
        final sub = registry.events.listen(events.add);

        await discovery.processRegistrationResponseForTesting(
          _registrationPayload(
            tools: [
              _validToolMap(),
              const {'invalid': true},
            ],
          ),
        );

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(registry.appInfo?.toolCount ?? 0, 0);
        expect(registry.appInfo?.resourceCount ?? 0, 0);
        expect(registry.getToolEntry('stale_tool'), isNull);
        expect(registry.getResourceEntry('visual://localhost/stale'), isNull);
        expect(events.whereType<AppUnregisteredEvent>(), isNotEmpty);

        final staleTool = await server.capabilityHost.agentRegistry.invoke(
          'stale_tool',
          const {},
        );
        expect(staleTool.ok, isFalse);
        expect(staleTool.code, 'intent_not_found');

        final staleResource = await server.capabilityHost.agentRegistry.invoke(
          'visual://localhost/stale',
          const {'uri': 'visual://localhost/stale'},
        );
        expect(staleResource.ok, isFalse);
        expect(staleResource.code, 'intent_not_found');
      },
    );

    test('valid payload registers tools after clearing prior app', () async {
      registry.registerTool(
        Tool(name: 'old_tool', description: 'old', inputSchema: ObjectSchema()),
        const DynamicAppId('old_app'),
      );

      await discovery.processRegistrationResponseForTesting(
        _registrationPayload(tools: [_validToolMap(name: 'new_tool')]),
      );

      expect(registry.appInfo?.toolCount, 1);
      expect(registry.getToolEntry('new_tool'), isNotNull);
      expect(registry.getToolEntry('old_tool'), isNull);
    });
  });
}
