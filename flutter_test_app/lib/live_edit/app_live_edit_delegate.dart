import 'package:flutter_live_edit_agent/flutter_live_edit_agent.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:test_app/live_edit/app_live_edit_config.dart';
import 'package:test_app/live_edit/app_live_edit_runtime_refresh.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

final class TestAppLiveEditDelegateFactory {
  TestAppLiveEditDelegateFactory({
    required this.config,
    required this.agentService,
    required this.availableBackends,
  });

  final TestAppLiveEditConfig config;
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

  Future<Map<String, Object?>> _applyDefault(
    final LiveEditApplyDraftRequest request,
  ) async {
    final workingDirectory = resolveLiveEditWorkingDirectory(
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
      final runtimeRefresh = await refreshRuntimeAfterApply(request);
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
    final backendLabel = this.backendLabel(backendId);

    switch (event.type) {
      case InferenceStructuredTextStreamEventType.lifecycle:
        final lifecycleState = event.lifecycleState == null
            ? null
            : 'State: ${event.lifecycleState!.name}';
        sink(
          LiveEditRuntimeEvent(
            kind: LiveEditRuntimeEventKind.codex,
            message: event.message ?? '$backendLabel stream lifecycle updated.',
            details: _detailList(<String?>[
              attempt,
              lifecycleState,
              ...metadata,
            ]),
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
            details: _detailList(<String?>[
              event.message,
              attempt,
              ...metadata,
            ]),
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
              textDelta == null ? null : _truncateForActivity(textDelta),
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
                event.message ??
                event.error?.message ??
                '$backendLabel failed.',
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
}

List<String> _detailList(final List<String?> values) {
  return values.whereType<String>().toList(growable: false);
}

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

Map<String, Object?> _optionalEntry(final String key, final Object? value) {
  return value == null
      ? const <String, Object?>{}
      : <String, Object?>{key: value};
}

String _truncateForActivity(final String value, {final int max = 140}) {
  final trimmed = value.trim();
  if (trimmed.length <= max) {
    return trimmed;
  }
  return '${trimmed.substring(0, max)}...';
}
