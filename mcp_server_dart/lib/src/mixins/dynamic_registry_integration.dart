// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_inspector_mcp_server/src/dynamic_registry/dynamic_registry_tools.dart';
import 'package:flutter_inspector_mcp_server/src/dynamic_registry/registry_discovery_service.dart';
import 'package:flutter_inspector_mcp_server/src/server.dart';
import 'package:meta/meta.dart';

/// Mixin that integrates dynamic registry with MCP server infrastructure
/// Provides seamless handling of both static and dynamic tools/resources
/// Works by wrapping the standard MCP tool/resource registration system
base mixin DynamicRegistryIntegration on BaseMCPToolkitServer {
  @protected
  late final DynamicRegistry _dynamicRegistry;

  @protected
  late final DynamicRegistryTools _dynamicRegistryTools;

  /// Check if dynamic registry is enabled
  @protected
  bool get isDynamicRegistrySupported => configuration.dynamicRegistrySupported;

  /// Initialize the dynamic registry integration
  @protected
  void initializeDynamicRegistry({
    required final MCPToolkitServer mcpToolkitServer,
  }) {
    _dynamicRegistry = DynamicRegistry(server: mcpToolkitServer);
    _dynamicRegistryTools = DynamicRegistryTools(registry: _dynamicRegistry);

    log(
      LoggingLevel.info,
      'Dynamic registry integration initialized',
      logger: 'DynamicRegistryIntegration',
    );

    // Listen to registry events for debugging/monitoring
    _dynamicRegistry.events.listen(_logRegistryEvent);
  }

  late RegistryDiscoveryService _discoveryService;

  /// Start registry discovery that immediately registers and listens for changes
  Future<void> startRegistryDiscovery({
    required final MCPToolkitServer mcpToolkitServer,
  }) async {
    _discoveryService = RegistryDiscoveryService(
      dynamicRegistry: _dynamicRegistry,
      server: mcpToolkitServer,
    );

    try {
      await _discoveryService.startDiscovery();

      log(
        LoggingLevel.info,
        'Simplified Flutter app discovery started successfully',
        logger: 'VMService',
      );
    } on Exception catch (e, s) {
      log(
        LoggingLevel.warning,
        'Failed to start simplified discovery: $e',
        logger: 'VMService',
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
  void disposeDynamicRegistry() {
    _dynamicRegistry.dispose();
    log(
      LoggingLevel.info,
      'Dynamic registry disposed',
      logger: 'DynamicRegistryIntegration',
    );
    _discoveryService.dispose();
  }

  /// Register the dynamic registry management tools
  void _registerDynamicRegistryTools() {
    for (final tool in DynamicRegistryTools.allTools) {
      try {
        if (this case final ToolsSupport toolsSupport) {
          toolsSupport.registerTool(
            tool,
            // ignore: unnecessary_async
            (final request) async => _dynamicRegistryTools.handleToolCall(
              request.name,
              request.arguments,
            ),
          );
        }
      } on Exception catch (e, stackTrace) {
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
  @protected
  void registerDynamicTool(
    final Tool tool,
    final String sourceApp, {
    final Map<String, dynamic> metadata = const {},
  }) {
    if (!isDynamicRegistrySupported) {
      log(
        LoggingLevel.warning,
        'Attempted to register dynamic tool but registry is disabled',
        logger: 'DynamicRegistryIntegration',
      );
      return;
    }

    final appId = DynamicAppId(sourceApp);

    // Register in the dynamic registry
    _dynamicRegistry.registerTool(tool, appId);

    // Register as a standard MCP tool that forwards to the dynamic registry
    if (this case final ToolsSupport toolsSupport) {
      try {
        toolsSupport.registerTool(
          tool,
          (final request) async =>
              await _dynamicRegistry.forwardToolCall(
                request.name,
                request.arguments,
              ) ??
              CallToolResult(
                content: [
                  TextContent(
                    text: 'Dynamic tool not available: ${request.name}',
                  ),
                ],
                isError: true,
              ),
        );

        log(
          LoggingLevel.info,
          'Registered dynamic tool as MCP tool: ${tool.name}',
          logger: 'DynamicRegistryIntegration',
        );
      } on Exception catch (e, stackTrace) {
        log(
          LoggingLevel.warning,
          'Failed to register dynamic tool ${tool.name} as MCP tool: $e '
          'stackTrace: $stackTrace',
          logger: 'DynamicRegistryIntegration',
        );
      }
    }
  }

  /// Register a dynamic resource from a Flutter client
  /// This creates a wrapper that forwards calls to the dynamic registry
  @protected
  void registerDynamicResource(
    final Resource resource,
    final String sourceApp, {
    final Map<String, dynamic> metadata = const {},
  }) {
    if (!isDynamicRegistrySupported) {
      log(
        LoggingLevel.warning,
        'Attempted to register dynamic resource but registry is disabled',
        logger: 'DynamicRegistryIntegration',
      );
      return;
    }

    final appId = DynamicAppId(sourceApp);

    // Register in the dynamic registry
    _dynamicRegistry.registerResource(resource, appId);

    // Register as a standard MCP resource that forwards to the dynamic registry
    if (this case final ResourcesSupport resourcesSupport) {
      try {
        resourcesSupport.addResource(resource, (final request) async {
          final content = await _dynamicRegistry.forwardResourceRead(
            request.uri,
          );
          if (content != null) return content;

          return ReadResourceResult(
            contents: [
              TextResourceContents(
                uri: request.uri,
                text: 'Dynamic resource not available: ${request.uri}',
              ),
            ],
          );
        });

        log(
          LoggingLevel.info,
          'Registered dynamic resource as MCP resource: ${resource.uri}',
          logger: 'DynamicRegistryIntegration',
        );
      } on Exception catch (e, stackTrace) {
        log(
          LoggingLevel.warning,
          'Failed to register dynamic resource ${resource.uri} as MCP resource: $e '
          'stackTrace: $stackTrace',
          logger: 'DynamicRegistryIntegration',
        );
      }
    }
  }

  /// Unregister all tools and resources from a Flutter client
  @protected
  void unregisterDynamicApp(final String sourceApp) {
    if (!isDynamicRegistrySupported) return;

    final hadContent = _dynamicRegistry.getAppEntries();

    // Unregister from MCP framework first
    if (this case final ToolsSupport toolsSupport) {
      for (final entry in hadContent.tools) {
        try {
          toolsSupport.unregisterTool(entry.tool.name);
        } on Exception catch (e, stackTrace) {
          log(
            LoggingLevel.warning,
            'Failed to unregister MCP tool ${entry.tool.name}: $e '
            'stackTrace: $stackTrace',
            logger: 'DynamicRegistryIntegration',
          );
        }
      }
    }

    if (this case final ResourcesSupport resourcesSupport) {
      for (final entry in hadContent.resources) {
        try {
          resourcesSupport.removeResource(entry.resource.uri);
        } on Exception catch (e, stackTrace) {
          log(
            LoggingLevel.warning,
            'Failed to unregister MCP resource ${entry.resource.uri}: $e '
            'stackTrace: $stackTrace',
            logger: 'DynamicRegistryIntegration',
          );
        }
      }
    }

    // Then unregister from dynamic registry
    if (hadContent.tools.isNotEmpty || hadContent.resources.isNotEmpty) {
      _dynamicRegistry.unregisterApp();
    }
  }

  /// Get dynamic registry statistics
  @protected
  DynamicAppInfo? getDynamicRegistryStats() {
    if (!isDynamicRegistrySupported) return null;
    return _dynamicRegistry.appInfo;
  }

  /// Get the dynamic registry instance (for advanced usage)
  @protected
  DynamicRegistry? get dynamicRegistry =>
      isDynamicRegistrySupported ? _dynamicRegistry : null;

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
