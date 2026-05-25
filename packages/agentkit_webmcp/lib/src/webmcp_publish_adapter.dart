import 'package:agentkit_core/agentkit_core.dart';

/// Callback surface matching `navigator.modelContext` tool registration.
typedef WebMcpToolPublisher =
    void Function({
      required String name,
      required String description,
      required Map<String, Object?> inputSchema,
      required Future<Map<String, Object?>> Function(
        Map<String, Object?> arguments,
      )
      execute,
    });

typedef WebMcpToolUnpublisher = void Function(String name);

/// Publishes registry tool intents to a WebMCP-compatible surface.
///
/// In the browser, wire [publish] to `navigator.modelContext.registerTool`.
/// On VM/test, use an in-memory fake (see tests).
final class WebMcpPublishAdapter implements AgentAdapter {
  WebMcpPublishAdapter({required this.publish, required this.unpublish});

  final WebMcpToolPublisher publish;
  final WebMcpToolUnpublisher unpublish;

  @override
  String get id => 'webmcp';

  @override
  bool get watchesRegistry => true;

  final List<String> _published = <String>[];

  @override
  Future<void> attach(final AgentRegistry registry) async {
    for (final descriptor in registry.listDescriptors()) {
      if (descriptor.kind == AgentIntentKind.tool) {
        _publishTool(registry, descriptor);
      }
    }
  }

  @override
  Future<void> detach() async {
    for (final name in _published.toList()) {
      unpublish(name);
    }
    _published.clear();
  }

  void _publishTool(
    final AgentRegistry registry,
    final AgentIntentDescriptor descriptor,
  ) {
    final name = descriptor.qualifiedName;
    publish(
      name: name,
      description: descriptor.description,
      inputSchema: descriptor.inputSchema,
      execute: (final arguments) async {
        final result = await registry.invoke(name, arguments);
        if (!result.ok) {
          return <String, Object?>{
            'ok': false,
            'code': result.code,
            'message': result.message,
            'details': result.details,
          };
        }
        return <String, Object?>{'ok': true, ...result.data};
      },
    );
    _published.add(name);
  }
}
