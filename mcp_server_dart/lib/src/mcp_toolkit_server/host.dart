// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: public_member_api_docs
import 'dart:async';

import 'package:dart_mcp/server.dart' as dart_mcp;
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

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

/// Bundle of publish + unpublish hooks. Either both must be provided or
/// neither — passing only one defeats rollback.
final class DartMcpDispatchBridge {
  const DartMcpDispatchBridge({required this.publish, required this.unpublish});
  final DartMcpToolPublisher publish;
  final DartMcpToolUnpublisher unpublish;
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
       _bridge = dispatchBridge;

  final Map<Type, HostService> _services;
  final CapabilityConfig _config;
  final DartMcpDispatchBridge? _bridge;
  final Map<String, _LoadedCapability> _capabilities =
      <String, _LoadedCapability>{};
  final Map<String, _RegisteredTool> _tools = <String, _RegisteredTool>{};

  Iterable<String> get toolNames => _tools.keys;

  Future<void> registerCapability(final Capability capability) async {
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
      // Roll back any tools registered before the throw, including from
      // dart_mcp dispatch (so partial publication can't survive the failure).
      final unpublish = _bridge?.unpublish;
      _tools.removeWhere((final fullName, _) {
        if (!fullName.startsWith(prefix)) return false;
        if (unpublish != null) unpublish(fullName);
        return true;
      });
      rethrow;
    } finally {
      ctx.sealed = true;
    }
    // Commit on success only.
    _capabilities[capability.id] = _LoadedCapability(capability);
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
    final bridge = _bridge;
    if (bridge != null) {
      bridge.publish(
        dart_mcp.Tool(
          name: fullName,
          description: registration.description,
          inputSchema: dart_mcp.ObjectSchema.fromMap(registration.inputSchema),
        ),
        registration.handler,
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
    final unpublish = _bridge?.unpublish;
    if (unpublish != null) {
      _tools.keys.forEach(unpublish);
    }
    _tools.clear();
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
    // T8 wires resource dispatch; until then, this always throws after the
    // seal check, intentionally — capabilities should not register resources
    // in this PR's snapshot.
    throw UnimplementedError(
      'registerResource not yet wired (tracked for T8).',
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
