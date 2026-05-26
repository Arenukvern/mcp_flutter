import 'dart:async';

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
  StreamSubscription<AgentRegistryEvent>? _events;
  AgentRegistry? _registry;

  @override
  Future<void> attach(final AgentRegistry registry) async {
    _registry = registry;
    for (final descriptor in registry.listDescriptors()) {
      if (descriptor.kind == AgentIntentKind.tool) {
        _publishTool(registry, descriptor);
      }
    }
    _events = registry.events.listen((final event) {
      final reg = _registry;
      if (reg == null) return;
      switch (event) {
        case IntentRegistered(:final qualifiedName):
          final intent = reg.get(qualifiedName);
          if (intent != null &&
              intent.descriptor.kind == AgentIntentKind.tool) {
            _publishTool(reg, intent.descriptor);
          }
        case IntentUnregistered(:final qualifiedName):
          _unpublish(qualifiedName);
      }
    });
  }

  @override
  Future<void> detach() async {
    await _events?.cancel();
    _events = null;
    _published.toList().forEach(_unpublish);
    _registry = null;
  }

  void _publishTool(
    final AgentRegistry registry,
    final AgentIntentDescriptor descriptor,
  ) {
    final name = descriptor.qualifiedName;
    if (_published.contains(name)) return;
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

  void _unpublish(final String name) {
    if (!_published.remove(name)) return;
    unpublish(name);
  }
}
