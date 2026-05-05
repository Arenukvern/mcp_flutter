// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catching_errors

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_mcp_toolkit_server/src/cli/diagnostics/bundle_builder.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/session/session_manager.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/sessions_persistence/safe_writes.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/sessions_persistence/snapshot_store.dart';
import 'package:flutter_mcp_toolkit_server/src/runtime_version.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/command_executor.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/commands/commands.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/error_codes.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/results.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_override.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/preconnect.dart';

final class CliDaemonServer {
  CliDaemonServer({
    required this.executor,
    required this.sessionManager,
    required this.catalog,
    required this.snapshotStore,
    required this.bundleBuilder,
    required this.configuration,
    this.input,
    this.output,
    this.error,
  });

  final DefaultCoreCommandExecutor executor;
  final SessionManager sessionManager;
  final CommandCatalog catalog;
  final SnapshotStore snapshotStore;
  final BundleBuilder bundleBuilder;
  final CoreRuntimeConfiguration configuration;
  final Stream<String>? input;
  final io.Stdout? output;
  final io.IOSink? error;

  final Map<String, _WatchHandle> _watches = <String, _WatchHandle>{};
  final Set<String> _cancelledRequestIds = <String>{};

  int _watchCounter = 0;

  Stream<String> get _inputLines {
    final customInput = input;
    if (customInput != null) {
      return customInput;
    }

    return io.stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((final line) => line.trim().isNotEmpty);
  }

  io.Stdout get _stdout => output ?? io.stdout;
  io.IOSink get _stderr => error ?? io.stderr;

  Future<void> serve() async {
    await for (final line in _inputLines) {
      await _handleLine(line);
    }

    await _stopAllWatches(reason: 'stdin_closed');
  }

  Future<void> _handleLine(final String line) async {
    Map<String, Object?> request;

    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, Object?>) {
        request = decoded;
      } else if (decoded is Map) {
        request = decoded.cast<String, Object?>();
      } else {
        _sendError(
          id: null,
          code: -32600,
          message: 'Invalid Request',
          data: const <String, Object?>{'reason': 'request must be an object'},
        );
        return;
      }
    } on FormatException {
      _sendError(id: null, code: -32700, message: 'Parse error');
      return;
    }

    final method = request['method']?.toString();
    final id = request['id'];

    if (method == null || method.isEmpty) {
      _sendError(id: id, code: -32600, message: 'Invalid Request');
      return;
    }

    if (method == r'$/cancelRequest') {
      final params = _asMapOrEmpty(request['params']);
      final cancelId = params['id'];
      if (cancelId != null) {
        _cancelledRequestIds.add('$cancelId');
      }
      return;
    }

    final isNotification = !request.containsKey('id');

    try {
      final paramsValue = request['params'];
      if (paramsValue != null && paramsValue is! Map) {
        throw const _JsonRpcException(
          code: -32602,
          message: 'Invalid params: params must be an object',
        );
      }
      final result = await _dispatch(
        method: method,
        params: _asMapOrEmpty(paramsValue),
        id: id,
      );
      if (!isNotification) {
        _send({'jsonrpc': '2.0', 'id': id, 'result': result});
      }
    } on _JsonRpcException catch (e) {
      if (!isNotification) {
        _sendError(id: id, code: e.code, message: e.message, data: e.data);
      }
    } on Exception catch (e) {
      if (!isNotification) {
        _sendError(
          id: id,
          code: -32000,
          message: 'Internal error',
          data: <String, Object?>{'error': '$e'},
        );
      }
    }
  }

  Future<Map<String, Object?>> _dispatch({
    required final String method,
    required final Map<String, Object?> params,
    final Object? id,
  }) async {
    _throwIfCancelled(id);

    return switch (method) {
      'initialize' => _handleInitialize(),
      'capabilities/get' => _handleCapabilities(),
      'schema/get' => _handleSchema(params),
      'command/execute' => _handleCommandExecute(params, id: id),
      'watch/start' => _handleWatchStart(params),
      'watch/stop' => _handleWatchStop(params),
      'snapshot/create' => _handleSnapshotCreate(params),
      'snapshot/diff' => _handleSnapshotDiff(params),
      'bundle/create' => _handleBundleCreate(params),
      'session/start' => _handleSessionStart(params),
      'session/end' => _handleSessionEnd(params),
      _ => throw _JsonRpcException(
        code: -32601,
        message: 'Method not found: $method',
      ),
    };
  }

  Map<String, Object?> _handleInitialize() {
    final capabilities = catalog.capabilities(configuration: configuration);
    return {
      'protocolVersion': capabilities.protocolVersion,
      'serverInfo': {'name': kFlutterMcpCliName, 'version': kFlutterMcpVersion},
      'capabilities': capabilities.toJson(),
    };
  }

  Map<String, Object?> _handleCapabilities() {
    final capabilities = catalog.capabilities(configuration: configuration);
    return capabilities.toJson();
  }

  Map<String, Object?> _handleSchema(final Map<String, Object?> params) {
    final name = _optionalString(params, 'name');
    try {
      return catalog.schema(name: name);
    } on ArgumentError catch (e) {
      throw _JsonRpcException(
        code: -32602,
        message: 'Invalid params',
        data: <String, Object?>{'error': '$e'},
      );
    }
  }

  Future<Map<String, Object?>> _handleCommandExecute(
    final Map<String, Object?> params, {
    final Object? id,
  }) async {
    _throwIfCancelled(id);

    final name = _requiredString(params, 'name');
    final rawArgs = _optionalObject(params, 'args');
    final sessionId = _optionalString(params, 'sessionId');
    final argsResolution = resolveCommandArgumentsForExecution(
      commandName: name,
      arguments: rawArgs,
    );
    final argsError = argsResolution.error;
    if (argsError != null) {
      throw _coreFailure(argsError);
    }

    final command = _buildCommandOrThrow(
      name: name,
      args: argsResolution.sanitizedArgs,
    );
    final execCommand = _wrapWithSessionIfNeeded(
      sessionId: sessionId,
      command: command,
    );

    final preconnectFailure = await preconnectForExecution(
      command: execCommand,
      executor: executor,
      sessionManager: sessionManager,
      explicitConnectionOverride: argsResolution.preconnectCommand,
    );
    if (preconnectFailure != null) {
      throw _coreFailure(preconnectFailure);
    }

    final result = await executor.execute(execCommand);
    if (!result.ok) {
      throw _coreFailure(result);
    }

    if (name == 'session_start' || name == 'session_end') {
      _emitSessionChanged(result);
    }

    return result.toEnvelopeJson();
  }

  Future<Map<String, Object?>> _handleWatchStart(
    final Map<String, Object?> params,
  ) async {
    final name = _requiredString(params, 'name');
    final rawArgs = _optionalObject(params, 'args');
    final sessionId = _optionalString(params, 'sessionId');
    final intervalMs = _optionalInt(params, 'intervalMs', fallback: 1000);
    final maxEvents = _optionalInt(params, 'maxEvents', fallback: 0);
    final stopOnError = _optionalBool(params, 'stopOnError', fallback: false);

    if (intervalMs <= 0) {
      throw const _JsonRpcException(
        code: -32602,
        message: 'Invalid params: intervalMs must be > 0',
      );
    }
    if (maxEvents < 0) {
      throw const _JsonRpcException(
        code: -32602,
        message: 'Invalid params: maxEvents must be >= 0',
      );
    }

    final watchIdRaw = _optionalString(params, 'watchId');
    final watchId = (watchIdRaw == null || watchIdRaw.isEmpty)
        ? _nextWatchId()
        : watchIdRaw;

    if (_watches.containsKey(watchId)) {
      throw const _JsonRpcException(
        code: -32602,
        message: 'Invalid params: watchId already exists',
      );
    }

    final argsResolution = resolveCommandArgumentsForExecution(
      commandName: name,
      arguments: rawArgs,
    );
    final argsError = argsResolution.error;
    if (argsError != null) {
      throw _coreFailure(argsError);
    }

    final command = _buildCommandOrThrow(
      name: name,
      args: argsResolution.sanitizedArgs,
    );
    final preconnectCommand = _wrapWithSessionIfNeeded(
      sessionId: sessionId,
      command: command,
    );
    final preconnectFailure = await preconnectForExecution(
      command: preconnectCommand,
      executor: executor,
      sessionManager: sessionManager,
      explicitConnectionOverride: argsResolution.preconnectCommand,
    );
    if (preconnectFailure != null) {
      throw _coreFailure(preconnectFailure);
    }

    final handle = _WatchHandle(
      id: watchId,
      sessionId: sessionId,
      commandName: name,
      command: command,
      intervalMs: intervalMs,
      maxEvents: maxEvents,
      stopOnError: stopOnError,
    );

    _watches[watchId] = handle;
    unawaited(_runWatch(handle));

    return {
      'watchId': watchId,
      'started': true,
      'intervalMs': intervalMs,
      'maxEvents': maxEvents,
      'stopOnError': stopOnError,
    };
  }

  Future<Map<String, Object?>> _handleWatchStop(
    final Map<String, Object?> params,
  ) async {
    final watchId = params['watchId']?.toString();
    if (watchId == null || watchId.isEmpty) {
      throw const _JsonRpcException(
        code: -32602,
        message: 'Invalid params: missing watchId',
      );
    }

    final watch = _watches[watchId];
    if (watch == null) {
      return {'watchId': watchId, 'stopped': false, 'reason': 'not_found'};
    }

    watch.stopRequested = true;
    return {'watchId': watchId, 'stopped': true};
  }

  Future<Map<String, Object?>> _handleSnapshotCreate(
    final Map<String, Object?> params,
  ) async {
    final name = _requiredString(params, 'name');
    final args = _optionalObject(params, 'args');
    final writeOptions = SafeWriteOptions(
      check: _optionalBool(params, 'check', fallback: false),
      diff: _optionalBool(params, 'diff', fallback: false),
      backup: _optionalBool(params, 'backup', fallback: false),
      noOverwrite: _optionalBool(params, 'noOverwrite', fallback: false),
    );

    try {
      final snapshot = await snapshotStore.createSnapshot(
        id: name,
        executor: executor,
        catalog: catalog,
        args: args,
        writeOptions: writeOptions,
      );
      if (_containsBlockedWrite(snapshot)) {
        throw _coreFailure(
          CoreResult.failure(
            code: CoreErrorCode.writeBlocked,
            message:
                'Snapshot target already exists and is blocked by noOverwrite',
            details: snapshot,
          ),
        );
      }
      return {'snapshot': snapshot};
    } on ArgumentError catch (e) {
      throw _JsonRpcException(
        code: -32602,
        message: 'Invalid params',
        data: <String, Object?>{'error': '$e'},
      );
    }
  }

  Future<Map<String, Object?>> _handleSnapshotDiff(
    final Map<String, Object?> params,
  ) async {
    final from = _requiredString(params, 'from');
    final to = _requiredString(params, 'to');

    try {
      final diff = await snapshotStore.diffSnapshots(fromId: from, toId: to);
      return {'diff': diff};
    } on ArgumentError catch (e) {
      throw _JsonRpcException(
        code: -32602,
        message: 'Invalid params',
        data: <String, Object?>{'error': '$e'},
      );
    }
  }

  Future<Map<String, Object?>> _handleBundleCreate(
    final Map<String, Object?> params,
  ) async {
    final fromSnapshot = _requiredString(params, 'fromSnapshot');
    final outputDir = _optionalString(params, 'output');
    final writeOptions = SafeWriteOptions(
      check: _optionalBool(params, 'check', fallback: false),
      diff: _optionalBool(params, 'diff', fallback: false),
      backup: _optionalBool(params, 'backup', fallback: false),
      noOverwrite: _optionalBool(params, 'noOverwrite', fallback: false),
    );
    final bundle = await bundleBuilder.createBundle(
      fromSnapshot: fromSnapshot,
      outputDirectory: outputDir,
      writeOptions: writeOptions,
    );
    if (_containsBlockedWrite(bundle)) {
      throw _coreFailure(
        CoreResult.failure(
          code: CoreErrorCode.writeBlocked,
          message: 'Bundle target already exists and is blocked by noOverwrite',
          details: bundle,
        ),
      );
    }

    return {'bundle': bundle};
  }

  Future<Map<String, Object?>> _handleSessionStart(
    final Map<String, Object?> params,
  ) async {
    final command = _buildCommandOrThrow(name: 'session_start', args: params);
    if (command is! SessionStartCommand) {
      throw const _JsonRpcException(
        code: -32603,
        message: 'Unexpected session command',
      );
    }

    final result = await sessionManager.startSession(command);
    if (!result.ok) {
      throw _coreFailure(result);
    }

    _emitSessionChanged(result);
    return result.toEnvelopeJson();
  }

  Future<Map<String, Object?>> _handleSessionEnd(
    final Map<String, Object?> params,
  ) async {
    final command = _buildCommandOrThrow(name: 'session_end', args: params);
    if (command is! SessionEndCommand) {
      throw const _JsonRpcException(
        code: -32603,
        message: 'Unexpected session command',
      );
    }

    final result = await sessionManager.endSession(command.sessionId);
    if (!result.ok) {
      throw _coreFailure(result);
    }

    _emitSessionChanged(result);
    return result.toEnvelopeJson();
  }

  CoreCommand _buildCommandOrThrow({
    required final String name,
    required final Map<String, Object?> args,
  }) {
    try {
      return catalog.buildCommand(name, args);
    } on ArgumentError catch (e) {
      throw _JsonRpcException(
        code: -32602,
        message: 'Invalid params',
        data: <String, Object?>{'error': '$e', 'name': name},
      );
    }
  }

  CoreCommand _wrapWithSessionIfNeeded({
    required final String? sessionId,
    required final CoreCommand command,
  }) {
    if (sessionId == null || sessionId.isEmpty) {
      return command;
    }

    if (command is SessionStartCommand ||
        command is SessionExecCommand ||
        command is SessionEndCommand) {
      return command;
    }

    return SessionExecCommand(sessionId: sessionId, command: command);
  }

  Future<void> _runWatch(final _WatchHandle watch) async {
    _sendWatchEvent(watch, 'watch/event', {
      'event': 'watch_started',
      'intervalMs': watch.intervalMs,
      'maxEvents': watch.maxEvents,
      'stopOnError': watch.stopOnError,
    });

    String stopReason = 'max_events_reached';

    while (!watch.stopRequested) {
      final execCommand = _wrapWithSessionIfNeeded(
        sessionId: watch.sessionId,
        command: watch.command,
      );

      final result = await executor.execute(execCommand);
      watch.emittedResults += 1;

      if (result.ok) {
        _sendWatchEvent(watch, 'watch/event', {
          'event': 'command_result',
          'result': result.toEnvelopeJson(),
        });
      } else {
        _sendWatchEvent(watch, 'watch/event', {
          'event': 'watch_error',
          'result': result.toEnvelopeJson(),
        });

        if (watch.stopOnError) {
          stopReason = 'stop_on_error';
          break;
        }
      }

      if (watch.maxEvents > 0 && watch.emittedResults >= watch.maxEvents) {
        stopReason = 'max_events_reached';
        break;
      }

      await Future<void>.delayed(Duration(milliseconds: watch.intervalMs));
    }

    if (watch.stopRequested) {
      stopReason = 'watch_stop_request';
    }

    _sendWatchEvent(watch, 'watch/event', {
      'event': 'watch_stopped',
      'reason': stopReason,
    });

    _watches.remove(watch.id);
  }

  void _sendWatchEvent(
    final _WatchHandle watch,
    final String method,
    final Map<String, Object?> payload,
  ) {
    watch.sequence += 1;
    final event = {
      'watchId': watch.id,
      'seq': watch.sequence,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'command': watch.commandName,
      if (watch.sessionId != null && watch.sessionId!.isNotEmpty)
        'sessionId': watch.sessionId,
      ...payload,
    };

    _send({'jsonrpc': '2.0', 'method': method, 'params': event});
  }

  void _emitSessionChanged(final CoreResult result) {
    final data = _asMapOrEmpty(result.data);
    final params = <String, Object?>{
      'sessionId': data['sessionId'] ?? result.meta['sessionId'],
      'activeSessionId': sessionManager.state.activeSessionId,
      'remainingSessions': sessionManager.state.sessions.length,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'result': result.toEnvelopeJson(),
    };
    _send({'jsonrpc': '2.0', 'method': 'session/changed', 'params': params});
  }

  Future<void> _stopAllWatches({required final String reason}) async {
    final ids = _watches.keys.toList();
    for (final id in ids) {
      final watch = _watches[id];
      if (watch == null) {
        continue;
      }
      watch.stopRequested = true;
      _sendWatchEvent(watch, 'watch/event', {
        'event': 'watch_stopped',
        'reason': reason,
      });
      _watches.remove(id);
    }
  }

  void _throwIfCancelled(final Object? id) {
    if (id == null) {
      return;
    }

    final key = '$id';
    if (_cancelledRequestIds.remove(key)) {
      throw const _JsonRpcException(code: -32800, message: 'Request cancelled');
    }
  }

  _JsonRpcException _coreFailure(final CoreResult result) {
    final error = result.error;
    if (error == null) {
      return const _JsonRpcException(
        code: -32000,
        message: 'Unknown core error',
      );
    }

    final descriptor = error.resolvedDescriptor;
    return _JsonRpcException(
      code: _jsonRpcCodeFromDescriptor(descriptor),
      message: error.message,
      data: {'error': error.toJson()},
    );
  }

  int _jsonRpcCodeFromDescriptor(final CoreErrorDescriptor descriptor) {
    final status = descriptor.httpLikeStatus;

    if (status >= 500) {
      return -32000;
    }

    if (status == 409) {
      return -32009;
    }

    if (status == 404) {
      return -32004;
    }

    if (status == 501 || status == 405) {
      return -32601;
    }

    if (status == 400 || status == 422) {
      return -32602;
    }

    return -32000;
  }

  void _sendError({
    required final Object? id,
    required final int code,
    required final String message,
    final Map<String, Object?>? data,
  }) {
    _send({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message, 'data': ?data},
    });
  }

  void _send(final Map<String, Object?> payload) {
    _stdout.writeln(jsonEncode(payload));
  }

  Map<String, Object?> _asMapOrEmpty(final Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }

  Map<String, Object?> _optionalObject(
    final Map<String, Object?> params,
    final String key,
  ) {
    if (!params.containsKey(key) || params[key] == null) {
      return const <String, Object?>{};
    }

    final value = params[key];
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }

    throw _JsonRpcException(
      code: -32602,
      message: 'Invalid params: $key must be an object',
    );
  }

  String _requiredString(final Map<String, Object?> params, final String key) {
    final value = params[key];
    if (value == null) {
      throw _JsonRpcException(
        code: -32602,
        message: 'Invalid params: missing $key',
      );
    }
    if (value is! String) {
      throw _JsonRpcException(
        code: -32602,
        message: 'Invalid params: $key must be a string',
      );
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw _JsonRpcException(
        code: -32602,
        message: 'Invalid params: missing $key',
      );
    }
    return trimmed;
  }

  String? _optionalString(final Map<String, Object?> params, final String key) {
    if (!params.containsKey(key) || params[key] == null) {
      return null;
    }
    final value = params[key];
    if (value is! String) {
      throw _JsonRpcException(
        code: -32602,
        message: 'Invalid params: $key must be a string',
      );
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _optionalInt(
    final Map<String, Object?> params,
    final String key, {
    required final int fallback,
  }) {
    if (!params.containsKey(key) || params[key] == null) {
      return fallback;
    }

    final value = params[key];
    if (value case final int v) {
      return v;
    }
    if (value case final num v when v == v.roundToDouble()) {
      return v.toInt();
    }

    throw _JsonRpcException(
      code: -32602,
      message: 'Invalid params: $key must be an integer',
    );
  }

  bool _optionalBool(
    final Map<String, Object?> params,
    final String key, {
    required final bool fallback,
  }) {
    if (!params.containsKey(key) || params[key] == null) {
      return fallback;
    }

    final value = params[key];
    if (value is bool) {
      return value;
    }

    throw _JsonRpcException(
      code: -32602,
      message: 'Invalid params: $key must be a boolean',
    );
  }

  bool _containsBlockedWrite(final Object? payload) {
    final map = _asMapOrEmpty(payload);
    final writeResults = map['writeResults'];
    if (writeResults is! List) {
      return false;
    }
    for (final entry in writeResults) {
      if (entry is! Map) {
        continue;
      }
      if ('${entry['status'] ?? ''}' == SafeWriteStatus.blocked) {
        return true;
      }
    }
    return false;
  }

  String _nextWatchId() {
    _watchCounter += 1;
    return 'watch_$_watchCounter';
  }

  void log(final String message) {
    _stderr.writeln('[CliDaemonServer] $message');
  }
}

final class _WatchHandle {
  _WatchHandle({
    required this.id,
    required this.commandName,
    required this.command,
    required this.intervalMs,
    required this.maxEvents,
    required this.stopOnError,
    this.sessionId,
  });

  final String id;
  final String commandName;
  final CoreCommand command;
  final String? sessionId;
  final int intervalMs;
  final int maxEvents;
  final bool stopOnError;

  bool stopRequested = false;
  int emittedResults = 0;
  int sequence = 0;
}

final class _JsonRpcException implements Exception {
  const _JsonRpcException({
    required this.code,
    required this.message,
    this.data,
  });

  final int code;
  final String message;
  final Map<String, Object?>? data;
}
