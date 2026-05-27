// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:convert';

import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:dart_mcp/server.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_consts.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/error_codes.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

export 'dynamic_registry_tools.dart';
export 'registry_discovery_service.dart';

/// Entry for a dynamically registered tool — [RegisteredAgentIntent] + MCP [Tool].
@immutable
final class DynamicToolEntry with EquatableMixin {
  const DynamicToolEntry({required this.intent, required this.tool});

  final RegisteredAgentIntent intent;
  final Tool tool;

  @override
  bool? get stringify => true;

  @override
  List<Object?> get props => [intent.descriptor.qualifiedName, tool.name];
}

/// Entry for a dynamically registered resource — intent + MCP [Resource].
@immutable
final class DynamicResourceEntry with EquatableMixin {
  const DynamicResourceEntry({required this.intent, required this.resource});

  final RegisteredAgentIntent intent;
  final Resource resource;

  @override
  bool? get stringify => true;

  @override
  List<Object?> get props => [
    intent.descriptor.effectiveResourceUri,
    resource.uri,
  ];
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

    final intent = _intentForTool(tool: tool, appId: appId);
    final entry = DynamicToolEntry(intent: intent, tool: tool);

    _tools[tool.name] = entry;
    _lastActivity = DateTime.now();

    logger.log(
      LoggingLevel.info,
      'Registered MCP tool: ${tool.name} for app $appId',
      logger: 'DynamicRegistry',
    );

    _addEvent(ToolRegisteredEvent(timestamp: DateTime.now(), entry: entry));
  }

  void _addEvent(final DynamicRegistryEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
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
      _appId = appId;
    }
  }

  /// Register a new resource from a Flutter application
  /// Resource must be MCP-compliant with proper uri, name, description
  void registerResource(final Resource resource, final DynamicAppId appId) {
    verifyAppConnection(appId);

    final intent = _intentForResource(resource: resource, appId: appId);
    final entry = DynamicResourceEntry(intent: intent, resource: resource);

    _resources[resource.uri] = entry;

    logger.log(
      LoggingLevel.info,
      'Registered MCP resource: ${resource.uri} for app $appId',
      logger: 'DynamicRegistry',
    );

    _addEvent(ResourceRegisteredEvent(timestamp: DateTime.now(), entry: entry));
  }

  /// Remove all tools and resources for the current app
  void unregisterApp() {
    final toolsCount = _tools.length;
    final resourcesCount = _resources.length;

    _clearCurrentRegistrations();

    _addEvent(
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
      _addEvent(
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
      _addEvent(
        ResourceUnregisteredEvent(
          timestamp: DateTime.now(),
          resourceUri: entry.resource.uri,
          appId: _appId ?? const DynamicAppId(''),
        ),
      );
    }

    server.sendNotification(
      ToolListChangedNotification.methodName,
      ToolListChangedNotification(),
    );

    _tools.clear();
    _resources.clear();
    _appId = null;
    _lastActivity = null;
  }

  /// Get all tool entries with metadata
  List<DynamicToolEntry> getToolEntries() => _tools.values.toList();

  /// Get all resource entries with metadata
  List<DynamicResourceEntry> getResourceEntries() => _resources.values.toList();

  /// Get tool entry by name for MCP CallToolRequest handling
  DynamicToolEntry? getToolEntry(final String name) => _tools[name];

  /// Get resource entry by URI for MCP ReadResourceRequest handling
  DynamicResourceEntry? getResourceEntry(final String uri) {
    final direct = _resources[uri];
    if (direct != null) {
      return direct;
    }

    final normalized = _normalizeResourceLookupUri(uri);
    return _resources[normalized];
  }

  /// Check if a tool is dynamically registered (for MCP tool routing)
  bool isDynamicTool(final String name) => _tools.containsKey(name);

  /// Check if a resource is dynamically registered (for MCP resource routing)
  bool isDynamicResource(final String uri) => getResourceEntry(uri) != null;

  /// Forward MCP tool call via stored [RegisteredAgentIntent].
  /// Returns null if tool not found.
  Future<CallToolResult?> forwardToolCall(
    final String toolName,
    final Map<String, Object?>? arguments,
  ) async {
    final entry = getToolEntry(toolName);
    if (entry == null) {
      return null;
    }

    updateAppActivity();
    final args = arguments ?? const <String, Object?>{};
    try {
      entry.intent.validate(args);
    } on AgentValidationException catch (e) {
      return agentResultToMcpResult(
        AgentResult.failure(
          code: CoreErrorCode.invalidCommand,
          message: e.message,
        ),
      );
    }

    final agentResult = await entry.intent.execute(
      AgentInvocation(descriptor: entry.intent.descriptor, arguments: args),
    );
    return agentResultToMcpResult(agentResult);
  }

  RegisteredAgentIntent _intentForTool({
    required final Tool tool,
    required final DynamicAppId appId,
  }) {
    final namespace = appId.isEmpty ? 'app' : appId;
    return RegisteredAgentIntent(
      descriptor: AgentIntentDescriptor(
        namespace: namespace,
        name: tool.name,
        description: tool.description ?? '',
        kind: AgentIntentKind.tool,
        inputSchema: inputSchemaFromMcpTool(tool),
      ),
      execute: (final invocation) => _invokeDynamicTool(
        toolName: tool.name,
        arguments: invocation.arguments,
      ),
    );
  }

  Future<AgentResult> _invokeDynamicTool({
    required final String toolName,
    required final AgentArguments arguments,
  }) async {
    try {
      final vmService = this.vmService;
      if (vmService == null) {
        return AgentResult.failure(
          code: CoreErrorCode.vmNotConnected,
          message: 'VM service not available for tool forwarding',
        );
      }

      final response = await server.callFlutterExtension(
        '$mcpToolkitExt.$toolName',
        args: arguments,
      );

      final data = jsonDecodeMap(response.json);
      final message = jsonDecodeString(
        data['message'],
      ).whenEmptyUse('Tool executed successfully');
      final resultParameters = jsonDecodeMap(data)..remove('message');

      return AgentResult.success(
        message: message,
        data: resultParameters,
        artifacts: [
          AgentArtifact.text(message),
          if (resultParameters.isNotEmpty)
            AgentArtifact.text(jsonEncode(resultParameters)),
        ],
      );
    } on Exception catch (e, stackTrace) {
      logger.log(
        LoggingLevel.error,
        'Failed to forward tool call to $toolName: $e'
        'stackTrace: $stackTrace',
        logger: 'DynamicRegistry',
      );

      return AgentResult.failure(
        code: CoreErrorCode.dynamicToolFailed,
        message: 'Error forwarding tool call: $e',
      );
    }
  }

  RegisteredAgentIntent _intentForResource({
    required final Resource resource,
    required final DynamicAppId appId,
  }) {
    final namespace = appId.isEmpty ? 'app' : appId;
    return RegisteredAgentIntent(
      descriptor: AgentIntentDescriptor(
        namespace: namespace,
        name: resource.name,
        description: resource.description ?? '',
        kind: AgentIntentKind.resource,
        inputSchema: const <String, Object?>{'type': 'object'},
        resourceUri: resource.uri,
        mimeType: resource.mimeType,
      ),
      execute: (final invocation) => _invokeDynamicResource(
        resource: resource,
        requestedUri: invocation.arguments['uri'] as String? ?? resource.uri,
      ),
    );
  }

  Future<AgentResult> _invokeDynamicResource({
    required final Resource resource,
    required final String requestedUri,
  }) async {
    try {
      final vmService = this.vmService;
      if (vmService == null) {
        return AgentResult.failure(
          code: CoreErrorCode.vmNotConnected,
          message: 'VM service not available for resource forwarding',
        );
      }

      logger.log(
        LoggingLevel.info,
        'Forwarding resource read ${resource.uri} to Flutter app',
        logger: 'DynamicRegistry',
      );

      final parsedResourceUri = Uri.parse(resource.uri);
      final candidates = _resourceExtensionCandidates(
        parsed: parsedResourceUri,
        fallbackName: resource.name,
      );

      Map<String, Object?>? data;
      Object? lastUnknownMethodError;
      for (final candidate in candidates) {
        try {
          final response = await server.callFlutterExtension(
            '$mcpToolkitExt.$candidate',
            args: {'uri': resource.uri},
          );
          data = jsonDecodeMap(response.json);
          break;
        } catch (e) {
          if (!_isUnknownExtensionMethodError(e)) {
            rethrow;
          }
          lastUnknownMethodError = e;
        }
      }

      if (data == null) {
        throw StateError(
          'No matching dynamic resource extension for ${resource.uri}. '
          'Last error: $lastUnknownMethodError',
        );
      }

      final mimeType = jsonDecodeString(
        data['mimeType'],
      ).whenEmptyUse(resource.mimeType ?? 'application/json');

      if (jsonDecodeBool(data['isBlob'])) {
        final blob = jsonDecodeString(data['blob']);
        if (blob.isNotEmpty) {
          return readResourceResultToAgentResult(
            ReadResourceResult(
              contents: [
                BlobResourceContents(
                  uri: requestedUri,
                  blob: blob,
                  mimeType: mimeType,
                ),
              ],
            ),
          );
        }
      }

      final content = jsonDecodeString(data['content']);
      if (content.isNotEmpty) {
        return readResourceResultToAgentResult(
          ReadResourceResult(
            contents: [
              TextResourceContents(
                uri: requestedUri,
                text: content,
                mimeType: mimeType,
              ),
            ],
          ),
        );
      }

      final payload = <String, Object?>{...data}
        ..remove('content')
        ..remove('mimeType')
        ..remove('blob')
        ..remove('isBlob');
      final message = jsonDecodeString(payload['message']);
      payload.remove('message');
      final normalizedPayload = <String, Object?>{
        if (message.isNotEmpty) 'message': message,
        if (payload.isNotEmpty) 'parameters': payload,
      };

      return readResourceResultToAgentResult(
        ReadResourceResult(
          contents: [
            TextResourceContents(
              uri: requestedUri,
              text: jsonEncode(normalizedPayload),
              mimeType: 'application/json',
            ),
          ],
        ),
      );
    } on Exception catch (e, stackTrace) {
      logger.log(
        LoggingLevel.error,
        'Failed to forward resource read to ${resource.uri}: $e'
        'stackTrace: $stackTrace',
        logger: 'DynamicRegistry',
      );

      return AgentResult.failure(
        code: CoreErrorCode.dynamicResourceFailed,
        message: 'Error forwarding resource read: $e',
      );
    }
  }

  /// Forward MCP resource read via stored [RegisteredAgentIntent].
  Future<ReadResourceResult?> forwardResourceRead(
    final String resourceUri,
  ) async {
    final entry = getResourceEntry(resourceUri);
    if (entry == null) {
      return null;
    }

    updateAppActivity();
    final args = <String, Object?>{'uri': resourceUri};
    try {
      entry.intent.validate(args);
    } on AgentValidationException catch (e) {
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            text: e.message,
            uri: resourceUri,
            mimeType: 'text/plain',
          ),
        ],
      );
    }

    final agentResult = await entry.intent.execute(
      AgentInvocation(
        descriptor: entry.intent.descriptor,
        arguments: args,
      ),
    );
    return agentResultToReadResourceResult(agentResult, uri: resourceUri);
  }

  /// Get tools and resources for the current app
  ({List<DynamicToolEntry> tools, List<DynamicResourceEntry> resources})
  getAppEntries() =>
      (tools: _tools.values.toList(), resources: _resources.values.toList());

  /// Update app activity timestamp
  void updateAppActivity() {
    _lastActivity = DateTime.now();
  }

  /// Cleanup and dispose
  Future<void> dispose() async {
    await _eventController.close();
    _tools.clear();
    _resources.clear();
  }

  @override
  String toString() =>
      'DynamicRegistry(${_tools.length} tools, '
      '${_resources.length} resources)';

  String _normalizeResourceLookupUri(final String uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) {
      return uri;
    }

    return parsed.replace(query: '', fragment: '').toString();
  }

  List<String> _resourceExtensionCandidates({
    required final Uri parsed,
    required final String fallbackName,
  }) {
    final candidates = <String>[];

    void addCandidate(final String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || candidates.contains(normalized)) {
        return;
      }
      candidates.add(normalized);
    }

    final pathSegments = parsed.pathSegments
        .where((final segment) => segment.trim().isNotEmpty)
        .toList();
    if (pathSegments.isNotEmpty) {
      addCandidate(pathSegments.last);
      if (pathSegments.length > 1) {
        addCandidate(pathSegments.join('_'));
      }
    }
    addCandidate(fallbackName);

    return candidates;
  }

  bool _isUnknownExtensionMethodError(final Object error) {
    final text = '$error'.toLowerCase();
    return text.contains('unknown method') ||
        text.contains('not found') ||
        text.contains('extension call returned null') ||
        text.contains('-32601');
  }
}

/// Copies MCP [Tool.inputSchema] into agentkit [InputSchema] for listing and validation.
InputSchema inputSchemaFromMcpTool(final Tool tool) {
  final raw = tool.inputSchema;
  return _deepCopyInputSchemaMap(Map<Object?, Object?>.from(raw as Map));
}

Map<String, Object?> _deepCopyInputSchemaMap(final Map<Object?, Object?> raw) =>
    raw.map(
      (final key, final value) =>
          MapEntry(key.toString(), _normalizeSchemaMapValue(value)),
    );

Object? _normalizeSchemaMapValue(final Object? value) {
  if (value is Map) {
    return _deepCopyInputSchemaMap(Map<Object?, Object?>.from(value));
  }
  if (value is Iterable && value is! String) {
    return value
        .map<Object?>(
          (final item) => item is Map
              ? _deepCopyInputSchemaMap(Map<Object?, Object?>.from(item))
              : item,
        )
        .toList();
  }
  return value;
}
