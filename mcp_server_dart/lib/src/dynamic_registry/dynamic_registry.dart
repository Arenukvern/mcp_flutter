// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_inspector_mcp_server/flutter_inspector_mcp_server.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

/// Entry for a dynamically registered tool - fully MCP compliant
@immutable
final class DynamicToolEntry with EquatableMixin {
  const DynamicToolEntry({required this.tool});

  final Tool tool;
  @override
  bool? get stringify => true;

  @override
  List<Object?> get props => [tool];
}

/// Entry for a dynamically registered resource - fully MCP compliant
@immutable
final class DynamicResourceEntry with EquatableMixin {
  const DynamicResourceEntry({required this.resource});

  final Resource resource;

  @override
  bool? get stringify => true;

  @override
  List<Object?> get props => [resource];
}

/// A string that represents a dynamic app id.
extension type const DynamicAppId(String _value) implements String {}

/// Information about a registered app
@immutable
extension type const DynamicAppInfo._(Map<String, Object?> _value)
    implements Map<String, Object?> {
  factory DynamicAppInfo({
    required final DynamicAppId id,
    required final int toolCount,
    required final int resourceCount,
    required final DateTime lastActivity,
  }) => DynamicAppInfo._({
    'id': id,
    'toolCount': toolCount,
    'resourceCount': resourceCount,
    'lastActivity': lastActivity.millisecondsSinceEpoch,
  });

  DynamicAppId get id => DynamicAppId(jsonDecodeString(_value['id']));
  int get port => jsonDecodeInt(_value['port']);
  int get toolCount => jsonDecodeInt(_value['toolCount']);
  int get resourceCount => jsonDecodeInt(_value['resourceCount']);
  DateTime get lastActivity => DateTime.fromMillisecondsSinceEpoch(
    jsonDecodeInt(_value['lastActivity']),
  );
}

/// Event emitted when registry changes
@immutable
sealed class DynamicRegistryEvent {
  const DynamicRegistryEvent({required this.timestamp});

  final DateTime timestamp;
}

final class ToolRegisteredEvent extends DynamicRegistryEvent {
  const ToolRegisteredEvent({required super.timestamp, required this.entry});

  final DynamicToolEntry entry;
}

final class ToolUnregisteredEvent extends DynamicRegistryEvent {
  const ToolUnregisteredEvent({
    required super.timestamp,
    required this.toolName,
    required this.appId,
  });

  final String toolName;
  final DynamicAppId appId;
}

final class ResourceRegisteredEvent extends DynamicRegistryEvent {
  const ResourceRegisteredEvent({
    required super.timestamp,
    required this.entry,
  });

  final DynamicResourceEntry entry;
}

final class ResourceUnregisteredEvent extends DynamicRegistryEvent {
  const ResourceUnregisteredEvent({
    required super.timestamp,
    required this.resourceUri,
    required this.appId,
  });

  final String resourceUri;
  final DynamicAppId appId;
}

final class AppUnregisteredEvent extends DynamicRegistryEvent {
  const AppUnregisteredEvent({
    required super.timestamp,
    required this.appId,
    required this.toolsRemoved,
    required this.resourcesRemoved,
  });

  final DynamicAppId appId;
  final int toolsRemoved;
  final int resourcesRemoved;
}

/// Tool call forwarding result for dynamic tools
typedef DynamicToolResult = ({Tool tool, List<Content> content});

/// Resource read forwarding result for dynamic resources
typedef DynamicResourceResult = ({Resource resource, List<Content> content});

/// Dynamic registry for tools and resources registered by Flutter applications
/// Manages runtime registration and cleanup with event-driven architecture
/// Fully compatible with MCP protocol defined in tools.dart
final class DynamicRegistry {
  DynamicRegistry({required this.server});

  final MCPToolkitServer server;
  LoggingSupport get logger => server;
  VmService? get vmService => server.vmService;

  // Storage - keyed for fast MCP protocol lookups
  final Map<String, DynamicToolEntry> _tools = {};
  final Map<String, DynamicResourceEntry> _resources = {};

  // Single app connection tracking
  DynamicAppId? _appId;
  DynamicAppInfo? get appInfo => DynamicAppInfo(
    id: appId,
    toolCount: _tools.length,
    resourceCount: _resources.length,
    lastActivity: lastActivity,
  );

  DateTime? _lastActivity;

  /// Get current connected app id
  DynamicAppId get appId => _appId ?? const DynamicAppId('');

  /// Get last activity timestamp
  DateTime get lastActivity => _lastActivity ?? DateTime.now();

  /// Check if there's a connected app
  bool get hasConnectedApp => _appId != null;

  // Event streaming
  final _eventController = StreamController<DynamicRegistryEvent>.broadcast();

  /// Stream of registry events
  Stream<DynamicRegistryEvent> get events => _eventController.stream;

  /// Register a new tool from a Flutter application
  /// Tool must be MCP-compliant with proper name, description, and inputSchema
  void registerTool(final Tool tool, final DynamicAppId appId) {
    verifyAppConnection(appId);

    final entry = DynamicToolEntry(tool: tool);

    _tools[tool.name] = entry;
    _lastActivity = DateTime.now();

    logger.log(
      LoggingLevel.info,
      'Registered MCP tool: ${tool.name} for app $appId',
      logger: 'DynamicRegistry',
    );

    _eventController.add(
      ToolRegisteredEvent(timestamp: DateTime.now(), entry: entry),
    );
  }

  /// Verify that the current app is the same as the appId.
  /// If not, clear the current registrations.
  void verifyAppConnection(final DynamicAppId appId) {
    if (_appId != null && _appId != appId) {
      logger.log(
        LoggingLevel.info,
        'Switching from app $_appId to $appId, '
        'clearing previous registrations',
        logger: 'DynamicRegistry',
      );
      _clearCurrentRegistrations();
    }
  }

  /// Register a new resource from a Flutter application
  /// Resource must be MCP-compliant with proper uri, name, description
  void registerResource(final Resource resource, final DynamicAppId appId) {
    verifyAppConnection(appId);

    final entry = DynamicResourceEntry(resource: resource);

    _resources[resource.uri] = entry;

    logger.log(
      LoggingLevel.info,
      'Registered MCP resource: ${resource.uri} for app $appId',
      logger: 'DynamicRegistry',
    );

    _eventController.add(
      ResourceRegisteredEvent(timestamp: DateTime.now(), entry: entry),
    );
  }

  /// Remove all tools and resources for the current app
  void unregisterApp() {
    final toolsCount = _tools.length;
    final resourcesCount = _resources.length;

    _clearCurrentRegistrations();

    _eventController.add(
      AppUnregisteredEvent(
        timestamp: DateTime.now(),
        appId: appId,
        toolsRemoved: toolsCount,
        resourcesRemoved: resourcesCount,
      ),
    );
  }

  /// Clear all current registrations
  void _clearCurrentRegistrations() {
    // Remove all tools
    for (final entry in _tools.values) {
      logger.log(
        LoggingLevel.info,
        'Unregistered MCP tool: ${entry.tool.name} from $_appId',
        logger: 'DynamicRegistry',
      );
      _eventController.add(
        ToolUnregisteredEvent(
          timestamp: DateTime.now(),
          toolName: entry.tool.name,
          appId: _appId ?? const DynamicAppId(''),
        ),
      );
    }

    // Remove all resources
    for (final entry in _resources.values) {
      logger.log(
        LoggingLevel.info,
        'Unregistered MCP resource: ${entry.resource.uri} from '
        '$_appId',
        logger: 'DynamicRegistry',
      );
      _eventController.add(
        ResourceUnregisteredEvent(
          timestamp: DateTime.now(),
          resourceUri: entry.resource.uri,
          appId: _appId ?? const DynamicAppId(''),
        ),
      );
    }

    _tools.clear();
    _resources.clear();
    _appId = null;
    _lastActivity = null;
  }

  /// Get all dynamically registered tools for MCP ListToolsResult
  List<Tool> getDynamicTools() =>
      _tools.values.map((final entry) => entry.tool).toList();

  /// Get all dynamically registered resources for MCP ListResourcesResult
  List<Resource> getDynamicResources() =>
      _resources.values.map((final entry) => entry.resource).toList();

  /// Get all tool entries with metadata
  List<DynamicToolEntry> getToolEntries() => _tools.values.toList();

  /// Get all resource entries with metadata
  List<DynamicResourceEntry> getResourceEntries() => _resources.values.toList();

  /// Get tool entry by name for MCP CallToolRequest handling
  DynamicToolEntry? getToolEntry(final String name) => _tools[name];

  /// Get resource entry by URI for MCP ReadResourceRequest handling
  DynamicResourceEntry? getResourceEntry(final String uri) => _resources[uri];

  /// Check if a tool is dynamically registered (for MCP tool routing)
  bool isDynamicTool(final String name) => _tools.containsKey(name);

  /// Check if a resource is dynamically registered (for MCP resource routing)
  bool isDynamicResource(final String uri) => _resources.containsKey(uri);

  /// Forward MCP tool call to the appropriate Flutter app
  /// Returns null if tool not found, otherwise forwards the call
  Future<CallToolResult?> forwardToolCall(
    final String toolName,
    final Map<String, Object?>? arguments,
  ) async {
    final entry = getToolEntry(toolName);
    if (entry == null) {
      return null;
    }

    updateAppActivity();

    try {
      final vmService = this.vmService;
      if (vmService == null) {
        logger.log(
          LoggingLevel.warning,
          'Cannot forward tool call: VM service not available',
          logger: 'DynamicRegistry',
        );
        return CallToolResult(
          content: [
            TextContent(text: 'VM service not available for tool forwarding'),
          ],
          isError: true,
        );
      }

      // Call the tool's specific service extension
      final response = await server.callFlutterExtension(
        'ext.mcp.toolkit.${entry.tool.name}',
        args: arguments ?? {},
      );

      // Parse the response from the Flutter app
      final data = jsonDecodeMap(response.json);
      final message = jsonDecodeString(
        data['message'],
      ).whenEmptyUse('Tool executed successfully');
      final resultParameters = jsonDecodeMap(data['parameters']);

      return CallToolResult(
        content: [
          TextContent(
            text: '$message\n\nResult: ${jsonEncode(resultParameters)}',
          ),
        ],
        isError: false,
      );
    } on Exception catch (e, stackTrace) {
      logger.log(
        LoggingLevel.error,
        'Failed to forward tool call to ${entry.tool.name}: $e'
        'stackTrace: $stackTrace',
        logger: 'DynamicRegistry',
      );

      return CallToolResult(
        content: [TextContent(text: 'Error forwarding tool call: $e')],
        isError: true,
      );
    }
  }

  /// Forward MCP resource read to the appropriate Flutter app
  /// Returns null if resource not found, otherwise forwards the read
  Future<ReadResourceResult?> forwardResourceRead(
    final String resourceUri,
  ) async {
    final entry = getResourceEntry(resourceUri);
    if (entry == null) {
      return null;
    }

    updateAppActivity();

    try {
      final vmService = this.vmService;
      if (vmService == null) {
        logger.log(
          LoggingLevel.warning,
          'Cannot forward resource read: VM service not available',
          logger: 'DynamicRegistry',
        );
        return ReadResourceResult(
          contents: [
            TextResourceContents(
              uri: resourceUri,
              text: 'VM service not available for resource forwarding',
            ),
          ],
        );
      }

      logger.log(
        LoggingLevel.info,
        'Forwarding resource read ${entry.resource.uri} to Flutter app',
        logger: 'DynamicRegistry',
      );

      // Extract resource name from URI for service extension call
      final resourceName = entry.resource.uri.split('/').last;

      // Call the resource's specific service extension
      final response = await server.callFlutterExtension(
        'ext.mcp.toolkit.$resourceName',
        args: {'uri': resourceUri},
      );

      // Parse the response from the Flutter app
      final data = jsonDecodeMap(response.json);
      final content = jsonDecodeString(
        data['content'],
      ).whenEmptyUse('Resource content not available');
      final mimeType = jsonDecodeString(
        data['mimeType'],
      ).whenEmptyUse(entry.resource.mimeType ?? 'text/plain');

      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: resourceUri,
            text: content,
            mimeType: mimeType,
          ),
        ],
      );
    } on Exception catch (e, stackTrace) {
      logger.log(
        LoggingLevel.error,
        'Failed to forward resource read to ${entry.resource.uri}: $e'
        'stackTrace: $stackTrace',
        logger: 'DynamicRegistry',
      );

      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: resourceUri,
            text: 'Error forwarding resource read: $e',
          ),
        ],
      );
    }
  }

  /// Get tools and resources for the current app
  ({List<DynamicToolEntry> tools, List<DynamicResourceEntry> resources})
  getAppEntries() => (
    tools: _tools.values.toList(),
    resources: _resources.values.toList(),
  );

  /// Update app activity timestamp
  void updateAppActivity() {
    _lastActivity = DateTime.now();
  }

  /// Cleanup and dispose
  void dispose() {
    unawaited(_eventController.close());
    _tools.clear();
    _resources.clear();
  }

  @override
  String toString() =>
      'DynamicRegistry(${_tools.length} tools, '
      '${_resources.length} resources)';
}
