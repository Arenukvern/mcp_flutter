// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/connection_context.dart';
import 'package:flutter_inspector_mcp_server/src/core/core_types.dart';
import 'package:flutter_inspector_mcp_server/src/core/diagnostics_bundle.dart';
import 'package:flutter_inspector_mcp_server/src/core/dynamic_gateway.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_analysis.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_summary_provider.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';
import 'package:flutter_inspector_mcp_server/src/core/services/core_image_file_saver.dart';
import 'package:flutter_inspector_mcp_server/src/core/services/core_port_scanner.dart';
import 'package:flutter_inspector_mcp_server/src/core/session_manager.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/mcp_toolkit_consts.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:vm_service/vm_service.dart';

/// Single command dispatch interface shared by CLI and MCP wrapper.
abstract interface class CoreCommandExecutor {
  Future<CoreResult> execute(final CoreCommand command);
}

final class DefaultCoreCommandExecutor implements CoreCommandExecutor {
  DefaultCoreCommandExecutor({
    required this.connectionContext,
    required this.portScanner,
    required this.imageFileSaver,
    required this.configuration,
    CoreDynamicGateway? dynamicGateway,
    this.sessionManager,
    ErrorCauseAnalyzer? errorCauseAnalyzer,
    Map<String, ErrorSummaryProvider>? summaryProviders,
  }) : _dynamicGateway = dynamicGateway,
       _errorCauseAnalyzer = errorCauseAnalyzer ?? const ErrorCauseAnalyzer(),
       _summaryProviders =
           summaryProviders ??
           <String, ErrorSummaryProvider>{
             'none': const NoopErrorSummaryProvider(),
             'openai': OpenAiErrorSummaryProvider(),
           };

  final ConnectionContext connectionContext;
  final CorePortScanner portScanner;
  final CoreImageFileSaver imageFileSaver;
  final CoreRuntimeConfiguration configuration;
  final SessionManager? sessionManager;

  final ErrorCauseAnalyzer _errorCauseAnalyzer;
  final Map<String, ErrorSummaryProvider> _summaryProviders;

  CoreDynamicGateway? _dynamicGateway;

  void setDynamicGateway(final CoreDynamicGateway? gateway) {
    _dynamicGateway = gateway;
  }

  @override
  Future<CoreResult> execute(final CoreCommand command) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await _dispatch(command);
      stopwatch.stop();
      return _withMeta(result, stopwatch.elapsedMilliseconds, command.name);
    } on Exception catch (e) {
      stopwatch.stop();
      return _withMeta(
        CoreResult.failure(
          code: CoreErrorCode.unexpectedExecutorError,
          message: 'Unexpected executor error: $e',
        ),
        stopwatch.elapsedMilliseconds,
        command.name,
      );
    }
  }

  Future<CoreResult> _dispatch(final CoreCommand command) async {
    return switch (command) {
      ConnectCommand() => _connect(command),
      SessionStartCommand() => _sessionStart(command),
      SessionExecCommand() => _sessionExec(command),
      SessionEndCommand() => _sessionEnd(command),
      DiagnoseCommand() => _diagnose(command),
      WatchCommand() => _watchSnapshot(command),
      ExplainErrorsCommand() => _explainErrors(command),
      StatusCommand() => Future.value(_status()),
      DiscoverDebugAppsCommand() => _discoverDebugApps(),
      GetVmCommand() => _getVm(),
      GetExtensionRpcsCommand() => _getExtensionRpcs(),
      HotReloadFlutterCommand() => _hotReload(command),
      HotRestartFlutterCommand() => _hotRestart(),
      GetActivePortsCommand() => _getActivePorts(),
      GetAppErrorsCommand() => _getAppErrors(command),
      GetScreenshotsCommand() => _getScreenshots(command),
      GetViewDetailsCommand() => _getViewDetails(),
      DebugDumpLayerTreeCommand() => _debugDumpLayerTree(),
      DebugDumpSemanticsTreeCommand() => _debugDumpSemanticsTree(),
      DebugDumpRenderTreeCommand() => _debugDumpRenderTree(),
      DebugDumpFocusTreeCommand() => _debugDumpFocusTree(),
      ListClientToolsAndResourcesCommand() => _listClientToolsAndResources(),
      RunClientToolCommand() => _runClientTool(command),
      RunClientResourceCommand() => _runClientResource(command),
      DynamicRegistryStatsCommand() => _dynamicRegistryStats(command),
    };
  }

  CoreResult _withMeta(
    final CoreResult result,
    final int durationMs,
    final String commandName,
  ) {
    final nextMeta = <String, Object?>{
      ...result.meta,
      'schemaVersion': 'core-envelope/v1',
      'command': commandName,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'durationMs': durationMs,
      'endpoint': connectionContext.activeEndpoint?.display,
      'mode': connectionContext.lastMode.name,
      'selectionDiagnostics': connectionContext.lastSelectionDiagnostics,
    };
    return result.withMeta(nextMeta);
  }

  Future<CoreResult> _connect(final ConnectCommand command) async {
    try {
      final data = await connectionContext.connect(
        mode: command.mode,
        uri: command.uri,
        host: command.host,
        port: command.port,
        forceReconnect: command.forceReconnect,
      );
      return CoreResult.success(data: data);
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.connectFailed,
        message: 'Failed to connect: $e',
      );
    }
  }

  Future<CoreResult> _sessionStart(final SessionStartCommand command) async {
    final manager = sessionManager;
    if (manager == null) {
      return CoreResult.failure(
        code: CoreErrorCode.sessionManagerNotConfigured,
        message: 'Session manager not configured for executor',
      );
    }

    return manager.startSession(command);
  }

  Future<CoreResult> _sessionExec(final SessionExecCommand command) async {
    final manager = sessionManager;
    if (manager == null) {
      return CoreResult.failure(
        code: CoreErrorCode.sessionManagerNotConfigured,
        message: 'Session manager not configured for executor',
      );
    }

    final attach = await manager.attachSession(sessionId: command.sessionId);
    if (!attach.ok) {
      return attach;
    }

    if (_isSessionControlCommand(command.command)) {
      return CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message:
            'session_exec cannot execute session control, watch, or diagnose commands',
      );
    }

    final sessionId = _extractSessionId(attach);
    final innerResult = await _dispatch(command.command);
    await manager.markSessionUsed(
      sessionId,
      endpointOverride: connectionContext.activeEndpoint?.display,
    );

    return innerResult.withMeta({
      ...innerResult.meta,
      'sessionId': sessionId,
      'sessionCommand': command.command.name,
    });
  }

  Future<CoreResult> _sessionEnd(final SessionEndCommand command) async {
    final manager = sessionManager;
    if (manager == null) {
      return CoreResult.failure(
        code: CoreErrorCode.sessionManagerNotConfigured,
        message: 'Session manager not configured for executor',
      );
    }

    return manager.endSession(command.sessionId);
  }

  Future<CoreResult> _diagnose(final DiagnoseCommand command) async {
    try {
      final bundler = DiagnosticsBundler(execute: _dispatch);
      final data = await bundler.run(
        includeViewDetails: command.includeViewDetails,
      );
      return CoreResult.success(data: data);
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.diagnoseFailed,
        message: 'Failed to run diagnostics bundle: $e',
      );
    }
  }

  Future<CoreResult> _watchSnapshot(final WatchCommand command) async {
    if (_isSessionControlCommand(command.command)) {
      return CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message:
            'watch command cannot target session control, diagnose, or watch commands',
      );
    }

    final manager = sessionManager;
    if (command.sessionId != null && manager != null) {
      final attach = await manager.attachSession(sessionId: command.sessionId);
      if (!attach.ok) {
        return attach;
      }
    }

    final snapshotResult = await _dispatch(command.command);
    return CoreResult.success(
      data: {
        'event': 'command_result',
        'command': command.command.name,
        'result': snapshotResult.toEnvelopeJson(),
      },
      meta: {if (command.sessionId != null) 'sessionId': command.sessionId},
    );
  }

  Future<CoreResult> _explainErrors(final ExplainErrorsCommand command) async {
    try {
      final errorsResult = await _getAppErrors(
        GetAppErrorsCommand(count: command.count),
      );
      if (!errorsResult.ok) {
        return errorsResult;
      }

      final data = _map(errorsResult.data);
      final message = jsonDecodeString(
        data['message'],
      ).whenEmptyUse('No errors found');
      final errors = jsonDecodeListAs<Map<String, dynamic>>(
        data['errors'],
      ).map((final e) => e.cast<String, Object?>()).toList();

      final causes = _errorCauseAnalyzer.analyze(errors);

      final provider = _summaryProviders[command.summaryProvider];
      if (provider == null) {
        return CoreResult.failure(
          code: CoreErrorCode.unsupportedSummaryProvider,
          message:
              'Unsupported summary provider: ${command.summaryProvider}. Supported: ${_summaryProviders.keys.join(', ')}',
        );
      }

      String? summary;
      if (command.includeSummary) {
        summary = await provider.summarize(errors: errors, causes: causes);
      }

      return CoreResult.success(
        data: {
          'message': message,
          'errors': errors,
          'causes': causes,
          'summary': summary,
          'summaryProvider': provider.id,
        },
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.explainErrorsFailed,
        message: 'Failed to explain errors: $e',
      );
    }
  }

  CoreResult _status() => CoreResult.success(
    data: {
      'connected': connectionContext.isConnected,
      'activeEndpoint': connectionContext.activeEndpoint?.display,
      'stickyEndpoint': connectionContext.stickyEndpoint?.display,
      'mode': connectionContext.lastMode.name,
      'dynamicRegistrySupported': configuration.dynamicRegistrySupported,
      'sessionsEnabled': sessionManager != null,
    },
  );

  Future<CoreResult> _discoverDebugApps() async {
    try {
      final ports = await portScanner.scanForFlutterPorts();
      return CoreResult.success(data: {'ports': ports, 'count': ports.length});
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.discoverDebugAppsFailed,
        message: 'Failed to discover debug apps: $e',
      );
    }
  }

  Future<CoreResult> _getVm() async {
    final connected = await connectionContext.ensureConnected();
    if (!connected) return _vmNotConnected();

    try {
      final vm = await connectionContext.vmService!.getVM();
      return CoreResult.success(data: vm.toJson());
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getVmFailed,
        message: 'Failed to get VM info: $e',
      );
    }
  }

  Future<CoreResult> _getExtensionRpcs() async {
    final connected = await connectionContext.ensureConnected();
    if (!connected) return _vmNotConnected();

    try {
      final vm = await connectionContext.vmService!.getVM();
      final allExtensions = <String>[];

      for (final isolateRef in vm.isolates ?? <IsolateRef>[]) {
        final isolate = await connectionContext.vmService!.getIsolate(
          isolateRef.id!,
        );
        if (isolate.extensionRPCs == null) continue;
        allExtensions.addAll(isolate.extensionRPCs!);
      }

      final uniqueExtensions = allExtensions.toSet().toList()..sort();
      return CoreResult.success(data: uniqueExtensions);
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getExtensionRpcsFailed,
        message: 'Failed to get extension RPCs: $e',
      );
    }
  }

  Future<CoreResult> _hotReload(final HotReloadFlutterCommand command) async {
    final connected = await connectionContext.ensureConnected();
    if (!connected) return _vmNotConnected();

    final result = await connectionContext.hotReload(force: command.force);
    if (result == null) {
      return CoreResult.failure(
        code: CoreErrorCode.hotReloadFailed,
        message: 'Hot reload failed: null response',
      );
    }

    if (result.containsKey('error')) {
      return CoreResult.failure(
        code: CoreErrorCode.hotReloadFailed,
        message: '${result['error']}',
      );
    }

    return CoreResult.success(data: result);
  }

  Future<CoreResult> _hotRestart() async {
    final connected = await connectionContext.ensureConnected();
    if (!connected) return _vmNotConnected();

    final result = await connectionContext.hotRestart();
    if (result == null) {
      return CoreResult.failure(
        code: CoreErrorCode.hotRestartFailed,
        message: 'Hot restart failed: null response',
      );
    }

    if (result.containsKey('error')) {
      return CoreResult.failure(
        code: CoreErrorCode.hotRestartFailed,
        message: '${result['error']}',
      );
    }

    return CoreResult.success(data: result);
  }

  Future<CoreResult> _getActivePorts() async {
    try {
      final ports = await portScanner.scanForFlutterPorts();
      return CoreResult.success(data: ports);
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getActivePortsFailed,
        message: 'Failed to get active ports: $e',
      );
    }
  }

  Future<CoreResult> _getAppErrors(final GetAppErrorsCommand command) async {
    final connected = await connectionContext.ensureConnected();
    if (!connected) return _vmNotConnected();

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.appErrors,
        args: {'count': command.count},
      );

      final errors = jsonDecodeListAs<Map<String, dynamic>>(
        result.json?['errors'],
      ).map((final e) => e.cast<String, Object?>()).toList();
      final message = jsonDecodeString(
        result.json?['message'],
      ).whenEmptyUse('No errors found');

      return CoreResult.success(data: {'message': message, 'errors': errors});
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getAppErrorsFailed,
        message: 'Failed to get app errors: $e',
      );
    }
  }

  Future<CoreResult> _getScreenshots(
    final GetScreenshotsCommand command,
  ) async {
    final connected = await connectionContext.ensureConnected();
    if (!connected) return _vmNotConnected();

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.viewScreenshots,
        args: {'compress': command.compress},
      );

      final images = jsonDecodeListAs<String>(result.json?['images']);
      if (!configuration.saveImagesToFiles) {
        return CoreResult.success(
          data: {'images': images, 'fileUrls': const <String>[]},
        );
      }

      await imageFileSaver.cleanupOldScreenshots();
      final fileUrls = await imageFileSaver.saveImagesToFiles(images);

      return CoreResult.success(
        data: {'images': const <String>[], 'fileUrls': fileUrls},
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getScreenshotsFailed,
        message: 'Failed to get screenshots: $e',
      );
    }
  }

  Future<CoreResult> _getViewDetails() async {
    final connected = await connectionContext.ensureConnected();
    if (!connected) return _vmNotConnected();

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.viewDetails,
      );
      final details = jsonDecodeListAs<Map<String, dynamic>>(
        result.json?['details'],
      ).map((final e) => e.cast<String, Object?>()).toList();
      final message = jsonDecodeString(
        result.json?['message'],
      ).whenEmptyUse('View details');

      return CoreResult.success(data: {'message': message, 'details': details});
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getViewDetailsFailed,
        message: 'Failed to get view details: $e',
      );
    }
  }

  Future<CoreResult> _debugDumpLayerTree() async {
    return _debugDump('ext.flutter.debugDumpLayerTree');
  }

  Future<CoreResult> _debugDumpSemanticsTree() async {
    return _debugDump('ext.flutter.debugDumpSemanticsTreeInTraversalOrder');
  }

  Future<CoreResult> _debugDumpRenderTree() async {
    return _debugDump('ext.flutter.debugDumpRenderTree');
  }

  Future<CoreResult> _debugDumpFocusTree() async {
    return _debugDump('ext.flutter.debugDumpFocusTree');
  }

  Future<CoreResult> _debugDump(final String extensionName) async {
    final connected = await connectionContext.ensureConnected();
    if (!connected) return _vmNotConnected();

    try {
      final response = await connectionContext.callFlutterExtension(
        extensionName,
        args: const <String, dynamic>{},
      );
      return CoreResult.success(
        data: response.json ?? const <String, Object?>{},
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.debugDumpFailed,
        message: 'Debug dump failed: $e',
      );
    }
  }

  Future<CoreResult> _listClientToolsAndResources() async {
    if (!configuration.dynamicRegistrySupported) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicRegistryDisabled,
        message: 'Dynamic registry support is disabled',
      );
    }

    final gateway =
        _dynamicGateway ??
        VmExtensionDynamicGateway(connectionContext: connectionContext);

    return gateway.listClientToolsAndResources();
  }

  Future<CoreResult> _runClientTool(final RunClientToolCommand command) async {
    if (!configuration.dynamicRegistrySupported) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicRegistryDisabled,
        message: 'Dynamic registry support is disabled',
      );
    }

    final gateway =
        _dynamicGateway ??
        VmExtensionDynamicGateway(connectionContext: connectionContext);

    return gateway.runClientTool(command.toolName, command.arguments);
  }

  Future<CoreResult> _runClientResource(
    final RunClientResourceCommand command,
  ) async {
    if (!configuration.dynamicRegistrySupported) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicRegistryDisabled,
        message: 'Dynamic registry support is disabled',
      );
    }

    final gateway =
        _dynamicGateway ??
        VmExtensionDynamicGateway(connectionContext: connectionContext);

    return gateway.runClientResource(command.resourceUri);
  }

  Future<CoreResult> _dynamicRegistryStats(
    final DynamicRegistryStatsCommand command,
  ) async {
    if (!configuration.dynamicRegistrySupported) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicRegistryDisabled,
        message: 'Dynamic registry support is disabled',
      );
    }

    final gateway =
        _dynamicGateway ??
        VmExtensionDynamicGateway(connectionContext: connectionContext);

    return gateway.dynamicRegistryStats(
      includeAppDetails: command.includeAppDetails,
    );
  }

  bool _isSessionControlCommand(final CoreCommand command) {
    return command is SessionStartCommand ||
        command is SessionExecCommand ||
        command is SessionEndCommand ||
        command is WatchCommand ||
        command is DiagnoseCommand;
  }

  String? _extractSessionId(final CoreResult result) {
    final metaSession = result.meta['sessionId'];
    if (metaSession is String && metaSession.isNotEmpty) {
      return metaSession;
    }

    final data = result.data;
    if (data is Map && data['sessionId'] is String) {
      final sessionId = data['sessionId'] as String;
      if (sessionId.isNotEmpty) return sessionId;
    }

    return null;
  }

  Map<String, Object?> _map(final Object? data) {
    if (data is Map<String, Object?>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }

  CoreResult _vmNotConnected() => CoreResult.failure(
    code: CoreErrorCode.vmNotConnected,
    message: 'VM service not connected',
  );
}
