// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/connection_override.dart'
    as core_connection_override;
import 'package:flutter_inspector_mcp_server/src/core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';

final ObjectSchema connectionObjectSchema = ObjectSchema(
  properties: {
    'targetId': Schema.string(
      description:
          'Preferred target identifier as full VM websocket URI '
          '(e.g. ws://127.0.0.1:8181/<token>/ws)',
    ),
    'mode': Schema.string(
      enumValues: ['auto', 'manual', 'uri'],
      description: 'Connection mode override: auto, manual, or uri',
    ),
    'host': Schema.string(
      description: 'Host used for manual mode connection selection',
    ),
    'port': Schema.int(
      description: 'Port used for manual mode connection selection',
    ),
    'uri': Schema.string(
      description: 'Full websocket VM URI used for uri mode selection',
    ),
    'forceReconnect': Schema.bool(
      description: 'If true, forces reconnect even to current endpoint',
    ),
  },
  additionalProperties: false,
);

ObjectSchema strictToolInputSchema({
  final Map<String, Schema> properties = const <String, Schema>{},
  final List<String> required = const <String>[],
}) => ObjectSchema(
  properties: {'connection': connectionObjectSchema, ...properties},
  required: required,
  additionalProperties: false,
);

/// Applies connection override arguments from a tool request.
///
/// Uses strict nested shape: `arguments.connection`.
Future<CoreResult?> applyConnectionOverride({
  required final CallToolRequest request,
  required final CoreCommandExecutor executor,
}) => applyConnectionOverrideFromArguments(
  arguments: request.arguments,
  executor: executor,
);

/// Applies connection override arguments from plain argument map.
///
/// Uses strict nested shape: `arguments.connection`.
Future<CoreResult?> applyConnectionOverrideFromArguments({
  required final Map<String, Object?>? arguments,
  required final CoreCommandExecutor executor,
}) async {
  final resolved = buildConnectCommandFromArguments(arguments: arguments);
  final parseError = resolved.error;
  if (parseError != null) {
    return parseError;
  }

  final command = resolved.command;
  if (command == null) {
    return null;
  }

  final result = await executor.execute(command);

  return result.ok ? null : result;
}

/// Builds a [ConnectCommand] from strict nested `arguments.connection`.
///
/// Returns `command: null` when no override was requested.
/// Set [fallbackToAuto] to true to return `ConnectCommand()` when no override
/// fields are provided (used by `connect_debug_app`).
({CoreResult? error, ConnectCommand? command})
buildConnectCommandFromArguments({
  required final Map<String, Object?>? arguments,
  final bool fallbackToAuto = false,
}) {
  final parsed = core_connection_override.parseConnectionOverrideArguments(
    arguments: arguments,
    fallbackToAuto: fallbackToAuto,
  );
  final parseError = parsed.error;
  if (parseError != null) {
    return (error: parseError, command: null);
  }

  return (error: null, command: parsed.preconnectCommand);
}

/// Applies connection override from URI query parameters:
/// `targetId`, `mode`, `host`, `port`, `uri`, `forceReconnect`.
Future<CoreResult?> applyConnectionOverrideFromResourceUri({
  required final String resourceUri,
  required final CoreCommandExecutor executor,
}) async {
  final parsedUri = Uri.tryParse(resourceUri);
  if (parsedUri == null) {
    return null;
  }

  final query = parsedUri.queryParameters;
  final hasRelevantParams =
      query.containsKey('targetId') ||
      query.containsKey('mode') ||
      query.containsKey('host') ||
      query.containsKey('port') ||
      query.containsKey('uri') ||
      query.containsKey('forceReconnect');
  if (!hasRelevantParams) {
    return null;
  }

  final connectionArgs = <String, Object?>{
    if (query.containsKey('targetId')) 'targetId': query['targetId'],
    if (query.containsKey('mode')) 'mode': query['mode'],
    if (query.containsKey('host')) 'host': query['host'],
    if (query.containsKey('port')) 'port': query['port'],
    if (query.containsKey('uri')) 'uri': query['uri'],
  };

  if (query.containsKey('forceReconnect')) {
    final parsedBool = _asBool(query['forceReconnect']);
    if (parsedBool == null) {
      return CoreResult.failure(
        code: CoreErrorCode.connectFailed,
        message:
            'Failed to connect: Invalid forceReconnect value in resource URI query',
        details: {
          'reason': 'invalid_query_parameter',
          'parameter': 'forceReconnect',
        },
      );
    }
    connectionArgs['forceReconnect'] = parsedBool;
  }

  final parsed = core_connection_override.parseConnectionOverrideArguments(
    arguments: {'connection': connectionArgs},
  );
  if (parsed.error != null) {
    return CoreResult.failure(
      code: CoreErrorCode.connectFailed,
      message:
          'Failed to connect: ${parsed.error!.error?.message ?? 'invalid connection override'}',
      details: parsed.error!.error?.details,
    );
  }

  final command = parsed.preconnectCommand;
  if (command == null) {
    return null;
  }

  final result = await executor.execute(command);

  return result.ok ? null : result;
}

CallToolResult toCallToolErrorResult(
  final CoreResult result, {
  required final String prefix,
}) => CallToolResult(
  isError: true,
  content: [TextContent(text: formatCoreErrorForMcp(result, prefix: prefix))],
);

ReadResourceResult toReadResourceErrorResult({
  required final String uri,
  required final CoreResult result,
  required final String prefix,
}) => ReadResourceResult(
  contents: [
    TextResourceContents(
      uri: uri,
      text: formatCoreErrorForMcp(result, prefix: prefix),
    ),
  ],
);

String formatCoreErrorForMcp(
  final CoreResult result, {
  required final String prefix,
}) {
  final _ = prefix;
  final error = result.error;
  if (error == null) {
    return jsonEncode(
      CoreResult.failure(
        code: CoreErrorCode.unknown,
        message: 'Unknown error',
      ).error?.toJson(),
    );
  }

  return jsonEncode(error.toJson());
}

bool? _asBool(final Object? value) {
  return switch (value) {
    final bool v => v,
    final num v => v != 0,
    final String v => bool.tryParse(v.trim()),
    _ => null,
  };
}
