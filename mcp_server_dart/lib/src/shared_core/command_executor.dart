// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_inspector_mcp_server/src/capabilities/ai_providers/error_summary_provider.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/diagnostics/diagnostics_bundle.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/dynamic_registry/dynamic_gateway.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/error_analysis/error_analysis.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/live_edit/live_edit_command_executor.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/live_edit/live_edit_host_bindings.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/visual_capture/core_image_file_saver.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/visual_capture/desktop_window_screenshot.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/visual_capture/visual_capture.dart';
import 'package:flutter_inspector_mcp_server/src/cli/session/session_manager.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_consts.dart';
import 'package:flutter_inspector_mcp_server/src/runtime_version.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/commands/commands.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/types/core_types.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/types/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/types/results.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/vm_connections/connection_context.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/vm_connections/core_port_scanner.dart';
import 'package:flutter_live_edit_toolkit/src/ai/agent/live_edit_agent_service.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:vm_service/vm_service.dart';

Future<void> _defaultActivateMacOsTargetPid(final int pid) async {
  try {
    await Process.run('swift', <String>[
      '-e',
      'import AppKit; import Foundation; '
          'let pid = pid_t($pid); '
          'guard let app = NSRunningApplication(processIdentifier: pid) '
          'else { Foundation.exit(2) }; '
          'let activated = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]); '
          'Foundation.exit(activated ? 0 : 1)',
    ]);
  } on Exception {
    // Best effort only. Capture still runs even if activation fails.
  }
}

/// Single command dispatch interface shared by CLI and MCP wrapper.
// ignore: one_member_abstracts
abstract interface class CoreCommandExecutor {
  Future<CoreResult> execute(final CoreCommand command);
}

final class DefaultCoreCommandExecutor implements CoreCommandExecutor {
  DefaultCoreCommandExecutor({
    required this.connectionContext,
    required this.portScanner,
    required this.imageFileSaver,
    required this.configuration,
    final CoreDynamicGateway? dynamicGateway,
    final DesktopWindowScreenshotService? desktopWindowScreenshotService,
    this.sessionManager,
    final ErrorCauseAnalyzer? errorCauseAnalyzer,
    final Map<String, ErrorSummaryProvider>? summaryProviders,
    final Future<void> Function(int pid)? activateMacOsTargetPid,
    final LiveEditAgentService? liveEditAgentService,
  }) : _dynamicGateway = dynamicGateway,
       _desktopWindowScreenshotService =
           desktopWindowScreenshotService ??
           MacOsDesktopWindowScreenshotService(),
       _errorCauseAnalyzer = errorCauseAnalyzer ?? const ErrorCauseAnalyzer(),
       _activateMacOsTargetPid =
           activateMacOsTargetPid ?? _defaultActivateMacOsTargetPid,
       _summaryProviders =
           summaryProviders ??
           <String, ErrorSummaryProvider>{
             'none': const NoopErrorSummaryProvider(),
             'openai': OpenAiErrorSummaryProvider(),
           } {
    _liveEditExecutor = configuration.liveEditSupported
        ? LiveEditCommandExecutor(
            host: _ExecutorLiveEditBindings(this),
            agentService: liveEditAgentService,
          )
        : null;
  }

  final ConnectionContext connectionContext;
  final CorePortScanner portScanner;
  final CoreImageFileSaver imageFileSaver;
  final CoreRuntimeConfiguration configuration;
  final SessionManager? sessionManager;

  final ErrorCauseAnalyzer _errorCauseAnalyzer;
  final Map<String, ErrorSummaryProvider> _summaryProviders;
  final DesktopWindowScreenshotService _desktopWindowScreenshotService;
  final Future<void> Function(int pid) _activateMacOsTargetPid;

  CoreDynamicGateway? _dynamicGateway;
  LiveEditCommandExecutor? _liveEditExecutor;

  Iterable<VisualCapturePlatformAdapter> get visualCaptureAdapters sync* {
    if (_desktopWindowScreenshotService
        case final VisualCapturePlatformAdapter adapter) {
      yield adapter;
    }
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

  void setDynamicGateway(final CoreDynamicGateway? gateway) {
    _dynamicGateway = gateway;
  }

  List<Map<String, Object?>> _buildImageSummaries(
    final Map<String, Object?> screenshotData,
  ) {
    final summaries = <Map<String, Object?>>[];

    final images = jsonDecodeListAs<String>(screenshotData['images']);
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      summaries.add({
        'id': 'image_${i + 1}',
        'source': 'inline_base64',
        'hash': _stableStringHash(image),
      });
    }

    final fileUrls = jsonDecodeListAs<String>(screenshotData['fileUrls']);
    for (var i = 0; i < fileUrls.length; i++) {
      final url = fileUrls[i];
      summaries.add({
        'id': 'image_${images.length + i + 1}',
        'source': 'file_url',
        'fileUrl': url,
        'hash': _stableStringHash(url),
      });
    }

    return summaries;
  }

  Future<CoreResult> _captureUiSnapshot(
    final CaptureUiSnapshotCommand command,
  ) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    final screenshotResult = await _getScreenshots(
      GetScreenshotsCommand(
        compress: command.compress,
        mode: command.screenshotMode,
        permissionPolicy: command.permissionPolicy,
      ),
    );
    if (!screenshotResult.ok) {
      return screenshotResult;
    }

    final screenshotData = _map(screenshotResult.data);
    final imageSummaries = _buildImageSummaries(screenshotData);

    Object? viewDetails;
    if (command.includeViewDetails) {
      final viewResult = await _getViewDetails();
      if (!viewResult.ok) {
        return viewResult;
      }
      viewDetails = viewResult.data;
    }

    Object? appErrors;
    if (command.includeErrors) {
      final errorResult = await _getAppErrors(
        GetAppErrorsCommand(count: command.errorsCount),
      );
      if (!errorResult.ok) {
        return errorResult;
      }
      appErrors = errorResult.data;
    }

    return CoreResult.success(
      data: {
        'message': 'Captured UI snapshot bundle.',
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'screenshots': screenshotData,
        'imageSummaries': imageSummaries,
        'viewDetails': ?viewDetails,
        'appErrors': ?appErrors,
        'summary': {
          'imageCount': imageSummaries.length,
          'includeViewDetails': command.includeViewDetails,
          'includeErrors': command.includeErrors,
          'errorsCount': command.errorsCount,
          'compress': command.compress,
          'requestedMode': command.screenshotMode.wireName,
          'actualMode':
              screenshotData['actualMode'] ?? screenshotData['captureMode'],
          'permissionStatus':
              _map(screenshotData['permission'])['status'] ??
              PermissionStatus.unsupported.wireName,
          'fallbackReason': screenshotData['fallbackReason'],
        },
      },
    );
  }

  Future<CoreResult> _connect(final ConnectCommand command) async {
    try {
      final data = await connectionContext.connect(
        mode: command.mode,
        targetId: command.targetId,
        uri: command.uri,
        host: command.host,
        port: command.port,
        forceReconnect: command.forceReconnect,
      );
      return CoreResult.success(data: data);
    } on CoreConnectionException catch (e) {
      if (e.reason == CoreConnectionFailureReason.multipleTargets) {
        return CoreResult.failure(
          code: CoreErrorCode.connectionSelectionRequired,
          message: e.message,
          details: e.details,
        );
      }

      return CoreResult.failure(
        code: CoreErrorCode.connectFailed,
        message: 'Failed to connect: ${e.message}',
        details: e.details,
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.connectFailed,
        message: 'Failed to connect: $e',
      );
    }
  }

  Future<int?> _connectedVmPid() async {
    final vmService = connectionContext.vmService;
    if (vmService == null) {
      return null;
    }
    try {
      final vm = await vmService.getVM();
      final pid = vm.pid;
      if (pid is int && pid > 0) {
        return pid;
      }
      return int.tryParse('$pid');
    } on Object {
      return null;
    }
  }

  Future<CoreResult> _debugDump(final String extensionName) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

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

  Future<CoreResult> _debugDumpFocusTree() =>
      _debugDump('ext.flutter.debugDumpFocusTree');

  Future<CoreResult> _debugDumpLayerTree() =>
      _debugDump('ext.flutter.debugDumpLayerTree');

  Future<CoreResult> _debugDumpRenderTree() =>
      _debugDump('ext.flutter.debugDumpRenderTree');

  Future<CoreResult> _debugDumpSemanticsTree() =>
      _debugDump('ext.flutter.debugDumpSemanticsTreeInTraversalOrder');

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

  Future<CoreResult> _discoverDebugApps() async {
    try {
      final targets = await connectionContext.discoverTargets();
      final ports = targets.map((final target) => target.port).toSet().toList()
        ..sort();
      return CoreResult.success(
        data: {
          'targets': targets.map((final target) => target.toJson()).toList(),
          'ports': ports,
          'count': targets.length,
          'diagnostics': connectionContext.lastDiscoveryDiagnostics,
        },
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.discoverDebugAppsFailed,
        message: 'Failed to discover debug apps: $e',
      );
    }
  }

  Future<CoreResult> _dispatch(final CoreCommand command) => switch (command) {
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
    InspectWidgetAtPointCommand() => _inspectWidgetAtPoint(command),
    CaptureUiSnapshotCommand() => _captureUiSnapshot(command),
    SemanticSnapshotCommand() => _semanticSnapshot(),
    TapWidgetCommand() => _tapWidget(command),
    EnterTextCommand() => _enterText(command),
    ScrollCommand() => _scroll(command),
    LongPressCommand() => _longPress(command),
    SwipeCommand() => _swipe(command),
    DragCommand() => _drag(command),
    HotReloadAndCaptureCommand() => _hotReloadAndCapture(command),
    EvaluateDartExpressionCommand() => _evaluateDartExpression(command),
    GetRecentLogsCommand() => _getRecentLogs(command),
    WaitForCommand() => _waitFor(command),
    PressKeyCommand() => Future.value(
      CoreResult.failure(
        code: CoreErrorCode.pressKeyFailed,
        message: 'press_key is registered but not yet implemented',
      ),
    ),
    HandleDialogCommand() => Future.value(
      CoreResult.failure(
        code: CoreErrorCode.handleDialogFailed,
        message: 'handle_dialog is registered but not yet implemented',
      ),
    ),
    NavigateCommand() => Future.value(
      CoreResult.failure(
        code: CoreErrorCode.navigateFailed,
        message: 'navigate is registered but not yet implemented',
      ),
    ),
    DebugDumpLayerTreeCommand() => _debugDumpLayerTree(),
    DebugDumpSemanticsTreeCommand() => _debugDumpSemanticsTree(),
    DebugDumpRenderTreeCommand() => _debugDumpRenderTree(),
    DebugDumpFocusTreeCommand() => _debugDumpFocusTree(),
    ListClientToolsAndResourcesCommand() => _listClientToolsAndResources(),
    RunClientToolCommand() => _runClientTool(command),
    RunClientResourceCommand() => _runClientResource(command),
    final LiveEditCommand c =>
      _liveEditExecutor?.execute(c) ??
          Future.value(
            CoreResult.failure(
              code: CoreErrorCode.liveEditDisabled,
              message: 'Live edit support is disabled',
            ),
          ),
    DynamicRegistryStatsCommand() => _dynamicRegistryStats(command),
  };

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

    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    return gateway.dynamicRegistryStats(
      includeAppDetails: command.includeAppDetails,
    );
  }

  Map<String, Object?> _enrichErrorWithTopFrame(
    final Map<String, Object?> error,
  ) {
    final next = <String, Object?>{...error};
    final stackTrace = '${next['stackTrace'] ?? ''}'.trim();
    if (stackTrace.isEmpty) {
      return next;
    }

    final frames = _parseStackFrames(stackTrace);
    if (frames.isEmpty) {
      return next;
    }

    next['topFrame'] = frames.first;
    next['frames'] = frames;
    return next;
  }

  Future<CoreResult?> _ensureVmConnected() async {
    final ensure = await connectionContext.ensureConnectedWithPolicy();
    if (ensure.connected) {
      return null;
    }

    return CoreResult.failure(
      code: ensure.code ?? CoreErrorCode.vmNotConnected,
      message: ensure.message ?? 'VM service not connected',
      details: ensure.details,
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
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.appErrors,
        args: {'count': command.count},
      );

      final rawErrors = jsonDecodeListAs<Map<String, dynamic>>(
        result.json?['errors'],
      ).map((final e) => e.cast<String, Object?>()).toList();
      final errors = rawErrors.map(_enrichErrorWithTopFrame).toList();
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

  Future<CoreResult> _getExtensionRpcs() async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

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

  Future<CoreResult> _getScreenshots(
    final GetScreenshotsCommand command,
  ) async {
    final permission = await _visualCaptureBroker().prepareForCapture(
      requestedMode: command.mode.wireName,
      policy: command.permissionPolicy,
    );
    if (!permission.canCapture) {
      return _visualCaptureFailure(
        permission,
        defaultMessage: 'Visual capture is unavailable for this request.',
      );
    }

    if (permission.actualMode == screenshotModeDesktopWindow) {
      final desktopCapture = await _tryDesktopWindowCapture(command);
      if (desktopCapture.data != null) {
        return CoreResult.success(
          data: _withPermissionMetadata(
            data: desktopCapture.data!,
            requestedMode: command.mode.wireName,
            permission: permission,
          ),
        );
      }
      return CoreResult.failure(
        code: CoreErrorCode.getScreenshotsFailed,
        message:
            desktopCapture.errorMessage ?? 'Desktop window screenshot failed.',
        details: <String, Object?>{
          'permission': permission.toJson(),
          if (desktopCapture.errorDetails.isNotEmpty)
            'desktopWindow': desktopCapture.errorDetails,
        },
      );
    }

    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.viewScreenshots,
        args: {'compress': command.compress},
      );

      final images = jsonDecodeListAs<String>(result.json?['images']);
      if (!configuration.saveImagesToFiles) {
        return CoreResult.success(
          data: _withPermissionMetadata(
            data: {
              'images': images,
              'fileUrls': const <String>[],
              'captureMode': screenshotModeFlutterLayer,
            },
            requestedMode: command.mode.wireName,
            permission: permission,
          ),
        );
      }

      await imageFileSaver.cleanupOldScreenshots();
      final fileUrls = await imageFileSaver.saveImagesToFiles(images);

      return CoreResult.success(
        data: _withPermissionMetadata(
          data: {
            'images': const <String>[],
            'fileUrls': fileUrls,
            'captureMode': screenshotModeFlutterLayer,
          },
          requestedMode: command.mode.wireName,
          permission: permission,
        ),
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getScreenshotsFailed,
        message: 'Failed to get screenshots: $e',
      );
    }
  }

  Future<CoreResult> _getViewDetails() async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.viewDetails,
      );
      final payload = _map(result.json);
      final details = jsonDecodeListAs<Map<String, dynamic>>(
        payload['details'],
      ).map((final e) => e.cast<String, Object?>()).toList();
      final message = jsonDecodeString(
        payload['message'],
      ).whenEmptyUse('View details');

      return CoreResult.success(
        data: {...payload, 'message': message, 'details': details},
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getViewDetailsFailed,
        message: 'Failed to get view details: $e',
      );
    }
  }

  Future<CoreResult> _getVm() async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

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

  Future<CoreResult> _hotReload(final HotReloadFlutterCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

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
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

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

  Future<CoreResult> _inspectWidgetAtPoint(
    final InspectWidgetAtPointCommand command,
  ) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.inspectWidgetAtPoint,
        args: {
          'x': command.x,
          'y': command.y,
          if (command.viewId != null) 'viewId': command.viewId,
        },
      );
      return CoreResult.success(data: _map(result.json));
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getViewDetailsFailed,
        message: 'Failed to inspect widget at point: $e',
      );
    }
  }

  Future<CoreResult> _semanticSnapshot() async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.semanticSnapshot,
      );
      return CoreResult.success(data: _map(result.json));
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.semanticSnapshotFailed,
        message: 'Failed to get semantic snapshot: $e',
      );
    }
  }

  Future<CoreResult> _tapWidget(final TapWidgetCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.tapWidget,
        args: {
          'ref': command.ref,
          if (command.snapshotId != null) 'snapshotId': command.snapshotId,
        },
      );
      return CoreResult.success(data: _map(result.json));
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.interactionFailed,
        message: 'Failed to tap widget: $e',
      );
    }
  }

  Future<CoreResult> _enterText(final EnterTextCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.enterText,
        args: {
          'ref': command.ref,
          'text': command.text,
          if (command.snapshotId != null) 'snapshotId': command.snapshotId,
        },
      );
      return CoreResult.success(data: _map(result.json));
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.interactionFailed,
        message: 'Failed to enter text: $e',
      );
    }
  }

  Future<CoreResult> _scroll(final ScrollCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.scroll,
        args: {
          'direction': command.direction,
          if (command.ref != null) 'ref': command.ref,
          'distance': command.distance,
          if (command.snapshotId != null) 'snapshotId': command.snapshotId,
        },
      );
      return CoreResult.success(data: _map(result.json));
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.interactionFailed,
        message: 'Failed to scroll: $e',
      );
    }
  }

  Future<CoreResult> _longPress(final LongPressCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.longPress,
        args: {
          'ref': command.ref,
          if (command.snapshotId != null) 'snapshotId': command.snapshotId,
        },
      );
      return CoreResult.success(data: _map(result.json));
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.interactionFailed,
        message: 'Failed to long press: $e',
      );
    }
  }

  Future<CoreResult> _swipe(final SwipeCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.swipe,
        args: {
          'direction': command.direction,
          if (command.ref != null) 'ref': command.ref,
          'distance': command.distance,
          if (command.snapshotId != null) 'snapshotId': command.snapshotId,
        },
      );
      return CoreResult.success(data: _map(result.json));
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.interactionFailed,
        message: 'Failed to swipe: $e',
      );
    }
  }

  Future<CoreResult> _drag(final DragCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.drag,
        args: {
          'fromRef': command.fromRef,
          'toRef': command.toRef,
          if (command.snapshotId != null) 'snapshotId': command.snapshotId,
        },
      );
      return CoreResult.success(data: _map(result.json));
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.interactionFailed,
        message: 'Failed to drag: $e',
      );
    }
  }

  Future<CoreResult> _hotReloadAndCapture(
    final HotReloadAndCaptureCommand command,
  ) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    // Step 1: Hot reload
    final reloadResult = await connectionContext.hotReload();
    final reloadSuccess =
        reloadResult != null && !reloadResult.containsKey('error');

    // Step 2: Wait for frame to settle
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Step 3: Capture screenshot
    Map<String, Object?> screenshotData = {};
    try {
      final screenshotResult = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.viewScreenshots,
        args: {'compress': command.compress},
      );
      screenshotData = _map(screenshotResult.json);
    } on Exception catch (e) {
      screenshotData = {'error': 'Screenshot failed: $e'};
    }

    // Step 4: Semantic snapshot (if requested)
    Map<String, Object?> semanticsData = {};
    if (command.includeSemantics) {
      try {
        final semanticsResult = await connectionContext.callFlutterExtension(
          mcpToolkitExtKeys.semanticSnapshot,
        );
        semanticsData = _map(semanticsResult.json);
      } on Exception catch (e) {
        semanticsData = {'error': 'Semantic snapshot failed: $e'};
      }
    }

    // Step 5: App errors (if requested)
    Map<String, Object?> errorsData = {};
    if (command.includeErrors) {
      try {
        final errorsResult = await connectionContext.callFlutterExtension(
          mcpToolkitExtKeys.appErrors,
          args: {'count': command.errorsCount},
        );
        errorsData = _map(errorsResult.json);
      } on Exception catch (e) {
        errorsData = {'error': 'Error capture failed: $e'};
      }
    }

    return CoreResult.success(
      data: {
        'hotReload': {
          'success': reloadSuccess,
          if (reloadResult != null) ...reloadResult,
        },
        'screenshot': screenshotData,
        if (command.includeSemantics) 'semantics': semanticsData,
        if (command.includeErrors) 'errors': errorsData,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<CoreResult> _evaluateDartExpression(
    final EvaluateDartExpressionCommand command,
  ) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final isolate = await connectionContext.getFlutterIsolate();
      if (isolate?.id == null) {
        return CoreResult.failure(
          code: CoreErrorCode.evaluateExpressionFailed,
          message: 'No Flutter isolate found',
        );
      }

      final vmService = connectionContext.vmService;
      if (vmService == null) {
        return CoreResult.failure(
          code: CoreErrorCode.evaluateExpressionFailed,
          message: 'VM service not connected',
        );
      }

      final isolateObj = await vmService.getIsolate(isolate!.id!);
      final rootLib = isolateObj.rootLib;
      if (rootLib?.id == null) {
        return CoreResult.failure(
          code: CoreErrorCode.evaluateExpressionFailed,
          message: 'Could not find root library for evaluation',
        );
      }

      final result = await vmService.evaluate(
        isolate.id!,
        rootLib!.id!,
        command.expression,
      );

      if (result is ErrorRef) {
        return CoreResult.failure(
          code: CoreErrorCode.evaluateExpressionFailed,
          message: 'Expression evaluation error: ${result.message}',
        );
      }

      final instanceRef = result as InstanceRef;
      return CoreResult.success(
        data: {
          'expression': command.expression,
          'result':
              instanceRef.valueAsString ?? instanceRef.classRef?.name ?? 'null',
          'kind': instanceRef.kind,
          'classRef': instanceRef.classRef?.name,
        },
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.evaluateExpressionFailed,
        message: 'Failed to evaluate expression: $e',
      );
    }
  }

  Future<CoreResult> _getRecentLogs(final GetRecentLogsCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.getRecentLogs,
        args: {'count': command.count},
      );
      return CoreResult.success(data: _map(result.json));
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.getRecentLogsFailed,
        message: 'Failed to get recent logs: $e',
      );
    }
  }

  Future<CoreResult> _waitFor(final WaitForCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.waitFor,
        args: {
          // Extension RPC args are stringly-typed; the toolkit-side handler
          // calls `jsonDecodeMap` on this. See `OnWaitForEntry` in
          // mcp_toolkit/.../toolkits/interaction_toolkit.dart.
          'predicate': jsonEncode(command.predicate),
          'timeoutMs': command.timeoutMs,
        },
      );
      final data = _map(result.json);
      final matched = data['matched'];
      // Treat anything other than literal `true` as a failure — the toolkit
      // writes bool literals, but a coerced wire value (string/int/null)
      // could otherwise slip through to the success path with a malformed
      // payload. Distinguish: matched==false → expected timeout; otherwise
      // bucket as waitForFailed (server/transport bug).
      if (matched != true) {
        return CoreResult.failure(
          code: matched == false
              ? CoreErrorCode.waitTimeout
              : CoreErrorCode.waitForFailed,
          message: matched == false
              ? 'wait_for timed out after ${data['elapsedMs']}ms'
              : 'wait_for returned malformed payload (matched=$matched)',
          details: data,
        );
      }
      return CoreResult.success(data: data);
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.waitForFailed,
        message: 'Failed to execute wait_for: $e',
      );
    }
  }

  bool _isSessionControlCommand(final CoreCommand command) =>
      command is SessionStartCommand ||
      command is SessionExecCommand ||
      command is SessionEndCommand ||
      command is WatchCommand ||
      command is DiagnoseCommand;

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

    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    return gateway.listClientToolsAndResources();
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

  List<Map<String, Object?>> _parseStackFrames(final String stackTrace) {
    final lines = stackTrace.split('\n');
    final frames = <Map<String, Object?>>[];
    final pattern = RegExp(r'\(([^:]+):(\d+):(\d+)\)$');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final match = pattern.firstMatch(trimmed);
      if (match == null) {
        continue;
      }

      final file = match.group(1);
      final lineNumber = int.tryParse(match.group(2) ?? '');
      final columnNumber = int.tryParse(match.group(3) ?? '');
      if (file == null || lineNumber == null || columnNumber == null) {
        continue;
      }

      frames.add({
        'file': file,
        'line': lineNumber,
        'column': columnNumber,
        'raw': trimmed,
      });

      if (frames.length >= 10) {
        break;
      }
    }

    return frames;
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

    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    return gateway.runClientResource(command.resourceUri);
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

    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    return gateway.runClientTool(command.toolName, command.arguments);
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

  String _stableStringHash(final String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  CoreResult _status() => CoreResult.success(
    data: {
      'connected': connectionContext.isConnected,
      'activeEndpoint': connectionContext.activeEndpoint?.display,
      'stickyEndpoint': connectionContext.stickyEndpoint?.display,
      'mode': connectionContext.lastMode.name,
      'dynamicRegistrySupported': configuration.dynamicRegistrySupported,
      'liveEditSupported': configuration.liveEditSupported,
      'sessionsEnabled': sessionManager != null,
    },
  );

  Future<_DesktopCaptureResolution> _tryDesktopWindowCapture(
    final GetScreenshotsCommand command,
  ) async {
    if (command.mode == ScreenshotMode.flutterLayer) {
      return const _DesktopCaptureResolution();
    }

    final projectDir = configuration.flutterProjectDir;
    final device = configuration.flutterDevice;
    if (projectDir == null || device == null) {
      return command.mode == ScreenshotMode.desktopWindow
          ? const _DesktopCaptureResolution(
              errorMessage:
                  'Desktop window screenshot mode requires both '
                  '--flutter-project-dir and --flutter-device.',
            )
          : const _DesktopCaptureResolution();
    }

    try {
      final targetPid = await _connectedVmPid();
      if (device == 'macos' && targetPid != null && targetPid > 0) {
        await _activateMacOsTargetPid(targetPid);
      }
      final capture = await _desktopWindowScreenshotService.capture(
        projectDir: projectDir,
        device: device,
        compress: command.compress,
        targetPid: targetPid,
        cacheDir: configuration.stateRootDir,
      );
      if (capture == null) {
        if (command.mode == ScreenshotMode.auto && device != 'macos') {
          return const _DesktopCaptureResolution();
        }
        return const _DesktopCaptureResolution(
          errorMessage:
              'Desktop window screenshot mode is unavailable for the current '
              'target or app window.',
        );
      }

      if (!configuration.saveImagesToFiles) {
        return _DesktopCaptureResolution(
          data: capture.toJson(fileUrls: const <String>[]),
        );
      }

      await imageFileSaver.cleanupOldScreenshots();
      final fileUrls = await imageFileSaver.saveImagesToFiles(capture.images);
      return _DesktopCaptureResolution(
        data: capture.toJson(fileUrls: fileUrls, includeImages: false),
      );
    } on DesktopWindowCaptureException catch (e) {
      return _DesktopCaptureResolution(
        errorMessage: 'Desktop window screenshot failed: $e',
        errorDetails: e.details,
      );
    } on Object catch (e) {
      return _DesktopCaptureResolution(
        errorMessage: 'Desktop window screenshot failed: $e',
      );
    }
  }

  VisualCaptureBroker _visualCaptureBroker() => VisualCaptureBroker(
    configuration: configuration,
    dynamicGateway: _dynamicGateway,
    adapters: visualCaptureAdapters,
  );

  CoreResult _visualCaptureFailure(
    final PermissionBrokerResult permission, {
    required final String defaultMessage,
  }) {
    final code = switch (permission.status) {
      PermissionStatus.denied => CoreErrorCode.visualCapturePermissionDenied,
      PermissionStatus.unsupported ||
      PermissionStatus.unsupportedUntilAppBridge =>
        CoreErrorCode.visualCaptureUnsupported,
      _ => CoreErrorCode.getScreenshotsFailed,
    };
    return CoreResult.failure(
      code: code,
      message: permission.message ?? defaultMessage,
      details: <String, Object?>{
        'permission': permission.toJson(),
        if (permission.canOpenSettings)
          'suggestedAction': 'flutter_mcp_cli permissions open-settings',
      },
    );
  }

  Future<bool> _waitForFlutterIsolateAfterRestart({
    final Duration timeout = const Duration(seconds: 10),
    final Duration pollInterval = const Duration(milliseconds: 250),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final isolate = await connectionContext.getFlutterIsolate();
        if (isolate?.id != null) {
          return true;
        }
      } on StateError {
        // Keep retrying until timeout while the isolate comes back.
      }
      await Future<void>.delayed(pollInterval);
    }
    return false;
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

  CoreResult _withMeta(
    final CoreResult result,
    final int durationMs,
    final String commandName,
  ) {
    final nextMeta = <String, Object?>{
      ...result.meta,
      'schemaVersion': kCoreEnvelopeSchemaVersion,
      'command': commandName,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'durationMs': durationMs,
      'endpoint': connectionContext.activeEndpoint?.display,
      'mode': connectionContext.lastMode.name,
      'selectionDiagnostics': connectionContext.lastSelectionDiagnostics,
    };
    return result.withMeta(nextMeta);
  }

  Map<String, Object?> _withPermissionMetadata({
    required final Map<String, Object?> data,
    required final String requestedMode,
    required final PermissionBrokerResult permission,
  }) => <String, Object?>{
    ...data,
    'requestedMode': requestedMode,
    'actualMode': permission.actualMode,
    'fallbackReason': permission.fallbackReason,
    'permissionStatus': permission.status.wireName,
    'permission': permission.toJson(),
  };
}

final class _ExecutorLiveEditBindings implements LiveEditHostBindings {
  _ExecutorLiveEditBindings(this._executor);

  final DefaultCoreCommandExecutor _executor;

  @override
  CoreRuntimeConfiguration get configuration => _executor.configuration;

  @override
  Future<CoreResult> captureUiSnapshotForLiveEdit() =>
      _executor._captureUiSnapshot(
        const CaptureUiSnapshotCommand(
          includeViewDetails: false,
          includeErrors: false,
        ),
      );

  @override
  Future<CoreResult> hotReload({final bool force = false}) =>
      _executor._hotReload(HotReloadFlutterCommand(force: force));

  @override
  Future<CoreResult> hotRestart() => _executor._hotRestart();

  @override
  Future<CoreResult> listClientToolsAndResources() =>
      _executor._listClientToolsAndResources();

  @override
  Future<CoreResult> runClientTool(
    final String toolName, {
    final Map<String, Object?> arguments = const <String, Object?>{},
  }) => _executor._runClientTool(
    RunClientToolCommand(toolName: toolName, arguments: arguments),
  );

  @override
  Future<bool> waitForFlutterIsolateAfterRestart({
    final Duration timeout = const Duration(seconds: 10),
    final Duration pollInterval = const Duration(milliseconds: 250),
  }) => _executor._waitForFlutterIsolateAfterRestart(
    timeout: timeout,
    pollInterval: pollInterval,
  );
}

final class _DesktopCaptureResolution {
  const _DesktopCaptureResolution({
    this.data,
    this.errorMessage,
    this.errorDetails = const <String, Object?>{},
  });

  final Map<String, Object?>? data;
  final String? errorMessage;
  final Map<String, Object?> errorDetails;
}
