// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: public_member_api_docs
import 'dart:async';

import 'package:dart_mcp/server.dart' as dart_mcp;
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_mcp/intentcall_mcp.dart';

/// Bridge contract used by [McpHost] to publish prefixed capability tools to
/// `dart_mcp`'s [dart_mcp.ToolsSupport]. Production wiring passes the
/// [MCPToolkitServer] itself; tests can pass a fake.
typedef DartMcpToolPublisher =
    void Function(
      dart_mcp.Tool tool,
      FutureOr<dart_mcp.CallToolResult> Function(dart_mcp.CallToolRequest) impl,
    );

/// Counterpart to [DartMcpToolPublisher] used by [McpHost] to roll back
/// publications when a capability's [Capability.register] throws partway.
typedef DartMcpToolUnpublisher = void Function(String name);

typedef DartMcpResourcePublisher =
    void Function(
      dart_mcp.Resource resource,
      FutureOr<dart_mcp.ReadResourceResult> Function(
        dart_mcp.ReadResourceRequest request,
      )
      impl,
    );

typedef DartMcpResourceUnpublisher = void Function(String uri);

typedef DartMcpResourceTemplatePublisher =
    void Function(
      dart_mcp.ResourceTemplate template,
      FutureOr<dart_mcp.ReadResourceResult?> Function(
        dart_mcp.ReadResourceRequest request,
      )
      impl,
    );

/// Bundle of publish + unpublish hooks. Either both must be provided or
/// neither — passing only one defeats rollback.
final class DartMcpDispatchBridge {
  const DartMcpDispatchBridge({
    required this.publish,
    required this.unpublish,
    this.publishResource,
    this.unpublishResource,
    this.publishResourceTemplate,
  });
  final DartMcpToolPublisher publish;
  final DartMcpToolUnpublisher unpublish;
  final DartMcpResourcePublisher? publishResource;
  final DartMcpResourceUnpublisher? unpublishResource;
  final DartMcpResourceTemplatePublisher? publishResourceTemplate;
}

/// Per-host registry of loaded [Capability] instances and the tools/resources
/// they registered.
final class McpHost {
  McpHost({
    final Map<Type, HostService>? services,
    final CapabilityConfig? config,
    final DartMcpDispatchBridge? dispatchBridge,
  }) : _services = services ?? const <Type, HostService>{},
       _config = config ?? const CapabilityConfig(),
       agentRegistry = InMemoryAgentRegistry() {
    if (dispatchBridge != null) {
      _mcpPublish = McpPublishAdapter(
        publishTool: dispatchBridge.publish,
        unpublishTool: dispatchBridge.unpublish,
        publishResource: dispatchBridge.publishResource,
        unpublishResource: dispatchBridge.unpublishResource,
        publishResourceTemplate: dispatchBridge.publishResourceTemplate,
      );
      _runtime = AgentRuntime(
        registry: agentRegistry,
        adapters: <AgentAdapter>[_mcpPublish!],
      );
      _runtimeReady = _runtime!.start();
    }
  }

  final Map<Type, HostService> _services;
  final CapabilityConfig _config;
  McpPublishAdapter? _mcpPublish;
  AgentRuntime? _runtime;
  Future<void>? _runtimeReady;
  final AgentRegistry agentRegistry;
  final Map<String, _LoadedCapability> _capabilities =
      <String, _LoadedCapability>{};
  final Map<String, _RegisteredTool> _tools = <String, _RegisteredTool>{};
  final Map<String, _RegisteredResource> _resources =
      <String, _RegisteredResource>{};
  final Map<String, _RegisteredResourceTemplate> _resourceTemplates =
      <String, _RegisteredResourceTemplate>{};

  Iterable<String> get toolNames => _tools.keys;
  Iterable<String> get resourceUris => _resources.keys;
  Iterable<String> get resourceTemplateUris => _resourceTemplates.keys;

  Future<void> _ensureRuntimeStarted() async {
    await (_runtimeReady ?? Future<void>.value());
  }

  Future<void> registerCapability(final Capability capability) async {
    await _ensureRuntimeStarted();
    validateCapabilityId(capability.id);
    if (_capabilities.containsKey(capability.id)) {
      throw CapabilityAlreadyRegisteredError(
        'Capability id "${capability.id}" already registered.',
      );
    }

    final ctx = _HostCapabilityContext(host: this, capability: capability);
    final prefix = '${capability.id}_';
    try {
      await capability.register(ctx);
    } on Object catch (_) {
      final publish = _mcpPublish;
      _tools.removeWhere((final fullName, _) {
        if (!fullName.startsWith(prefix)) return false;
        publish?.unpublishRegistryTool(
          registry: agentRegistry,
          fullName: fullName,
        );
        return true;
      });
      _resources.removeWhere((final uri, _) {
        publish?.unpublishRegistryResource(registry: agentRegistry, uri: uri);
        return true;
      });
      _resourceTemplates.removeWhere((final uriTemplate, _) {
        publish?.unpublishRegistryResourceTemplate(
          registry: agentRegistry,
          uriTemplate: uriTemplate,
        );
        return true;
      });
      rethrow;
    } finally {
      ctx.sealed = true;
    }
    _capabilities[capability.id] = _LoadedCapability(capability);
  }

  /// Publish a static resource (e.g. Flutter Inspector `visual://` surface).
  Future<void> registerPublishedResource({
    required final String capabilityId,
    required final ResourceRegistration registration,
  }) async {
    await _ensureRuntimeStarted();
    _registerResource(capabilityId: capabilityId, registration: registration);
  }

  /// Publish a parameterized resource template via [AgentRegistry].
  Future<void> registerPublishedResourceTemplate({
    required final String capabilityId,
    required final ResourceTemplateRegistration registration,
  }) async {
    await _ensureRuntimeStarted();
    _registerResourceTemplate(
      capabilityId: capabilityId,
      registration: registration,
    );
  }

  void _registerTool({
    required final String capabilityId,
    required final ToolRegistration registration,
  }) {
    validateBareToolName(capabilityId: capabilityId, name: registration.name);
    final fullName = applyPrefix(
      capabilityId: capabilityId,
      name: registration.name,
    );
    if (_tools.containsKey(fullName)) {
      throw ToolNameCollisionError('Tool "$fullName" registered twice.');
    }
    _tools[fullName] = _RegisteredTool(
      capabilityId: capabilityId,
      registration: registration,
    );
    _mcpPublish?.publishCapabilityTool(
      registry: agentRegistry,
      capabilityId: capabilityId,
      registration: registration,
      fullName: fullName,
    );
    if (_mcpPublish == null) {
      agentRegistry.register(
        toolRegistrationToRegistration(
          capabilityId: capabilityId,
          registration: registration,
        ),
        qualifiedNameOverride: fullName,
      );
    }
  }

  void _registerResource({
    required final String capabilityId,
    required final ResourceRegistration registration,
  }) {
    if (_resources.containsKey(registration.uri)) {
      throw StateError('Resource "${registration.uri}" registered twice.');
    }
    _resources[registration.uri] = _RegisteredResource(
      capabilityId: capabilityId,
      registration: registration,
    );
    _mcpPublish?.publishCapabilityResource(
      registry: agentRegistry,
      capabilityId: capabilityId,
      registration: registration,
    );
    if (_mcpPublish == null) {
      agentRegistry.register(
        resourceRegistrationToRegistration(
          capabilityId: capabilityId,
          registration: registration,
        ),
        qualifiedNameOverride: registration.uri,
      );
    }
  }

  void _registerResourceTemplate({
    required final String capabilityId,
    required final ResourceTemplateRegistration registration,
  }) {
    if (_resourceTemplates.containsKey(registration.uriTemplate)) {
      throw StateError(
        'Resource template "${registration.uriTemplate}" registered twice.',
      );
    }
    _resourceTemplates[registration.uriTemplate] = _RegisteredResourceTemplate(
      capabilityId: capabilityId,
      registration: registration,
    );
    _mcpPublish?.publishCapabilityResourceTemplate(
      registry: agentRegistry,
      capabilityId: capabilityId,
      registration: registration,
    );
    if (_mcpPublish == null) {
      agentRegistry.register(
        resourceTemplateRegistrationToRegistration(
          capabilityId: capabilityId,
          registration: registration,
        ),
        qualifiedNameOverride: registration.uriTemplate,
      );
    }
  }

  T _require<T extends HostService>() {
    final service = _services[T];
    if (service == null) {
      throw HostServiceUnavailableError(
        'Host service of type $T was not provided.',
      );
    }
    return service as T;
  }

  Future<void> dispose() async {
    final errors = <Object>[];
    for (final loaded in _capabilities.values) {
      try {
        await loaded.capability.dispose();
      } on Object catch (e) {
        errors.add(e);
      }
    }
    _capabilities.clear();
    await _runtime?.stop();
    _tools.clear();
    _resources.clear();
    _resourceTemplates.clear();
    if (errors.isNotEmpty) {
      throw StateError(
        'One or more capabilities threw during dispose: $errors',
      );
    }
  }
}

final class _LoadedCapability {
  _LoadedCapability(this.capability);
  final Capability capability;
}

final class _RegisteredTool {
  _RegisteredTool({required this.capabilityId, required this.registration});
  final String capabilityId;
  final ToolRegistration registration;
}

final class _RegisteredResource {
  _RegisteredResource({required this.capabilityId, required this.registration});
  final String capabilityId;
  final ResourceRegistration registration;
}

final class _RegisteredResourceTemplate {
  _RegisteredResourceTemplate({
    required this.capabilityId,
    required this.registration,
  });
  final String capabilityId;
  final ResourceTemplateRegistration registration;
}

final class _HostCapabilityContext implements CapabilityContext {
  _HostCapabilityContext({required this.host, required this.capability});

  final McpHost host;
  final Capability capability;
  bool sealed = false;

  @override
  String get capabilityId => capability.id;

  @override
  CapabilityConfig get config => host._config;

  @override
  void registerTool(final ToolRegistration registration) {
    _ensureNotSealed();
    host._registerTool(capabilityId: capability.id, registration: registration);
  }

  @override
  void registerResource(final ResourceRegistration registration) {
    _ensureNotSealed();
    host._registerResource(
      capabilityId: capability.id,
      registration: registration,
    );
  }

  @override
  T require<T extends HostService>() => host._require<T>();

  @override
  void log(final String message, {final LogLevel level = LogLevel.info}) {
    // ignore: avoid_print
    print('[${capability.id}] $message');
  }

  void _ensureNotSealed() {
    if (sealed) {
      throw StateError(
        'CapabilityContext for "${capability.id}" used after register() '
        'returned. Capabilities must register synchronously.',
      );
    }
  }
}
