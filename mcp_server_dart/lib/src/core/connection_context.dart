// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses, lines_longer_than_80_chars

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/core_types.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:vm_service/vm_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final class CoreEndpoint {
  const CoreEndpoint({
    required this.host,
    required this.port,
    this.wsPath = '/ws',
  });

  final String host;
  final int port;
  final String wsPath;

  Uri get wsUri {
    final normalizedPath = wsPath.startsWith('/') ? wsPath : '/$wsPath';
    return Uri(scheme: 'ws', host: host, port: port, path: normalizedPath);
  }

  String get display => wsUri.toString();

  static CoreEndpoint fromUri(final Uri uri) {
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

  @override
  bool operator ==(final Object other) {
    return other is CoreEndpoint &&
        other.host == host &&
        other.port == port &&
        other.wsPath == wsPath;
  }

  @override
  int get hashCode => Object.hash(host, port, wsPath);
}

final class ConnectionContext {
  ConnectionContext({
    required this.defaultHost,
    required this.defaultPort,
    required this.logger,
    required this.discoverPorts,
    this.initialStickyEndpointUri,
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
  final String? initialStickyEndpointUri;

  VmService? _vmService;
  WebSocketChannel? _vmChannel;
  DartToolingDaemon? _dartToolingDaemon;

  CoreEndpoint? _activeEndpoint;
  CoreEndpoint? _stickyEndpoint;

  CoreConnectionMode _lastMode = CoreConnectionMode.auto;
  Map<String, Object?> _lastSelectionDiagnostics = const <String, Object?>{};

  bool _wasConnected = false;
  bool _disconnectedSinceLastConnect = false;

  /// Callback invoked when a previously disconnected context reconnects.
  void Function()? onReconnected;

  VmService? get vmService => _vmService;
  DartToolingDaemon? get dartToolingDaemon => _dartToolingDaemon;
  bool get isConnected => _vmService != null;
  CoreEndpoint? get activeEndpoint => _activeEndpoint;
  CoreEndpoint? get stickyEndpoint => _stickyEndpoint;
  CoreConnectionMode get lastMode => _lastMode;
  Map<String, Object?> get lastSelectionDiagnostics =>
      _lastSelectionDiagnostics;

  void setStickyEndpointFromUri(final String uri) {
    _stickyEndpoint = CoreEndpoint.fromUri(Uri.parse(uri));
  }

  Future<Map<String, Object?>> connect({
    final CoreConnectionMode mode = CoreConnectionMode.auto,
    final String? uri,
    final String? host,
    final int? port,
    final bool forceReconnect = false,
    final Duration timeout = const Duration(seconds: 2),
  }) async {
    final resolution = await _resolveEndpoint(
      mode: mode,
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

    await disconnect();
    await _connectToEndpoint(endpoint, timeout: timeout);

    _stickyEndpoint = endpoint;
    _activeEndpoint = endpoint;
    _lastMode = mode;
    _lastSelectionDiagnostics = diagnostics;
    _wasConnected = true;
    _disconnectedSinceLastConnect = false;

    if (shouldNotifyReconnect) {
      onReconnected?.call();
    }

    return {
      'connected': true,
      'reusedConnection': false,
      'endpoint': endpoint.display,
      ...diagnostics,
    };
  }

  Future<bool> ensureConnected({
    final Duration timeout = const Duration(seconds: 2),
  }) async {
    if (isConnected) {
      return true;
    }

    try {
      await connect(mode: CoreConnectionMode.auto, timeout: timeout);
      return isConnected;
    } catch (e) {
      logger(
        LoggingLevel.warning,
        'Failed to ensure connection: $e',
        logger: 'ConnectionContext',
      );
      return false;
    }
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
    final String? uri,
    final String? host,
    final int? port,
  }) async {
    switch (mode) {
      case CoreConnectionMode.uri:
        final parsedUri = Uri.tryParse(uri ?? '');
        if (parsedUri == null) {
          throw const FormatException('Invalid URI');
        }
        final endpoint = CoreEndpoint.fromUri(parsedUri);
        return (
          endpoint: endpoint,
          diagnostics: {
            'mode': mode.name,
            'selectedEndpoint': endpoint.display,
            'decision': 'Used explicit URI endpoint',
            'candidates': <String>[endpoint.display],
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
            'selectedEndpoint': endpoint.display,
            'decision': 'Used manually provided host/port',
            'candidates': <String>[endpoint.display],
            'stickyEndpoint': _stickyEndpoint?.display,
          },
        );

      case CoreConnectionMode.auto:
        final discoveredPorts = (await discoverPorts().catchError(
          (_) => <int>[],
        )).toSet().toList()..sort();

        final sticky = _stickyEndpoint;
        final stickyInDiscovery =
            sticky != null && discoveredPorts.contains(sticky.port);

        CoreEndpoint endpoint;
        String decision;

        if (stickyInDiscovery) {
          endpoint = sticky;
          decision = 'Reused sticky endpoint discovered in current scan';
        } else if (discoveredPorts.contains(defaultPort)) {
          endpoint = CoreEndpoint(host: defaultHost, port: defaultPort);
          decision =
              'Selected configured default endpoint from discovered ports';
        } else if (discoveredPorts.isNotEmpty) {
          endpoint = CoreEndpoint(
            host: defaultHost,
            port: discoveredPorts.first,
          );
          decision = 'Selected lowest discovered debug port deterministically';
        } else if (sticky != null) {
          endpoint = sticky;
          decision = 'No ports discovered, falling back to sticky endpoint';
        } else {
          endpoint = CoreEndpoint(host: defaultHost, port: defaultPort);
          decision = 'No ports discovered, falling back to configured default';
        }

        final candidates = discoveredPorts
            .map((final p) => Uri.parse('ws://$defaultHost:$p/ws').toString())
            .toList();

        return (
          endpoint: endpoint,
          diagnostics: {
            'mode': mode.name,
            'selectedEndpoint': endpoint.display,
            'decision': decision,
            'candidates': candidates,
            'discoveredPorts': discoveredPorts,
            'stickyEndpoint': _stickyEndpoint?.display,
          },
        );
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

  Future<Map<String, dynamic>?> hotReload({final bool force = false}) async {
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

  Future<Map<String, dynamic>?> hotRestart() async {
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
