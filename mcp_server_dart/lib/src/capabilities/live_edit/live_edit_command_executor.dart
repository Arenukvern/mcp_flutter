// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:io';

import 'package:flutter_inspector_mcp_server/src/capabilities/live_edit/live_edit_host_bindings.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/shared_core.dart';
import 'package:flutter_live_edit_toolkit/src/ai/agent/live_edit_agent_service.dart';
import 'package:flutter_live_edit_toolkit/src/models/live_edit_models.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:live_edit_tooling_ui_kit/src/models/models.dart';

bool hasText(final String? value) => value != null && value.trim().isNotEmpty;

/// Executes [LiveEditCommand]s using the host for VM / hot reload / client tools.
final class LiveEditCommandExecutor {
  LiveEditCommandExecutor({
    required final LiveEditHostBindings host,
    final LiveEditAgentService? agentService,
  }) : _host = host,
       _agent = agentService ?? LiveEditAgentService();

  final LiveEditHostBindings _host;
  final LiveEditAgentService _agent;
  final Map<String, String> _sessionModes = <String, String>{};

  Future<CoreResult> execute(final LiveEditCommand command) =>
      switch (command) {
        final LiveEditStartSessionCommand c => _liveEditStartSession(c),
        final LiveEditPrepareSessionCommand c => _liveEditPrepareSession(c),
        final LiveEditSetOverlayCommand c => _liveEditSetOverlay(c),
        final LiveEditGetTreeCommand c => _liveEditGetTree(c),
        final LiveEditSelectAtPointCommand c => _liveEditSelectAtPoint(c),
        final LiveEditGetSelectionCommand c => _liveEditGetSelection(c),
        final LiveEditGetCapabilitiesCommand c => _liveEditGetCapabilities(c),
        final LiveEditGetSelectionCandidatesCommand c =>
          _liveEditGetSelectionCandidates(c),
        final LiveEditSetActiveSelectionCommand c =>
          _liveEditSetActiveSelection(c),
        final LiveEditGetPropertyPanelCommand c => _liveEditGetPropertyPanel(c),
        final LiveEditSetEditModeCommand c => _liveEditSetEditMode(c),
        final LiveEditGetPreviewStateCommand c => _liveEditGetPreviewState(c),
        final LiveEditUpdateDraftCommand c => _liveEditUpdateDraft(c),
        final LiveEditGetDraftCommand c => _liveEditGetDraft(c),
        final LiveEditDiscardDraftCommand c => _liveEditDiscardDraft(c),
        final LiveEditEndSessionCommand c => _liveEditEndSession(c),
        LiveEditListAgentBackendsCommand() => _liveEditListAgentBackends(),
        final LiveEditGetAgentBackendCommand c => _liveEditGetAgentBackend(c),
        final LiveEditSetAgentBackendCommand c => _liveEditSetAgentBackend(c),
        final LiveEditResolveDraftCommand c => _liveEditResolveDraft(c),
        final LiveEditApplyDraftCommand c => _liveEditApplyDraft(c),
        final LiveEditAcceptResolutionCommand c => _liveEditAcceptResolution(c),
        final LiveEditRejectResolutionCommand c => _liveEditRejectResolution(c),
      };

  String? _firstNonEmpty(final String? first, final String? second) =>
      _stringOrNull(first) ?? _stringOrNull(second);

  String? _stringOrNull(final Object? value) {
    final normalized = '$value'.trim();
    if (value == null || normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
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

  Future<CoreResult> _ensureLiveEditSessionId(final String? sessionId) async {
    if (hasText(sessionId)) {
      return CoreResult.success(
        data: <String, Object?>{'sessionId': sessionId!.trim()},
      );
    }
    return _liveEditStartSession(const LiveEditStartSessionCommand());
  }

  Future<CoreResult> _liveEditAcceptResolution(
    final LiveEditAcceptResolutionCommand command,
  ) async {
    final request = _agent.requestForProposal(command.proposalId);
    if (request == null) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditProposalNotFound,
        message: 'Unknown live edit proposal: ${command.proposalId}',
      );
    }

    final proposal = _agent.getProposal(command.proposalId);
    final workingDirectory = _resolveWorkingDirectory(
      command.workingDirectory ?? request.workingDirectory,
    );

    LiveEditResolutionResult applyResult;
    try {
      applyResult = await _agent.applyProposal(
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
    if (hasText(discardSessionId)) {
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

    final hotReloadResult = await _host.hotReload(force: true);
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

    if (!hasText(proposalId)) {
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

    if (!hasText(proposalId)) {
      return CoreResult.failure(
        code: CoreErrorCode.liveEditProposalNotFound,
        message: 'Live edit proposal id is unavailable for apply flow',
      );
    }

    LiveEditExecutionPlan executionPlan;
    try {
      executionPlan = _agent.buildExecutionPlan(proposalId!);
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
      if (hasText(command.sessionId)) 'sessionId': command.sessionId,
    },
  );

  Future<CoreResult> _liveEditEndSession(
    final LiveEditEndSessionCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.endSession,
    arguments: <String, Object?>{
      if (hasText(command.sessionId)) 'sessionId': command.sessionId,
    },
  );

  Future<CoreResult> _liveEditGetAgentBackend(
    final LiveEditGetAgentBackendCommand command,
  ) async {
    try {
      final backend = _agent.getBackend(
        backendId: command.backendId,
        sessionId: command.sessionId,
      );
      return CoreResult.success(
        data: <String, Object?>{
          'backend': backend.toJson(),
          if (hasText(command.sessionId)) 'sessionId': command.sessionId,
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
    final backend = _agent.getBackend(sessionId: command.sessionId);
    return CoreResult.success(
      data: <String, Object?>{
        if (hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
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
          if (hasText(command.sessionId)) 'sessionId': command.sessionId,
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
        if (hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
        'mode': _sessionModes[command.sessionId ?? ''] ?? 'inspect',
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
        if (hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
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
      if (hasText(command.sessionId)) 'sessionId': command.sessionId,
      if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
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
        if (hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
        'activeNodeId': selection?.nodeId,
        'candidates': candidates,
      },
    );
  }

  Future<CoreResult> _liveEditGetTree(final LiveEditGetTreeCommand command) =>
      _runLiveEditRuntimeTool(
        LiveEditRuntimeToolNames.getTree,
        arguments: <String, Object?>{
          if (hasText(command.sessionId)) 'sessionId': command.sessionId,
          if (hasText(command.targetDomain))
            'targetDomain': command.targetDomain,
        },
      );

  Future<CoreResult> _liveEditListAgentBackends() async {
    final backends = _agent.listBackends();
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
    if (!hasText(sessionId)) {
      return CoreResult.failure(
        code: CoreErrorCode.unexpectedExecutorError,
        message: 'Live edit session initialization did not return a session id',
      );
    }

    if (hasText(command.backendId) || command.inferenceConfig != null) {
      final backendResult = await _liveEditSetAgentBackend(
        LiveEditSetAgentBackendCommand(
          sessionId: sessionId!,
          backendId:
              command.backendId ?? _agent.getBackend(sessionId: sessionId).id,
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
        if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
        if (hasText(command.workingDirectory))
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
      final result = _agent.rejectProposal(command.proposalId);
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
    if (!hasText(sessionId)) {
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

    final hasIntentText = hasText(command.intentText);
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
    final snapshotResult = await _host.captureUiSnapshotForLiveEdit();

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
      final proposal = await _agent.resolve(request);
      final backend = _agent.getBackend(
        backendId: proposal.backendId,
        sessionId: sessionId,
      );
      return CoreResult.success(
        data: <String, Object?>{
          'sessionId': sessionId,
          if (hasText(command.targetDomain))
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
      if (hasText(command.sessionId)) 'sessionId': command.sessionId,
      'x': command.x,
      'y': command.y,
      if (command.viewId != null) 'viewId': command.viewId,
      'selectionPolicy': command.selectionPolicy.wireName,
      if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
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
    final candidates = jsonDecodeListAs(data['candidates']);
    if (candidates.isEmpty) {
      return CoreResult.success(
        data: <String, Object?>{
          if (hasText(command.sessionId)) 'sessionId': command.sessionId,
          if (hasText(command.targetDomain))
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
        !hasText(requestedNodeId) || requestedNodeId == first['nodeId'];

    return CoreResult.success(
      data: <String, Object?>{
        if (hasText(command.sessionId)) 'sessionId': command.sessionId,
        if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
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
      _agent.setSessionBackend(
        sessionId: command.sessionId,
        backendId: command.backendId,
        inferenceConfig: command.inferenceConfig,
      );
      final backend = _agent.getBackend(
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
    if (!hasText(sessionId)) {
      return CoreResult.failure(
        code: CoreErrorCode.unexpectedExecutorError,
        message: 'Live edit session initialization did not return a session id',
      );
    }

    final normalizedMode = command.mode.trim().isEmpty
        ? 'inspect'
        : command.mode.trim().toLowerCase();
    _sessionModes[sessionId!] = normalizedMode;
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
        if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
      },
    );
  }

  Future<CoreResult> _liveEditSetOverlay(
    final LiveEditSetOverlayCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.setOverlay,
    arguments: <String, Object?>{
      if (hasText(command.sessionId)) 'sessionId': command.sessionId,
      'enabled': command.enabled,
    },
  );

  Future<CoreResult> _liveEditStartSession(
    final LiveEditStartSessionCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.startSession,
    arguments: <String, Object?>{
      if (hasText(command.sessionId)) 'sessionId': command.sessionId,
      if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
    },
  );

  Future<CoreResult> _liveEditUpdateDraft(
    final LiveEditUpdateDraftCommand command,
  ) => _runLiveEditRuntimeTool(
    LiveEditRuntimeToolNames.updateDraft,
    arguments: <String, Object?>{
      if (hasText(command.sessionId)) 'sessionId': command.sessionId,
      if (hasText(command.targetDomain)) 'targetDomain': command.targetDomain,
      'changeJson': encodeLiveEditJson(command.change.toJson()),
    },
  );
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

  Future<Map<String, Object?>> _recoverLiveEditValidationAfterHotRestart({
    required final LiveEditResolutionRequest request,
    required final String? fallbackSessionId,
  }) async {
    final result = <String, Object?>{'attempted': true};

    final hotRestartResult = await _host.hotRestart();
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

    final isolateReady = await _host.waitForFlutterIsolateAfterRestart();
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
    if (hasText(sessionId)) {
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
    if (!hasText(sessionId) || bounds == null) {
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
          if (hasText(reason)) 'reason': reason,
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
    if (hasText(workingDirectory)) {
      return workingDirectory!.trim();
    }
    if (hasText(_host.configuration.flutterProjectDir)) {
      return _host.configuration.flutterProjectDir!.trim();
    }
    return Directory.current.path;
  }

  Future<CoreResult> _runLiveEditRuntimeTool(
    final String toolName, {
    final Map<String, Object?> arguments = const <String, Object?>{},
  }) async {
    final result = await _host.runClientTool(toolName, arguments: arguments);
    if (!result.ok) {
      return result;
    }

    final data = _map(result.data);
    final message = jsonDecodeString(data['message']);
    return CoreResult.success(
      data: _map(data['parameters']),
      meta: <String, Object?>{
        ...result.meta,
        'clientTool': toolName,
        if (message.isNotEmpty) 'clientMessage': message,
      },
    );
  }

  Future<Map<String, Object?>> _validateAppliedLiveEditRequest({
    required final LiveEditResolutionRequest request,
    required final String? fallbackSessionId,
  }) async {
    final sessionId = _firstNonEmpty(fallbackSessionId, request.sessionId);
    if (!hasText(sessionId)) {
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

  Future<bool> _waitForLiveEditRuntimeToolAfterRestart(
    final String toolName, {
    final Duration timeout = const Duration(seconds: 15),
    final Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final toolsResult = await _host.listClientToolsAndResources();
      if (toolsResult.ok) {
        final tools = jsonDecodeListAs(_map(toolsResult.data)['tools']);
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
}
