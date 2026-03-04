// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';

/// Strict JSON-schema fragment for optional request-scoped connection override.
Map<String, Object?> connectionOverrideJsonSchema() => {
  'type': 'object',
  'properties': {
    'targetId': {
      'type': 'string',
      'description':
          'Preferred target identifier as full VM websocket URI '
          '(e.g. ws://127.0.0.1:8181/<token>/ws). '
          'Copy from discover_debug_apps/availableTargets when possible. '
          'Do not use host:port values.',
    },
    'mode': {
      'type': 'string',
      'enum': const <String>['auto', 'manual', 'uri'],
      'description': 'Connection mode override: auto, manual, or uri',
    },
    'host': {
      'type': 'string',
      'description': 'Host used for manual mode connection selection',
    },
    'port': {'type': 'integer', 'description': 'Port used for manual mode'},
    'uri': {
      'type': 'string',
      'description':
          'Full websocket VM URI used for uri mode selection. '
          'Safest selector: paste app.debugPort.wsUri exactly.',
    },
    'forceReconnect': {
      'type': 'boolean',
      'description': 'If true, forces reconnect even to current endpoint',
    },
  },
  'additionalProperties': false,
};

/// Appends optional `connection` override field to an object input schema.
Map<String, Object?> withOptionalConnectionOverrideSchema(
  final Map<String, Object?> inputSchema,
) {
  final properties = _asMap(inputSchema['properties']);
  return {
    ...inputSchema,
    'properties': {...properties, 'connection': connectionOverrideJsonSchema()},
  };
}

final class ConnectionArgsResolution {
  const ConnectionArgsResolution({
    required this.sanitizedArgs,
    required this.preconnectCommand,
    required this.connectionProvided,
    this.error,
  });

  final Map<String, Object?> sanitizedArgs;
  final ConnectCommand? preconnectCommand;
  final bool connectionProvided;
  final CoreResult? error;
}

/// Parses strict nested `args.connection` and returns command args with the
/// `connection` key removed.
///
/// - Rejects non-object `connection`.
/// - Rejects unknown fields inside `connection`.
/// - Rejects malformed values (`mode`, `port`, field types).
/// - Produces optional [ConnectCommand] for pre-connect execution.
ConnectionArgsResolution parseConnectionOverrideArguments({
  required final Map<String, Object?>? arguments,
  final bool fallbackToAuto = false,
}) {
  final input = _asMap(arguments);
  final sanitized = Map<String, Object?>.from(input)..remove('connection');
  final hasConnection = input.containsKey('connection');
  final rawConnection = input['connection'];

  if (!hasConnection) {
    return ConnectionArgsResolution(
      sanitizedArgs: sanitized,
      preconnectCommand: fallbackToAuto ? const ConnectCommand() : null,
      connectionProvided: false,
    );
  }

  final connection = switch (rawConnection) {
    final Map<String, Object?> value => value,
    final Map value => value.cast<String, Object?>(),
    _ => null,
  };

  if (connection == null) {
    return ConnectionArgsResolution(
      sanitizedArgs: sanitized,
      preconnectCommand: null,
      connectionProvided: true,
      error: CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message: 'Invalid connection argument: expected object',
      ),
    );
  }

  final unknownFields =
      connection.keys
          .where((final key) => !_connectionOverrideFields.contains(key))
          .toList()
        ..sort();
  if (unknownFields.isNotEmpty) {
    return ConnectionArgsResolution(
      sanitizedArgs: sanitized,
      preconnectCommand: null,
      connectionProvided: true,
      error: CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message:
            'Invalid connection argument: unknown field(s): ${unknownFields.join(', ')}',
        details: {'unknownFields': unknownFields},
      ),
    );
  }

  final targetId = _parseOptionalStringField(
    key: 'targetId',
    source: connection,
  );
  if (targetId.error != null) {
    return _withFieldError(
      sanitized: sanitized,
      fieldError: targetId.error!,
      hasConnection: true,
    );
  }

  final mode = _parseModeField(connection);
  if (mode.error != null) {
    return _withFieldError(
      sanitized: sanitized,
      fieldError: mode.error!,
      hasConnection: true,
    );
  }

  final host = _parseOptionalStringField(key: 'host', source: connection);
  if (host.error != null) {
    return _withFieldError(
      sanitized: sanitized,
      fieldError: host.error!,
      hasConnection: true,
    );
  }

  final port = _parsePortField(connection);
  if (port.error != null) {
    return _withFieldError(
      sanitized: sanitized,
      fieldError: port.error!,
      hasConnection: true,
    );
  }

  final uri = _parseOptionalStringField(key: 'uri', source: connection);
  if (uri.error != null) {
    return _withFieldError(
      sanitized: sanitized,
      fieldError: uri.error!,
      hasConnection: true,
    );
  }

  final forceReconnect = _parseBoolField(
    key: 'forceReconnect',
    source: connection,
  );
  if (forceReconnect.error != null) {
    return _withFieldError(
      sanitized: sanitized,
      fieldError: forceReconnect.error!,
      hasConnection: true,
    );
  }

  final hasOverride =
      targetId.value != null ||
      mode.value != null ||
      host.value != null ||
      port.value != null ||
      uri.value != null ||
      (forceReconnect.value ?? false);

  if (!hasOverride) {
    return ConnectionArgsResolution(
      sanitizedArgs: sanitized,
      preconnectCommand: fallbackToAuto ? const ConnectCommand() : null,
      connectionProvided: true,
    );
  }

  final resolvedMode =
      mode.value ??
      (uri.value != null
          ? CoreConnectionMode.uri
          : (host.value != null || port.value != null
                ? CoreConnectionMode.manual
                : CoreConnectionMode.auto));

  return ConnectionArgsResolution(
    sanitizedArgs: sanitized,
    preconnectCommand: ConnectCommand(
      mode: resolvedMode,
      targetId: targetId.value,
      host: host.value,
      port: port.value,
      uri: uri.value,
      forceReconnect: forceReconnect.value ?? false,
    ),
    connectionProvided: true,
  );
}

/// Resolves command args for CLI/daemon execution:
/// - Parses strict nested `connection`.
/// - Removes `connection` from args before command build.
/// - Rejects legacy flat `host`/`port`/`uri` selectors on non-selector
///   commands.
/// - For selector commands (`connect`, `session_start`), projects nested
///   `connection` into native selector args.
/// - Rejects conflicts when both native selector fields and nested
///   `connection` are provided.
ConnectionArgsResolution resolveCommandArgumentsForExecution({
  required final String commandName,
  required final Map<String, Object?>? arguments,
}) {
  final parsed = parseConnectionOverrideArguments(arguments: arguments);
  final parseError = parsed.error;
  if (parseError != null) {
    return parsed;
  }

  final sanitized = Map<String, Object?>.from(parsed.sanitizedArgs);
  final selectorCommand = _isSelectorCommand(commandName);

  if (!selectorCommand) {
    final legacyFields =
        sanitized.keys
            .where((final key) => _legacyFlatConnectionFields.contains(key))
            .toList()
          ..sort();
    if (legacyFields.isNotEmpty) {
      return ConnectionArgsResolution(
        sanitizedArgs: sanitized,
        preconnectCommand: null,
        connectionProvided: parsed.connectionProvided,
        error: CoreResult.failure(
          code: CoreErrorCode.invalidCommand,
          message:
              'Invalid command args: top-level ${legacyFields.join(', ')} are not supported. '
              'Use args.connection instead.',
          details: {
            'legacyFields': legacyFields,
            'howToFix': {
              'connection': {
                for (final field in legacyFields) field: sanitized[field],
              },
            },
          },
        ),
      );
    }

    return ConnectionArgsResolution(
      sanitizedArgs: sanitized,
      preconnectCommand: parsed.preconnectCommand,
      connectionProvided: parsed.connectionProvided,
    );
  }

  if (!parsed.connectionProvided) {
    return ConnectionArgsResolution(
      sanitizedArgs: sanitized,
      preconnectCommand: null,
      connectionProvided: false,
    );
  }

  final conflictingNativeFields = _nativeSelectorFields(
    commandName,
  ).where((final key) => sanitized.containsKey(key)).toList()..sort();
  if (conflictingNativeFields.isNotEmpty) {
    return ConnectionArgsResolution(
      sanitizedArgs: sanitized,
      preconnectCommand: null,
      connectionProvided: true,
      error: CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message:
            'Invalid command args: cannot combine args.connection with native selector field(s): '
            '${conflictingNativeFields.join(', ')}',
        details: {
          'conflictingFields': conflictingNativeFields,
          'selectorCommand': commandName,
        },
      ),
    );
  }

  final preconnectCommand = parsed.preconnectCommand;
  if (preconnectCommand == null) {
    return ConnectionArgsResolution(
      sanitizedArgs: sanitized,
      preconnectCommand: null,
      connectionProvided: true,
    );
  }

  return ConnectionArgsResolution(
    sanitizedArgs: {
      ...sanitized,
      ..._selectorArgsFromConnectCommand(preconnectCommand),
    },
    preconnectCommand: null,
    connectionProvided: true,
  );
}

ConnectionArgsResolution _withFieldError({
  required final Map<String, Object?> sanitized,
  required final CoreResult fieldError,
  required final bool hasConnection,
}) {
  return ConnectionArgsResolution(
    sanitizedArgs: sanitized,
    preconnectCommand: null,
    connectionProvided: hasConnection,
    error: fieldError,
  );
}

Map<String, Object?> _selectorArgsFromConnectCommand(
  final ConnectCommand command,
) {
  return {
    'mode': command.mode.name,
    if (command.targetId != null) 'targetId': command.targetId,
    if (command.host != null) 'host': command.host,
    if (command.port != null) 'port': command.port,
    if (command.uri != null) 'uri': command.uri,
    if (command.forceReconnect) 'force': true,
  };
}

({String? value, CoreResult? error}) _parseOptionalStringField({
  required final String key,
  required final Map<String, Object?> source,
}) {
  if (!source.containsKey(key)) {
    return (value: null, error: null);
  }

  final raw = source[key];
  if (raw is! String) {
    return (
      value: null,
      error: _invalidConnectionField(
        field: key,
        expected: 'string',
        actual: raw,
      ),
    );
  }

  final trimmed = raw.trim();
  return (value: trimmed.isEmpty ? null : trimmed, error: null);
}

({CoreConnectionMode? value, CoreResult? error}) _parseModeField(
  final Map<String, Object?> source,
) {
  if (!source.containsKey('mode')) {
    return (value: null, error: null);
  }

  final raw = source['mode'];
  if (raw is! String) {
    return (
      value: null,
      error: _invalidConnectionField(
        field: 'mode',
        expected: 'string (auto|manual|uri)',
        actual: raw,
      ),
    );
  }

  return switch (raw.trim()) {
    'auto' => (value: CoreConnectionMode.auto, error: null),
    'manual' => (value: CoreConnectionMode.manual, error: null),
    'uri' => (value: CoreConnectionMode.uri, error: null),
    _ => (
      value: null,
      error: CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message: 'Invalid connection.mode: expected one of auto, manual, uri',
      ),
    ),
  };
}

({int? value, CoreResult? error}) _parsePortField(
  final Map<String, Object?> source,
) {
  if (!source.containsKey('port')) {
    return (value: null, error: null);
  }

  final raw = source['port'];
  final parsed = switch (raw) {
    final int value => value,
    final num value when value == value.toInt() => value.toInt(),
    _ => null,
  };

  if (parsed == null || parsed <= 0) {
    return (
      value: null,
      error: _invalidConnectionField(
        field: 'port',
        expected: 'positive integer',
        actual: raw,
      ),
    );
  }

  return (value: parsed, error: null);
}

({bool? value, CoreResult? error}) _parseBoolField({
  required final String key,
  required final Map<String, Object?> source,
}) {
  if (!source.containsKey(key)) {
    return (value: null, error: null);
  }

  final raw = source[key];
  if (raw is! bool) {
    return (
      value: null,
      error: _invalidConnectionField(
        field: key,
        expected: 'boolean',
        actual: raw,
      ),
    );
  }

  return (value: raw, error: null);
}

CoreResult _invalidConnectionField({
  required final String field,
  required final String expected,
  required final Object? actual,
}) {
  return CoreResult.failure(
    code: CoreErrorCode.invalidCommand,
    message: 'Invalid connection.$field: expected $expected',
    details: {
      'field': field,
      'expected': expected,
      'actualType': actual == null ? 'null' : actual.runtimeType.toString(),
    },
  );
}

Map<String, Object?> _asMap(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

bool _isSelectorCommand(final String commandName) =>
    commandName == 'connect' || commandName == 'session_start';

Set<String> _nativeSelectorFields(final String commandName) {
  if (commandName == 'session_start') {
    return _selectorFieldsWithoutForceReconnect;
  }
  return _selectorFieldsWithoutForceReconnect;
}

const Set<String> _selectorFieldsWithoutForceReconnect = {
  'mode',
  'targetId',
  'target-id',
  'host',
  'port',
  'uri',
  'force',
};

const Set<String> _legacyFlatConnectionFields = {'host', 'port', 'uri'};

const Set<String> _connectionOverrideFields = {
  'targetId',
  'mode',
  'host',
  'port',
  'uri',
  'forceReconnect',
};
