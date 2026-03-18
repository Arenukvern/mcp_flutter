import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_agent/flutter_live_edit_agent.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

import 'live_edit_host.dart';
import 'live_edit_orchestrator.dart';
import 'live_edit_scope.dart';
import 'live_edit_toolkit.dart';
import 'live_edit_types.dart';

const _liveEditTestModeFromDefine = bool.fromEnvironment('LIVE_EDIT_TEST_MODE');
const _liveEditBackendIdFromDefine = String.fromEnvironment(
  'LIVE_EDIT_BACKEND',
  defaultValue: 'codex_exec',
);
const _liveEditWorkingDirectoryFromDefine = String.fromEnvironment(
  'LIVE_EDIT_WORKING_DIRECTORY',
);

Future<void> bootstrapFlutterLiveEditApp({
  required final void Function() runApp,
  final Future<void> Function()? initializeApp,
  final Future<void> Function()? registerInitialEntries,
  final Future<void> Function()? registerDelayedEntries,
  final Duration delayedRegistrationDelay = const Duration(seconds: 5),
  final FlutterLiveEditAutoConfig? config,
  final void Function(Object error, StackTrace stackTrace)? onError,
}) async {
  final resolvedConfig = config ?? FlutterLiveEditAutoConfig.fromEnvironment();
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kIsWeb && resolvedConfig.enableWebSemantics) {
        SemanticsBinding.instance.ensureSemantics();
      }
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();
      await MCPToolkitBinding.instance.initializeFlutterLiveEditToolkit();

      if (initializeApp != null) {
        await initializeApp();
      }
      if (registerInitialEntries != null) {
        await registerInitialEntries();
      }
      runApp();

      if (registerDelayedEntries != null) {
        Timer(
          delayedRegistrationDelay,
          () => unawaited(registerDelayedEntries()),
        );
      }
    },
    (final error, final stackTrace) {
      if (onError != null) {
        onError(error, stackTrace);
        return;
      }
      MCPToolkitBinding.instance.handleZoneError(error, stackTrace);
    },
  );
}

@visibleForTesting
LiveEditOrchestrator? debugFlutterLiveEditAutoHostOrchestratorOverride;

final class FlutterLiveEditAutoConfig {
  const FlutterLiveEditAutoConfig({
    this.backendId = _liveEditBackendIdFromDefine,
    this.workingDirectory,
    this.intentText,
    this.testMode = false,
    this.availableBackends,
    this.enableRuntimeRefresh = true,
    this.enableWebSemantics = true,
    this.appId,
    this.meta = const <String, Object?>{},
  });

  factory FlutterLiveEditAutoConfig.fromEnvironment({
    final String? intentText,
    final List<LiveEditAgentBackend>? availableBackends,
    final bool enableRuntimeRefresh = true,
    final bool enableWebSemantics = true,
    final String? appId,
    final Map<String, Object?> meta = const <String, Object?>{},
  }) => FlutterLiveEditAutoConfig(
    workingDirectory: _trimToNull(_liveEditWorkingDirectoryFromDefine),
    intentText: intentText,
    testMode:
        _liveEditTestModeFromDefine ||
        (kIsWeb && Uri.base.queryParameters['live_edit_test_mode'] == '1'),
    availableBackends: availableBackends,
    enableRuntimeRefresh: enableRuntimeRefresh,
    enableWebSemantics: enableWebSemantics,
    appId: appId,
    meta: meta,
  );

  final String backendId;
  final String? workingDirectory;
  final String? intentText;
  final bool testMode;
  final List<LiveEditAgentBackend>? availableBackends;
  final bool enableRuntimeRefresh;
  final bool enableWebSemantics;
  final String? appId;
  final Map<String, Object?> meta;

  String? get hostWorkingDirectory =>
      testMode ? null : _trimToNull(workingDirectory);

  String get hostIntentText {
    final explicit = _trimToNull(intentText);
    if (explicit != null) {
      return explicit;
    }
    return testMode
        ? 'Persist live-edit changes for the selected deterministic test fixture.'
        : 'Persist the requested live-edit change in the selected source file.';
  }

  FlutterLiveEditAutoConfig copyWith({
    final String? backendId,
    final String? workingDirectory,
    final String? intentText,
    final bool? testMode,
    final List<LiveEditAgentBackend>? availableBackends,
    final bool? enableRuntimeRefresh,
    final bool? enableWebSemantics,
    final String? appId,
    final Map<String, Object?>? meta,
  }) => FlutterLiveEditAutoConfig(
    backendId: backendId ?? this.backendId,
    workingDirectory: workingDirectory ?? this.workingDirectory,
    intentText: intentText ?? this.intentText,
    testMode: testMode ?? this.testMode,
    availableBackends: availableBackends ?? this.availableBackends,
    enableRuntimeRefresh: enableRuntimeRefresh ?? this.enableRuntimeRefresh,
    enableWebSemantics: enableWebSemantics ?? this.enableWebSemantics,
    appId: appId ?? this.appId,
    meta: meta ?? this.meta,
  );
}

class FlutterLiveEditAutoHost extends StatelessWidget {
  FlutterLiveEditAutoHost({
    required this.child,
    super.key,
    this.config,
    this.orchestrator,
    this.applyDraftDelegate,
    final LiveEditAgentService? agentService,
  }) : _agentService = agentService ?? LiveEditAgentService();

  final Widget child;
  final FlutterLiveEditAutoConfig? config;
  final LiveEditOrchestrator? orchestrator;
  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final LiveEditAgentService _agentService;

  @override
  Widget build(final BuildContext context) {
    final resolvedConfig =
        config ?? FlutterLiveEditAutoConfig.fromEnvironment();
    final resolvedOrchestrator =
        orchestrator ?? debugFlutterLiveEditAutoHostOrchestratorOverride;
    final backends =
        resolvedConfig.availableBackends ?? _agentService.listBackends();
    final defaultDelegate =
        applyDraftDelegate ??
        _FlutterLiveEditAutoDelegate(
          config: resolvedConfig,
          agentService: _agentService,
          availableBackends: backends,
        ).apply;
    final host = FlutterLiveEditHost(
      orchestrator: resolvedOrchestrator,
      applyDraftDelegate: resolvedOrchestrator == null ? defaultDelegate : null,
      backendId: resolvedOrchestrator == null ? resolvedConfig.backendId : null,
      availableBackends: resolvedOrchestrator == null
          ? backends
          : const <LiveEditAgentBackend>[],
      workingDirectory: resolvedOrchestrator == null
          ? resolvedConfig.hostWorkingDirectory
          : null,
      intentText: resolvedOrchestrator == null
          ? resolvedConfig.hostIntentText
          : null,
      child: child,
    );
    if (resolvedOrchestrator == null) {
      return LiveEditScope(
        applyDraftDelegate: defaultDelegate,
        backendId: resolvedConfig.backendId,
        availableBackends: backends,
        workingDirectory: resolvedConfig.hostWorkingDirectory,
        intentText: resolvedConfig.hostIntentText,
        child: host,
      );
    }
    return host;
  }
}

final class _FlutterLiveEditAutoDelegate {
  _FlutterLiveEditAutoDelegate({
    required this.config,
    required this.agentService,
    required this.availableBackends,
  });

  final FlutterLiveEditAutoConfig config;
  final LiveEditAgentService agentService;
  final List<LiveEditAgentBackend> availableBackends;

  Future<Map<String, Object?>> apply(final LiveEditApplyDraftRequest request) {
    if (config.testMode) {
      return _applyDeterministicTestResponse(request);
    }
    return _applyDefault(request);
  }

  String backendLabel(final String backendId) {
    for (final backend in availableBackends) {
      if (backend.id == backendId) {
        return backend.label;
      }
    }
    return backendId;
  }

  Future<Map<String, Object?>> _applyDeterministicTestResponse(
    final LiveEditApplyDraftRequest request,
  ) async {
    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Preparing deterministic test response.',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Deterministic backend stream started.',
      ),
    );
    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Deterministic backend streamed draft output.',
        details: <String>[
          '{"summary":"Persist the inline live-edit changes."}',
        ],
      ),
    );
    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.debug,
        message: 'Deterministic raw stdout chunk.',
        details: <String>[
          '{"summary":"Persist the inline live-edit changes."}',
        ],
        debugOnly: true,
      ),
    );
    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Returning deterministic proposal.',
      ),
    );
    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Applying deterministic test patch.',
      ),
    );
    return <String, Object?>{
      'proposalId': 'maestro-live-edit-proposal',
      'executionPlan': <String, Object?>{
        'proposalId': 'maestro-live-edit-proposal',
        'title': 'Apply live edit',
        'summary':
            'Persist the inline live-edit changes for deterministic tests.',
        'selectedNode': 'Text',
        'requestedChanges': <String>[
          'Update selected text property from the panel draft.',
        ],
        'affectedFiles': <String>['lib/main.dart'],
        'confidence': 0.96,
        'riskNotes': <String>['demo'],
        'agentInstruction':
            'Persist the selected live-edit draft in the current app.',
      },
      'result': <String, Object?>{
        'status': 'applied',
        'changedFiles': <String>['lib/main.dart'],
      },
    };
  }

  Future<Map<String, Object?>> _applyDefault(
    final LiveEditApplyDraftRequest request,
  ) async {
    final workingDirectory = _resolveLiveEditWorkingDirectory(
      request,
      config: config,
    );
    if (workingDirectory == null || workingDirectory.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'message':
            'Live edit could not infer a working directory. Set LIVE_EDIT_WORKING_DIRECTORY or select a source-backed widget.',
      };
    }

    final backendId = request.backendId ?? config.backendId;
    final backendLabel = this.backendLabel(backendId);
    final debugDetails = _liveEditRequestDebugDetails(
      request,
      backendId: backendId,
      workingDirectory: workingDirectory,
    );
    request.onEvent?.call(
      LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Preparing source context for $backendLabel.',
        details: <String>[
          'Workspace: $workingDirectory',
          'Backend: $backendLabel',
        ],
      ),
    );
    request.onEvent?.call(
      LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.debug,
        message: 'Dispatching resolve request.',
        details: <String>[
          ...debugDetails,
          if ((request.intentText ?? '').trim().isNotEmpty)
            'Intent: ${request.intentText!.trim()}',
        ],
        debugOnly: true,
      ),
    );

    final resolutionRequest = LiveEditResolutionRequest(
      sessionId: request.sessionId,
      bubbleId: request.effectiveBubbleId,
      backendId: backendId,
      workingDirectory: workingDirectory,
      instructionText: request.effectiveInstructionText,
      primarySelection: request.effectivePrimarySelection,
      selectedWidgets: request.effectiveSelectedWidgets,
      sourceTargets: request.sourceTargets,
      applyMode: request.applyMode,
      inferenceConfig: request.inferenceConfig,
      intentText: request.intentText,
      selection: request.selection,
      meta: <String, Object?>{
        if ((config.appId ?? '').trim().isNotEmpty) 'app': config.appId,
        'driver': 'flutter_live_edit_auto_host',
        ...config.meta,
      },
    );
    final promptText = agentService.buildResolvedPrompt(resolutionRequest);
    request.onEvent?.call(
      LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.debug,
        message: 'Resolved backend prompt captured.',
        details: <String>[
          ...debugDetails,
          'Prompt bytes: ${promptText.length}',
        ],
        promptText: promptText,
        debugOnly: true,
      ),
    );

    try {
      final execution = await agentService.executeDirectApply(
        resolutionRequest,
        onStreamEvent: (final event) =>
            _emitInferenceStreamEvent(request, event, backendId: backendId),
      );
      final runtimeRefresh = config.enableRuntimeRefresh
          ? await _refreshRuntimeAfterApply(request)
          : const LiveEditRuntimeRefreshResult(
              validation: <String, Object?>{
                'validated': false,
                'reason': 'runtime_refresh_disabled',
              },
            );
      final refreshedExecution = LiveEditDirectApplyResult(
        executionId: execution.executionId,
        backendId: execution.backendId,
        summary: execution.summary,
        changedFiles: execution.changedFiles,
        warnings: execution.warnings,
        validationSteps: execution.validationSteps,
        runtimeRefresh: runtimeRefresh,
        meta: execution.meta,
      );
      final executionPlan = agentService.buildExecutionPlanForExecution(
        request: resolutionRequest,
        execution: refreshedExecution,
      );
      request.onEvent?.call(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: '$backendLabel applied this bubble change.',
          details: <String>[
            refreshedExecution.summary,
            ...refreshedExecution.changedFiles.take(4),
            if (runtimeRefresh.didRefresh)
              'Runtime: ${runtimeRefresh.action.wireName}',
          ],
        ),
      );
      request.onEvent?.call(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Execution result received.',
          details: <String>[
            'Execution: ${refreshedExecution.executionId}',
            'Backend: ${refreshedExecution.backendId}',
            if ((request.inferenceConfig?.model ?? '').trim().isNotEmpty)
              'Model: ${request.inferenceConfig!.model}',
            if (runtimeRefresh.didRefresh)
              'Runtime: ${runtimeRefresh.action.wireName}',
            ...refreshedExecution.changedFiles.take(4),
          ],
          debugOnly: true,
        ),
      );
      return <String, Object?>{
        'proposalId': refreshedExecution.executionId,
        'executionPlan': executionPlan.toJson(),
        'executionResult': refreshedExecution.toJson(),
        'result': refreshedExecution.toJson(),
        'runtimeRefresh': runtimeRefresh.toJson(),
      };
    } on LiveEditAgentException catch (error) {
      request.onEvent?.call(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Direct apply request failed.',
          details: <String>[
            ...debugDetails,
            'Error: ${_liveEditErrorMessage(error.message, details: error.details)}',
          ],
          debugOnly: true,
        ),
      );
      return _liveEditFailureResponse(
        error.message,
        details: error.details,
        meta: error.meta,
      );
    } on Exception catch (error) {
      request.onEvent?.call(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Direct apply request failed.',
          details: <String>[...debugDetails, 'Error: $error'],
          debugOnly: true,
        ),
      );
      return _liveEditFailureResponse('$error');
    }
  }
}

String? _resolveLiveEditWorkingDirectory(
  final LiveEditApplyDraftRequest request, {
  required final FlutterLiveEditAutoConfig config,
}) {
  final requested = _trimToNull(request.workingDirectory);
  if (requested != null) {
    return requested;
  }
  final configured = _trimToNull(config.workingDirectory);
  if (configured != null) {
    return configured;
  }
  final inferred = _workingDirectoryFromSelection(request.selection);
  if (inferred != null) {
    return inferred;
  }
  final cwd = Directory.current.path;
  return File('$cwd/pubspec.yaml').existsSync() ? cwd : null;
}

String? _workingDirectoryFromSelection(final LiveEditSelection? selection) {
  final sourceFile = _trimToNull(selection?.source?.file);
  if (sourceFile == null) {
    return null;
  }
  final normalized = _normalizePath(sourceFile);
  final file = File(normalized);
  Directory? cursor = file.existsSync() ? file.parent : Directory(normalized);
  while (cursor != null) {
    final pubspec = File('${cursor.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      return cursor.path;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      break;
    }
    cursor = parent;
  }
  return null;
}

String _normalizePath(final String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.scheme == 'file') {
    return uri.toFilePath();
  }
  return rawPath;
}

String? _trimToNull(final String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

Future<LiveEditRuntimeRefreshResult> _refreshRuntimeAfterApply(
  final LiveEditApplyDraftRequest request,
) async {
  if (kIsWeb || kReleaseMode) {
    return const LiveEditRuntimeRefreshResult(
      validation: <String, Object?>{
        'validated': false,
        'reason': 'runtime_refresh_unavailable',
      },
    );
  }

  final info = await developer.Service.getInfo();
  final wsUri =
      info.serverWebSocketUri ??
      (info.serverUri == null
          ? null
          : convertToWebSocketUrl(serviceProtocolUrl: info.serverUri!));
  if (wsUri == null) {
    return const LiveEditRuntimeRefreshResult(
      validation: <String, Object?>{
        'validated': false,
        'reason': 'vm_service_uri_unavailable',
      },
    );
  }

  final service = await vmServiceConnectUri(wsUri.toString());
  try {
    final vm = await service.getVM();
    final isolateId = vm.isolates != null && vm.isolates!.isNotEmpty
        ? vm.isolates!.first.id
        : null;
    if (isolateId == null || isolateId.isEmpty) {
      return const LiveEditRuntimeRefreshResult(
        validation: <String, Object?>{
          'validated': false,
          'reason': 'isolate_unavailable',
        },
      );
    }

    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Triggering hot reload after apply.',
      ),
    );
    final hotReload = await _triggerOwnHotReload(service, isolateId: isolateId);
    if (hotReload['ok'] == true) {
      return LiveEditRuntimeRefreshResult(
        action: LiveEditRuntimeAction.hotReload,
        validation: <String, Object?>{
          'validated': true,
          'reason': '${hotReload['reason'] ?? 'hot_reload_succeeded'}',
        },
        hotReload: hotReload,
      );
    }

    if (!_shouldAutoRestartAfterApply(request)) {
      request.onEvent?.call(
        const LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message:
              'Hot reload did not confirm success. Skipping auto-restart for a widget-scoped edit.',
        ),
      );
      return LiveEditRuntimeRefreshResult(
        validation: <String, Object?>{
          'validated': false,
          'reason': 'hot_reload_failed_restart_skipped',
        },
        hotReload: hotReload,
      );
    }

    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message:
            'Hot reload did not confirm success for a broad edit. Triggering hot restart.',
      ),
    );
    final hotRestart = await _triggerOwnHotRestart(service);
    return LiveEditRuntimeRefreshResult(
      action: hotRestart['ok'] == true
          ? LiveEditRuntimeAction.hotRestart
          : LiveEditRuntimeAction.none,
      validation: <String, Object?>{
        'validated': hotRestart['ok'] == true,
        'reason': hotRestart['ok'] == true
            ? 'hot_restart_after_reload_failure'
            : 'hot_restart_failed',
      },
      hotReload: hotReload,
      hotRestart: hotRestart,
      validationRecovery: const <String, Object?>{'attempted': true},
    );
  } finally {
    await service.dispose();
  }
}

bool _shouldAutoRestartAfterApply(final LiveEditApplyDraftRequest request) {
  if (request.effectivePrimarySelection != null ||
      request.effectiveSelectedWidgets.isNotEmpty ||
      request.selection != null ||
      request.sourceTargets.isNotEmpty) {
    return false;
  }
  return true;
}

Future<Map<String, Object?>> _triggerOwnHotReload(
  final VmService service, {
  required final String isolateId,
}) async {
  StreamSubscription<Event>? serviceStreamSubscription;
  try {
    final hotReloadMethodNameCompleter = Completer<String?>();
    serviceStreamSubscription = service.onEvent(EventStreams.kService).listen((
      final event,
    ) {
      if (event.kind == EventKind.kServiceRegistered &&
          event.service == 'reloadSources' &&
          !hotReloadMethodNameCompleter.isCompleted) {
        hotReloadMethodNameCompleter.complete(event.method);
      }
    });

    await service.streamListen(EventStreams.kService);
    final hotReloadMethodName = await hotReloadMethodNameCompleter.future
        .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);

    if (hotReloadMethodName == null) {
      final report = await service.reloadSources(isolateId, force: true);
      final json = report.toJson();
      final success =
          report.success == true ||
          '${json['type'] ?? ''}'.trim().toLowerCase() == 'success';
      return <String, Object?>{
        'ok': success,
        'reason': success ? 'reload_report_success' : 'reload_report_failed',
        'report': json,
      };
    }

    final response = await service.callMethod(
      hotReloadMethodName,
      isolateId: isolateId,
      args: <String, Object?>{'force': true},
    );
    final json = response.json ?? const <String, Object?>{};
    final responseType = '${json['type'] ?? ''}'.trim().toLowerCase();
    final success =
        responseType == 'success' ||
        (responseType == 'reloadreport' && json['success'] == true);
    return <String, Object?>{
      'ok': success,
      'reason': success
          ? 'reload_service_extension_success'
          : 'reload_service_extension_failed',
      'report': json,
    };
  } on Exception catch (error) {
    return <String, Object?>{
      'ok': false,
      'reason': 'hot_reload_exception',
      'error': '$error',
    };
  } finally {
    try {
      await serviceStreamSubscription?.cancel();
      await service.streamCancel(EventStreams.kService);
    } catch (_) {
      // Ignore shutdown races.
    }
  }
}

Future<Map<String, Object?>> _triggerOwnHotRestart(
  final VmService service,
) async {
  String? hotRestartMethodName;
  StreamSubscription<Event>? eventSubscription;
  try {
    final completer = Completer<String?>();
    eventSubscription = service.onEvent(EventStreams.kService).listen((
      final event,
    ) {
      if (event.kind == EventKind.kServiceRegistered &&
          event.service == 'hotRestart' &&
          !completer.isCompleted) {
        completer.complete(event.method);
      }
    });

    await service.streamListen(EventStreams.kService);
    hotRestartMethodName = await completer.future.timeout(
      const Duration(milliseconds: 800),
      onTimeout: () => null,
    );
  } finally {
    try {
      await eventSubscription?.cancel();
      await service.streamCancel(EventStreams.kService);
    } catch (_) {
      // Ignore shutdown races.
    }
  }

  try {
    final response = await service.callMethod(
      hotRestartMethodName ?? 'hotRestart',
    );
    return <String, Object?>{
      'ok': true,
      'report': <String, Object?>{
        'type': response.json?['type'] ?? 'Success',
        'success': response.json?['success'] ?? true,
      },
    };
  } on Exception catch (error) {
    return <String, Object?>{'ok': false, 'error': '$error'};
  }
}

List<String> _liveEditRequestDebugDetails(
  final LiveEditApplyDraftRequest request, {
  required final String backendId,
  required final String workingDirectory,
}) => <String>[
  'Session: ${request.sessionId}',
  'Backend: $backendId',
  if ((request.inferenceConfig?.model ?? '').trim().isNotEmpty)
    'Model: ${request.inferenceConfig!.model}',
  if ((request.inferenceConfig?.reasoningEffort ?? '').trim().isNotEmpty)
    'Reasoning: ${request.inferenceConfig!.reasoningEffort}',
  'Workspace: $workingDirectory',
  'Node: ${request.selection?.nodeId ?? '<none>'}',
  'Intent present: ${(request.intentText ?? '').trim().isNotEmpty}',
];

void _emitInferenceStreamEvent(
  final LiveEditApplyDraftRequest request,
  final InferenceStructuredTextStreamEvent event, {
  required final String backendId,
}) {
  final sink = request.onEvent;
  if (sink == null) {
    return;
  }

  final attempt = event.attempt == null ? null : 'Attempt: ${event.attempt}';
  final metadata = event.metadata.entries
      .where((final entry) => '${entry.value}'.trim().isNotEmpty)
      .take(4)
      .map((final entry) => '${entry.key}: ${entry.value}')
      .toList(growable: false);
  final backendLabel = _backendLabelForEvent(backendId);

  switch (event.type) {
    case InferenceStructuredTextStreamEventType.lifecycle:
      final lifecycleState = event.lifecycleState == null
          ? null
          : 'State: ${event.lifecycleState!.name}';
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: event.message ?? '$backendLabel stream lifecycle updated.',
          details: _detailList(<String?>[attempt, lifecycleState, ...metadata]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference lifecycle event.',
          details: _detailList(<String?>[
            event.message,
            attempt,
            lifecycleState,
            ...metadata,
          ]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.progress:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: _truncateForActivity(
            event.message ?? '$backendLabel reported progress.',
          ),
          details: _detailList(<String?>[attempt, ...metadata]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference progress event.',
          details: _detailList(<String?>[event.message, attempt, ...metadata]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.partialOutput:
      final textDelta = (event.textDelta ?? '').trim().isEmpty
          ? null
          : event.textDelta!;
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: '$backendLabel streamed output.',
          details: _detailList(<String?>[
            attempt,
            if (textDelta == null) null else _truncateForActivity(textDelta),
          ]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference partial output event.',
          details: _detailList(<String?>[textDelta, attempt]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.raw:
      final rawText = (event.rawText ?? '').trim().isEmpty
          ? null
          : event.rawText!;
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message:
              'Raw ${event.rawChannel?.name ?? 'stream'} chunk from $backendLabel.',
          details: _detailList(<String?>[rawText, attempt, ...metadata]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.warning:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: event.message ?? '$backendLabel emitted a warning.',
          details: _detailList(<String?>[
            attempt,
            if (event.isTransient) 'Transient warning',
          ]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference warning event.',
          details: _detailList(<String?>[
            event.message,
            attempt,
            if (event.isTransient) 'Transient warning',
          ]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.error:
      final errorCode = event.error == null
          ? null
          : 'Code: ${event.error!.code}';
      final errorDetails = event.error?.details == null
          ? null
          : '${event.error!.details}';
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message:
              event.message ?? event.error?.message ?? '$backendLabel failed.',
          details: _detailList(<String?>[attempt, errorCode]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference error event.',
          details: _detailList(<String?>[
            event.message,
            errorCode,
            errorDetails,
            attempt,
          ]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.completion:
      final attemptCount = event.completion?.attemptCount == null
          ? null
          : 'Attempts: ${event.completion!.attemptCount}';
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: event.completion?.result.success == true
              ? '$backendLabel stream completed.'
              : '$backendLabel stream failed.',
          details: _detailList(<String?>[attempt, attemptCount]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference completion event.',
          details: _detailList(<String?>[
            'Success: ${event.completion?.result.success == true}',
            attempt,
            attemptCount,
          ]),
          debugOnly: true,
        ),
      );
  }
}

String _backendLabelForEvent(final String backendId) => backendId;

List<String> _detailList(final List<String?> values) =>
    values.whereType<String>().toList(growable: false);

String _liveEditErrorMessage(final String message, {final Object? details}) {
  final normalizedMessage = message.trim().isEmpty
      ? 'Live edit failed.'
      : message.trim();
  String? salient;
  if (details is Map) {
    final map = details.map(
      (final key, final value) => MapEntry('$key', value),
    );
    final stderr = '${map['stderr'] ?? ''}'.trim();
    final rawDetails = '${map['rawDetails'] ?? ''}'.trim();
    if (stderr.isNotEmpty) {
      salient = stderr;
    } else if (rawDetails.isNotEmpty) {
      salient = rawDetails;
    }
  } else {
    final raw = '$details'.trim();
    if (raw.isNotEmpty && raw != 'null') {
      salient = raw;
    }
  }
  if (salient == null || salient == normalizedMessage) {
    return normalizedMessage;
  }
  return '$normalizedMessage\n$salient';
}

Map<String, Object?> _liveEditFailureResponse(
  final String message, {
  final Object? details,
  final Map<String, Object?> meta = const <String, Object?>{},
}) => <String, Object?>{
  'ok': false,
  'message': _liveEditErrorMessage(message, details: details),
  'details': details,
  if (meta.isNotEmpty) 'meta': meta,
  'error': <String, Object?>{
    'message': _liveEditErrorMessage(message, details: details),
    ..._optionalEntry('details', details),
    if (meta.isNotEmpty) 'meta': meta,
  },
};

Map<String, Object?> _optionalEntry(final String key, final Object? value) =>
    value == null ? const <String, Object?>{} : <String, Object?>{key: value};

String _truncateForActivity(final String value, {final int max = 140}) {
  final trimmed = value.trim();
  if (trimmed.length <= max) {
    return trimmed;
  }
  return '${trimmed.substring(0, max)}...';
}
