// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses, lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/commands/commands.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/types.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/flutter_tool_machine_discovery.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

@immutable
final class CoreEndpoint {
  const CoreEndpoint({
    required this.host,
    required this.port,
    this.wsPath = '/ws',
  });

  factory CoreEndpoint.fromUri(final Uri uri) {
    final normalizedHost = uri.host.isEmpty ? 'localhost' : uri.host;
    final normalizedPort = uri.hasPort ? uri.port : 0;
    if (normalizedPort <= 0) {
      throw FormatException('URI is missing port: $uri');
    }
    final normalizedPath = uri.path.isEmpty ? '/ws' : uri.path;
    return CoreEndpoint(
      host: normalizedHost,
      port: normalizedPort,
      wsPath: normalizedPath,
    );
  }

  final String host;
  final int port;
  final String wsPath;

  Uri get wsUri {
    final normalizedPath = wsPath.startsWith('/') ? wsPath : '/$wsPath';
    return Uri(scheme: 'ws', host: host, port: port, path: normalizedPath);
  }

  String get display => wsUri.toString();

  @override
  bool operator ==(final Object other) =>
      other is CoreEndpoint &&
      other.host == host &&
      other.port == port &&
      other.wsPath == wsPath;

  @override
  int get hashCode => Object.hash(host, port, wsPath);
}

final class CoreConnectionTarget {
  const CoreConnectionTarget({
    required this.targetId,
    required this.host,
    required this.port,
    required this.endpoint,
    required this.isSticky,
    required this.isCurrent,
    this.dtdUri,
    this.discoverySource = _portScanSource,
  });

  final String targetId;
  final String host;
  final int port;
  final String endpoint;
  final bool isSticky;
  final bool isCurrent;
  final String? dtdUri;
  final String discoverySource;

  static const String machineDiscoverySource = _machineSource;
  static const String portScanDiscoverySource = _portScanSource;

  static String buildTargetId({required final Uri vmServiceWsUri}) =>
      canonicalizeVmServiceWsUri(vmServiceWsUri).toString();

  static Uri canonicalizeVmServiceWsUri(final Uri vmServiceWsUri) =>
      FlutterToolMachineDiscovery.canonicalizeVmServiceWsUri(vmServiceWsUri);

  static Uri? parseTargetIdUri(final String value) =>
      FlutterToolMachineDiscovery.parseVmServiceWsUri(value);

  static bool isLegacyHostPortTargetId(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.contains('://') ||
        trimmed.contains('/') ||
        trimmed.contains('?') ||
        trimmed.contains('#')) {
      return false;
    }

    final delimiter = trimmed.lastIndexOf(':');
    if (delimiter <= 0 || delimiter == trimmed.length - 1) {
      return false;
    }

    final parsedPort = int.tryParse(trimmed.substring(delimiter + 1));
    return parsedPort != null && parsedPort > 0;
  }

  Map<String, Object?> toJson() => {
    'targetId': targetId,
    'host': host,
    'port': port,
    'endpoint': endpoint,
    if (dtdUri != null) 'dtdUri': dtdUri,
    'discoverySource': discoverySource,
    'isSticky': isSticky,
    'isCurrent': isCurrent,
  };
}

const _machineSource = 'flutter_tool_machine';
const _portScanSource = 'port_scan';

enum CoreConnectionFailureReason {
  multipleTargets,
  targetNotFound,
  noTargets,
  invalidUri,
  invalidTargetId,
}

final class CoreConnectionException implements Exception {
  const CoreConnectionException({
    required this.reason,
    required this.message,
    this.details,
  });

  final CoreConnectionFailureReason reason;
  final String message;
  final Object? details;

  @override
  String toString() => message;
}

final class EnsureConnectionResult {
  const EnsureConnectionResult._({
    required this.connected,
    this.code,
    this.message,
    this.details,
    this.recovery,
  });

  const EnsureConnectionResult.success({final Map<String, Object?>? recovery})
    : this._(
        connected: true,
        code: null,
        message: null,
        details: null,
        recovery: recovery,
      );

  const EnsureConnectionResult.failure({
    required final String code,
    required final String message,
    final Object? details,
  }) : this._(
         connected: false,
         code: code,
         message: message,
         details: details,
         recovery: null,
       );

  final bool connected;
  final String? code;
  final String? message;
  final Object? details;

  /// Set when [ensureConnectedWithPolicy] re-attached after a dropped session.
  final Map<String, Object?>? recovery;
}

typedef CoreFlutterTargetProbe =
    Future<bool> Function(CoreEndpoint endpoint, {required Duration timeout});

final class ConnectionContext {
  ConnectionContext({
    required this.defaultHost,
    required this.defaultPort,
    required this.logger,
    required this.discoverPorts,
    this.discoverMachineTargets,
    this.initialStickyEndpointUri,
    this.probeFlutterTarget,
  }) {
    final rawSticky = initialStickyEndpointUri;
    if (rawSticky == null || rawSticky.isEmpty) {
      return;
    }

    try {
      _stickyEndpoint = CoreEndpoint.fromUri(Uri.parse(rawSticky));
    } on Exception {
      // Keep startup resilient: invalid persisted URI should not fail boot.
      _stickyEndpoint = null;
    }
  }

  final String defaultHost;
  final int defaultPort;
  final CoreLogger logger;
  final Future<List<int>> Function() discoverPorts;
  final Future<List<FlutterMachineDiscoveryTarget>> Function()?
  discoverMachineTargets;
  final String? initialStickyEndpointUri;
  final CoreFlutterTargetProbe? probeFlutterTarget;

  VmService? _vmService;
  WebSocketChannel? _vmChannel;
  DartToolingDaemon? _dartToolingDaemon;

  CoreEndpoint? _activeEndpoint;
  CoreEndpoint? _stickyEndpoint;

  CoreConnectionMode _lastMode = CoreConnectionMode.auto;
  Map<String, Object?> _lastSelectionDiagnostics = const <String, Object?>{};
  Map<String, Object?> _lastDiscoveryDiagnostics = const <String, Object?>{};
  final Map<String, ({bool isFlutter, DateTime checkedAt})> _flutterProbeCache =
      <String, ({bool isFlutter, DateTime checkedAt})>{};

  bool _wasConnected = false;
  bool _disconnectedSinceLastConnect = false;
  Map<String, Object?>? _pendingRecovery;

  /// Single-flight gate shared by [hotReload] and [hotRestart].
  ///
  /// The VM can only safely reload one set of sources at a time; concurrent
  /// callers (e.g. two live-edit bubbles applying in parallel) must wait for
  /// an in-progress reload instead of issuing a second one. [ConnectionContext]
  /// is per VM-service target, so a single future is sufficient here — the
  /// per-`targetId` `Map<String, Future<…>>` exists implicitly as "one entry
  /// per ConnectionContext instance".
  Future<Map<String, dynamic>?>? _pendingReloadOrRestart;

  /// Callback invoked when a previously disconnected context reconnects.
  void Function()? onReconnected;

  VmService? get vmService => _vmService;

  /// When non-null and positive, [resolveConnectedVmPid] returns this value
  /// without querying [vmService]. For tests only.
  @visibleForTesting
  int? debugConnectedVmPidOverride;

  /// Test-only: when set, view_details scan uses this payload without VM I/O.
  @visibleForTesting
  Map<String, Object?>? debugViewDetailsPayload;

  /// Test-only: when set, view_screenshots uses this payload without VM I/O.
  @visibleForTesting
  Map<String, Object?>? debugViewScreenshotsPayload;

  /// VM process id for the active service connection, or null if unknown.
  Future<int?> resolveConnectedVmPid() async {
    final override = debugConnectedVmPidOverride;
    if (override != null) {
      return override > 0 ? override : null;
    }

    final service = _vmService;
    if (service == null) {
      return null;
    }
    try {
      final vm = await service.getVM();
      final pid = vm.pid;
      if (pid is int && pid > 0) {
        return pid;
      }
      return int.tryParse('$pid');
    } on Object {
      return null;
    }
  }

  DartToolingDaemon? get dartToolingDaemon => _dartToolingDaemon;
  bool get isConnected => _vmService != null;
  CoreEndpoint? get activeEndpoint => _activeEndpoint;
  CoreEndpoint? get stickyEndpoint => _stickyEndpoint;
  CoreConnectionMode get lastMode => _lastMode;
  Map<String, Object?> get lastSelectionDiagnostics =>
      _lastSelectionDiagnostics;
  Map<String, Object?> get lastDiscoveryDiagnostics =>
      _lastDiscoveryDiagnostics;

  /// Consumes and clears recovery metadata from the last successful re-attach.
  Map<String, Object?>? takePendingRecovery() {
    final recovery = _pendingRecovery;
    _pendingRecovery = null;
    return recovery;
  }

  void setStickyEndpointFromUri(final String uri) {
    _stickyEndpoint = CoreEndpoint.fromUri(Uri.parse(uri));
  }

  Future<Map<String, Object?>> connect({
    final CoreConnectionMode mode = CoreConnectionMode.auto,
    final String? targetId,
    final String? uri,
    final String? host,
    final int? port,
    final bool forceReconnect = false,
    final Duration timeout = const Duration(seconds: 2),
  }) async {
    final resolution = await _resolveEndpoint(
      mode: mode,
      targetId: targetId,
      uri: uri,
      host: host,
      port: port,
    );

    final endpoint = resolution.endpoint;
    final diagnostics = resolution.diagnostics;

    final reusedConnection =
        !forceReconnect && isConnected && _activeEndpoint == endpoint;
    if (reusedConnection) {
      _stickyEndpoint = endpoint;
      _lastMode = mode;
      _lastSelectionDiagnostics = diagnostics;
      return {
        'connected': true,
        'reusedConnection': true,
        'endpoint': endpoint.display,
        ...diagnostics,
      };
    }

    final shouldNotifyReconnect =
        _wasConnected && _disconnectedSinceLastConnect;
    final previousEndpoint = shouldNotifyReconnect
        ? (_activeEndpoint?.display ?? _stickyEndpoint?.display)
        : null;

    await disconnect();
    await _connectToEndpoint(endpoint, timeout: timeout);

    _stickyEndpoint = endpoint;
    _activeEndpoint = endpoint;
    _lastMode = mode;
    _lastSelectionDiagnostics = diagnostics;
    _wasConnected = true;
    _disconnectedSinceLastConnect = false;

    if (shouldNotifyReconnect) {
      _pendingRecovery = <String, Object?>{
        'reattachedTo': endpoint.display,
        'previousEndpoint': ?previousEndpoint,
        'decision': diagnostics['decision'],
      };
      onReconnected?.call();
    }

    return {
      'connected': true,
      'reusedConnection': false,
      'endpoint': endpoint.display,
      if (shouldNotifyReconnect) 'recovery': _pendingRecovery,
      ...diagnostics,
    };
  }

  Future<EnsureConnectionResult> ensureConnectedWithPolicy({
    final Duration timeout = const Duration(seconds: 2),
  }) async {
    if (isConnected) {
      final healthy = await _isCurrentConnectionHealthy(
        timeout: _connectionHealthCheckTimeout,
      );
      if (healthy) {
        return const EnsureConnectionResult.success();
      }

      await disconnect();
    }

    try {
      final connectResult = await connect(timeout: timeout);
      final recovery = connectResult['recovery'];
      return EnsureConnectionResult.success(
        recovery: recovery is Map<String, Object?>
            ? recovery
            : recovery is Map
            ? recovery.cast<String, Object?>()
            : _pendingRecovery,
      );
    } on CoreConnectionException catch (e) {
      if (e.reason == CoreConnectionFailureReason.multipleTargets) {
        return EnsureConnectionResult.failure(
          code: CoreErrorCode.connectionSelectionRequired,
          message: e.message,
          details: _enrichConnectionFailureDetails(e.details),
        );
      }

      return EnsureConnectionResult.failure(
        code: CoreErrorCode.vmNotConnected,
        message: 'VM service not connected',
        details: _enrichConnectionFailureDetails(e.details),
      );
    } catch (e) {
      logger(
        LoggingLevel.warning,
        'Failed to ensure connection: $e',
        logger: 'ConnectionContext',
      );
      return EnsureConnectionResult.failure(
        code: CoreErrorCode.vmNotConnected,
        message: 'VM service not connected',
        details: _enrichConnectionFailureDetails(null),
      );
    }
  }

  Map<String, Object?> _enrichConnectionFailureDetails(final Object? details) {
    final base = switch (details) {
      final Map<String, Object?> value => Map<String, Object?>.from(value),
      final Map value => value.cast<String, Object?>(),
      _ => <String, Object?>{},
    };
    return {
      ...base,
      'stickyEndpoint': _stickyEndpoint?.display,
      'discovery': _lastDiscoveryDiagnostics,
      'suggestedActions': <String>[
        'Run discover_debug_apps and pass connection.targetId explicitly.',
        'After hot restart, use the new app.debugPort.wsUri (token changes).',
        if (discoverMachineTargets != null)
          'Pass --flutter-project-dir so machine discovery can find the app.',
      ],
    };
  }

  Future<bool> ensureConnected({
    final Duration timeout = const Duration(seconds: 2),
  }) async => (await ensureConnectedWithPolicy(timeout: timeout)).connected;

  Future<List<CoreConnectionTarget>> discoverTargets() async {
    final machineTargets = await _discoverMachineTargets();
    final machineOnlyTargets = _buildMachineTargets(machineTargets);
    if (machineOnlyTargets.isNotEmpty) {
      _lastDiscoveryDiagnostics = {
        'strategyUsed': 'machine_only',
        'machineRawCount': machineTargets.length,
        'machineValidCount': machineOnlyTargets.length,
        'portRawCount': 0,
        'portCandidateCount': 0,
        'portFlutterCount': 0,
        'portDroppedNonFlutterCount': 0,
      };
      return machineOnlyTargets;
    }

    final discoveredPorts = await _discoverPorts();
    final portCandidates = _buildPortScanTargets(discoveredPorts);
    final flutterPortTargets = await _filterFlutterPortScanTargets(
      portCandidates,
    );

    _lastDiscoveryDiagnostics = {
      'strategyUsed': 'port_scan_flutter_filtered',
      'machineRawCount': machineTargets.length,
      'machineValidCount': machineOnlyTargets.length,
      'portRawCount': discoveredPorts.length,
      'portCandidateCount': portCandidates.length,
      'portFlutterCount': flutterPortTargets.length,
      'portDroppedNonFlutterCount':
          portCandidates.length - flutterPortTargets.length,
    };
    return flutterPortTargets;
  }

  List<CoreConnectionTarget> _buildMachineTargets(
    final List<FlutterMachineDiscoveryTarget> machineTargets,
  ) {
    final targetsById = <String, CoreConnectionTarget>{};

    for (final machineTarget in machineTargets) {
      try {
        final endpoint = CoreEndpoint.fromUri(machineTarget.vmServiceWsUri);
        final target = _buildTarget(
          endpoint: endpoint,
          discoverySource: CoreConnectionTarget.machineDiscoverySource,
          dtdUri: machineTarget.dtdUri?.toString(),
        );
        targetsById[target.targetId] = target;
      } on FormatException catch (e) {
        logger(
          LoggingLevel.debug,
          'Skipping invalid machine discovery endpoint: $e',
          logger: 'ConnectionContext',
        );
      }
    }

    return _sortTargets(targetsById.values);
  }

  List<CoreConnectionTarget> _buildPortScanTargets(final List<int> ports) {
    final targetsById = <String, CoreConnectionTarget>{};
    for (final discoveredPort in ports) {
      final endpoint = _endpointForDiscoveredPort(discoveredPort);
      final target = _buildTarget(
        endpoint: endpoint,
        discoverySource: CoreConnectionTarget.portScanDiscoverySource,
      );
      targetsById[target.targetId] = target;
    }
    return _sortTargets(targetsById.values);
  }

  CoreConnectionTarget _buildTarget({
    required final CoreEndpoint endpoint,
    required final String discoverySource,
    final String? dtdUri,
  }) {
    final sticky = _stickyEndpoint;
    final current = _activeEndpoint;
    final canonicalTargetId = CoreConnectionTarget.buildTargetId(
      vmServiceWsUri: endpoint.wsUri,
    );
    return CoreConnectionTarget(
      targetId: canonicalTargetId,
      host: endpoint.host,
      port: endpoint.port,
      endpoint: canonicalTargetId,
      dtdUri: dtdUri,
      discoverySource: discoverySource,
      isSticky: sticky != null && _sameEndpointByTargetId(sticky, endpoint),
      isCurrent: current != null && _sameEndpointByTargetId(current, endpoint),
    );
  }

  List<CoreConnectionTarget> _sortTargets(
    final Iterable<CoreConnectionTarget> targets,
  ) {
    final sorted = targets.toList()
      ..sort((final a, final b) => a.targetId.compareTo(b.targetId));
    return sorted;
  }

  Future<void> disconnect() async {
    try {
      if (_vmService != null) {
        await _vmService?.dispose();
      }
      if (_vmChannel != null) {
        await _vmChannel?.sink.close();
      }
    } catch (e) {
      logger(
        LoggingLevel.warning,
        'Error during disconnect: $e',
        logger: 'ConnectionContext',
      );
    } finally {
      _vmService = null;
      _vmChannel = null;
      _dartToolingDaemon = null;
      _activeEndpoint = null;
      _disconnectedSinceLastConnect = true;
    }
  }

  Future<void> _connectToEndpoint(
    final CoreEndpoint endpoint, {
    required final Duration timeout,
  }) async {
    final wsUri = endpoint.wsUri;
    logger(
      LoggingLevel.info,
      'Connecting to $wsUri',
      logger: 'ConnectionContext',
    );

    try {
      final dtdFuture = DartToolingDaemon.connect(wsUri);
      _dartToolingDaemon = timeout == Duration.zero
          ? await dtdFuture
          : await dtdFuture.timeout(timeout);

      _vmChannel = WebSocketChannel.connect(wsUri);

      _vmService = VmService(
        _vmChannel!.stream.cast<String>(),
        (final message) => _vmChannel!.sink.add(message),
      );

      final vmPing = _vmService!.getVM();
      if (timeout == Duration.zero) {
        await vmPing;
      } else {
        await vmPing.timeout(timeout);
      }

      unawaited(
        _vmChannel!.sink.done
            .then((_) => _handleDisconnect('WebSocket sink closed'))
            .catchError((final error) {
              _handleDisconnect('WebSocket sink error: $error');
            }),
      );

      logger(
        LoggingLevel.info,
        'Connection established at ${endpoint.display}',
        logger: 'ConnectionContext',
      );
    } catch (e, s) {
      logger(
        LoggingLevel.error,
        'Failed to connect to $wsUri: $e',
        logger: 'ConnectionContext',
      );
      logger(
        LoggingLevel.debug,
        'Stack trace: $s',
        logger: 'ConnectionContext',
      );
      await disconnect();
      rethrow;
    }
  }

  void _handleDisconnect(final String reason) {
    if (_vmService == null) return;

    logger(
      LoggingLevel.info,
      'Connection dropped: $reason',
      logger: 'ConnectionContext',
    );

    _vmService = null;
    _vmChannel = null;
    _dartToolingDaemon = null;
    _activeEndpoint = null;
    _disconnectedSinceLastConnect = true;
  }

  Future<({CoreEndpoint endpoint, Map<String, Object?> diagnostics})>
  _resolveEndpoint({
    required final CoreConnectionMode mode,
    final String? targetId,
    final String? uri,
    final String? host,
    final int? port,
  }) async {
    final normalizedTargetId = targetId?.trim();
    if (normalizedTargetId != null && normalizedTargetId.isNotEmpty) {
      return _resolveByTargetId(normalizedTargetId, mode: mode);
    }

    switch (mode) {
      case CoreConnectionMode.uri:
        final parsedUri = Uri.tryParse(uri ?? '');
        if (parsedUri == null) {
          throw const CoreConnectionException(
            reason: CoreConnectionFailureReason.invalidUri,
            message: 'Invalid URI',
            details: {'reason': 'invalid_uri', 'uri': null},
          );
        }
        late final CoreEndpoint endpoint;
        try {
          endpoint = CoreEndpoint.fromUri(parsedUri);
        } on FormatException catch (e) {
          throw CoreConnectionException(
            reason: CoreConnectionFailureReason.invalidUri,
            message: e.message,
            details: {'reason': 'invalid_uri', 'uri': uri},
          );
        }
        return (
          endpoint: endpoint,
          diagnostics: {
            'mode': mode.name,
            'selectedTargetId': CoreConnectionTarget.buildTargetId(
              vmServiceWsUri: endpoint.wsUri,
            ),
            'selectedEndpoint': CoreConnectionTarget.buildTargetId(
              vmServiceWsUri: endpoint.wsUri,
            ),
            'decision': 'Used explicit URI endpoint',
            'candidates': <String>[
              CoreConnectionTarget.buildTargetId(
                vmServiceWsUri: endpoint.wsUri,
              ),
            ],
            'stickyEndpoint': _stickyEndpoint?.display,
          },
        );

      case CoreConnectionMode.manual:
        final endpoint = CoreEndpoint(
          host: host ?? _stickyEndpoint?.host ?? defaultHost,
          port: port ?? _stickyEndpoint?.port ?? defaultPort,
          wsPath: _stickyEndpoint?.wsPath ?? '/ws',
        );
        return (
          endpoint: endpoint,
          diagnostics: {
            'mode': mode.name,
            'selectedTargetId': CoreConnectionTarget.buildTargetId(
              vmServiceWsUri: endpoint.wsUri,
            ),
            'selectedEndpoint': CoreConnectionTarget.buildTargetId(
              vmServiceWsUri: endpoint.wsUri,
            ),
            'decision': 'Used manually provided host/port',
            'candidates': <String>[
              CoreConnectionTarget.buildTargetId(
                vmServiceWsUri: endpoint.wsUri,
              ),
            ],
            'stickyEndpoint': _stickyEndpoint?.display,
          },
        );

      case CoreConnectionMode.auto:
        return _resolveAutoEndpoint();
    }
  }

  Future<({CoreEndpoint endpoint, Map<String, Object?> diagnostics})>
  _resolveByTargetId(
    final String targetId, {
    required final CoreConnectionMode mode,
  }) async {
    final parsedTargetUri = _parseTargetIdOrThrow(targetId);
    final canonicalTargetId = CoreConnectionTarget.buildTargetId(
      vmServiceWsUri: parsedTargetUri,
    );
    final targets = await discoverTargets();
    final selected = targets.firstWhere(
      (final t) => t.targetId == canonicalTargetId,
      orElse: () => const CoreConnectionTarget(
        targetId: '',
        host: '',
        port: 0,
        endpoint: '',
        isSticky: false,
        isCurrent: false,
      ),
    );

    if (selected.targetId.isEmpty) {
      // Explicit target IDs with tokenized VM paths (for example /<token>/ws)
      // may not be discoverable via port scan. When path is non-default, trust
      // the caller-provided URI and attempt direct connection.
      if (_hasNonDefaultWsPath(parsedTargetUri)) {
        final endpoint = CoreEndpoint.fromUri(parsedTargetUri);
        return (
          endpoint: endpoint,
          diagnostics: {
            'mode': mode.name,
            'selectedTargetId': CoreConnectionTarget.buildTargetId(
              vmServiceWsUri: endpoint.wsUri,
            ),
            'selectedEndpoint': CoreConnectionTarget.buildTargetId(
              vmServiceWsUri: endpoint.wsUri,
            ),
            'decision':
                'Used explicit targetId URI fallback after discovery miss',
            'requestedTargetId': targetId,
            'targetIdLookupMiss': canonicalTargetId,
            'availableTargets': targets.map((final t) => t.toJson()).toList(),
            'stickyEndpoint': _stickyEndpoint?.display,
            'discovery': _lastDiscoveryDiagnostics,
          },
        );
      }

      throw CoreConnectionException(
        reason: CoreConnectionFailureReason.targetNotFound,
        message: 'Target not found: $canonicalTargetId',
        details: {
          'reason': 'target_not_found',
          'targetId': canonicalTargetId,
          'availableTargets': targets.map((final t) => t.toJson()).toList(),
          'discovery': _lastDiscoveryDiagnostics,
        },
      );
    }

    final endpoint = CoreEndpoint.fromUri(Uri.parse(selected.endpoint));
    return (
      endpoint: endpoint,
      diagnostics: {
        'mode': mode.name,
        'selectedTargetId': selected.targetId,
        'selectedEndpoint': selected.endpoint,
        'decision': 'Used explicit targetId',
        'availableTargets': targets.map((final t) => t.toJson()).toList(),
        'stickyEndpoint': _stickyEndpoint?.display,
        'discovery': _lastDiscoveryDiagnostics,
      },
    );
  }

  Future<({CoreEndpoint endpoint, Map<String, Object?> diagnostics})>
  _resolveAutoEndpoint() async {
    final active = _activeEndpoint;
    if (isConnected && active != null) {
      final healthy = await _isCurrentConnectionHealthy(
        timeout: _connectionHealthCheckTimeout,
      );
      if (healthy) {
        final targets = await discoverTargets();
        final selectedTargetId = CoreConnectionTarget.buildTargetId(
          vmServiceWsUri: active.wsUri,
        );
        return (
          endpoint: active,
          diagnostics: {
            'mode': CoreConnectionMode.auto.name,
            'selectedTargetId': selectedTargetId,
            'selectedEndpoint': selectedTargetId,
            'decision': 'Reused active connection',
            'availableTargets': targets.map((final t) => t.toJson()).toList(),
            'stickyEndpoint': _stickyEndpoint?.display,
            'discovery': _lastDiscoveryDiagnostics,
          },
        );
      }

      await disconnect();
    }

    final targets = await discoverTargets();
    final sticky = _stickyEndpoint;

    if (targets.isEmpty) {
      throw CoreConnectionException(
        reason: CoreConnectionFailureReason.noTargets,
        message: 'No debug targets discovered',
        details: {
          'reason': 'no_targets',
          'availableTargets': const [],
          'discovery': _lastDiscoveryDiagnostics,
        },
      );
    }

    CoreConnectionTarget? stickyTarget;
    if (sticky != null) {
      final stickyTargetId = CoreConnectionTarget.buildTargetId(
        vmServiceWsUri: sticky.wsUri,
      );
      for (final target in targets) {
        if (target.targetId == stickyTargetId) {
          stickyTarget = target;
          break;
        }
      }
    }

    final selected =
        stickyTarget ?? (targets.length == 1 ? targets.first : null);
    if (selected == null) {
      final selectionDetails = _multipleTargetsDetails(targets);
      throw CoreConnectionException(
        reason: CoreConnectionFailureReason.multipleTargets,
        message:
            'Multiple debug targets detected. Retry with URI connection.targetId.',
        details: selectionDetails,
      );
    }

    final endpoint = CoreEndpoint.fromUri(Uri.parse(selected.endpoint));
    return (
      endpoint: endpoint,
      diagnostics: {
        'mode': CoreConnectionMode.auto.name,
        'selectedTargetId': selected.targetId,
        'selectedEndpoint': selected.endpoint,
        'decision': stickyTarget != null
            ? 'Reused sticky target discovered in current scan'
            : 'Auto-attached single discovered target',
        'availableTargets': targets.map((final t) => t.toJson()).toList(),
        'stickyEndpoint': _stickyEndpoint?.display,
        'discovery': _lastDiscoveryDiagnostics,
      },
    );
  }

  Map<String, Object?> _multipleTargetsDetails(
    final List<CoreConnectionTarget> targets,
  ) {
    final availableTargets = targets.map((final t) => t.toJson()).toList();
    final suggestedTarget = targets.first.targetId;
    final shortlist = availableTargets
        .take(_maxConnectionSelectionShortlist)
        .toList();

    return {
      'reason': 'multiple_targets',
      'availableTargets': availableTargets,
      'shortlist': shortlist,
      'targetCount': availableTargets.length,
      'discovery': _lastDiscoveryDiagnostics,
      'suggestedAction': 'retry_with_connection_target',
      'example': {
        'connection': {'targetId': suggestedTarget},
      },
      'howToRetry': {
        'connection': {'targetId': suggestedTarget},
      },
    };
  }

  Future<List<FlutterMachineDiscoveryTarget>> _discoverMachineTargets() async {
    final provider = discoverMachineTargets;
    if (provider == null) {
      return const <FlutterMachineDiscoveryTarget>[];
    }

    try {
      return await provider();
    } on Exception catch (e) {
      logger(
        LoggingLevel.debug,
        'Machine discovery provider failed: $e',
        logger: 'ConnectionContext',
      );
      return const <FlutterMachineDiscoveryTarget>[];
    }
  }

  Uri _parseTargetIdOrThrow(final String targetId) {
    if (CoreConnectionTarget.isLegacyHostPortTargetId(targetId)) {
      throw CoreConnectionException(
        reason: CoreConnectionFailureReason.invalidTargetId,
        message:
            'Invalid targetId: host:port identifiers are no longer supported. '
            'Use a full VM websocket URI targetId or connection.uri.',
        details: {
          'reason': 'invalid_target_id_legacy_host_port',
          'targetId': targetId,
          'migrationHint':
              'Use connection.targetId set to a full ws://.../ws URI or provide connection.uri.',
        },
      );
    }

    final parsed = CoreConnectionTarget.parseTargetIdUri(targetId);
    if (parsed == null) {
      throw CoreConnectionException(
        reason: CoreConnectionFailureReason.invalidTargetId,
        message:
            'Invalid targetId: expected full VM websocket URI (ws://.../ws).',
        details: {
          'reason': 'invalid_target_id',
          'targetId': targetId,
          'migrationHint':
              'Use connection.targetId set to a full ws://.../ws URI or provide connection.uri.',
        },
      );
    }

    return parsed;
  }

  bool _hasNonDefaultWsPath(final Uri uri) {
    final rawPath = uri.path.trim();
    if (rawPath.isEmpty) {
      return false;
    }

    var normalizedPath = rawPath.startsWith('/') ? rawPath : '/$rawPath';
    while (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
    }

    return normalizedPath != '/ws';
  }

  Future<List<CoreConnectionTarget>> _filterFlutterPortScanTargets(
    final List<CoreConnectionTarget> candidates,
  ) async {
    if (candidates.isEmpty) {
      return const <CoreConnectionTarget>[];
    }

    final checks = await Future.wait(candidates.map(_isFlutterPortScanTarget));

    final flutterTargets = <CoreConnectionTarget>[];
    for (var i = 0; i < candidates.length; i++) {
      if (checks[i]) {
        flutterTargets.add(candidates[i]);
      }
    }
    return flutterTargets;
  }

  Future<bool> _isFlutterPortScanTarget(
    final CoreConnectionTarget target,
  ) async {
    final now = DateTime.now().toUtc();
    final cached = _flutterProbeCache[target.targetId];
    if (cached != null &&
        now.difference(cached.checkedAt) <= _portScanFlutterProbeCacheTtl) {
      return cached.isFlutter;
    }

    bool isFlutter = false;
    try {
      final endpoint = CoreEndpoint.fromUri(Uri.parse(target.endpoint));
      if (probeFlutterTarget != null) {
        isFlutter = await probeFlutterTarget!(
          endpoint,
          timeout: _portScanFlutterProbeTimeout,
        );
      } else {
        isFlutter = await _probeFlutterEndpoint(
          endpoint,
          timeout: _portScanFlutterProbeTimeout,
        );
      }
    } catch (_) {
      isFlutter = false;
    }

    _flutterProbeCache[target.targetId] = (
      isFlutter: isFlutter,
      checkedAt: now,
    );
    return isFlutter;
  }

  Future<bool> _probeFlutterEndpoint(
    final CoreEndpoint endpoint, {
    required final Duration timeout,
  }) async {
    final client = HttpClient();
    try {
      final httpBase = _vmServiceHttpBaseUri(endpoint);
      final vmPayload = await _fetchVmServiceMap(
        client: client,
        uri: _vmServiceMethodUri(httpBase, 'getVM'),
        timeout: timeout,
      );
      final isolates =
          _extractResultMap(vmPayload)['isolates'] as List<Object?>? ??
          const <Object?>[];

      for (final isolateRef in isolates) {
        if (isolateRef is! Map) {
          continue;
        }
        final isolateId = isolateRef['id']?.toString();
        if (isolateId == null || isolateId.isEmpty) {
          continue;
        }
        final isolatePayload = await _fetchVmServiceMap(
          client: client,
          uri: _vmServiceMethodUri(
            httpBase,
            'getIsolate',
            query: <String, String>{'isolateId': isolateId},
          ),
          timeout: timeout,
        );
        final extensionRPCs =
            (_extractResultMap(isolatePayload)['extensionRPCs']
                        as List<Object?>? ??
                    const <Object?>[])
                .map((final e) => '$e')
                .toList(growable: false);
        if (_hasFlutterExtensions(extensionRPCs)) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  bool _hasFlutterExtensions(final List<String> extensionRPCs) {
    for (final extension in extensionRPCs) {
      for (final prefix in _flutterExtensionPrefixes) {
        if (extension.startsWith(prefix)) {
          return true;
        }
      }
    }
    return false;
  }

  Uri _vmServiceHttpBaseUri(final CoreEndpoint endpoint) {
    final wsUri = endpoint.wsUri;
    final pathSegments = wsUri.pathSegments
        .where((final s) => s.isNotEmpty)
        .toList();
    if (pathSegments.isNotEmpty && pathSegments.last == 'ws') {
      pathSegments.removeLast();
    }
    return Uri(
      scheme: 'http',
      host: wsUri.host,
      port: wsUri.port,
      pathSegments: pathSegments,
    );
  }

  Uri _vmServiceMethodUri(
    final Uri base,
    final String method, {
    final Map<String, String>? query,
  }) {
    final pathSegments = <String>[
      ...base.pathSegments.where((final s) => s.isNotEmpty),
      method,
    ];
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      pathSegments: pathSegments,
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<Map<String, Object?>> _fetchVmServiceMap({
    required final HttpClient client,
    required final Uri uri,
    required final Duration timeout,
  }) async {
    final requestFuture = client.getUrl(uri);
    final request = timeout == Duration.zero
        ? await requestFuture
        : await requestFuture.timeout(timeout);
    final responseFuture = request.close();
    final response = timeout == Duration.zero
        ? await responseFuture
        : await responseFuture.timeout(timeout);
    if (response.statusCode != 200) {
      throw StateError('VM service probe failed: ${response.statusCode} $uri');
    }
    final bodyFuture = response.transform(utf8.decoder).join();
    final body = timeout == Duration.zero
        ? await bodyFuture
        : await bodyFuture.timeout(timeout);
    final decoded = jsonDecode(body);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
    throw StateError('VM service probe returned non-map payload: $uri');
  }

  Map<String, Object?> _extractResultMap(final Map<String, Object?> payload) {
    final result = payload['result'];
    if (result is Map<String, Object?>) {
      return result;
    }
    if (result is Map) {
      return result.cast<String, Object?>();
    }
    return payload;
  }

  Future<List<int>> _discoverPorts() async {
    final discovered = (await discoverPorts().catchError(
      (_) => <int>[],
    )).toSet().toList()..sort();
    return discovered;
  }

  CoreEndpoint _endpointForDiscoveredPort(final int discoveredPort) {
    final sticky = _stickyEndpoint;
    if (sticky != null && sticky.port == discoveredPort) {
      return sticky;
    }

    final current = _activeEndpoint;
    if (current != null && current.port == discoveredPort) {
      return current;
    }

    return CoreEndpoint(host: defaultHost, port: discoveredPort);
  }

  bool _sameEndpointByTargetId(final CoreEndpoint a, final CoreEndpoint b) =>
      CoreConnectionTarget.buildTargetId(vmServiceWsUri: a.wsUri) ==
      CoreConnectionTarget.buildTargetId(vmServiceWsUri: b.wsUri);

  static const Duration _connectionHealthCheckTimeout = Duration(
    milliseconds: 300,
  );
  static const Duration _portScanFlutterProbeTimeout = Duration(
    milliseconds: 350,
  );
  static const Duration _portScanFlutterProbeCacheTtl = Duration(seconds: 5);
  static const int _maxConnectionSelectionShortlist = 8;
  static const List<String> _flutterExtensionPrefixes = <String>[
    'ext.flutter',
    'ext.mcp.toolkit',
  ];

  Future<bool> _isCurrentConnectionHealthy({
    required final Duration timeout,
  }) async {
    final vmService = _vmService;
    if (vmService == null) {
      return false;
    }

    try {
      final ping = vmService.getVM();
      if (timeout == Duration.zero) {
        await ping;
      } else {
        await ping.timeout(timeout);
      }
      return true;
    } on Exception {
      return false;
    }
  }

  Future<Response> callFlutterExtension(
    final String method, {
    final Map<String, dynamic>? args,
  }) async {
    final isolate = await getFlutterIsolate();
    final isolateId = isolate?.id;
    if (isolateId == null) {
      throw StateError('No Flutter isolate found');
    }

    final response = await callServiceExtension(
      method,
      isolateId: isolateId,
      args: args,
    );
    if (response == null) {
      throw StateError('Extension call returned null');
    }
    return response;
  }

  Future<Response?> callServiceExtension(
    final String method, {
    final String? isolateId,
    final Map<String, dynamic>? args,
  }) async {
    final vmService = _vmService;
    if (vmService == null) {
      throw StateError('VM service not connected');
    }

    try {
      return await vmService.callServiceExtension(
        method,
        isolateId: isolateId,
        args: args,
      );
    } on Exception catch (e, s) {
      logger(
        LoggingLevel.error,
        'Failed to call service extension $method: $e',
        logger: 'ConnectionContext',
      );
      logger(
        LoggingLevel.debug,
        'Stack trace: $s',
        logger: 'ConnectionContext',
      );
      return null;
    }
  }

  Future<List<IsolateRef>> getIsolates() async {
    final vmService = _vmService;
    if (vmService == null) {
      throw StateError('VM service not connected');
    }

    try {
      final vm = await vmService.getVM();
      return vm.isolates ?? <IsolateRef>[];
    } on Exception {
      return <IsolateRef>[];
    }
  }

  Future<IsolateRef?> getFlutterIsolate() async {
    final vmService = _vmService;
    if (vmService == null) {
      throw StateError('VM service not connected');
    }

    final isolates = await getIsolates();

    for (final isolate in isolates) {
      try {
        final isolateInfo = await vmService.getIsolate(isolate.id!);
        final extensionRPCs = isolateInfo.extensionRPCs ?? <String>[];
        if (extensionRPCs.any((final ext) => ext.startsWith('ext.flutter'))) {
          return isolate;
        }
      } on Exception {
        // Ignore broken isolate and continue.
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> hotReload({final bool force = false}) {
    final pending = _pendingReloadOrRestart;
    if (pending != null) return pending;
    final completer = Completer<Map<String, dynamic>?>();
    _pendingReloadOrRestart = completer.future;
    unawaited(
      _runHotReload(force: force)
          .then(completer.complete)
          .catchError(completer.completeError)
          .whenComplete(() {
            if (identical(_pendingReloadOrRestart, completer.future)) {
              _pendingReloadOrRestart = null;
            }
          }),
    );
    return completer.future;
  }

  Future<Map<String, dynamic>?> _runHotReload({
    required final bool force,
  }) async {
    final vmService = _vmService;
    if (vmService == null) {
      return {'error': 'VM service not connected'};
    }

    try {
      final vm = await vmService.getVM();
      ReloadReport? report;
      StreamSubscription<Event>? serviceStreamSubscription;

      try {
        final hotReloadMethodNameCompleter = Completer<String?>();
        serviceStreamSubscription = vmService
            .onEvent(EventStreams.kService)
            .listen((final e) {
              if (e.kind == EventKind.kServiceRegistered &&
                  e.service == 'reloadSources') {
                hotReloadMethodNameCompleter.complete(e.method);
              }
            });

        await vmService.streamListen(EventStreams.kService);

        final hotReloadMethodName = await hotReloadMethodNameCompleter.future
            .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);

        if (hotReloadMethodName == null) {
          report = await vmService.reloadSources(
            vm.isolates!.first.id!,
            force: force,
          );
        } else {
          final result = await callServiceExtension(
            hotReloadMethodName,
            isolateId: vm.isolates!.first.id,
            args: {'force': force},
          );
          final jsonMap = jsonDecodeMap(result?.json);
          final resultType = jsonDecodeString(jsonMap['type']);
          final success = jsonDecodeBool(jsonMap['success']);
          if (resultType == 'Success' ||
              (resultType == 'ReloadReport' && success)) {
            report = ReloadReport(success: true);
          } else {
            report = ReloadReport(success: false);
          }
        }
      } finally {
        await serviceStreamSubscription?.cancel();
        await vmService.streamCancel(EventStreams.kService);
      }

      return {'report': report.toJson()};
    } on Exception catch (e, s) {
      return {'error': 'Hot reload failed: $e $s'};
    }
  }

  Future<Map<String, dynamic>?> hotRestart() {
    final pending = _pendingReloadOrRestart;
    if (pending != null) return pending;
    final completer = Completer<Map<String, dynamic>?>();
    _pendingReloadOrRestart = completer.future;
    unawaited(
      _runHotRestart()
          .then(completer.complete)
          .catchError(completer.completeError)
          .whenComplete(() {
            if (identical(_pendingReloadOrRestart, completer.future)) {
              _pendingReloadOrRestart = null;
            }
          }),
    );
    return completer.future;
  }

  Future<Map<String, dynamic>?> _runHotRestart() async {
    final vmService = _vmService;
    if (vmService == null) {
      return {'error': 'VM service not connected'};
    }

    try {
      String? hotRestartMethodName;
      StreamSubscription<Event>? eventSubscription;
      try {
        final completer = Completer<String?>();
        eventSubscription = vmService.onEvent(EventStreams.kService).listen((
          final e,
        ) {
          if (e.kind == EventKind.kServiceRegistered &&
              e.service == 'hotRestart') {
            if (!completer.isCompleted) completer.complete(e.method);
          }
        });

        await vmService.streamListen(EventStreams.kService);
        hotRestartMethodName = await completer.future.timeout(
          const Duration(milliseconds: 800),
          onTimeout: () => null,
        );
      } finally {
        try {
          await eventSubscription?.cancel();
          await vmService.streamCancel(EventStreams.kService);
        } catch (_) {
          // Ignore shutdown racing errors.
        }
      }

      final methodToCall = hotRestartMethodName ?? 'hotRestart';
      final response = await vmService.callMethod(methodToCall);
      final json = response.json;

      return {
        'report': {
          'type': json?['type'] ?? 'Success',
          'success': json?['success'] ?? true,
        },
      };
    } on Exception catch (e, s) {
      return {'error': 'Hot restart failed: $e $s'};
    }
  }
}
