// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses, lines_longer_than_80_chars

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter_inspector_mcp_server/flutter_inspector_mcp_server.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:vm_service/vm_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Mixin providing VM service connection and management capabilities
base mixin VMServiceSupport on BaseMCPToolkitServer {
  VmService? _vmService;
  WebSocketChannel? _vmChannel;
  DartToolingDaemon? _dartToolingDaemon;
  StreamSubscription<DTDEvent>? _discoverySubscription;

  /// Get the current VM service instance
  VmService? get vmService => _vmService;
  DartToolingDaemon? get dartToolingDaemon => _dartToolingDaemon;

  /// Check if VM service is connected
  bool get isVMServiceConnected => _vmService != null;

  /// Initialize VM service connection
  Future<void> initializeVMService() async {
    final url = 'ws://${configuration.vmHost}:${configuration.vmPort}/ws';
    log(
      LoggingLevel.info,
      'Initializing VM service connection to $url',
      logger: 'VMService',
    );

    try {
      final uri = Uri.parse(url);
      log(
        LoggingLevel.debug,
        'Creating WebSocket connection',
        logger: 'VMService',
      );
      _vmChannel = WebSocketChannel.connect(uri);

      log(
        LoggingLevel.debug,
        'Connecting to Dart Tooling Daemon',
        logger: 'VMService',
      );
      _dartToolingDaemon = await DartToolingDaemon.connect(uri);

      log(
        LoggingLevel.debug,
        'Creating VM service instance',
        logger: 'VMService',
      );
      _vmService = VmService(
        _vmChannel!.stream.cast<String>(),
        (final message) => _vmChannel!.sink.add(message),
      );

      // Test connection
      log(
        LoggingLevel.debug,
        'Testing VM service connection',
        logger: 'VMService',
      );
      await _vmService!.getVM();
      log(
        LoggingLevel.info,
        'VM service connection established successfully',
        logger: 'VMService',
      );
    } on Exception catch (e, s) {
      log(
        LoggingLevel.error,
        'Failed to connect to VM service at '
        '${configuration.vmHost}:${configuration.vmPort}: $e',
        logger: 'VMService',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
      await disconnectVMService();
      rethrow;
    }
  }

  /// Disconnect from VM service
  Future<void> disconnectVMService() async {
    log(
      LoggingLevel.info,
      'Disconnecting from VM service',
      logger: 'VMService',
    );

    try {
      // Stop discovery
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;

      if (_vmService != null) {
        log(LoggingLevel.debug, 'Disposing VM service', logger: 'VMService');
        await _vmService?.dispose();
      }

      if (_vmChannel != null) {
        log(
          LoggingLevel.debug,
          'Closing WebSocket channel',
          logger: 'VMService',
        );
        await _vmChannel?.sink.close();
      }

      _vmService = null;
      _vmChannel = null;
      log(
        LoggingLevel.info,
        'VM service disconnected successfully',
        logger: 'VMService',
      );
    } on Exception catch (e, s) {
      log(
        LoggingLevel.warning,
        'Error during VM service disconnect: $e',
        logger: 'VMService',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
    }
  }

  /// Call a Flutter extension method
  Future<Response> callFlutterExtension(
    final String method, {
    final Map<String, dynamic>? args,
  }) async {
    final isolate = await getFlutterIsolate();
    final isolateId = isolate?.id;
    if (isolateId == null) {
      log(
        LoggingLevel.error,
        'Cannot call Flutter extension $method: No isolate found',
        logger: 'VMService',
      );
      throw StateError('No isolate found');
    }

    final response = await callServiceExtension(
      method,
      isolateId: isolateId,
      args: args,
    );

    if (response == null) {
      log(
        LoggingLevel.error,
        'Flutter extension $method returned null response',
        logger: 'FlutterInspector',
      );
      throw StateError('Extension call returned null');
    }

    return response;
  }

  /// Call a service extension method
  Future<Response?> callServiceExtension(
    final String method, {
    final String? isolateId,
    final Map<String, dynamic>? args,
  }) async {
    if (_vmService == null) {
      log(
        LoggingLevel.error,
        'Attempted to call service extension $method '
        'but VM service not connected',
        logger: 'VMService',
      );
      throw StateError('VM service not connected');
    }

    log(
      LoggingLevel.debug,
      'Calling service extension: $method',
      logger: 'VMService',
    );
    log(LoggingLevel.debug, () => 'Extension args: $args', logger: 'VMService');

    try {
      final response = await _vmService!.callServiceExtension(
        method,
        isolateId: isolateId,
        args: args,
      );
      log(
        LoggingLevel.debug,
        'Service extension $method completed successfully',
        logger: 'VMService',
      );
      return response;
    } on Exception catch (e, s) {
      log(
        LoggingLevel.error,
        'Failed to call service extension $method: $e',
        logger: 'VMService',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
      return null;
    }
  }

  /// Get all isolates
  Future<List<IsolateRef>> getIsolates() async {
    if (_vmService == null) {
      log(
        LoggingLevel.error,
        'Attempted to get isolates but VM service not connected',
        logger: 'VMService',
      );
      throw StateError('VM service not connected');
    }

    log(LoggingLevel.debug, 'Getting VM isolates', logger: 'VMService');

    try {
      final vm = await _vmService!.getVM();
      final isolates = vm.isolates ?? [];
      log(
        LoggingLevel.debug,
        'Found ${isolates.length} isolates',
        logger: 'VMService',
      );
      return isolates;
    } on Exception catch (e, s) {
      log(
        LoggingLevel.error,
        'Failed to get isolates: $e',
        logger: 'VMService',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
      return [];
    }
  }

  /// Get the Flutter isolate
  Future<IsolateRef?> getFlutterIsolate() async {
    log(
      LoggingLevel.debug,
      'Searching for Flutter isolate',
      logger: 'VMService',
    );

    final isolates = await getIsolates();
    log(
      LoggingLevel.debug,
      'Checking ${isolates.length} isolates for Flutter extensions',
      logger: 'VMService',
    );

    // Find isolate with Flutter extension RPCs
    for (final isolate in isolates) {
      try {
        log(
          LoggingLevel.debug,
          'Checking isolate ${isolate.id} for Flutter extensions',
          logger: 'VMService',
        );
        final isolateInfo = await _vmService!.getIsolate(isolate.id!);
        final extensionRPCs = isolateInfo.extensionRPCs ?? [];

        if (extensionRPCs.any((final ext) => ext.startsWith('ext.flutter'))) {
          log(
            LoggingLevel.info,
            'Found Flutter isolate: ${isolate.id}',
            logger: 'VMService',
          );
          log(
            LoggingLevel.debug,
            () =>
                'Flutter extensions: ${extensionRPCs.where((final ext) => ext.startsWith('ext.flutter')).toList()}',
            logger: 'VMService',
          );
          return isolate;
        }
      } on Exception catch (e) {
        log(
          LoggingLevel.warning,
          'Error checking isolate ${isolate.id}: $e',
          logger: 'VMService',
        );
      }
    }

    log(
      LoggingLevel.warning,
      'No Flutter isolate found among ${isolates.length} isolates',
      logger: 'VMService',
    );
    return null;
  }

  /// Hot reload the Flutter app
  ///
  /// Hard copy from [https://github.com/dart-lang/ai/blob/e04e501de6441528dc530e97ed79400dd201762f/pkgs/dart_mcp_server/lib/src/mixins/dtd.dart#L292]
  Future<Map<String, dynamic>?> hotReload({final bool force = false}) async {
    log(
      LoggingLevel.info,
      'Starting hot reload (force: $force)',
      logger: 'VMService',
    );

    final vmService = this.vmService;
    if (vmService == null) {
      log(
        LoggingLevel.error,
        'Hot reload failed: VM service not connected',
        logger: 'VMService',
      );
      return {'error': 'VM service not connected'};
    }

    try {
      final vm = await vmService.getVM();
      ReloadReport? report;
      StreamSubscription<Event>? serviceStreamSubscription;

      try {
        log(
          LoggingLevel.debug,
          'Setting up service event listener for hot reload',
          logger: 'VMService',
        );
        final hotReloadMethodNameCompleter = Completer<String?>();
        serviceStreamSubscription = vmService
            .onEvent(EventStreams.kService)
            .listen((final e) {
              if (e.kind == EventKind.kServiceRegistered) {
                final serviceName = e.service!;
                if (serviceName == 'reloadSources') {
                  // This may look something like 's0.reloadSources'.
                  log(
                    LoggingLevel.debug,
                    'Found hot reload service: ${e.method}',
                    logger: 'VMService',
                  );
                  hotReloadMethodNameCompleter.complete(e.method);
                }
              }
            });

        await vmService.streamListen(EventStreams.kService);

        final hotReloadMethodName = await hotReloadMethodNameCompleter.future
            .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);

        /// If we haven't seen a specific one, we just call the default one.
        if (hotReloadMethodName == null) {
          log(
            LoggingLevel.debug,
            'Using default reload method',
            logger: 'VMService',
          );
          report = await vmService.reloadSources(
            vm.isolates!.first.id!,
            force: force,
          );
        } else {
          log(
            LoggingLevel.debug,
            'Using custom reload method: $hotReloadMethodName',
            logger: 'VMService',
          );
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

      final isolate = await getFlutterIsolate();
      if (isolate?.id == null) {
        log(
          LoggingLevel.error,
          'Hot reload failed: No isolate found',
          logger: 'VMService',
        );
        return {'error': 'No isolate found'};
      }

      try {
        final result = {'report': report.toJson()};
        log(
          LoggingLevel.info,
          'Hot reload completed successfully',
          logger: 'VMService',
        );
        log(
          LoggingLevel.debug,
          () => 'Hot reload result: $result',
          logger: 'VMService',
        );
        return result;
      } on Exception catch (e, s) {
        log(LoggingLevel.error, 'Hot reload failed: $e', logger: 'VMService');
        log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
        return {'error': 'Hot reload failed: $e $s'};
      }
    } on Exception catch (e, s) {
      log(
        LoggingLevel.error,
        'Hot reload operation failed: $e',
        logger: 'VMService',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
      return {'error': 'Hot reload failed: $e $s'};
    }
  }

  /// Get VM information
  Future<Map<String, dynamic>?> getVMInfo() async {
    log(LoggingLevel.debug, 'Getting VM information', logger: 'VMService');

    if (_vmService == null) {
      log(
        LoggingLevel.error,
        'Cannot get VM info: VM service not connected',
        logger: 'VMService',
      );
      return {'error': 'VM service not connected'};
    }

    try {
      final vm = await _vmService!.getVM();
      final vmInfo = {
        'name': vm.name,
        'version': vm.version,
        'pid': vm.pid,
        'startTime': vm.startTime,
        'isolates':
            vm.isolates
                ?.map(
                  (final i) => {'id': i.id, 'name': i.name, 'number': i.number},
                )
                .toList(),
      };

      log(
        LoggingLevel.debug,
        'VM info retrieved successfully',
        logger: 'VMService',
      );
      log(
        LoggingLevel.debug,
        () => 'VM details: ${vm.name} v${vm.version}, PID: ${vm.pid}',
        logger: 'VMService',
      );
      return vmInfo;
    } on Exception catch (e, s) {
      log(LoggingLevel.error, 'Failed to get VM info: $e', logger: 'VMService');
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
      return {'error': 'Failed to get VM info: $e $s'};
    }
  }

  /// Get available extension RPCs
  Future<Map<String, dynamic>?> getExtensionRPCs() async {
    log(LoggingLevel.debug, 'Getting extension RPCs', logger: 'VMService');

    final isolate = await getFlutterIsolate();
    if (isolate?.id == null) {
      log(
        LoggingLevel.error,
        'Cannot get extension RPCs: No isolate found',
        logger: 'VMService',
      );
      return {'error': 'No isolate found'};
    }

    try {
      final isolateInfo = await _vmService!.getIsolate(isolate!.id!);
      final extensions = isolateInfo.extensionRPCs ?? [];

      log(
        LoggingLevel.debug,
        'Found ${extensions.length} extension RPCs',
        logger: 'VMService',
      );
      log(
        LoggingLevel.debug,
        () => 'Extensions: $extensions',
        logger: 'VMService',
      );

      return {'extensions': extensions};
    } on Exception catch (e, s) {
      log(
        LoggingLevel.error,
        'Failed to get extension RPCs: $e',
        logger: 'VMService',
      );
      log(LoggingLevel.debug, () => 'Stack trace: $s', logger: 'VMService');
      return {'error': 'Failed to get extension RPCs: $e $s'};
    }
  }

  /// Ensure VM service is connected; try to connect if not.
  Future<bool> ensureVMServiceConnected({
    final Duration timeout = const Duration(seconds: 2),
  }) async {
    if (isVMServiceConnected) {
      log(
        LoggingLevel.debug,
        'VM service already connected',
        logger: 'VMService',
      );
      return true;
    }

    log(
      LoggingLevel.info,
      'Attempting to ensure VM service connection '
      '(timeout: ${timeout.inSeconds}s)',
      logger: 'VMService',
    );

    try {
      final connectFuture = initializeVMService();
      if (timeout != Duration.zero) {
        await connectFuture.timeout(timeout);
      } else {
        await connectFuture;
      }

      final connected = isVMServiceConnected;
      if (connected) {
        log(
          LoggingLevel.info,
          'VM service connection ensured successfully',
          logger: 'VMService',
        );
      } else {
        log(
          LoggingLevel.warning,
          'VM service connection could not be established',
          logger: 'VMService',
        );
      }
      return connected;
    } on Exception catch (e) {
      log(
        LoggingLevel.warning,
        'Failed to ensure VM service connection: $e',
        logger: 'VMService',
      );
      return false;
    }
  }
}
