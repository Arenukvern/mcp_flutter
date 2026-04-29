// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// Pure connection-override parsing re-exported from mcp_shared_core.
// Transport-coupled helpers (ObjectSchema, applyConnectionOverride) stay here.

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/command_executor.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

export 'package:mcp_shared_core/mcp_shared_core.dart'
    show
        ConnectionArgsResolution,
        connectionOverrideJsonSchema,
        parseConnectionOverrideArguments,
        resolveCommandArgumentsForExecution,
        withOptionalConnectionOverrideSchema;

/// dart_mcp ObjectSchema for the connection override field.
/// Uses [ObjectSchema] (transport type) so stays here, not in mcp_shared_core.
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
  final parsed = parseConnectionOverrideArguments(
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
    final parsedBool = jsonDecodeBool(query['forceReconnect']);
    connectionArgs['forceReconnect'] = parsedBool;
  }

  final parsed = parseConnectionOverrideArguments(
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
