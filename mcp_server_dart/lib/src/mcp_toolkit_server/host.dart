// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: public_member_api_docs
import 'dart:async';

import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

/// Per-host registry of loaded [Capability] instances and the tools/resources
/// they registered.
final class McpHost {
  McpHost({final Map<Type, HostService>? services})
    : _services = services ?? const <Type, HostService>{};

  final Map<Type, HostService> _services;
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

    final loaded = _LoadedCapability(capability);
    _capabilities[capability.id] = loaded;

    final ctx = _HostCapabilityContext(host: this, capability: capability);
    try {
      await capability.register(ctx);
    } finally {
      ctx.sealed = true;
    }
  }

  void _registerTool({
    required final String capabilityId,
    required final ToolRegistration registration,
  }) {
    validateBareToolName(
      capabilityId: capabilityId,
      name: registration.name,
    );
    final fullName = applyPrefix(
      capabilityId: capabilityId,
      name: registration.name,
    );
    if (_tools.containsKey(fullName)) {
      throw ToolNameCollisionError(
        'Tool "$fullName" registered twice.',
      );
    }
    _tools[fullName] = _RegisteredTool(
      capabilityId: capabilityId,
      registration: registration,
    );
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
    for (final loaded in _capabilities.values) {
      await loaded.capability.dispose();
    }
    _capabilities.clear();
    _tools.clear();
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
  CapabilityConfig get config => const CapabilityConfig();

  @override
  void registerTool(final ToolRegistration registration) {
    _ensureNotSealed();
    host._registerTool(
      capabilityId: capability.id,
      registration: registration,
    );
  }

  @override
  void registerResource(final ResourceRegistration registration) {
    _ensureNotSealed();
    throw UnimplementedError('registerResource not yet wired (tracked for T8).');
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
