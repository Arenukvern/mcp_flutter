// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses, lines_longer_than_80_chars

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/core_dynamic_registry_gateway.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/server.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/error_codes.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_override.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:meta/meta.dart';

/// Mixin that integrates dynamic registry with MCP server infrastructure
/// Provides seamless handling of both static and dynamic tools/resources
/// Works by wrapping the standard MCP tool/resource registration system
base mixin DynamicRegistryIntegration on BaseMCPToolkitServer {
  @protected
  DynamicRegistry? _dynamicRegistry;

  @protected
  DynamicRegistryTools? _dynamicRegistryTools;
  RegistryDiscoveryService? discoveryService;

  /// Check if dynamic registry is enabled
  @protected
  bool get isDynamicRegistrySupported => configuration.dynamicRegistrySupported;
  StreamSubscription? _subscription;

  /// Initialize the dynamic registry integration
  @protected
  void initializeDynamicRegistry({
    required final MCPToolkitServer mcpToolkitServer,
  }) {
    final registry = _dynamicRegistry = DynamicRegistry(
      server: mcpToolkitServer,
    );
    _dynamicRegistryTools = DynamicRegistryTools(
      registry: registry,
      server: mcpToolkitServer,
    );
    mcpToolkitServer.attachDynamicGateway(
      RegistryBackedDynamicGateway(
        registry: registry,
        agentRegistry: mcpToolkitServer.capabilityHost.agentRegistry,
        discoveryService: () => discoveryService,
      ),
    );

    log(
      LoggingLevel.info,
      'Dynamic registry integration initialized',
      logger: 'DynamicRegistryIntegration',
    );

    // Listen to registry events for debugging/monitoring
    _subscription = registry.events.listen(_logRegistryEvent);
  }

  /// Start registry discovery that immediately registers and listens for changes
  Future<void> startRegistryDiscovery({
    required final MCPToolkitServer mcpToolkitServer,
  }) async {
    final registry = _dynamicRegistry;
    if (registry == null) return;

    discoveryService = RegistryDiscoveryService(
      dynamicRegistry: registry,
      server: mcpToolkitServer,
    );

    try {
      await mcpToolkitServer.ensureVMServiceConnected();

      await discoveryService?.startDiscovery();

      // Immediate registration when connected
      // will fail if VM service is not connected
      await discoveryService?.registerToolsAndResources();

      log(
        LoggingLevel.info,
        'Flutter app discovery started successfully',
        logger: 'DynamicRegistryIntegration',
      );
    } catch (e, s) {
      log(
        LoggingLevel.warning,
        'Failed to start discovery: $e',
        logger: 'DynamicRegistryIntegration',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
    }

    // Set up reconnection callback AFTER initial attempt (success or failure).
    // This ensures callback only fires on REconnection, not initial connection.
    mcpToolkitServer.onVMServiceReconnected = () {
      log(
        LoggingLevel.info,
        'VM service reconnected, re-initializing registry discovery...',
        logger: 'DynamicRegistryIntegration',
      );
      unawaited(_reinitializeDiscovery(mcpToolkitServer));
    };
  }

  /// Re-initialize discovery after VM service reconnection
  Future<void> _reinitializeDiscovery(
    final MCPToolkitServer mcpToolkitServer,
  ) async {
    try {
      // Dispose old discovery service
      await discoveryService?.dispose();

      // Create new discovery service
      final registry = _dynamicRegistry;
      if (registry == null) return;

      discoveryService = RegistryDiscoveryService(
        dynamicRegistry: registry,
        server: mcpToolkitServer,
      );

      await discoveryService?.startDiscovery();
      await discoveryService?.registerToolsAndResources();

      log(
        LoggingLevel.info,
        'Registry discovery re-initialized successfully after reconnection',
        logger: 'DynamicRegistryIntegration',
      );
    } catch (e, s) {
      log(
        LoggingLevel.warning,
        'Failed to re-initialize discovery after reconnection: $e',
        logger: 'DynamicRegistryIntegration',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
    }
  }

  /// Override initialize to register dynamic registry management tools
  @override
  FutureOr<InitializeResult> initialize(final InitializeRequest request) {
    if (isDynamicRegistrySupported) {
      final mcpToolkitServer = this as MCPToolkitServer;
      // Initialize the dynamic registry first
      initializeDynamicRegistry(mcpToolkitServer: mcpToolkitServer);

      // Register the dynamic registry management tools using standard MCP approach
      _registerDynamicRegistryTools();
    }

    return super.initialize(request);
  }

  /// Dispose dynamic registry resources
  @protected
  Future<void> disposeDynamicRegistry() async {
    await _subscription?.cancel();
    await _dynamicRegistry?.dispose();
    final server = this;
    if (server case final MCPToolkitServer toolkitServer) {
      toolkitServer.attachDynamicGateway(null);
    }
    log(
      LoggingLevel.info,
      'Dynamic registry disposed',
      logger: 'DynamicRegistryIntegration',
    );
    await discoveryService?.dispose();
  }

  /// Register the dynamic registry management tools
  void _registerDynamicRegistryTools() {
    final registryTools = _dynamicRegistryTools;
    if (registryTools == null) return;

    for (final MapEntry(key: tool, value: handler)
        in registryTools.allTools.entries) {
      try {
        // it should register the tool and send a notification when the
        // tool is registered. However most client doesn't support it yet.
        //
        // https://github.com/orgs/modelcontextprotocol/discussions/76
        registerTool(tool, handler);
      } catch (e, stackTrace) {
        log(
          LoggingLevel.warning,
          'Failed to register dynamic registry tool ${tool.name}: $e '
          'stackTrace: $stackTrace',
          logger: 'DynamicRegistryIntegration',
        );
      }
    }
  }

  /// Register a dynamic tool from a Flutter client
  /// This creates a wrapper that forwards calls to the dynamic registry
  void registerDynamicTool(
    final Tool tool,
    final String sourceApp, {
    final Map<String, dynamic> metadata = const {},
  }) {
    final registry = _dynamicRegistry;
    if (registry == null) return;

    if (!isDynamicRegistrySupported) {
      log(
        LoggingLevel.warning,
        'Attempted to register dynamic tool but registry is disabled',
        logger: 'DynamicRegistryIntegration',
      );
      return;
    }

    final appId = DynamicAppId(sourceApp);
    final toolkitServer = this as MCPToolkitServer;

    registry.registerTool(tool, appId);
    final entry = registry.getToolEntry(tool.name);
    if (entry != null) {
      toolkitServer.capabilityHost.agentRegistry.register(
        _wrapDynamicToolIntent(
          toolkitServer: toolkitServer,
          intent: entry.intent,
        ),
        qualifiedNameOverride: tool.name,
      );
    }

    log(
      LoggingLevel.info,
      'Registered dynamic tool via AgentRegistry: ${tool.name}',
      logger: 'DynamicRegistryIntegration',
    );
  }

  /// Register a dynamic resource from a Flutter client
  /// This creates a wrapper that forwards calls to the dynamic registry
  void registerDynamicResource(
    final Resource resource,
    final String sourceApp, {
    final Map<String, dynamic> metadata = const {},
    final Map<String, Object?>? inputSchema,
  }) {
    final registry = _dynamicRegistry;
    if (registry == null) return;

    if (!isDynamicRegistrySupported) {
      log(
        LoggingLevel.warning,
        'Attempted to register dynamic resource but registry is disabled',
        logger: 'DynamicRegistryIntegration',
      );
      return;
    }

    final appId = DynamicAppId(sourceApp);

    registry.registerResource(resource, appId, inputSchema: inputSchema);
    final toolkitServer = this as MCPToolkitServer;
    final resourceEntry = registry.getResourceEntry(resource.uri);
    if (resourceEntry != null) {
      toolkitServer.capabilityHost.agentRegistry.register(
        _wrapDynamicResourceIntent(
          toolkitServer: toolkitServer,
          intent: resourceEntry.intent,
          resourceUri: resource.uri,
        ),
        qualifiedNameOverride: resource.uri,
      );
    }

    log(
      LoggingLevel.info,
      'Registered dynamic resource via AgentRegistry: ${resource.uri}',
      logger: 'DynamicRegistryIntegration',
    );
  }

  /// Unregister all tools and resources from a Flutter client
  void unregisterDynamicApp(final String sourceApp) {
    if (!isDynamicRegistrySupported) return;

    final registry = _dynamicRegistry;
    if (registry == null) return;

    final hadContent = registry.getAppEntries();
    final toolkitServer = this as MCPToolkitServer;

    for (final entry in hadContent.tools) {
      try {
        toolkitServer.capabilityHost.agentRegistry.unregister(entry.tool.name);
      } catch (e, stackTrace) {
        log(
          LoggingLevel.warning,
          'Failed to unregister dynamic tool ${entry.tool.name}: $e '
          'stackTrace: $stackTrace',
          logger: 'DynamicRegistryIntegration',
        );
      }
    }

    for (final entry in hadContent.resources) {
      try {
        toolkitServer.capabilityHost.agentRegistry.unregister(
          entry.resource.uri,
        );
      } catch (e, stackTrace) {
        log(
          LoggingLevel.warning,
          'Failed to unregister dynamic resource ${entry.resource.uri}: $e '
          'stackTrace: $stackTrace',
          logger: 'DynamicRegistryIntegration',
        );
      }
    }

    // Then unregister from dynamic registry
    registry.unregisterApp();
  }

  /// Get dynamic registry statistics
  @protected
  DynamicAppInfo? getDynamicRegistryStats() {
    if (!isDynamicRegistrySupported) return null;
    final registry = _dynamicRegistry;
    if (registry == null) return null;
    return registry.appInfo;
  }

  /// Get the dynamic registry instance (for advanced usage)
  @protected
  DynamicRegistry? get dynamicRegistry =>
      isDynamicRegistrySupported ? _dynamicRegistry : null;

  /// Test-only access to the dynamic registry instance.
  @visibleForTesting
  DynamicRegistry? get dynamicRegistryForTesting =>
      isDynamicRegistrySupported ? _dynamicRegistry : null;

  RegisteredAgentIntent _wrapDynamicToolIntent({
    required final MCPToolkitServer toolkitServer,
    required final RegisteredAgentIntent intent,
  }) => RegisteredAgentIntent(
    descriptor: intent.descriptor,
    execute: (final invocation) async {
      final ensure = await toolkitServer.connectionContext
          .ensureConnectedWithPolicy();
      if (!ensure.connected) {
        return AgentResult.failure(
          code: ensure.code ?? CoreErrorCode.vmNotConnected,
          message: ensure.message ?? 'VM service not connected',
          details: _agentFailureDetails(ensure.details),
        );
      }
      return intent.execute(invocation);
    },
  );

  RegisteredAgentIntent _wrapDynamicResourceIntent({
    required final MCPToolkitServer toolkitServer,
    required final RegisteredAgentIntent intent,
    required final String resourceUri,
  }) => RegisteredAgentIntent(
    descriptor: intent.descriptor,
    execute: (final invocation) async {
      final requestedUri =
          invocation.arguments['uri'] as String? ?? resourceUri;
      final connectError = await applyConnectionOverrideFromResourceUri(
        resourceUri: requestedUri,
        executor: toolkitServer.coreCommandExecutor,
      );
      if (connectError != null) {
        final err = connectError.error!;
        return AgentResult.failure(
          code: err.code,
          message: err.message,
          details: _agentFailureDetails(err.details),
        );
      }

      final ensure = await toolkitServer.connectionContext
          .ensureConnectedWithPolicy();
      if (!ensure.connected) {
        return AgentResult.failure(
          code: ensure.code ?? CoreErrorCode.vmNotConnected,
          message: ensure.message ?? 'VM service not connected',
          details: _agentFailureDetails(ensure.details),
        );
      }
      return intent.execute(invocation);
    },
  );

  void _logRegistryEvent(final DynamicRegistryEvent event) {
    switch (event) {
      case ToolRegisteredEvent(:final entry):
        log(
          LoggingLevel.debug,
          'Dynamic tool registered: ${entry.tool.name}',
          logger: 'DynamicRegistryIntegration',
        );

      case ToolUnregisteredEvent(:final toolName, :final appId):
        log(
          LoggingLevel.debug,
          'Dynamic tool unregistered: $toolName from $appId',
          logger: 'DynamicRegistryIntegration',
        );

      case ResourceRegisteredEvent(:final entry):
        log(
          LoggingLevel.debug,
          'Dynamic resource registered: ${entry.resource.uri}',
          logger: 'DynamicRegistryIntegration',
        );

      case ResourceUnregisteredEvent(:final resourceUri, :final appId):
        log(
          LoggingLevel.debug,
          'Dynamic resource unregistered: $resourceUri from $appId',
          logger: 'DynamicRegistryIntegration',
        );

      case AppUnregisteredEvent(
        :final appId,
        :final toolsRemoved,
        :final resourcesRemoved,
      ):
        log(
          LoggingLevel.info,
          'Dynamic app unregistered: $appId ($toolsRemoved tools, $resourcesRemoved resources)',
          logger: 'DynamicRegistryIntegration',
        );
    }
  }
}

Map<String, Object?> _agentFailureDetails(final Object? raw) {
  if (raw is Map<String, Object?>) {
    return raw;
  }
  if (raw is Map) {
    return Map<String, Object?>.from(raw);
  }
  if (raw == null) {
    return const {};
  }
  return {'detail': raw};
}
