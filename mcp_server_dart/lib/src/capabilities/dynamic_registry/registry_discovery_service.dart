// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_server.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_consts.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:meta/meta.dart';
import 'package:rx/constructors.dart';
import 'package:rx/converters.dart';
import 'package:vm_service/vm_service.dart';

/// Thrown when one or more tools/resources in a registerDynamics payload fail
/// to parse.
final class RegisterDynamicsPayloadException implements Exception {
  const RegisterDynamicsPayloadException(this.failures);

  final List<String> failures;

  @override
  String toString() =>
      'RegisterDynamicsPayloadException(${failures.join('; ')})';
}

/// Parsed registerDynamics payload — tools and resources ready to register.
@visibleForTesting
typedef ParsedRegisterDynamicsPayload = ({
  DynamicAppId appId,
  List<Tool> tools,
  List<({Resource resource, Map<String, Object?>? inputSchema})> resources,
});

/// Parses registerDynamics response data.
///
/// Throws [RegisterDynamicsPayloadException] if any tool or resource fails
/// [Tool.fromMap] / [Resource.fromMap] (fail-closed; no partial registration).
@visibleForTesting
ParsedRegisterDynamicsPayload parseRegisterDynamicsPayload(
  final Map<String, dynamic> data,
) {
  final failures = <String>[];
  final appId = DynamicAppId(jsonDecodeString(data['appId']));
  final toolsRaw = jsonDecodeListAs<Map<String, dynamic>>(data['tools']);
  final resourcesRaw = jsonDecodeListAs<Map<String, dynamic>>(
    data['resources'],
  );

  final tools = <Tool>[];
  for (final toolData in toolsRaw) {
    try {
      final tool = Tool.fromMap(toolData);
      if (allMcpToolkitExtNames.contains(tool.name)) {
        continue;
      }
      tools.add(tool);
    } catch (e) {
      failures.add('tool "${toolData['name']}": $e');
    }
  }

  final resources =
      <({Resource resource, Map<String, Object?>? inputSchema})>[];
  for (final resourceData in resourcesRaw) {
    try {
      final resource = Resource.fromMap(resourceData);
      if (allMcpToolkitExtNames.contains(resource.uri)) {
        continue;
      }
      resources.add((
        resource: resource,
        inputSchema: inputSchemaFromDynamicRegistrationMap(resourceData),
      ));
    } catch (e) {
      failures.add('resource "${resourceData['uri']}": $e');
    }
  }

  if (failures.isNotEmpty) {
    throw RegisterDynamicsPayloadException(failures);
  }

  return (appId: appId, tools: tools, resources: resources);
}

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

    final mergedStream = merge<DTDEvent>([
      dtd.onEvent(EventStreams.kExtension).toObservable(),
      dtd.onEvent(EventStreams.kService).toObservable(),
    ]);

    final listener = mergedStream.toStream().listen(
      (final e) {
        // final method = e.data['method'];
        if (e.kind == EventKind.kServiceRegistered) {
          logger.log(
            LoggingLevel.info,
            'Service registered: $e',
            logger: _loggerName,
          );
          unawaited(registerToolsAndResources());
        }
        unawaited(_handleMCPToolkitEvent(e));
      },
      onError: (final error, final stackTrace) => logger.log(
        LoggingLevel.warning,
        'Error in DTD event listener: $error'
        'stackTrace: $stackTrace',
        logger: _loggerName,
      ),
    );

    try {
      // Listen to the MCPToolkit stream for tool registration events
      return listener;
    } catch (e, stackTrace) {
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
          await registerToolsAndResources();
        case 'ServiceExtensionStateChanged':
          // Tool state changed - might need re-registration
          final extensionName = jsonDecodeString(eventData['extension']);
          if (extensionName.contains(mcpToolkitExtNames.registerDynamics)) {
            await registerToolsAndResources();
          }
        default:
          logger.log(
            LoggingLevel.debug,
            'Ignoring MCP Toolkit event: $eventKind',
            logger: _loggerName,
          );
      }
    } catch (e, stackTrace) {
      logger.log(
        LoggingLevel.warning,
        'Error handling MCP Toolkit event: $e'
        'stackTrace: $stackTrace',
        logger: _loggerName,
      );
    }
  }

  /// Register tools from the Flutter isolate
  Future<void> registerToolsAndResources() async {
    try {
      logger.log(
        LoggingLevel.info,
        'Calling registerDynamic',
        logger: _loggerName,
      );

      final response = await server.callFlutterExtension(
        '$mcpToolkitExt.${mcpToolkitExtNames.registerDynamics}',
      );

      final data = jsonDecodeMap(response.json);
      await _processRegistrationResponse(data);
    } catch (e, stackTrace) {
      logger.log(
        LoggingLevel.error,
        'Failed to call registerDynamics: $e'
        'stackTrace: $stackTrace',
        logger: _loggerName,
      );
      dynamicRegistry.unregisterApp();
    }
  }

  /// Process the response from registerDynamics
  Future<void> _processRegistrationResponse(
    final Map<String, dynamic> data,
  ) async {
    try {
      final parsed = parseRegisterDynamicsPayload(data);

      logger.log(
        LoggingLevel.info,
        'Processing registration: ${parsed.tools.length} tools, '
        '${parsed.resources.length} resources from ${parsed.appId}',
        logger: _loggerName,
      );

      // Clear existing registrations for this app
      server.unregisterDynamicApp(parsed.appId);

      for (final tool in parsed.tools) {
        server.registerDynamicTool(tool, parsed.appId);
      }

      for (final entry in parsed.resources) {
        server.registerDynamicResource(
          entry.resource,
          parsed.appId,
          inputSchema: entry.inputSchema,
        );
      }

      logger.log(
        LoggingLevel.info,
        'Successfully registered ${parsed.appId} with '
        '${parsed.tools.length} tools and ${parsed.resources.length} resources',
        logger: _loggerName,
      );
    } catch (e, stackTrace) {
      logger.log(
        LoggingLevel.error,
        'Failed to process registration response: $e'
        'stackTrace: $stackTrace',
        logger: _loggerName,
      );
      dynamicRegistry.unregisterApp();
    }
  }

  /// Test hook for [_processRegistrationResponse].
  @visibleForTesting
  Future<void> processRegistrationResponseForTesting(
    final Map<String, dynamic> data,
  ) => _processRegistrationResponse(data);
}
