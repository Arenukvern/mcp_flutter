import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

import '../../ai/agent/live_edit_agent_service.dart';
import '../../models/models.dart';
import '../../types/live_edit_types.dart';
import 'flutter_live_edit_auto_host_config.dart';

part 'flutter_live_edit_auto_host_delegate_helpers.dart';

final class FlutterLiveEditAutoDelegate {
  FlutterLiveEditAutoDelegate({
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
          if ((request.instructionText ?? '').trim().isNotEmpty)
            'Intent: ${request.instructionText!.trim()}',
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
