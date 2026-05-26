import 'dart:async';
import 'dart:convert';

import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/codegen/get_recent_logs_tool.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/host.dart';
import 'package:test/test.dart';

void main() {
  group('agentkit registry-MCP contracts', () {
    test(
      'fmt_get_recent_logs registry invoke matches MCP adapter envelope',
      () async {
        const toolName = 'fmt_get_recent_logs';
        const args = <String, Object?>{'count': 7};
        final published =
            <String, FutureOr<CallToolResult> Function(CallToolRequest)>{};
        final host = McpHost(
          dispatchBridge: DartMcpDispatchBridge(
            publish: (final tool, final impl) {
              published[tool.name] = impl;
            },
            unpublish: (_) {},
          ),
        );

        await host.registerCapability(_FmtCodegenContractCapability());

        expect(published, contains(toolName));

        final registryResult = await host.agentRegistry.invoke(toolName, args);
        final mcpResult = await published[toolName]!(
          CallToolRequest(name: toolName, arguments: args),
        );

        expect(registryResult.ok, isTrue);
        expect(registryResult.data['count'], 7);
        expect(mcpResult, equals(agentResultToMcpResult(registryResult)));
        expect(mcpResultToAgentResult(mcpResult).data['text'], isNotNull);
        final decoded =
            jsonDecode(mcpResultToAgentResult(mcpResult).data['text']! as String)
                as Map<String, Object?>;
        expect(decoded['count'], 7);
      },
    );

    test('dynamic fake intent registers and round-trips via MCP adapter', () async {
      const toolName = 'dynapp_fake_echo';
      final published =
          <String, FutureOr<CallToolResult> Function(CallToolRequest)>{};
      final unpublished = <String>[];
      final registry = InMemoryAgentRegistry();
      final adapter = McpPublishAdapter(
        publishTool: (final tool, final impl) {
          published[tool.name] = impl;
        },
        unpublishTool: unpublished.add,
      );

      await adapter.attach(registry);
      expect(published, isEmpty);

      registry.register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'dynapp',
            name: 'fake_echo',
            description: 'contract fake dynamic tool',
            kind: AgentIntentKind.tool,
            inputSchema: <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'message': <String, Object?>{'type': 'string'},
              },
            },
          ),
          execute: (final invocation) async => AgentResult.success(
            data: <String, Object?>{
              'echo': invocation.arguments['message'] ?? 'ok',
            },
          ),
        ),
        qualifiedNameOverride: toolName,
      );

      await Future<void>.delayed(Duration.zero);
      expect(published, contains(toolName));

      const args = <String, Object?>{'message': 'round-trip'};
      final registryResult = await registry.invoke(toolName, args);
      final mcpResult = await published[toolName]!(
        CallToolRequest(name: toolName, arguments: args),
      );

      expect(registryResult.ok, isTrue);
      expect(registryResult.data['echo'], 'round-trip');
      expect(mcpResult, equals(agentResultToMcpResult(registryResult)));

      registry.unregister(toolName);
      await Future<void>.delayed(Duration.zero);
      expect(unpublished, contains(toolName));

      await adapter.detach();
    });

    test(
      'application_errors resource template round-trips registry and MCP read',
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
            publish: (_, __) {},
            unpublish: (_) {},
            publishResource: (_, __) {},
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

        expect(publishedTemplates, contains(uriTemplate));

        final registryResult = await host.agentRegistry.invoke(
          uriTemplate,
          <String, Object?>{'uri': readUri, 'count': '3'},
        );
        expect(registryResult.ok, isTrue);

        final mcpRead = await publishedTemplates[uriTemplate]!(
          ReadResourceRequest(uri: readUri),
        );
        expect(mcpRead, isNotNull);

        final fromRegistry = agentResultToReadResourceResult(
          registryResult,
          uri: readUri,
        );
        expect(fromRegistry.contents, mcpRead!.contents);
        final text = (mcpRead.contents.first as TextResourceContents).text;
        expect(text, '{"count":3}');

        final roundTrip = readResourceResultToAgentResult(mcpRead);
        expect(roundTrip.ok, isTrue);
        final registryText =
            ((registryResult.data['contents'] as List).first as Map)['text'];
        final roundTripText =
            ((roundTrip.data['contents'] as List).first as Map)['text'];
        expect(roundTripText, registryText);
        expect(roundTripText, '{"count":3}');
      },
    );
  });
}

final class _FmtCodegenContractCapability implements Capability {
  @override
  String get id => 'fmt';

  @override
  String get description => 'fmt codegen contract';

  @override
  String get version => '0.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    context.registerTool(
      agentCallEntryToToolRegistration(
        getRecentLogsCallEntry,
        handler: (final args) async {
          final count = args['count'];
          return AgentResult.success(
            data: <String, Object?>{
              'count': count is int ? count : 50,
            },
          );
        },
      ),
    );
  }

  @override
  Future<void> dispose() async {}
}
