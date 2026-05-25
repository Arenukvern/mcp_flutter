import 'dart:async';

import 'package:agentkit_core/agentkit_core.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';

import 'agent_bridge.dart';
import 'mcp_resource_mapper.dart';
import 'mcp_result_mapper.dart';

typedef McpToolPublisher =
    void Function(
      Tool tool,
      FutureOr<CallToolResult> Function(CallToolRequest request) impl,
    );

typedef McpToolUnpublisher = void Function(String name);

typedef McpResourcePublisher =
    void Function(
      Resource resource,
      FutureOr<ReadResourceResult> Function(ReadResourceRequest request) impl,
    );

typedef McpResourceUnpublisher = void Function(String uri);

/// Publishes registry-backed tools and resources to dart_mcp.
final class McpPublishAdapter implements AgentAdapter {
  McpPublishAdapter({
    required this.publishTool,
    required this.unpublishTool,
    this.publishResource,
    this.unpublishResource,
  });

  final McpToolPublisher publishTool;
  final McpToolUnpublisher unpublishTool;
  final McpResourcePublisher? publishResource;
  final McpResourceUnpublisher? unpublishResource;

  final Set<String> _publishedTools = <String>{};
  final Set<String> _publishedResources = <String>{};
  StreamSubscription<AgentRegistryEvent>? _events;
  AgentRegistry? _registry;

  @override
  String get id => 'mcp';

  @override
  bool get watchesRegistry => true;

  @override
  Future<void> attach(final AgentRegistry registry) async {
    _registry = registry;
    for (final descriptor in registry.listDescriptors()) {
      _syncDescriptor(registry, descriptor);
    }
    _events = registry.events.listen((final event) {
      final reg = _registry;
      if (reg == null) return;
      switch (event) {
        case IntentRegistered(:final qualifiedName):
          final intent = reg.get(qualifiedName);
          if (intent != null) {
            _syncDescriptor(reg, intent.descriptor, registryKey: qualifiedName);
          }
        case IntentUnregistered(:final qualifiedName):
          _unpublishKey(qualifiedName, reg);
      }
    });
  }

  @override
  Future<void> detach() async {
    await _events?.cancel();
    _events = null;
    final registry = _registry;
    if (registry != null) {
      unpublishAll(registry: registry);
    }
    _registry = null;
  }

  void publishCapabilityTool({
    required final AgentRegistry registry,
    required final String capabilityId,
    required final ToolRegistration registration,
    required final String fullName,
  }) {
    registry.register(
      toolRegistrationToRegistration(
        capabilityId: capabilityId,
        registration: registration,
      ),
      qualifiedNameOverride: fullName,
    );
    _publishToolIntent(
      registry: registry,
      key: fullName,
      descriptor: AgentIntentDescriptor(
        namespace: capabilityId,
        name: registration.name,
        description: registration.description,
        kind: AgentIntentKind.tool,
        inputSchema: registration.inputSchema,
      ),
    );
  }

  void publishCapabilityResource({
    required final AgentRegistry registry,
    required final String capabilityId,
    required final ResourceRegistration registration,
  }) {
    registry.register(
      resourceRegistrationToRegistration(
        capabilityId: capabilityId,
        registration: registration,
      ),
      qualifiedNameOverride: registration.uri,
    );
    _publishResourceIntent(
      registry: registry,
      key: registration.uri,
      registration: registration,
      descriptor: null,
    );
  }

  void unpublishRegistryTool({
    required final AgentRegistry registry,
    required final String fullName,
  }) {
    _unpublishKey(fullName, registry);
  }

  void unpublishRegistryResource({
    required final AgentRegistry registry,
    required final String uri,
  }) {
    _unpublishKey(uri, registry);
  }

  void unpublishAll({required final AgentRegistry registry}) {
    for (final name in _publishedTools.toList()) {
      unpublishRegistryTool(registry: registry, fullName: name);
    }
    for (final uri in _publishedResources.toList()) {
      unpublishRegistryResource(registry: registry, uri: uri);
    }
  }

  void _syncDescriptor(
    final AgentRegistry registry,
    final AgentIntentDescriptor descriptor, {
    final String? registryKey,
  }) {
    final key = registryKey ?? descriptor.qualifiedName;
    if (descriptor.kind == AgentIntentKind.tool) {
      if (_publishedTools.contains(key)) return;
      _publishToolIntent(registry: registry, key: key, descriptor: descriptor);
    } else if (publishResource != null) {
      if (_publishedResources.contains(key)) return;
      _publishResourceIntent(
        registry: registry,
        key: key,
        descriptor: descriptor,
      );
    }
  }

  void _publishToolIntent({
    required final AgentRegistry registry,
    required final String key,
    required final AgentIntentDescriptor descriptor,
  }) {
    publishTool(
      Tool(
        name: key,
        description: descriptor.description,
        inputSchema: ObjectSchema.fromMap(descriptor.inputSchema),
      ),
      (final request) async => agentResultToMcpResult(
        await registry.invoke(
          key,
          request.arguments ?? const <String, Object?>{},
        ),
      ),
    );
    _publishedTools.add(key);
  }

  void _publishResourceIntent({
    required final AgentRegistry registry,
    required final String key,
    ResourceRegistration? registration,
    AgentIntentDescriptor? descriptor,
  }) {
    final publish = publishResource;
    if (publish == null) return;
    final d =
        descriptor ??
        AgentIntentDescriptor(
          namespace: 'resource',
          name: registration!.name,
          description: registration.description,
          kind: AgentIntentKind.resource,
          inputSchema: const <String, Object?>{'type': 'object'},
          resourceUri: registration.uri,
          mimeType: registration.mimeType,
        );
    publish(
      Resource(
        uri: registration?.uri ?? d.effectiveResourceUri,
        name: registration?.name ?? d.name,
        description: registration?.description ?? d.description,
        mimeType: registration?.mimeType ?? d.mimeType ?? 'application/json',
      ),
      (final request) async => agentResultToReadResourceResult(
        await registry.invoke(
          key,
          <String, Object?>{'uri': request.uri},
        ),
        uri: request.uri,
      ),
    );
    _publishedResources.add(key);
  }

  void _unpublishKey(final String key, final AgentRegistry registry) {
    registry.unregister(key);
    if (_publishedTools.remove(key)) {
      unpublishTool(key);
    }
    if (_publishedResources.remove(key)) {
      unpublishResource?.call(key);
    }
  }

}
