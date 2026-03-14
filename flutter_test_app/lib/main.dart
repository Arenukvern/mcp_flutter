// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_live_edit_agent/flutter_live_edit_agent.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:provider/provider.dart';
import 'package:test_app/change_notifier_example.dart';
import 'package:test_app/live_edit_codex_fixture.dart';
import 'package:test_app/stateful_widget_example.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

const _liveEditTestModeFromDefine = bool.fromEnvironment('LIVE_EDIT_TEST_MODE');
const _liveEditBackendId = String.fromEnvironment(
  'LIVE_EDIT_BACKEND',
  defaultValue: 'codex_exec',
);
const _liveEditWorkingDirectoryDefine = String.fromEnvironment(
  'LIVE_EDIT_WORKING_DIRECTORY',
);

bool get _liveEditTestMode =>
    _liveEditTestModeFromDefine ||
    (kIsWeb && Uri.base.queryParameters['live_edit_test_mode'] == '1');

@visibleForTesting
LiveEditOrchestrator? debugLiveEditOrchestratorOverride;

final LiveEditAgentService _liveEditAgentService = LiveEditAgentService();
final List<LiveEditAgentBackend> _liveEditBackends = _liveEditAgentService
    .listBackends();

String _backendLabel(final String backendId) {
  for (final backend in _liveEditBackends) {
    if (backend.id == backendId) {
      return backend.label;
    }
  }
  return backendId;
}

Future<Map<String, Object?>> _liveEditTestApplyDelegate(
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
      details: <String>['{"summary":"Persist the inline live-edit changes."}'],
    ),
  );
  request.onEvent?.call(
    const LiveEditRuntimeEvent(
      kind: LiveEditRuntimeEventKind.debug,
      message: 'Deterministic raw stdout chunk.',
      details: <String>['{"summary":"Persist the inline live-edit changes."}'],
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
      'summary': 'Persist the inline live-edit changes for Maestro.',
      'selectedNode': 'Text',
      'requestedChanges': <String>[
        'Update selected text property from the panel draft.',
      ],
      'affectedFiles': <String>['lib/main.dart'],
      'confidence': 0.96,
      'riskNotes': <String>['demo'],
      'agentInstruction':
          'Persist the selected live-edit draft in the demo app.',
    },
    'result': <String, Object?>{
      'status': 'applied',
      'changedFiles': <String>['lib/main.dart'],
    },
  };
}

String _normalizePath(final String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.scheme == 'file') {
    return uri.toFilePath();
  }
  return rawPath;
}

String? _workingDirectoryFromSelection(final LiveEditSelection? selection) {
  final sourceFile = selection?.source?.file;
  if (sourceFile == null || sourceFile.trim().isEmpty) {
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

String? _resolveLiveEditWorkingDirectory(
  final LiveEditApplyDraftRequest request,
) {
  final requested = request.workingDirectory?.trim() ?? '';
  if (requested.isNotEmpty) {
    return requested;
  }
  if (_liveEditWorkingDirectoryDefine.isNotEmpty) {
    return _liveEditWorkingDirectoryDefine;
  }
  final inferred = _workingDirectoryFromSelection(request.selection);
  if (inferred != null && inferred.isNotEmpty) {
    return inferred;
  }
  final cwd = Directory.current.path;
  return File('$cwd/pubspec.yaml').existsSync() ? cwd : null;
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
  'Drafts: ${request.draftChanges.length}',
  'Intent present: ${((request.intentText ?? '').trim().isNotEmpty)}',
];

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
    if (details != null) 'details': details,
    if (meta.isNotEmpty) 'meta': meta,
  },
};

String _truncateForActivity(final String value, {final int max = 140}) {
  final trimmed = value.trim();
  if (trimmed.length <= max) {
    return trimmed;
  }
  return '${trimmed.substring(0, max)}...';
}

Future<LiveEditRuntimeRefreshResult> _refreshOwnRuntime(
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
  if (request.draftChanges.isNotEmpty ||
      request.effectiveStagedPropertyChanges.isNotEmpty) {
    return false;
  }
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

void _emitInferenceStreamEvent(
  final LiveEditApplyDraftRequest request,
  final InferenceStructuredTextStreamEvent event,
) {
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
  final backendLabel = _backendLabel(request.backendId ?? _liveEditBackendId);

  switch (event.type) {
    case InferenceStructuredTextStreamEventType.lifecycle:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: event.message ?? '$backendLabel stream lifecycle updated.',
          details: <String>[
            if (attempt != null) attempt,
            if (event.lifecycleState != null)
              'State: ${event.lifecycleState!.name}',
            ...metadata,
          ],
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference lifecycle event.',
          details: <String>[
            if (event.message != null) event.message!,
            if (attempt != null) attempt,
            if (event.lifecycleState != null)
              'State: ${event.lifecycleState!.name}',
            ...metadata,
          ],
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
          details: <String>[if (attempt != null) attempt, ...metadata],
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference progress event.',
          details: <String>[
            if (event.message != null) event.message!,
            if (attempt != null) attempt,
            ...metadata,
          ],
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.partialOutput:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: '$backendLabel streamed output.',
          details: <String>[
            if (attempt != null) attempt,
            if ((event.textDelta ?? '').trim().isNotEmpty)
              _truncateForActivity(event.textDelta!),
          ],
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference partial output event.',
          details: <String>[
            if ((event.textDelta ?? '').trim().isNotEmpty) event.textDelta!,
            if (attempt != null) attempt,
          ],
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.raw:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message:
              'Raw ${event.rawChannel?.name ?? 'stream'} chunk from $backendLabel.',
          details: <String>[
            if ((event.rawText ?? '').trim().isNotEmpty) event.rawText!,
            if (attempt != null) attempt,
            ...metadata,
          ],
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.warning:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: event.message ?? '$backendLabel emitted a warning.',
          details: <String>[
            if (attempt != null) attempt,
            if (event.isTransient) 'Transient warning',
          ],
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference warning event.',
          details: <String>[
            if (event.message != null) event.message!,
            if (attempt != null) attempt,
            if (event.isTransient) 'Transient warning',
          ],
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.error:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message:
              event.message ?? event.error?.message ?? '$backendLabel failed.',
          details: <String>[
            if (attempt != null) attempt,
            if (event.error != null) 'Code: ${event.error!.code}',
          ],
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference error event.',
          details: <String>[
            if (event.message != null) event.message!,
            if (event.error != null) 'Code: ${event.error!.code}',
            if (event.error?.details != null) '${event.error!.details}',
            if (attempt != null) attempt,
          ],
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.completion:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: event.completion?.result.success == true
              ? '$backendLabel stream completed.'
              : '$backendLabel stream failed.',
          details: <String>[
            if (attempt != null) attempt,
            if (event.completion?.attemptCount != null)
              'Attempts: ${event.completion!.attemptCount}',
          ],
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference completion event.',
          details: <String>[
            'Success: ${event.completion?.result.success == true}',
            if (attempt != null) attempt,
            if (event.completion?.attemptCount != null)
              'Attempts: ${event.completion!.attemptCount}',
          ],
          debugOnly: true,
        ),
      );
  }
}

Future<Map<String, Object?>> _liveEditDefaultApplyDelegate(
  final LiveEditApplyDraftRequest request,
) async {
  final workingDirectory = _resolveLiveEditWorkingDirectory(request);
  if (workingDirectory == null || workingDirectory.isEmpty) {
    return <String, Object?>{
      'ok': false,
      'message':
          'Live edit could not infer a working directory. Set LIVE_EDIT_WORKING_DIRECTORY or select a source-backed widget.',
    };
  }

  final backendId = request.backendId ?? _liveEditBackendId;
  final backendLabel = _backendLabel(backendId);
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
    stagedPropertyChanges: request.effectiveStagedPropertyChanges,
    applyMode: request.applyMode,
    inferenceConfig: request.inferenceConfig,
    intentText: request.intentText,
    draftChanges: request.draftChanges,
    selection: request.selection,
    meta: const <String, Object?>{
      'app': 'test_app',
      'driver': 'live_edit_host',
    },
  );
  final promptText = _liveEditAgentService.buildResolvedPrompt(
    resolutionRequest,
  );
  request.onEvent?.call(
    LiveEditRuntimeEvent(
      kind: LiveEditRuntimeEventKind.debug,
      message: 'Resolved backend prompt captured.',
      details: <String>[...debugDetails, 'Prompt bytes: ${promptText.length}'],
      promptText: promptText,
      debugOnly: true,
    ),
  );
  try {
    final execution = await _liveEditAgentService.executeDirectApply(
      resolutionRequest,
      onStreamEvent: (final event) => _emitInferenceStreamEvent(request, event),
    );
    final runtimeRefresh = await _refreshOwnRuntime(request);
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
    final executionPlan = _liveEditAgentService.buildExecutionPlanForExecution(
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

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kIsWeb) {
        SemanticsBinding.instance.ensureSemantics();
      }
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit()
        ..initializeFlutterLiveEditToolkit();

      await _registerInitialMCPTools();
      runApp(const MyApp());

      // Demonstrate delayed tool registration
      Timer(const Duration(seconds: 5), () async {
        await _registerDelayedMCPTools();
      });
    },
    (error, stack) {
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Toolkit Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (final context, final child) {
        final orchestrator = debugLiveEditOrchestratorOverride;
        final applyDelegate = orchestrator == null
            ? (_liveEditTestMode
                  ? _liveEditTestApplyDelegate
                  : (!kIsWeb ? _liveEditDefaultApplyDelegate : null))
            : null;
        return FlutterLiveEditHost(
          orchestrator: orchestrator,
          applyDraftDelegate: applyDelegate,
          backendId: orchestrator == null ? _liveEditBackendId : null,
          availableBackends: orchestrator == null
              ? _liveEditBackends
              : const <LiveEditAgentBackend>[],
          workingDirectory: orchestrator == null && !_liveEditTestMode
              ? _liveEditWorkingDirectoryDefine
              : null,
          intentText: orchestrator == null
              ? (_liveEditTestMode
                    ? 'Persist live-edit changes for the Maestro test fixture.'
                    : 'Persist the requested live-edit change in the selected source file.')
              : null,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: ChangeNotifierProvider(
        create: (final context) => CustomNotifier(),
        child: const MCPDemoHomePage(),
      ),
    );
  }
}

class MCPDemoHomePage extends StatefulWidget {
  const MCPDemoHomePage({super.key});

  @override
  State<MCPDemoHomePage> createState() => _MCPDemoHomePageState();
}

class _MCPDemoHomePageState extends State<MCPDemoHomePage> {
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _initializeMCPIntegration();
    _startPeriodicStatusCheck();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _initializeMCPIntegration() {
    // Register a tool that tracks UI state
    addMcpTool(
      MCPCallEntry.tool(
        handler: (request) {
          return MCPCallResult(
            message: 'Current app UI state',
            parameters: {
              'totalMCPEntries': MCPToolkitBinding.instance.allEntries.length,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        },
        definition: MCPToolDefinition(
          name: 'get_app_ui_state',
          description: 'Get current UI state and MCP integration status',
          inputSchema: ObjectSchema(properties: {}),
        ),
      ),
    );
  }

  void _startPeriodicStatusCheck() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text(
          'MCP Toolkit Demo',
          semanticsIdentifier: 'app_title_text',
        ),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_liveEditTestMode) ...[
              const LiveEditCodexFixture(),
              SizedBox(height: 24),
            ],
            // Header Section
            _HeaderSection(),
            SizedBox(height: 24),

            // Counter Demos Section
            _CounterDemoSection(),
            SizedBox(height: 24),

            // MCP Tools Section
            _MCPToolsSection(),
            SizedBox(height: 24),

            // Status Section
            _StatusSection(),
            SizedBox(height: 24),

            // Error Section
            ErrorSection(),
          ],
        ),
      ),
    );
  }
}

// Header section explaining the demo
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Semantics(
                  identifier: 'about_demo_heading',
                  child: Text(
                    'Cursor Live Editing For Flutter!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This Flutter app demonstrates dynamic MCP (Model Context Protocol) tool registration using MCP Toolkit. '
              'The app registers various tools and resources that can be accessed by MCP clients.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: const Text('MCP Integration'),
                  backgroundColor: Colors.blue.shade100,
                ),
                Chip(
                  label: const Text('Dynamic Registration'),
                  backgroundColor: Colors.green.shade100,
                ),
                Chip(
                  label: const Text('Flutter Toolkit'),
                  backgroundColor: Colors.purple.shade100,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Counter demonstrations section
class _CounterDemoSection extends StatelessWidget {
  const _CounterDemoSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Semantics(
                  identifier: 'counter_demo_icon',
                  child: Icon(
                    Icons.calculate,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  identifier: 'counter_demo_heading',
                  child: Text(
                    'State Management Examples',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: StatefulCounterWidget()),
                SizedBox(width: 16),
                Expanded(child: ChangeNotifierCounterWidget()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorSection extends StatelessWidget {
  const ErrorSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Error Section',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // @ai DO NOT FIX:
            // this line will cause an overflow error for testing purposes
            // so ai could find the cause using MCP screenshot tool
            // or get error tool.
            Row(children: List.generate(100, (index) => Text('hello world'))),
          ],
        ),
      ),
    );
  }
}

// MCP Tools management section
class _MCPToolsSection extends StatelessWidget {
  const _MCPToolsSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'MCP Tool Management',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _DynamicToolRegistration(),
          ],
        ),
      ),
    );
  }
}

// Dynamic tool registration widget
class _DynamicToolRegistration extends StatefulWidget {
  const _DynamicToolRegistration();

  @override
  State<_DynamicToolRegistration> createState() =>
      _DynamicToolRegistrationState();
}

class _DynamicToolRegistrationState extends State<_DynamicToolRegistration> {
  int _toolCount = 0;

  Future<void> _registerNewTool() async {
    final binding = MCPToolkitBinding.instance;

    try {
      _toolCount++;
      final toolName = 'dynamic_tool_$_toolCount';

      final dynamicEntry = MCPCallEntry.tool(
        definition: MCPToolDefinition(
          name: toolName,
          description: 'Dynamically registered tool #$_toolCount',
          inputSchema: ObjectSchema(properties: {}),
        ),
        handler: (request) {
          return MCPCallResult(
            message: 'Response from dynamically registered tool #$_toolCount',
            parameters: {
              'toolNumber': _toolCount,
              'registeredAt': DateTime.now().toIso8601String(),
            },
          );
        },
      );

      await binding.addEntries(entries: {dynamicEntry});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully registered tool: $toolName'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register tool: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Register new MCP tools dynamically to demonstrate auto-registration capabilities.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Semantics(
              identifier: 'register_new_tool_button',
              button: true,
              child: ElevatedButton.icon(
                onPressed: _registerNewTool,
                icon: const Icon(Icons.add_circle),
                label: const Text(
                  'Register New Tool',
                  semanticsIdentifier: 'register_new_tool_label',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Semantics(
              container: true,
              identifier: 'dynamic_tool_count',
              label: 'Tools created: $_toolCount',
              liveRegion: true,
              child: ExcludeSemantics(
                child: Text(
                  'Tools created: $_toolCount',
                  semanticsIdentifier: 'dynamic_tool_count_text',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Status and information section
class _StatusSection extends StatelessWidget {
  const _StatusSection();

  @override
  Widget build(BuildContext context) {
    final allEntries = MCPToolkitBinding.instance.allEntries;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dashboard,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'MCP Status Dashboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Connection Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Text(
                    'MCP Toolkit Active',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Registered Entries
            Text(
              'Registered Entries: ${allEntries.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            if (allEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Extensions:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    // Fixed the overflow issue by using proper wrapping
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: allEntries
                          .map(
                            (entry) => Chip(
                              label: Text(
                                entry.key,
                                style: const TextStyle(fontSize: 11),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// MCP Tool Registration Functions
Future<void> _registerInitialMCPTools() async {
  final binding = MCPToolkitBinding.instance;
  await Future.delayed(const Duration(seconds: 1));

  final fibonacciEntry = MCPCallEntry.tool(
    handler: (request) {
      final n = int.tryParse(request['n'] ?? '0') ?? 0;
      final result = _calculateFibonacci(n);
      return MCPCallResult(
        message: 'Calculated Fibonacci number for position $n',
        parameters: {'result': result, 'position': n},
      );
    },
    definition: MCPToolDefinition(
      name: 'calculate_fibonacci',
      description: 'Calculate the nth Fibonacci number',
      inputSchema: ObjectSchema(
        properties: {
          'n': IntegerSchema(
            description: 'The position in the Fibonacci sequence',
            minimum: 0,
            maximum: 100,
          ),
        },
        required: ['n'],
      ),
    ),
  );

  final appStateEntry = MCPCallEntry.resource(
    definition: MCPResourceDefinition(
      name: 'app_state',
      description: 'Current application state and configuration',
      mimeType: 'application/json',
    ),
    handler: (request) {
      return MCPCallResult(
        message: 'Current application state and configuration',
        parameters: {
          'appName': 'MCP Toolkit Demo',
          'isConnected': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    },
  );

  await binding.addEntries(entries: {fibonacciEntry, appStateEntry});
  print('Initial MCP tools and resources registered');
}

Future<void> _registerDelayedMCPTools() async {
  final binding = MCPToolkitBinding.instance;

  final preferencesEntry = MCPCallEntry.tool(
    handler: (request) {
      final category = request['category'] ?? 'all';
      final preferences = _getUserPreferences(category);
      return MCPCallResult(
        message: 'User preferences for category: $category',
        parameters: {'preferences': preferences, 'category': category},
      );
    },
    definition: MCPToolDefinition(
      name: 'get_user_preferences',
      description: 'Get user preferences and settings',
      inputSchema: ObjectSchema(
        properties: {
          'category': Schema.string(
            description:
                'Preference category (theme, notifications, privacy, all)',
          ),
        },
      ),
    ),
  );

  await binding.addEntries(entries: {preferencesEntry});
  print('Delayed MCP tools registered - demonstrating auto-registration');
}

// Helper Functions
int _calculateFibonacci(int n) {
  if (n <= 1) return n;
  int a = 0, b = 1;
  for (int i = 2; i <= n; i++) {
    final temp = a + b;
    a = b;
    b = temp;
  }
  return b;
}

Map<String, dynamic> _getUserPreferences(String category) {
  final allPreferences = {
    'theme': {'mode': 'dark', 'primaryColor': 'deepPurple'},
    'notifications': {'enabled': true, 'sound': true},
    'privacy': {'analytics': false, 'crashReporting': true},
  };

  if (category == 'all') {
    return allPreferences;
  }

  return {category: allPreferences[category] ?? {}};
}
