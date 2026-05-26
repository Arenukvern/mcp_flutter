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
          data: const <String, Object?>{'text': 'hi'},
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

  test(
    'WebMcpPublishAdapter hot-syncs register and unregister after attach',
    () async {
      final registry = InMemoryAgentRegistry();
      final published = <String, Future<Map<String, Object?>> Function(
        Map<String, Object?>,
      )>{};
      final unpublished = <String>[];
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
        unpublish: unpublished.add,
      );

      await adapter.attach(registry);
      expect(published, isEmpty);

      registry.register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'late',
            description: 'registered after attach',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{'type': 'object'},
          ),
          execute: (_) async => AgentResult.success(
            data: const <String, Object?>{'text': 'late'},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(published, contains('app_late'));

      final out = await published['app_late']!(const <String, Object?>{});
      expect(out['ok'], isTrue);
      expect(out['text'], 'late');

      registry.unregister('app_late');
      await Future<void>.delayed(Duration.zero);
      expect(unpublished, contains('app_late'));

      await adapter.detach();
    },
  );
}
