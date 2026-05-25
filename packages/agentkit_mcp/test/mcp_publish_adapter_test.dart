import 'dart:async';

import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:dart_mcp/server.dart';
import 'package:test/test.dart';

void main() {
  test(
    'McpPublishAdapter hot-syncs resource on IntentRegistered event',
    () async {
      final registry = InMemoryAgentRegistry();
      final publishedResources =
          <
            String,
            FutureOr<ReadResourceResult> Function(ReadResourceRequest)
          >{};
      final unpublished = <String>[];
      const uri = 'visual://localhost/app/errors';

      final adapter = McpPublishAdapter(
        publishTool: (_, __) {},
        unpublishTool: (_) {},
        publishResource: (final resource, final impl) {
          publishedResources[resource.uri] = impl;
        },
        unpublishResource: unpublished.add,
      );

      await adapter.attach(registry);
      expect(publishedResources, isEmpty);

      registry.register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'errors',
            description: 'errors resource',
            kind: AgentIntentKind.resource,
            inputSchema: const <String, Object?>{'type': 'object'},
            resourceUri: uri,
            mimeType: 'application/json',
          ),
          execute: (_) async => AgentResult.success(
            data: <String, Object?>{
              'contents': [
                <String, Object?>{
                  'type': 'text',
                  'text': '{"count":0}',
                  'mimeType': 'application/json',
                },
              ],
            },
          ),
        ),
        qualifiedNameOverride: uri,
      );

      await Future<void>.delayed(Duration.zero);
      expect(publishedResources, contains(uri));

      final read = await publishedResources[uri]!(
        ReadResourceRequest(uri: uri),
      );
      expect(read.contents, isNotEmpty);
      final text = (read.contents.first as TextResourceContents).text;
      expect(text, '{"count":0}');

      registry.unregister(uri);
      await Future<void>.delayed(Duration.zero);
      expect(unpublished, contains(uri));

      await adapter.detach();
    },
  );
}
