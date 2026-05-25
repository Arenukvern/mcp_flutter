import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:agentkit_webmcp/agentkit_webmcp.dart';
import 'package:test/test.dart';

void main() {
  test('WebMcpPublishAdapter publishes tools and invokes registry', () async {
    final registry = InMemoryAgentRegistry();
    registry.register(
      RegisteredAgentIntent(
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: 'hello',
          description: 'say hello',
          kind: AgentIntentKind.tool,
          inputSchema: const <String, Object?>{'type': 'object'},
        ),
        execute: (_) async => AgentResult.success(
          data: <String, Object?>{'text': 'hi'},
        ),
      ),
    );

    final published = <String, Future<Map<String, Object?>> Function(
      Map<String, Object?>,
    )>{};
    final adapter = WebMcpPublishAdapter(
      publish:
          ({
            required final name,
            required final description,
            required final inputSchema,
            required final execute,
          }) {
            published[name] = execute;
          },
      unpublish: (_) {},
    );

    await adapter.attach(registry);
    expect(published, contains('app_hello'));

    final out = await published['app_hello']!(const <String, Object?>{});
    expect(out['ok'], isTrue);
    expect(out['text'], 'hi');

    await adapter.detach();
  });
}
