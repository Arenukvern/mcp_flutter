// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter_inspector_mcp_server/flutter_inspector_mcp_server.dart';
import 'package:flutter_inspector_mcp_server/src/dynamic_registry/dynamic_registry.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:vm_service/vm_service.dart';

/// Registry discovery service that leverages DTD events and
/// direct VM connection
/// Uses the insight that when VM service connects, we're already
/// connected to the Flutter isolate
final class RegistryDiscoveryService {
  RegistryDiscoveryService({
    required this.dynamicRegistry,
    required this.server,
  });

  final DynamicRegistry dynamicRegistry;
  LoggingSupport get logger => server;
  final MCPToolkitServer server;
  VmService? get vmService => server.vmService;
  DartToolingDaemon? get dtd => server.dartToolingDaemon;
  static const _loggerName = 'RegistryDiscovery';
  StreamSubscription<DTDEvent>? _discoverySubscription;

  Future<void> dispose() async {
    try {
      await _discoverySubscription?.cancel();
      // ignore: avoid_catches_without_on_clauses
    } catch (e, stackTrace) {
      logger.log(
        LoggingLevel.warning,
        'Error disposing registry discovery: $e'
        'stackTrace: $stackTrace',
        logger: _loggerName,
      );
    }
  }

  /// Start simplified discovery - immediately register and listen for changes
  Future<void> startDiscovery() async {
    logger.log(
      LoggingLevel.info,
      'Starting registry discovery',
      logger: _loggerName,
    );

    // Immediate registration when connected
    await _registerToolsAndResources();

    // Listen for DTD events for re-registration
    _discoverySubscription = _listenForToolChanges();
  }

  /// Listen for DTD events that indicate tool changes
  StreamSubscription<DTDEvent>? _listenForToolChanges() {
    final dtd = this.dtd;
    if (dtd == null) {
      logger.log(
        LoggingLevel.warning,
        'DTD not available for event listening',
        logger: _loggerName,
      );
      return null;
    }

    logger.log(
      LoggingLevel.info,
      'Setting up DTD event listener for tool changes',
      logger: _loggerName,
    );

    dtd.onEvent(EventStreams.kService).listen((final e) {
      final method = e.data['method'];
      if (e.kind == EventKind.kServiceRegistered &&
          method == 'registerDynamics') {
        logger.log(
          LoggingLevel.info,
          'Service registered: $e',
          logger: _loggerName,
        );
        unawaited(_registerToolsAndResources());
      }
    });

    try {
      // Listen to the MCPToolkit stream for tool registration events
      return dtd
          .onEvent('MCPToolkit')
          .listen(
            _handleMCPToolkitEvent,
            onError:
                (final error, final stackTrace) => logger.log(
                  LoggingLevel.warning,
                  'Error in DTD event listener: $error'
                  'stackTrace: $stackTrace',
                  logger: _loggerName,
                ),
          );
    } on Exception catch (e, stackTrace) {
      logger.log(
        LoggingLevel.warning,
        'Failed to set up DTD event listener: $e'
        'stackTrace: $stackTrace',
        logger: _loggerName,
      );
      return null;
    }
  }

  /// Handle MCP Toolkit events from DTD
  Future<void> _handleMCPToolkitEvent(final DTDEvent event) async {
    try {
      final eventData = event.data;
      final eventKind = jsonDecodeString(eventData['kind']);

      logger.log(
        LoggingLevel.debug,
        'Received MCP Toolkit event: $eventKind',
        logger: _loggerName,
      );

      switch (eventKind) {
        case 'ToolRegistration':
          // Flutter app has registered new tools - re-register everything
          await _registerToolsAndResources();
        case 'ServiceExtensionStateChanged':
          // Tool state changed - might need re-registration
          final extensionName = jsonDecodeString(eventData['extension']);
          if (extensionName.contains('registerDynamics')) {
            await _registerToolsAndResources();
          }
        default:
          logger.log(
            LoggingLevel.debug,
            'Ignoring MCP Toolkit event: $eventKind',
            logger: _loggerName,
          );
      }
    } on Exception catch (e, stackTrace) {
      logger.log(
        LoggingLevel.warning,
        'Error handling MCP Toolkit event: $e'
        'stackTrace: $stackTrace',
        logger: _loggerName,
      );
    }
  }

  /// Register tools from the Flutter isolate
  Future<void> _registerToolsAndResources() async {
    try {
      logger.log(
        LoggingLevel.info,
        'Calling registerDynamic',
        logger: _loggerName,
      );

      final response = await server.callFlutterExtension(
        'ext.mcp.toolkit.registerDynamics',
      );

      final data = jsonDecodeMap(response.json);
      await _processRegistrationResponse(data);
    } on Exception catch (e, stackTrace) {
      logger.log(
        LoggingLevel.error,
        'Failed to call registerDynamics: $e'
        'stackTrace: $stackTrace',
        logger: _loggerName,
      );
    }
  }

  /// Process the response from registerDynamics
  Future<void> _processRegistrationResponse(
    final Map<String, dynamic> data,
  ) async {
    try {
      final appId = DynamicAppId(jsonDecodeString(data['appId']));
      final tools = jsonDecodeListAs<Map<String, dynamic>>(data['tools']);
      final resources = jsonDecodeListAs<Map<String, dynamic>>(
        data['resources'],
      );

      logger.log(
        LoggingLevel.info,
        'Processing registration: ${tools.length} tools, '
        '${resources.length} resources from $appId',
        logger: _loggerName,
      );

      // Clear existing registrations for this app
      server.unregisterDynamicApp(appId);

      // Register tools
      for (final toolData in tools) {
        try {
          final tool = Tool.fromMap(toolData);
          server.registerDynamicTool(tool, appId);
        } on Exception catch (e) {
          logger.log(
            LoggingLevel.warning,
            'Failed to register tool ${toolData['name']}: $e',
            logger: _loggerName,
          );
        }
      }

      // Register resources
      for (final resourceData in resources) {
        try {
          final resource = Resource.fromMap(resourceData);
          server.registerDynamicResource(resource, appId);
        } on Exception catch (e) {
          logger.log(
            LoggingLevel.warning,
            'Failed to register resource ${resourceData['uri']}: $e',
            logger: _loggerName,
          );
        }
      }

      logger.log(
        LoggingLevel.info,
        'Successfully registered $appId with ${tools.length} '
        'tools and ${resources.length} resources',
        logger: _loggerName,
      );
    } on Exception catch (e, stackTrace) {
      logger.log(
        LoggingLevel.error,
        'Failed to process registration response: $e'
        'stackTrace: $stackTrace',
        logger: _loggerName,
      );
    }
  }
}
