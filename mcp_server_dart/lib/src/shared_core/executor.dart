// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_inspector_mcp_server/src/capabilities/visual_capture/desktop_window_screenshot.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/visual_capture/visual_capture.dart';
import 'package:flutter_inspector_mcp_server/src/cli/sessions/session_manager.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/commands/commands_catalogue.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/diagnostics_bundle.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/dynamic_gateway.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/error_analysis.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/error_summary_provider.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/results.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/runtime_version.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/services/core_image_file_saver.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/services/core_port_scanner.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/types/core_types.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/vm_connections/connection_context.dart';
import 'package:flutter_inspector_mcp_server/src/shared_mixins/mcp_toolkit_consts.dart';
import 'package:flutter_live_edit_agent/flutter_live_edit_agent.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
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
       _liveEditAgentService = liveEditAgentService ?? LiveEditAgentService(),
       _activateMacOsTargetPid =
           activateMacOsTargetPid ?? _defaultActivateMacOsTargetPid,
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
  final DesktopWindowScreenshotService _desktopWindowScreenshotService;
  final LiveEditAgentService _liveEditAgentService;
  final Future<void> Function(int pid) _activateMacOsTargetPid;

  CoreDynamicGateway? _dynamicGateway;
  final Map<String, String> _liveEditSessionModes = <String, String>{};

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

  List<Object?> _asObjectList(final Object? value) {
    if (value is List<Object?>) {
      return value;
    }
    if (value is List) {
      return value.cast<Object?>();
    }
    return const <Object?>[];
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

  List<LiveEditDraftChange> _decodeDraftChanges(final Object? value) {
    if (value is! List) {
      return const <LiveEditDraftChange>[];
    }
    return value
        .whereType<Map>()
        .map(
          (final item) =>
              LiveEditDraftChange.fromJson(item.cast<String, Object?>()),
        )
        .toList(growable: false);
  }

  LiveEditSelection? _decodeSelection(final Object? value) {
    if (value is Map<String, Object?>) {
      return LiveEditSelection.fromJson(value);
    }
    if (value is Map) {
      return LiveEditSelection.fromJson(value.cast<String, Object?>());
    }
    return null;
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
    DebugDumpLayerTreeCommand() => _debugDumpLayerTree(),
    DebugDumpSemanticsTreeCommand() => _debugDumpSemanticsTree(),
    DebugDumpRenderTreeCommand() => _debugDumpRenderTree(),
    DebugDumpFocusTreeCommand() => _debugDumpFocusTree(),
    ListClientToolsAndResourcesCommand() => _listClientToolsAndResources(),
    RunClientToolCommand() => _runClientTool(command),
    RunClientResourceCommand() => _runClientResource(command),
    LiveEditStartSessionCommand() => _liveEditStartSession(command),
    LiveEditPrepareSessionCommand() => _liveEditPrepareSession(command),
    LiveEditSetOverlayCommand() => _liveEditSetOverlay(command),
    LiveEditGetTreeCommand() => _liveEditGetTree(command),
    LiveEditSelectAtPointCommand() => _liveEditSelectAtPoint(command),
    LiveEditGetSelectionCommand() => _liveEditGetSelection(command),
    LiveEditGetCapabilitiesCommand() => _liveEditGetCapabilities(command),
    LiveEditGetSelectionCandidatesCommand() => _liveEditGetSelectionCandidates(
      command,
    ),
    LiveEditSetActiveSelectionCommand() => _liveEditSetActiveSelection(command),
    LiveEditGetPropertyPanelCommand() => _liveEditGetPropertyPanel(command),
    LiveEditSetEditModeCommand() => _liveEditSetEditMode(command),
    LiveEditGetPreviewStateCommand() => _liveEditGetPreviewState(command),
    LiveEditUpdateDraftCommand() => _liveEditUpdateDraft(command),
    LiveEditGetDraftCommand() => _liveEditGetDraft(command),
    LiveEditDiscardDraftCommand() => _liveEditDiscardDraft(command),
    LiveEditEndSessionCommand() => _liveEditEndSession(command),
    LiveEditListAgentBackendsCommand() => _liveEditListAgentBackends(),
    LiveEditGetAgentBackendCommand() => _liveEditGetAgentBackend(command),
    LiveEditSetAgentBackendCommand() => _liveEditSetAgentBackend(command),
    LiveEditResolveDraftCommand() => _liveEditResolveDraft(command),
    LiveEditApplyDraftCommand() => _liveEditApplyDraft(command),
    LiveEditAcceptResolutionCommand() => _liveEditAcceptResolution(command),
    LiveEditRejectResolutionCommand() => _liveEditRejectResolution(command),
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

  Future<CoreResult> _ensureLiveEditSessionId(final String? sessionId) async {
    if (_hasText(sessionId)) {
      return CoreResult.success(
        data: <String, Object?>{'sessionId': sessionId!.trim()},
      );
    }
    return _liveEditStartSession(const LiveEditStartSessionCommand());
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

  String? _firstNonEmpty(final String? first, final String? second) =>
      _stringOrNull(first) ?? _stringOrNull(second);

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

  bool _hasText(final Object? value) => _stringOrNull(value) != null;

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

  Future<CoreResult> _liveEditAcceptResolution(
    final LiveEditAcceptResolutionCommand command,
  ) async {
    final request = _liveEditAgentService.requestForProposal(
      command.proposalId,
    );
    if (request == null) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditProposalNotFound,
        message: 'Unknown live edit proposal: ${command.proposalId}',
      );
    }

    final proposal = _liveEditAgentService.getProposal(command.proposalId);
    final workingDirectory = _resolveWorkingDirectory(
      command.workingDirectory ?? request.workingDirectory,
    );

    LiveEditResolutionResult applyResult;
    try {
      applyResult = await _liveEditAgentService.applyProposal(
        command.proposalId,
        workingDirectory: workingDirectory,
      );
    } on FileSystemException catch (error) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditApplyFailed,
        message: 'Failed to apply live edit proposal: $error',
        details: <String, Object?>{
          'proposalId': command.proposalId,
          'workingDirectory': workingDirectory,
        },
      );
    } on StateError catch (error) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditApplyFailed,
        message: 'Failed to apply live edit proposal: $error',
        details: <String, Object?>{
          'proposalId': command.proposalId,
          'workingDirectory': workingDirectory,
        },
      );
    }

    final runtimeRefresh = await _refreshAppliedLiveEditRuntime(
      request: request,
      fallbackSessionId: command.sessionId,
    );
    final validation = _map(runtimeRefresh['validation']);
    final validationRecovery = switch (runtimeRefresh['validationRecovery']) {
      final Map<String, Object?> value => value,
      final Map value => value.map(
        (final key, final nested) => MapEntry('$key', nested),
      ),
      _ => null,
    };
    if (validation['validated'] != true) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditValidationFailed,
        message:
            'Proposal applied, but runtime validation did not match the draft',
        details: <String, Object?>{
          'proposal': proposal.toJson(),
          'apply': applyResult.toJson(),
          'runtimeRefresh': runtimeRefresh,
        },
      );
    }

    Map<String, Object?>? discardData;
    final discardSessionId = _firstNonEmpty(
      command.sessionId,
      request.sessionId,
    );
    if (_hasText(discardSessionId)) {
      final discardResult = await _liveEditDiscardDraft(
        LiveEditDiscardDraftCommand(sessionId: discardSessionId),
      );
      if (discardResult.ok) {
        discardData = _map(discardResult.data);
      }
    }

    return CoreResult.success(
      data: <String, Object?>{
        'proposal': proposal.toJson(),
        'result': applyResult.toJson(),
        'runtimeRefresh': runtimeRefresh,
        'hotReload': runtimeRefresh['hotReload'],
        'hotRestart': runtimeRefresh['hotRestart'],
        'validation': validation,
        'validationRecovery': ?validationRecovery,
        'draft': ?discardData,
      },
    );
  }

  Future<Map<String, Object?>> _refreshAppliedLiveEditRuntime({
    required final LiveEditResolutionRequest request,
    required final String? fallbackSessionId,
  }) async {
    final result = <String, Object?>{
      'action': LiveEditRuntimeAction.none.wireName,
      'validation': const <String, Object?>{},
      'hotReload': const <String, Object?>{},
      'hotRestart': const <String, Object?>{},
      'validationRecovery': const <String, Object?>{},
    };

    final hotReloadResult = await _hotReload(
      const HotReloadFlutterCommand(force: true),
    );
    result['hotReload'] = hotReloadResult.ok
        ? _map(hotReloadResult.data)
        : <String, Object?>{
            'ok': false,
            'error': hotReloadResult.error?.toJson(),
          };

    if (hotReloadResult.ok) {
      final validation = await _validateAppliedLiveEditRequest(
        request: request,
        fallbackSessionId: fallbackSessionId,
      );
      result['validation'] = validation;
      if (validation['validated'] == true) {
        result['action'] = LiveEditRuntimeAction.hotReload.wireName;
        return result;
      }
    }

    final validationRecovery = await _recoverLiveEditValidationAfterHotRestart(
      request: request,
      fallbackSessionId: fallbackSessionId,
    );
    result['validationRecovery'] = validationRecovery;
    result['hotRestart'] = _map(validationRecovery['hotRestart']);
    final recoveredValidation = _map(validationRecovery['validation']);
    if (recoveredValidation.isNotEmpty) {
      result['validation'] = recoveredValidation;
    }
    if (recoveredValidation['validated'] == true) {
      result['action'] = LiveEditRuntimeAction.hotRestart.wireName;
    }
    return result;
  }

  Future<CoreResult> _liveEditApplyDraft(
    final LiveEditApplyDraftCommand command,
  ) async {
    String? proposalId = _stringOrNull(command.proposalId);
    CoreResult? resolveResult;

    if (!_hasText(proposalId)) {
      resolveResult = await _liveEditResolveDraft(
        LiveEditResolveDraftCommand(
          sessionId: command.sessionId,
          backendId: command.backendId,
          inferenceConfig: command.inferenceConfig,
          workingDirectory: command.workingDirectory,
          intentText: command.intentText,
        ),
      );
      if (!resolveResult.ok) {
        return resolveResult;
      }
      final proposal = _map(_map(resolveResult.data)['proposal']);
      proposalId = _stringOrNull(proposal['proposalId']);
    }

    if (!_hasText(proposalId)) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditProposalNotFound,
        message: 'Live edit proposal id is unavailable for apply flow',
      );
    }

    LiveEditExecutionPlan executionPlan;
    try {
      executionPlan = _liveEditAgentService.buildExecutionPlan(proposalId!);
    } on StateError catch (error) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditProposalNotFound,
        message: '$error',
        details: <String, Object?>{'proposalId': proposalId},
      );
    }

    final acceptResult = await _liveEditAcceptResolution(
      LiveEditAcceptResolutionCommand(
        proposalId: proposalId,
        sessionId: command.sessionId,
        workingDirectory: command.workingDirectory,
      ),
    );
    if (!acceptResult.ok) {
      return acceptResult;
    }

    return CoreResult.success(
      data: <String, Object?>{
        'proposalId': proposalId,
        'approved': true,
        'applied': true,
        'executionPlan': executionPlan.toJson(),
        'result': acceptResult.data,
        if (resolveResult != null) 'resolve': resolveResult.data,
      },
    );
  }

  List<Map<String, int>> _liveEditCandidatePointsForBounds(
    final LiveEditBounds bounds,
  ) {
    final inset = bounds.width < 24 || bounds.height < 24 ? 2.0 : 8.0;
    final left = bounds.left + inset;
    final right = bounds.right - inset;
    final top = bounds.top + inset;
    final bottom = bounds.bottom - inset;
    final midX = (bounds.left + bounds.right) / 2;
    final midY = (bounds.top + bounds.bottom) / 2;

    final ordered = <Map<String, int>>[
      <String, int>{'x': left.round(), 'y': top.round()},
      <String, int>{'x': right.round(), 'y': top.round()},
      <String, int>{'x': left.round(), 'y': bottom.round()},
      <String, int>{'x': right.round(), 'y': bottom.round()},
      <String, int>{'x': left.round(), 'y': midY.round()},
      <String, int>{'x': right.round(), 'y': midY.round()},
      <String, int>{'x': midX.round(), 'y': top.round()},
      <String, int>{'x': midX.round(), 'y': bottom.round()},
      <String, int>{'x': midX.round(), 'y': midY.round()},
    ];

    final seen = <String>{};
    return ordered
        .where((final point) {
          final key = '${point['x']}:${point['y']}';
          return seen.add(key);
        })
        .toList(growable: false);
  }

  Future<CoreResult> _liveEditDiscardDraft(
    final LiveEditDiscardDraftCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.discardDraft,
    arguments: <String, Object?>{
      if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
    },
  );

  Future<CoreResult> _liveEditEndSession(
    final LiveEditEndSessionCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.endSession,
    arguments: <String, Object?>{
      if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
    },
  );

  Future<CoreResult> _liveEditGetAgentBackend(
    final LiveEditGetAgentBackendCommand command,
  ) async {
    try {
      final backend = _liveEditAgentService.getBackend(
        backendId: command.backendId,
        sessionId: command.sessionId,
      );
      return CoreResult.success(
        data: <String, Object?>{
          'backend': backend.toJson(),
          if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
        },
      );
    } on StateError catch (error) {
      return CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message: '$error',
        details: <String, Object?>{
          'backendId': command.backendId,
          'sessionId': command.sessionId,
        },
      );
    }
  }

  Future<CoreResult> _liveEditGetCapabilities(
    final LiveEditGetCapabilitiesCommand command,
  ) async {
    final backend = _liveEditAgentService.getBackend(
      sessionId: command.sessionId,
    );
    return CoreResult.success(
      data: <String, Object?>{
        if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (_hasText(command.targetDomain))
          'targetDomain': command.targetDomain,
        'backend': backend.toJson(),
        'capabilities': const <String, Object?>{
          'overlay': true,
          'selection': true,
          'selectionCandidates': true,
          'propertyPanel': true,
          'draft': true,
          'exactPreview': true,
          'ghostPreview': true,
          'agentResolution': true,
          'editModes': <String>['inspect', 'edit', 'ai'],
          'targetDomains': <String>['app_scene', 'tool_scene'],
        },
      },
    );
  }

  Future<CoreResult> _liveEditGetDraft(final LiveEditGetDraftCommand command) =>
      _runLiveEditRuntimeTool(
        LiveEditRuntimeToolNames.getDraft,
        arguments: <String, Object?>{
          if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
        },
      );

  Future<CoreResult> _liveEditGetPreviewState(
    final LiveEditGetPreviewStateCommand command,
  ) async {
    final draftResult = await _liveEditGetDraft(
      LiveEditGetDraftCommand(sessionId: command.sessionId),
    );
    if (!draftResult.ok) {
      return draftResult;
    }

    final selectionResult = await _liveEditGetSelection(
      LiveEditGetSelectionCommand(
        sessionId: command.sessionId,
        targetDomain: command.targetDomain,
      ),
    );
    if (!selectionResult.ok) {
      return selectionResult;
    }

    final draftChanges = _decodeDraftChanges(
      _map(draftResult.data)['draftChanges'],
    );
    final selection = _decodeSelection(_map(selectionResult.data)['selection']);
    return CoreResult.success(
      data: <String, Object?>{
        if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (_hasText(command.targetDomain))
          'targetDomain': command.targetDomain,
        'mode': _liveEditSessionModes[command.sessionId ?? ''] ?? 'inspect',
        'selectionAvailable': selection != null,
        if (selection != null) 'nodeId': selection.nodeId,
        'draftChanges': draftChanges
            .map((final change) => change.toJson())
            .toList(growable: false),
        'hasDraft': draftChanges.isNotEmpty,
        'exactPreviewPropertyIds': const <String>[],
        'pendingPropertyIds': const <String>[],
      },
    );
  }

  Future<CoreResult> _liveEditGetPropertyPanel(
    final LiveEditGetPropertyPanelCommand command,
  ) async {
    final selectionResult = await _liveEditGetSelection(
      LiveEditGetSelectionCommand(
        sessionId: command.sessionId,
        targetDomain: command.targetDomain,
      ),
    );
    if (!selectionResult.ok) {
      return selectionResult;
    }

    final selection = _decodeSelection(_map(selectionResult.data)['selection']);
    return CoreResult.success(
      data: <String, Object?>{
        if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (_hasText(command.targetDomain))
          'targetDomain': command.targetDomain,
        if (selection != null) 'nodeId': selection.nodeId,
        if (selection != null) 'widgetType': selection.widgetType,
        'properties': selection?.propertiesForWire ?? const <Object?>[],
        if (selection != null) 'selection': selection.toJson(),
      },
    );
  }

  Future<CoreResult> _liveEditGetSelection(
    final LiveEditGetSelectionCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.getSelection,
    arguments: <String, Object?>{
      if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
      if (_hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
    },
  );

  Future<CoreResult> _liveEditGetSelectionCandidates(
    final LiveEditGetSelectionCandidatesCommand command,
  ) async {
    final selectionResult = await _liveEditGetSelection(
      LiveEditGetSelectionCommand(
        sessionId: command.sessionId,
        targetDomain: command.targetDomain,
      ),
    );
    if (!selectionResult.ok) {
      return selectionResult;
    }

    final data = _map(selectionResult.data);
    final selection = _decodeSelection(data['selection']);
    final candidates = selection == null
        ? const <Map<String, Object?>>[]
        : <Map<String, Object?>>[
            <String, Object?>{
              'index': 0,
              'nodeId': selection.nodeId,
              'widgetType': selection.widgetType,
              'selection': selection.toJson(),
            },
          ];
    return CoreResult.success(
      data: <String, Object?>{
        if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (_hasText(command.targetDomain))
          'targetDomain': command.targetDomain,
        'activeNodeId': selection?.nodeId,
        'candidates': candidates,
      },
    );
  }

  Future<CoreResult> _liveEditGetTree(final LiveEditGetTreeCommand command) =>
      _runLiveEditRuntimeTool(
        LiveEditRuntimeToolNames.getTree,
        arguments: <String, Object?>{
          if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
          if (_hasText(command.targetDomain))
            'targetDomain': command.targetDomain,
        },
      );

  Future<CoreResult> _liveEditListAgentBackends() async {
    final backends = _liveEditAgentService.listBackends();
    final defaultBackend = backends.firstWhere(
      (final backend) => backend.isDefault,
      orElse: () => backends.first,
    );
    return CoreResult.success(
      data: <String, Object?>{
        'backends': backends.map((final backend) => backend.toJson()).toList(),
        'defaultBackendId': defaultBackend.id,
      },
    );
  }

  Future<CoreResult> _liveEditPrepareSession(
    final LiveEditPrepareSessionCommand command,
  ) async {
    final sessionResult = await _ensureLiveEditSessionId(command.sessionId);
    if (!sessionResult.ok) {
      return sessionResult;
    }

    final sessionId = _stringOrNull(_map(sessionResult.data)['sessionId']);
    if (!_hasText(sessionId)) {
      return CoreResult.failure(
        code: CoreErrorCode.unexpectedExecutorError,
        message: 'Live edit session initialization did not return a session id',
      );
    }

    if (_hasText(command.backendId) || command.inferenceConfig != null) {
      final backendResult = await _liveEditSetAgentBackend(
        LiveEditSetAgentBackendCommand(
          sessionId: sessionId!,
          backendId:
              command.backendId ??
              _liveEditAgentService.getBackend(sessionId: sessionId).id,
          inferenceConfig: command.inferenceConfig,
        ),
      );
      if (!backendResult.ok) {
        return backendResult;
      }
    }

    final overlayResult = await _liveEditSetOverlay(
      LiveEditSetOverlayCommand(sessionId: sessionId, enabled: true),
    );
    if (!overlayResult.ok) {
      return overlayResult;
    }

    final capabilitiesResult = await _liveEditGetCapabilities(
      LiveEditGetCapabilitiesCommand(
        sessionId: sessionId,
        targetDomain: command.targetDomain,
      ),
    );
    if (!capabilitiesResult.ok) {
      return capabilitiesResult;
    }

    final selectionResult = await _liveEditGetSelection(
      LiveEditGetSelectionCommand(
        sessionId: sessionId,
        targetDomain: command.targetDomain,
      ),
    );
    final draftResult = await _liveEditGetDraft(
      LiveEditGetDraftCommand(sessionId: sessionId),
    );

    return CoreResult.success(
      data: <String, Object?>{
        'sessionId': sessionId,
        if (_hasText(command.targetDomain))
          'targetDomain': command.targetDomain,
        if (_hasText(command.workingDirectory))
          'workingDirectory': command.workingDirectory,
        'overlay': _map(overlayResult.data),
        'capabilities': _map(capabilitiesResult.data),
        if (selectionResult.ok) 'selection': _map(selectionResult.data),
        if (draftResult.ok) 'draft': _map(draftResult.data),
      },
    );
  }

  Future<CoreResult> _liveEditRejectResolution(
    final LiveEditRejectResolutionCommand command,
  ) async {
    try {
      final result = _liveEditAgentService.rejectProposal(command.proposalId);
      return CoreResult.success(data: result.toJson());
    } on StateError {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditProposalNotFound,
        message: 'Unknown live edit proposal: ${command.proposalId}',
      );
    }
  }

  Future<CoreResult> _liveEditResolveDraft(
    final LiveEditResolveDraftCommand command,
  ) async {
    final sessionIdResult = await _ensureLiveEditSessionId(command.sessionId);
    if (!sessionIdResult.ok) {
      return sessionIdResult;
    }

    final sessionId = _stringOrNull(_map(sessionIdResult.data)['sessionId']);
    if (!_hasText(sessionId)) {
      return CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message: 'Live edit session id is unavailable',
      );
    }

    final draftResult = await _liveEditGetDraft(
      LiveEditGetDraftCommand(sessionId: sessionId),
    );
    if (!draftResult.ok) {
      return draftResult;
    }

    final hasIntentText = _hasText(command.intentText);
    if (!hasIntentText) {
      return CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message: 'No live edit prompt is available for resolution',
        details: <String, Object?>{'sessionId': sessionId},
      );
    }

    final selectionResult = await _liveEditGetSelection(
      LiveEditGetSelectionCommand(
        sessionId: sessionId,
        targetDomain: command.targetDomain,
      ),
    );
    if (!selectionResult.ok) {
      return selectionResult;
    }

    final treeResult = await _liveEditGetTree(
      LiveEditGetTreeCommand(
        sessionId: sessionId,
        targetDomain: command.targetDomain,
      ),
    );
    if (!treeResult.ok) {
      return treeResult;
    }

    final selection = _decodeSelection(_map(selectionResult.data)['selection']);
    final treeData = _map(treeResult.data);
    final workingDirectory = _resolveWorkingDirectory(command.workingDirectory);
    final snapshotResult = await _captureUiSnapshot(
      const CaptureUiSnapshotCommand(
        includeViewDetails: false,
        includeErrors: false,
      ),
    );

    final evidence = <String, Object?>{
      'tree': treeData['tree'],
      if (selection != null) 'selection': selection.toJson(),
      if (snapshotResult.ok)
        'uiSnapshot': snapshotResult.data
      else
        'uiSnapshotError': snapshotResult.error?.toJson(),
    };

    final request = LiveEditResolutionRequest(
      sessionId: sessionId!,
      workingDirectory: workingDirectory,
      selection: selection,
      backendId: command.backendId,
      inferenceConfig: command.inferenceConfig,
      intentText: command.intentText,
      evidence: evidence,
      meta: <String, Object?>{'treeSelectedNodeId': treeData['selectedNodeId']},
    );

    try {
      final proposal = await _liveEditAgentService.resolve(request);
      final backend = _liveEditAgentService.getBackend(
        backendId: proposal.backendId,
        sessionId: sessionId,
      );
      return CoreResult.success(
        data: <String, Object?>{
          'sessionId': sessionId,
          if (_hasText(command.targetDomain))
            'targetDomain': command.targetDomain,
          'backend': backend.toJson(),
          'proposal': proposal.toJson(),
        },
      );
    } on LiveEditAgentException catch (error) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditBackendFailed,
        message: 'Live edit resolution failed: $error',
        details: <String, Object?>{
          'request': request.toJson(),
          'backendError': error.toJson(),
        },
      );
    } on StateError catch (error) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditBackendFailed,
        message: 'Live edit resolution failed: $error',
        details: request.toJson(),
      );
    } on FileSystemException catch (error) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditBackendFailed,
        message: 'Live edit resolution failed: $error',
        details: request.toJson(),
      );
    }
  }

  Future<CoreResult> _liveEditSelectAtPoint(
    final LiveEditSelectAtPointCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.selectAtPoint,
    arguments: <String, Object?>{
      if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
      'x': command.x,
      'y': command.y,
      if (command.viewId != null) 'viewId': command.viewId,
      'selectionPolicy': command.selectionPolicy.wireName,
      if (_hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
    },
  );

  Future<CoreResult> _liveEditSetActiveSelection(
    final LiveEditSetActiveSelectionCommand command,
  ) async {
    final candidatesResult = await _liveEditGetSelectionCandidates(
      LiveEditGetSelectionCandidatesCommand(
        sessionId: command.sessionId,
        targetDomain: command.targetDomain,
      ),
    );
    if (!candidatesResult.ok) {
      return candidatesResult;
    }

    final data = _map(candidatesResult.data);
    final candidates = _asObjectList(data['candidates']);
    if (candidates.isEmpty) {
      return CoreResult.success(
        data: <String, Object?>{
          if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
          if (_hasText(command.targetDomain))
            'targetDomain': command.targetDomain,
          'activated': false,
          'reason': 'no_selection_candidates',
          'candidates': candidates,
        },
      );
    }

    final first = _map(candidates.first);
    final requestedIndex = command.index;
    final requestedNodeId = _stringOrNull(command.nodeId);
    final matchesIndex = requestedIndex == null || requestedIndex == 0;
    final matchesNode =
        !_hasText(requestedNodeId) || requestedNodeId == first['nodeId'];

    return CoreResult.success(
      data: <String, Object?>{
        if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (_hasText(command.targetDomain))
          'targetDomain': command.targetDomain,
        'activated': matchesIndex && matchesNode,
        'activeNodeId': first['nodeId'],
        'selection': first['selection'],
        if (!(matchesIndex && matchesNode))
          'reason': 'selection_candidates_runtime_only_supports_active_node',
        'candidates': candidates,
      },
    );
  }

  Future<CoreResult> _liveEditSetAgentBackend(
    final LiveEditSetAgentBackendCommand command,
  ) async {
    try {
      _liveEditAgentService.setSessionBackend(
        sessionId: command.sessionId,
        backendId: command.backendId,
        inferenceConfig: command.inferenceConfig,
      );
      final backend = _liveEditAgentService.getBackend(
        backendId: command.backendId,
        sessionId: command.sessionId,
      );
      return CoreResult.success(
        data: <String, Object?>{
          'sessionId': command.sessionId,
          'backend': backend.toJson(),
        },
      );
    } on StateError catch (error) {
      return CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message: '$error',
        details: <String, Object?>{
          'sessionId': command.sessionId,
          'backendId': command.backendId,
        },
      );
    }
  }

  Future<CoreResult> _liveEditSetEditMode(
    final LiveEditSetEditModeCommand command,
  ) async {
    final sessionResult = await _ensureLiveEditSessionId(command.sessionId);
    if (!sessionResult.ok) {
      return sessionResult;
    }

    final sessionId = _stringOrNull(_map(sessionResult.data)['sessionId']);
    if (!_hasText(sessionId)) {
      return CoreResult.failure(
        code: CoreErrorCode.unexpectedExecutorError,
        message: 'Live edit session initialization did not return a session id',
      );
    }

    final normalizedMode = command.mode.trim().isEmpty
        ? 'inspect'
        : command.mode.trim().toLowerCase();
    _liveEditSessionModes[sessionId!] = normalizedMode;
    if (normalizedMode == 'hidden') {
      final overlayResult = await _liveEditSetOverlay(
        LiveEditSetOverlayCommand(sessionId: sessionId, enabled: false),
      );
      if (!overlayResult.ok) {
        return overlayResult;
      }
    } else {
      final overlayResult = await _liveEditSetOverlay(
        LiveEditSetOverlayCommand(sessionId: sessionId, enabled: true),
      );
      if (!overlayResult.ok) {
        return overlayResult;
      }
    }

    return CoreResult.success(
      data: <String, Object?>{
        'sessionId': sessionId,
        'mode': normalizedMode,
        if (_hasText(command.targetDomain))
          'targetDomain': command.targetDomain,
      },
    );
  }

  Future<CoreResult> _liveEditSetOverlay(
    final LiveEditSetOverlayCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.setOverlay,
    arguments: <String, Object?>{
      if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
      'enabled': command.enabled,
    },
  );

  Future<CoreResult> _liveEditStartSession(
    final LiveEditStartSessionCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.startSession,
    arguments: <String, Object?>{
      if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
      if (_hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
    },
  );

  Future<CoreResult> _liveEditUpdateDraft(
    final LiveEditUpdateDraftCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.updateDraft,
    arguments: <String, Object?>{
      if (_hasText(command.sessionId)) 'sessionId': command.sessionId,
      if (_hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
      'changeJson': encodeLiveEditJson(command.change.toJson()),
    },
  );

  Map<String, Object?> _map(final Object? data) {
    if (data is Map<String, Object?>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }

  bool _matchesRequestedLiveEditSelection({
    required final LiveEditSelection? requested,
    required final LiveEditSelection? actual,
    required final bool hit,
  }) {
    if (!hit || actual == null) {
      return false;
    }
    if (requested == null) {
      return true;
    }
    if (requested.widgetType != actual.widgetType) {
      return false;
    }

    final requestedSource = requested.source;
    if (requestedSource == null) {
      return true;
    }

    final actualSource = actual.source;
    if (actualSource == null) {
      return false;
    }

    if (_normalizeLiveEditSourceFile(requestedSource.file) !=
        _normalizeLiveEditSourceFile(actualSource.file)) {
      return false;
    }

    if (requestedSource.line != null &&
        actualSource.line != requestedSource.line) {
      return false;
    }

    return true;
  }

  String _normalizeLiveEditSourceFile(final String file) {
    final parsed = Uri.tryParse(file);
    if (parsed != null && parsed.scheme == 'file') {
      return parsed.toFilePath();
    }
    return file;
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

  Future<Map<String, Object?>> _recoverLiveEditValidationAfterHotRestart({
    required final LiveEditResolutionRequest request,
    required final String? fallbackSessionId,
  }) async {
    final result = <String, Object?>{'attempted': true};

    final hotRestartResult = await _hotRestart();
    result['hotRestart'] = hotRestartResult.ok
        ? hotRestartResult.data
        : hotRestartResult.error?.toJson();
    if (!hotRestartResult.ok) {
      return <String, Object?>{
        ...result,
        'validated': false,
        'reason': 'hot_restart_failed',
      };
    }

    final isolateReady = await _waitForFlutterIsolateAfterRestart();
    result['flutterIsolateReady'] = isolateReady;
    if (!isolateReady) {
      return <String, Object?>{
        ...result,
        'validated': false,
        'reason': 'flutter_isolate_unavailable_after_restart',
      };
    }

    final runtimeReady = await _waitForLiveEditRuntimeToolAfterRestart(
      LiveEditRuntimeToolNames.selectAtPoint,
    );
    result['liveEditRuntimeReady'] = runtimeReady;
    if (!runtimeReady) {
      return <String, Object?>{
        ...result,
        'validated': false,
        'reason': 'live_edit_runtime_unavailable_after_restart',
      };
    }

    final sessionId = _firstNonEmpty(fallbackSessionId, request.sessionId);
    if (_hasText(sessionId)) {
      final restartSession = await _liveEditStartSession(
        LiveEditStartSessionCommand(sessionId: sessionId),
      );
      result['restartSession'] = restartSession.ok
          ? restartSession.data
          : restartSession.error?.toJson();
      if (!restartSession.ok) {
        return <String, Object?>{
          ...result,
          'validated': false,
          'reason': 'live_edit_session_restart_failed',
        };
      }
    }

    Map<String, Object?>? reselection;
    try {
      reselection = await _reselectLiveEditTargetFromRequest(
        request: request,
        fallbackSessionId: fallbackSessionId,
      );
    } on StateError catch (error) {
      return <String, Object?>{
        ...result,
        'validated': false,
        'reason': 'reselect_failed',
        'error': '$error',
      };
    }
    if (reselection != null) {
      result['reselection'] = reselection;
      if (reselection['ok'] != true || reselection['hit'] != true) {
        return <String, Object?>{
          ...result,
          'validated': false,
          'reason': reselection['ok'] == true
              ? 'reselect_missed'
              : 'reselect_failed',
        };
      }
    }

    final validation = await _validateAppliedLiveEditRequest(
      request: request,
      fallbackSessionId: fallbackSessionId,
    );
    return <String, Object?>{
      ...result,
      'validated': validation['validated'] == true,
      'validation': validation,
      if (validation['validated'] != true)
        'reason': 'validation_mismatch_after_restart',
    };
  }

  Future<Map<String, Object?>?> _reselectLiveEditTargetFromRequest({
    required final LiveEditResolutionRequest request,
    required final String? fallbackSessionId,
  }) async {
    final sessionId = _firstNonEmpty(fallbackSessionId, request.sessionId);
    final bounds = request.selection?.bounds;
    if (!_hasText(sessionId) || bounds == null) {
      return null;
    }

    final candidatePoints = _liveEditCandidatePointsForBounds(bounds);
    final attempts = <Map<String, Object?>>[];

    for (var index = 0; index < 6; index++) {
      var widgetTreeUnavailable = false;
      for (final point in candidatePoints) {
        final x = point['x']!;
        final y = point['y']!;
        final result = await _liveEditSelectAtPoint(
          LiveEditSelectAtPointCommand(
            sessionId: sessionId,
            x: x,
            y: y,
            selectionPolicy: LiveEditSelectionPolicy.nearestProjectAncestor,
          ),
        );
        final data = _map(result.data);
        final hit = data['hit'] == true;
        final reason = _stringOrNull(data['reason']);
        final selection = _decodeSelection(data['selection']);
        final matched = _matchesRequestedLiveEditSelection(
          requested: request.selection,
          actual: selection,
          hit: hit,
        );
        attempts.add(<String, Object?>{
          'attempt': index + 1,
          'x': x,
          'y': y,
          'ok': result.ok,
          'hit': hit,
          'matched': matched,
          if (selection != null) 'selectedWidgetType': selection.widgetType,
          if (selection?.source != null)
            'selectedSource': selection!.source!.toJson(),
          if (_hasText(reason)) 'reason': reason,
          if (result.ok) 'data': data,
          if (!result.ok) 'error': result.error?.toJson(),
        });

        if (!result.ok) {
          return <String, Object?>{
            'ok': false,
            'hit': false,
            'attempts': attempts,
            'error': result.error?.toJson(),
          };
        }

        if (matched) {
          return <String, Object?>{
            'ok': true,
            'hit': true,
            'matched': true,
            'x': x,
            'y': y,
            'attempts': attempts,
            'data': data,
          };
        }

        if (reason == 'widget_tree_unavailable') {
          widgetTreeUnavailable = true;
          break;
        }
      }

      if (!widgetTreeUnavailable || index == 5) {
        return <String, Object?>{
          'ok': true,
          'hit': false,
          'matched': false,
          'attempts': attempts,
        };
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    return <String, Object?>{
      'ok': true,
      'hit': false,
      'matched': false,
      'attempts': attempts,
    };
  }

  String _resolveWorkingDirectory(final String? workingDirectory) {
    if (_hasText(workingDirectory)) {
      return workingDirectory!.trim();
    }
    if (_hasText(configuration.flutterProjectDir)) {
      return configuration.flutterProjectDir!.trim();
    }
    return Directory.current.path;
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

  Future<CoreResult> _runLiveEditRuntimeTool(
    final String toolName, {
    final Map<String, Object?> arguments = const <String, Object?>{},
  }) async {
    final result = await _runClientTool(
      RunClientToolCommand(toolName: toolName, arguments: arguments),
    );
    if (!result.ok) {
      return result;
    }

    final data = _map(result.data);
    return CoreResult.success(
      data: _map(data['parameters']),
      meta: <String, Object?>{
        ...result.meta,
        'clientTool': toolName,
        if (_hasText(data['message'])) 'clientMessage': '${data['message']}',
      },
    );
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
      'sessionsEnabled': sessionManager != null,
    },
  );

  String? _stringOrNull(final Object? value) {
    final normalized = '$value'.trim();
    if (value == null || normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
  }

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

  Future<Map<String, Object?>> _validateAppliedLiveEditRequest({
    required final LiveEditResolutionRequest request,
    required final String? fallbackSessionId,
  }) async {
    final sessionId = _firstNonEmpty(fallbackSessionId, request.sessionId);
    if (!_hasText(sessionId)) {
      return <String, Object?>{
        'validated': false,
        'reason': 'missing_session_id',
      };
    }

    final selectionResult = await _liveEditGetSelection(
      LiveEditGetSelectionCommand(sessionId: sessionId),
    );
    if (!selectionResult.ok) {
      return <String, Object?>{
        'validated': false,
        'reason': 'selection_unavailable',
        'error': selectionResult.error?.toJson(),
      };
    }

    final selection = _decodeSelection(_map(selectionResult.data)['selection']);
    if (selection == null) {
      return <String, Object?>{
        'validated': false,
        'reason': 'selection_missing',
      };
    }
    return <String, Object?>{
      'validated': true,
      'nodeId': selection.nodeId,
      'matchedProperties': <String>[],
      'mismatches': <Map<String, Object?>>[],
    };
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

  Future<bool> _waitForLiveEditRuntimeToolAfterRestart(
    final String toolName, {
    final Duration timeout = const Duration(seconds: 15),
    final Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final toolsResult = await _listClientToolsAndResources();
      if (toolsResult.ok) {
        final tools = _asObjectList(_map(toolsResult.data)['tools']);
        final names = tools
            .whereType<Map>()
            .map((final entry) => '${entry['name'] ?? ''}')
            .toSet();
        if (names.contains(toolName)) {
          return true;
        }
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
