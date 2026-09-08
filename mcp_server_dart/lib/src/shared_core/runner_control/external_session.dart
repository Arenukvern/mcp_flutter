// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/runner_control/runner_control.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// Contract version of the runner discovery file
/// (`<project>/.flutter_mcp/runner-session.json` by default) this adapter
/// speaks. Readers reject unknown schema values (frozen dev-session contract,
/// spec v2).
const int externalSessionSchema = 1;

/// Parsed contents of a runner's discovery file (schema 1).
///
/// The file is written by the EXTERNAL runner process (not by the toolkit) at
/// session start and deleted by the runner at session exit; absent means no
/// live delegable session. All fields except [runner] are required by the
/// frozen contract; unknown extra fields are tolerated, unknown schema values
/// are rejected.
@immutable
final class ExternalSessionConfig {
  const ExternalSessionConfig({
    required this.schema,
    required this.vmServiceUri,
    required this.controlPort,
    required this.deviceId,
    required this.pid,
    required this.startedAt,
    this.runner,
  });

  /// Parses and validates a decoded discovery-file payload.
  ///
  /// Throws [RunnerControlException] with an actionable message when the file
  /// is corrupt or written by an incompatible schema.
  factory ExternalSessionConfig.fromJson(
    final Map<Object?, Object?> json, {
    required final String filePath,
  }) {
    final schema = _requireInt(json, 'schema', filePath);
    if (schema != externalSessionSchema) {
      throw RunnerControlException(
        'Unsupported $filePath schema: $schema '
        '(this toolkit speaks schema $externalSessionSchema). '
        'Upgrade the toolkit or the runner so both use the same frozen '
        'contract.',
      );
    }

    final vmServiceUri = _requireString(json, 'vm_service_uri', filePath);
    final controlPort = _requirePort(json, 'control_port', filePath);
    final deviceId = _requireString(json, 'device_id', filePath);
    final pid = _requireInt(json, 'pid', filePath);
    final startedAt = _requireString(json, 'started_at', filePath);
    final runner = json['runner'];
    final runnerName = runner is String && runner.isNotEmpty ? runner : null;

    return ExternalSessionConfig(
      schema: schema,
      runner: runnerName,
      vmServiceUri: vmServiceUri,
      controlPort: controlPort,
      deviceId: deviceId,
      pid: pid,
      startedAt: startedAt,
    );
  }

  /// [externalSessionSchema] is the only supported value.
  final int schema;

  /// Display metadata supplied by the runner itself (optional per the frozen
  /// contract). Surfaced verbatim in delegation results; the toolkit never
  /// derives behavior from it.
  final String? runner;

  /// Live app VM service websocket URI (`ws://127.0.0.1:<port>/<token>/ws`).
  final String vmServiceUri;

  /// TCP control port of the owning runner session (127.0.0.1 only).
  final int controlPort;

  final String deviceId;
  final int pid;
  final String startedAt;

  static int _requireInt(
    final Map<Object?, Object?> json,
    final String key,
    final String filePath,
  ) {
    final value = json[key];
    if (value is int) return value;
    throw RunnerControlException(
      'Corrupt $filePath: "$key" must be an integer, got: $value',
    );
  }

  static String _requireString(
    final Map<Object?, Object?> json,
    final String key,
    final String filePath,
  ) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw RunnerControlException(
      'Corrupt $filePath: "$key" must be a non-empty string, got: $value',
    );
  }

  static int _requirePort(
    final Map<Object?, Object?> json,
    final String key,
    final String filePath,
  ) {
    final port = _requireInt(json, key, filePath);
    if (port > 0 && port <= 65535) return port;
    throw RunnerControlException(
      'Corrupt $filePath: "$key" must be a TCP port between 1 and 65535, '
      'got: $port',
    );
  }
}

/// [RunnerControl] implementation for a live session owned by an EXTERNAL
/// runner process (any runner speaking the frozen dev-session contract,
/// spec v2).
///
/// Discovery: the runner writes a conforming session file (default
/// `<project>/.flutter_mcp/runner-session.json`) at session start and deletes
/// it at session exit. The session is the only compile-capable channel for
/// the app it owns, so reload/restart are delegated to its TCP control
/// channel (127.0.0.1 only, JSON lines) instead of attempting VM-service
/// reloads the toolkit can never compile for.
///
/// The `runner` field of the file is display metadata only: it is surfaced
/// verbatim in results and never used for behavior. The control protocol
/// carries no auth by design (localhost-only dev tool).
final class ExternalSessionRunnerControl implements RunnerControl {
  ExternalSessionRunnerControl({
    required final String sessionFile,
    this.logger,
    this.connectTimeout = defaultConnectTimeout,
    this.probeTimeout = defaultProbeTimeout,
    this.reloadTimeout = defaultReloadTimeout,
    this.restartTimeout = defaultRestartTimeout,
  }) : _sessionFile = p.absolute(sessionFile);

  /// Default discovery-file location for [projectDir]: sibling of the
  /// toolkit's own `.flutter_mcp/state.json` (same directory, different
  /// writer, different lifecycle).
  static String defaultSessionPathFor(final String projectDir) => p.join(
    p.absolute(projectDir),
    '.flutter_mcp',
    'runner-session.json',
  );

  /// [RunnerControl.runnerName] used before a discovery file has been read
  /// (for example when the file is absent). Once a file is read, the
  /// runner-provided `runner` display metadata takes over.
  static const String defaultRunnerName = 'external-session';

  /// Bounded, generous-enough timeouts: the control channel is localhost, but
  /// a restart fallback (relaunch + re-attach) can legitimately take a while.
  static const Duration defaultConnectTimeout = Duration(seconds: 2);
  static const Duration defaultProbeTimeout = Duration(milliseconds: 500);
  static const Duration defaultReloadTimeout = Duration(seconds: 30);
  static const Duration defaultRestartTimeout = Duration(seconds: 120);

  final String _sessionFile;

  /// Optional logging callback for delegation diagnostics.
  final CoreLogger? logger;
  final Duration connectTimeout;
  final Duration probeTimeout;
  final Duration reloadTimeout;
  final Duration restartTimeout;

  /// The runner-supplied display name from the most recent successful read of
  /// the discovery file, or null when no file has been read yet.
  String? _runnerDisplayName;

  int _nextRequestId = 0;

  String get sessionFilePath => _sessionFile;

  @override
  String get runnerName => _runnerDisplayName ?? defaultRunnerName;

  @override
  Future<bool> isAlive() async {
    final config = await readSessionConfigOrNull();
    if (config == null) return false;
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        config.controlPort,
        timeout: probeTimeout,
      );
      socket.destroy();
      return true;
    } catch (e) {
      _log(
        LoggingLevel.debug,
        'runner control probe failed on 127.0.0.1:${config.controlPort}: $e',
      );
      return false;
    }
  }

  @override
  Future<RunnerControlOutcome> reload() async {
    final config = await _requireSessionConfig();
    return _runRequest(
      method: 'reload',
      config: config,
      timeout: reloadTimeout,
    );
  }

  @override
  Future<RunnerControlOutcome> restart() async {
    final config = await _requireSessionConfig();
    try {
      return await _runRequest(
        method: 'restart',
        config: config,
        timeout: restartTimeout,
      );
    } on _ControlConnectionClosedException {
      // Frozen contract: the control connection may close mid-restart when the
      // attach-mode fallback (relaunch + re-attach) triggers. Re-read the
      // discovery file ONCE — the relaunched app owns a new wsUri — and
      // surface the relaunch so the caller can retry the CONNECTION (never
      // the restart itself).
      return _outcomeAfterRelaunchFallback(previousConfig: config);
    }
  }

  /// Asks the session for its status (protocol `status` method). Useful for
  /// diagnostics; not part of the [RunnerControl] seam.
  Future<Map<String, Object?>> status() async {
    final config = await _requireSessionConfig();
    final result = await _exchange(
      method: 'status',
      config: config,
      timeout: probeTimeout,
    );
    return result;
  }

  @override
  Future<String?> liveVmServiceUri() async =>
      (await readSessionConfigOrNull())?.vmServiceUri;

  /// Reads and validates the runner's discovery file.
  ///
  /// Returns null when the file does not exist (no live session). Throws
  /// [RunnerControlException] when it exists but is unreadable or corrupt.
  Future<ExternalSessionConfig?> readSessionConfigOrNull() async {
    final file = File(_sessionFile);
    if (!file.existsSync()) return null;
    return _parseSessionFile(file);
  }

  Future<ExternalSessionConfig> _requireSessionConfig() async {
    final config = await readSessionConfigOrNull();
    if (config == null) {
      throw RunnerControlException(
        'No live dev session: $_sessionFile does not exist. Start the runner '
        'in this project (it writes the discovery file at session start and '
        'removes it on exit), or point --runner-session-file at it.',
      );
    }
    return config;
  }

  ExternalSessionConfig _parseSessionFile(final File file) {
    String contents;
    try {
      contents = file.readAsStringSync();
    } catch (e) {
      throw RunnerControlException(
        'Cannot read ${file.path}: $e. '
        'Delete the stale file or restart the runner session.',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException catch (e) {
      throw RunnerControlException(
        'Corrupt ${file.path}: invalid JSON (${e.message}). '
        'Restart the runner session to regenerate it.',
      );
    }
    if (decoded is! Map) {
      throw RunnerControlException(
        'Corrupt ${file.path}: expected a JSON object, got ${decoded.runtimeType}.',
      );
    }
    final config = ExternalSessionConfig.fromJson(
      decoded.cast<Object?, Object?>(),
      filePath: file.path,
    );
    if (config.runner != null) _runnerDisplayName = config.runner;
    return config;
  }

  Future<RunnerControlOutcome> _runRequest({
    required final String method,
    required final ExternalSessionConfig config,
    required final Duration timeout,
  }) async {
    try {
      final result = await _exchange(
        method: method,
        config: config,
        timeout: timeout,
      );
      return _outcomeFromResult(result);
    } on _ControlRequestFailedException catch (e) {
      return RunnerControlOutcome(ok: false, error: e.message);
    } on _ControlConnectionClosedException {
      if (method == 'restart') rethrow;
      // Frozen contract: the connection may close on session end. Distinguish
      // a dead session from a transport hiccup so the error is actionable.
      final stillThere = await readSessionConfigOrNull();
      return RunnerControlOutcome(
        ok: false,
        error: stillThere == null
            ? 'the dev session ended while $method was in flight '
                '(discovery file $_sessionFile was removed). '
                'Start a new runner session and retry.'
            : 'the runner control connection closed during "$method" '
                '(127.0.0.1:${config.controlPort}) before a response arrived. '
                'The session discovery file still exists; retry, and if it '
                'keeps failing restart the runner session.',
      );
    } on TimeoutException {
      return RunnerControlOutcome(
        ok: false,
        error: 'runner control request "$method" timed out after '
            '${timeout.inSeconds}s on 127.0.0.1:${config.controlPort}. The '
            'session may be busy (for example mid relaunch); retry, and if it '
            'stays unresponsive restart the runner session.',
      );
    } on SocketException catch (e) {
      return RunnerControlOutcome(
        ok: false,
        error: 'Cannot reach the runner control channel at '
            '127.0.0.1:${config.controlPort}: $e. Is the runner session that '
            'wrote $_sessionFile still running?',
      );
    }
  }

  RunnerControlOutcome _outcomeFromResult(final Map<String, Object?> result) {
    final fallback = result['fallback'] == true;
    return RunnerControlOutcome(ok: true, fallback: fallback, raw: result);
  }

  /// Handles the restart EOF fallback: re-read the discovery file once and
  /// report the (possibly new) app endpoint. Never re-sends the restart.
  Future<RunnerControlOutcome> _outcomeAfterRelaunchFallback({
    required final ExternalSessionConfig previousConfig,
  }) async {
    ExternalSessionConfig? next;
    try {
      next = await readSessionConfigOrNull();
    } on RunnerControlException {
      next = null;
    }

    if (next == null) {
      return RunnerControlOutcome(
        ok: false,
        sessionRelaunched: true,
        vmServiceUri: previousConfig.vmServiceUri,
        error: 'the dev session ended during the restart fallback: '
            '$_sessionFile was removed. Start a new runner session and '
            'reconnect.',
        raw: const {'fallback': true, 'sessionEnded': true},
      );
    }

    final uriChanged = next.vmServiceUri != previousConfig.vmServiceUri;
    _log(
      LoggingLevel.info,
      'runner control connection closed mid-restart (relaunch fallback); '
      're-read the discovery file once: '
      '${uriChanged ? 'new' : 'unchanged'} vm_service_uri '
      '${next.vmServiceUri}',
    );
    return RunnerControlOutcome(
      ok: true,
      fallback: true,
      sessionRelaunched: true,
      vmServiceUri: next.vmServiceUri,
      raw: <String, Object?>{
        'fallback': true,
        'inferred': 'relaunch_fallback_eof',
        'vmServiceUriChanged': uriChanged,
        'session': <String, Object?>{
          'vm_service_uri': next.vmServiceUri,
          'control_port': next.controlPort,
          'pid': next.pid,
          'started_at': next.startedAt,
        },
      },
    );
  }

  Future<Map<String, Object?>> _exchange({
    required final String method,
    required final ExternalSessionConfig config,
    required final Duration timeout,
  }) async {
    final id = _nextRequestId++;
    Socket? socket;
    StreamSubscription<String>? subscription;
    final response = Completer<Map<String, Object?>>();

    void fail(final Object error) {
      if (!response.isCompleted) response.completeError(error);
    }

    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        config.controlPort,
        timeout: connectTimeout,
      );
      final request = jsonEncode(<String, Object?>{'id': id, 'method': method});
      socket.write('$request\n');

      final lines = socket
          .map(utf8.decode)
          .transform(const LineSplitter());
      subscription = lines.listen(
        (final line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || response.isCompleted) return;
          Object? decoded;
          try {
            decoded = jsonDecode(trimmed);
          } on FormatException {
            // Not a JSON line — ignore junk and keep waiting for the reply.
            return;
          }
          if (decoded is! Map || decoded['id'] != id) return;
          if (decoded['ok'] == true) {
            if (!response.isCompleted) {
              response.complete(_coerceResultMap(decoded['result']));
            }
          } else {
            fail(
              _ControlRequestFailedException(
                (decoded['error'] ?? 'the runner reported a failure without a '
                        'message')
                    .toString(),
              ),
            );
          }
        },
        onDone: () => fail(const _ControlConnectionClosedException()),
        onError: fail,
        cancelOnError: true,
      );

      final result = await response.future.timeout(
        timeout,
        onTimeout: () =>
            throw TimeoutException('runner control request "$method"', timeout),
      );
      return result;
    } finally {
      await subscription?.cancel();
      socket?.destroy();
    }
  }

  Map<String, Object?> _coerceResultMap(final Object? result) {
    if (result is Map<String, Object?>) return result;
    if (result is Map) return result.cast<String, Object?>();
    return <String, Object?>{'result': result};
  }

  void _log(final LoggingLevel level, final String message) {
    logger?.call(level, message, logger: runnerName);
  }
}

final class _ControlRequestFailedException implements Exception {
  const _ControlRequestFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The control socket closed before a matching response arrived.
final class _ControlConnectionClosedException implements Exception {
  const _ControlConnectionClosedException();

  @override
  String toString() =>
      'runner control connection closed before a response arrived';
}
