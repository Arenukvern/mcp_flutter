import 'dart:async';

import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/host.dart';
import 'package:test/test.dart';

void main() {
  group('Flutter Inspector resource templates', () {
    test(
      'registerPublishedResourceTemplate reads count via registry and MCP',
      () async {
        const uriTemplate = 'visual://localhost/app/errors/{count}';
        const readUri = 'visual://localhost/app/errors/3';
        final publishedTemplates =
            <
              String,
              FutureOr<ReadResourceResult?> Function(ReadResourceRequest)
            >{};
        final host = McpHost(
          dispatchBridge: DartMcpDispatchBridge(
            publish: (_, final _) {},
            unpublish: (_) {},
            publishResource: (_, final _) {},
            unpublishResource: (_) {},
            publishResourceTemplate: (final template, final impl) {
              publishedTemplates[template.uriTemplate] = impl;
            },
          ),
        );

        await host.registerPublishedResourceTemplate(
          capabilityId: 'visual',
          registration: ResourceTemplateRegistration(
            uriTemplate: uriTemplate,
            name: 'application_errors',
            description: 'Get N application errors',
            mimeType: 'application/json',
            handler: (final uri) async {
              final count = Uri.parse(uri).pathSegments.last;
              return AgentResult.success(
                data: <String, Object?>{
                  'contents': [
                    <String, Object?>{
                      'type': 'text',
                      'text': '{"count":$count}',
                      'mimeType': 'application/json',
                    },
                  ],
                },
              );
            },
          ),
        );

        expect(host.resourceTemplateUris, contains(uriTemplate));
        expect(publishedTemplates, contains(uriTemplate));

        final direct = await host.agentRegistry.invoke(
          uriTemplate,
          <String, Object?>{'uri': readUri, 'count': '3'},
        );
        expect(direct.ok, isTrue);
        final directContents = direct.data['contents']! as List;
        expect(
          (directContents.first as Map)['text'],
          '{"count":3}',
        );

        final mcpRead = await publishedTemplates[uriTemplate]!(
          ReadResourceRequest(uri: readUri),
        );
        expect(mcpRead, isNotNull);
        final text = (mcpRead!.contents.first as TextResourceContents).text;
        expect(text, '{"count":3}');

        final noMatch = await publishedTemplates[uriTemplate]!(
          ReadResourceRequest(uri: 'visual://localhost/other/3'),
        );
        expect(noMatch, isNull);
      },
    );
  });
}
