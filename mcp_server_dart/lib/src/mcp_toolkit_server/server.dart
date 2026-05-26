// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/core/default_command_runner.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/host.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/mixins/dynamic_registry_integration.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/mixins/flutter_inspector.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/mixins/vm_service_support.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/server_instructions.dart';
import 'package:flutter_mcp_toolkit_server/src/runtime_version.dart';
import 'package:stream_channel/stream_channel.dart';

// Keep this prompt concise; detailed troubleshooting and control workflows live
// in skill docs to avoid instruction drift and duplicated maintenance.
/// Flutter Inspector MCP Server
///
/// Provides tools and resources for Flutter app inspection and debugging
final class MCPToolkitServer extends BaseMCPToolkitServer
    with VMServiceSupport, DynamicRegistryIntegration, FlutterInspector {
  MCPToolkitServer.fromStreamChannel(
    super.channel, {
    required super.configuration,
  }) : super.fromStreamChannel(
         implementation: Implementation(
           name: kFlutterMcpServerImplementationName,
           version: kFlutterMcpVersion,
         ),
         instructions: buildMcpToolkitServerInstructions(configuration),
       ) {
    _host = McpHost(
      services: <Type, HostService>{
        CommandRunner: DefaultCommandRunner(executor: coreCommandExecutor),
      },
      config: CapabilityConfig(
        values: <String, Object?>{
          'dumps_supported': configuration.dumpsSupported,
          'resources_supported': configuration.resourcesSupported,
          'images_supported': configuration.imagesSupported,
        },
      ),
      dispatchBridge: DartMcpDispatchBridge(
        publish: registerTool,
        unpublish: unregisterTool,
        publishResource: addResource,
        unpublishResource: removeResource,
        publishResourceTemplate: addResourceTemplate,
      ),
    );
  }

  /// Create and connect a Flutter Inspector MCP Server
  factory MCPToolkitServer.connect(
    final StreamChannel<String> channel, {
    required final VMServiceConfigurationRecord configuration,
  }) =>
      MCPToolkitServer.fromStreamChannel(channel, configuration: configuration);

  /// The capability host registry. Always populated; capabilities are
  /// registered into it via [McpHost.registerCapability] (see [main]).
  McpHost get capabilityHost => _host;
  late final McpHost _host;

  @override
  FutureOr<InitializeResult> initialize(final InitializeRequest request) async {
    log(
      LoggingLevel.info,
      'Initializing Flutter Inspector MCP Server',
      logger: 'MCPToolkitServer',
    );

    // Call parent initialize first which will trigger the mixin's initialize
    // This registers tools and resources regardless of VM service connection
    final result = await super.initialize(request);

    log(
      LoggingLevel.debug,
      () => 'Server capabilities: ${result.capabilities}',
      logger: 'MCPToolkitServer',
    );

    // Try to initialize VM service connection (non-blocking)
    // This allows tools to be available even if no Flutter app is running
    try {
      if (configuration.awaitDndConnection) {
        await _initializeVMServiceAsync();
        log(
          LoggingLevel.info,
          'VM service connected successfully',
          logger: 'VMService',
        );
      } else {
        unawaited(_initializeVMServiceAsync());
        log(
          LoggingLevel.debug,
          'VM service initialization started in background',
          logger: 'VMService',
        );
      }
    } catch (e, s) {
      // Log but don't fail - tools should still be available
      log(
        LoggingLevel.warning,
        'VM service initialization failed (this is normal if no '
        'Flutter app is running): $e ',
        logger: 'VMService',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
    }

    // Start dynamic registry discovery if supported
    //
    // Warning! This may block the server from starting up
    // if --await-dynamics is set.
    //
    // This made is to fight current limitations of MCP Clients
    // which doesn't support tools updates.
    if (configuration.dynamicRegistrySupported) {
      if (configuration.awaitDndConnection) {
        await startRegistryDiscovery(mcpToolkitServer: this);
      } else {
        unawaited(
          Future<void>(() async {
            await startRegistryDiscovery(mcpToolkitServer: this);
          }),
        );
      }
    }

    log(
      LoggingLevel.info,
      'Flutter Inspector MCP Server initialized successfully',
      logger: 'MCPToolkitServer',
    );
    return result;
  }

  /// Initialize VM service connection asynchronously without blocking
  Future<void> _initializeVMServiceAsync() async {
    log(
      LoggingLevel.debug,
      'Attempting VM service connection...',
      logger: 'VMService',
    );

    try {
      await initializeVMService();

      log(
        LoggingLevel.info,
        'VM service initialization completed',
        logger: 'VMService',
      );
    } catch (e, s) {
      // Log but don't fail - tools should still be available
      log(
        LoggingLevel.error,
        'VM service initialization failed: $e',
        logger: 'VMService',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
    }
  }

  @override
  Future<void> shutdown() async {
    log(
      LoggingLevel.info,
      'Shutting down Flutter Inspector MCP Server',
      logger: 'MCPToolkitServer',
    );

    try {
      await disconnectVMService();
      await dispose();
      await disposeDynamicRegistry();
      log(LoggingLevel.debug, 'VM service disconnected', logger: 'VMService');
    } catch (e) {
      log(
        LoggingLevel.warning,
        'Error during VM service disconnect: $e',
        logger: 'VMService',
      );
    }

    await super.shutdown();
    log(
      LoggingLevel.info,
      'Server shutdown complete',
      logger: 'MCPToolkitServer',
    );
  }
}
