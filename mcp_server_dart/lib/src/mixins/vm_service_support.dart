// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses, lines_longer_than_80_chars

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/connection_context.dart';
import 'package:flutter_inspector_mcp_server/src/core/core_types.dart';
import 'package:flutter_inspector_mcp_server/src/core/dynamic_gateway.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/services/core_image_file_saver.dart';
import 'package:flutter_inspector_mcp_server/src/core/services/core_port_scanner.dart';
import 'package:flutter_inspector_mcp_server/src/core/services/flutter_tool_machine_discovery.dart';
import 'package:vm_service/vm_service.dart';

/// Mixin that exposes VM service lifecycle but delegates implementation to core.
base mixin VMServiceSupport on BaseMCPToolkitServer {
  late final FlutterToolMachineDiscovery _flutterMachineDiscovery =
      FlutterToolMachineDiscovery(logger: _log);

  late final ConnectionContext _connectionContext = ConnectionContext(
    defaultHost: configuration.vmHost,
    defaultPort: configuration.vmPort,
    logger: _log,
    discoverPorts: _corePortScanner.scanForFlutterPorts,
    discoverMachineTargets: _discoverMachineTargets,
  );

  late final CorePortScanner _corePortScanner = CorePortScanner(logger: _log);

  late final CoreImageFileSaver _coreImageFileSaver = CoreImageFileSaver(
    logger: _log,
  );

  Future<List<FlutterMachineDiscoveryTarget>> _discoverMachineTargets() {
    return _flutterMachineDiscovery.discover(
      projectDir: configuration.flutterProjectDir,
      device: configuration.flutterDevice,
      timeout: Duration(milliseconds: configuration.flutterDiscoveryTimeoutMs),
    );
  }

  late final DefaultCoreCommandExecutor _coreCommandExecutor =
      DefaultCoreCommandExecutor(
        connectionContext: _connectionContext,
        portScanner: _corePortScanner,
        imageFileSaver: _coreImageFileSaver,
        configuration: CoreRuntimeConfiguration(
          vmHost: configuration.vmHost,
          vmPort: configuration.vmPort,
          resourcesSupported: configuration.resourcesSupported,
          imagesSupported: configuration.imagesSupported,
          dumpsSupported: configuration.dumpsSupported,
          dynamicRegistrySupported: configuration.dynamicRegistrySupported,
          saveImagesToFiles: configuration.saveImagesToFiles,
        ),
      );

  void _log(
    final LoggingLevel level,
    final String message, {
    final String logger = 'VMService',
  }) {
    log(level, message, logger: logger);
  }

  void Function()? _onVMServiceReconnected;

  /// Callback invoked when VM service reconnects after a disconnection.
  void Function()? get onVMServiceReconnected => _onVMServiceReconnected;

  set onVMServiceReconnected(final void Function()? callback) {
    _onVMServiceReconnected = callback;
    _connectionContext.onReconnected = callback;
  }

  /// Shared core command executor.
  CoreCommandExecutor get coreCommandExecutor => _coreCommandExecutor;

  /// Shared connection context.
  ConnectionContext get connectionContext => _connectionContext;

  /// Install/replace the dynamic command gateway used by core executor.
  void attachDynamicGateway(final CoreDynamicGateway? gateway) {
    _coreCommandExecutor.setDynamicGateway(gateway);
  }

  /// Get the current VM service instance.
  VmService? get vmService => _connectionContext.vmService;

  DartToolingDaemon? get dartToolingDaemon =>
      _connectionContext.dartToolingDaemon;

  /// Check if VM service is connected.
  bool get isVMServiceConnected => _connectionContext.isConnected;

  /// Initialize VM service connection using configured host/port.
  Future<void> initializeVMService() async {
    await _connectionContext.connect(
      mode: CoreConnectionMode.auto,
      forceReconnect: true,
      timeout: const Duration(seconds: 3),
    );
  }

  /// Disconnect from VM service.
  Future<void> disconnectVMService() async {
    await _connectionContext.disconnect();
  }

  /// Call a Flutter extension method.
  Future<Response> callFlutterExtension(
    final String method, {
    final Map<String, dynamic>? args,
  }) => _connectionContext.callFlutterExtension(method, args: args);

  /// Call a service extension method.
  Future<Response?> callServiceExtension(
    final String method, {
    final String? isolateId,
    final Map<String, dynamic>? args,
  }) => _connectionContext.callServiceExtension(
    method,
    isolateId: isolateId,
    args: args,
  );

  /// Get all isolates.
  Future<List<IsolateRef>> getIsolates() => _connectionContext.getIsolates();

  /// Get the Flutter isolate.
  Future<IsolateRef?> getFlutterIsolate() =>
      _connectionContext.getFlutterIsolate();

  /// Hot reload the Flutter app.
  Future<Map<String, dynamic>?> hotReload({final bool force = false}) =>
      _connectionContext.hotReload(force: force);

  /// Get VM information.
  Future<Map<String, dynamic>?> getVMInfo() async {
    final vmService = this.vmService;
    if (vmService == null) {
      return {'error': 'VM service not connected'};
    }

    try {
      final vm = await vmService.getVM();
      return {
        'name': vm.name,
        'version': vm.version,
        'pid': vm.pid,
        'startTime': vm.startTime,
        'isolates': vm.isolates
            ?.map((final i) => {'id': i.id, 'name': i.name, 'number': i.number})
            .toList(),
      };
    } on Exception catch (e, s) {
      return {'error': 'Failed to get VM info: $e $s'};
    }
  }

  /// Get available extension RPCs.
  Future<Map<String, dynamic>?> getExtensionRPCs() async {
    final isolate = await getFlutterIsolate();
    if (isolate?.id == null) {
      return {'error': 'No isolate found'};
    }

    try {
      final isolateInfo = await vmService!.getIsolate(isolate!.id!);
      return {'extensions': isolateInfo.extensionRPCs ?? <String>[]};
    } on Exception catch (e, s) {
      return {'error': 'Failed to get extension RPCs: $e $s'};
    }
  }

  /// Ensure VM service is connected.
  Future<bool> ensureVMServiceConnected({
    final Duration timeout = const Duration(seconds: 2),
  }) async {
    final ensure = await _connectionContext.ensureConnectedWithPolicy(
      timeout: timeout,
    );
    return ensure.connected;
  }

  /// Hot restart the Flutter app.
  Future<Map<String, dynamic>?> hotRestart() => _connectionContext.hotRestart();
}
