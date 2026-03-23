import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:path/path.dart' as p;
import 'package:xsoulspace_inference_codex_exec/xsoulspace_inference_codex_exec.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';
import 'package:xsoulspace_inference_cursor_agent/xsoulspace_inference_cursor_agent.dart';

import '../../models/models.dart';
import '../../ui_selectors/ui_selectors.dart';
import 'live_edit_agent_plan.dart';
import 'live_edit_agent_request_summary.dart';
import 'live_edit_agent_utils.dart';
import 'live_edit_agent_validation.dart';

Map<String, Object?> _mergeErrorDetails(
  final Object? details, {
  required final LiveEditResolutionRequest request,
  required final String backendId,
}) {
  final merged = <String, Object?>{
    'requestSummary': resolutionRequestSummary(request, backendId: backendId),
    'request': request.toJson(),
  };
  if (details is Map) {
    merged.addAll(jsonDecodeMapLoose(details));
    return merged;
  }
  if (details != null) merged['rawDetails'] = details;
  return merged;
}

final class LiveEditAgentException implements Exception {
  const LiveEditAgentException({
    required this.code,
    required this.message,
    this.details,
    this.warnings = const <String>[],
    this.meta = const <String, Object?>{},
  });

  final String code;
  final String message;
  final Object? details;
  final List<String> warnings;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    if (details != null) 'details': details,
    if (warnings.isNotEmpty) 'warnings': warnings,
    if (meta.isNotEmpty) 'meta': meta,
  };

  @override
  String toString() => '$code: $message';
}

final class LiveEditAgentRegistry {
  LiveEditAgentRegistry({
    required final Map<String, InferenceClient> clients,
    final String? defaultBackendId,
  }) : _clients = Map<String, InferenceClient>.unmodifiable(clients),
       _defaultBackendId = _resolveDefaultBackendId(
         clients: clients,
         requestedBackendId: defaultBackendId,
       );

  factory LiveEditAgentRegistry.withDefaults() {
    final codexClient = CodexExecInferenceClient(
      defaultModel: 'gpt-5.3-codex',
      defaultReasoningEffort: 'medium',
      executionTimeout: const Duration(minutes: 6),
      maxTimeoutRetries: 0,
    );
    final cursorClient = CursorAgentInferenceClient(
      defaultModel: 'auto',
      executionTimeout: const Duration(minutes: 6),
      maxTimeoutRetries: 0,
    );
    return LiveEditAgentRegistry(
      clients: <String, InferenceClient>{
        'codex_exec': codexClient,
        'cursor_agent': cursorClient,
      },
      defaultBackendId: Platform.environment['LIVE_EDIT_BACKEND'],
    );
  }

  final Map<String, InferenceClient> _clients;
  final String _defaultBackendId;
  final Map<String, _LiveEditAgentSessionState> _sessionStates =
      <String, _LiveEditAgentSessionState>{};

  InferenceClient clientFor({
    final String? backendId,
    final String? sessionId,
  }) {
    final resolvedId = resolveBackendId(
      backendId: backendId,
      sessionId: sessionId,
    );
    return _clients[resolvedId]!;
  }

  LiveEditAgentBackend getBackend({
    final String? backendId,
    final String? sessionId,
  }) {
    final resolvedId = resolveBackendId(
      backendId: backendId,
      sessionId: sessionId,
    );
    return _buildBackend(
      backendId: resolvedId,
      client: _clients[resolvedId]!,
      sessionId: sessionId,
    );
  }

  List<LiveEditAgentBackend> listBackends() => _clients.entries
      .map(
        (final entry) =>
            _buildBackend(backendId: entry.key, client: entry.value),
      )
      .toList(growable: false);

  String resolveBackendId({final String? backendId, final String? sessionId}) {
    final requested = backendId?.trim();
    if (requested != null && requested.isNotEmpty) {
      if (!_clients.containsKey(requested)) {
        throw StateError('Unknown live edit backend: $requested');
      }
      return requested;
    }
    if (sessionId != null && _sessionStates.containsKey(sessionId)) {
      return _sessionStates[sessionId]!.backendId;
    }
    return _defaultBackendId;
  }

  LiveEditInferenceConfig? resolveInferenceConfig({
    final String? backendId,
    final String? sessionId,
    final LiveEditInferenceConfig? requestInferenceConfig,
  }) {
    final resolvedBackendId = resolveBackendId(
      backendId: backendId,
      sessionId: sessionId,
    );
    final normalizedRequest = LiveEditCodexOptions.normalizeConfig(
      requestInferenceConfig,
    );
    if (normalizedRequest != null) {
      return normalizedRequest;
    }
    final sessionConfig = sessionId == null
        ? null
        : LiveEditCodexOptions.normalizeConfig(
            _sessionStates[sessionId]?.inferenceConfig,
          );
    if (sessionConfig != null) {
      return sessionConfig;
    }
    final client = _clients[resolvedBackendId];
    return switch (client) {
      CodexExecInferenceClient(
        :final defaultModel,
        :final defaultReasoningEffort,
      ) =>
        LiveEditCodexOptions.normalizeConfig(
          LiveEditInferenceConfig(
            model: defaultModel,
            reasoningEffort: defaultReasoningEffort,
          ),
        ),
      CursorAgentInferenceClient(
        :final defaultModel,
        :final defaultReasoningEffort,
      ) =>
        LiveEditCodexOptions.normalizeConfig(
          LiveEditInferenceConfig(
            model: defaultModel,
            reasoningEffort: defaultReasoningEffort,
          ),
        ),
      _ => null,
    };
  }

  void setSessionBackend({
    required final String sessionId,
    required final String backendId,
    final LiveEditInferenceConfig? inferenceConfig,
  }) {
    if (!_clients.containsKey(backendId)) {
      throw StateError('Unknown live edit backend: $backendId');
    }
    final normalized = LiveEditCodexOptions.normalizeConfig(inferenceConfig);
    _sessionStates[sessionId] = _LiveEditAgentSessionState(
      backendId: backendId,
      inferenceConfig: normalized,
    );
  }

  LiveEditAgentBackend _buildBackend({
    required final String backendId,
    required final InferenceClient client,
    final String? sessionId,
  }) {
    final defaultConfig =
        resolveInferenceConfig(backendId: backendId) ??
        const LiveEditInferenceConfig();
    final meta = <String, Object?>{
      'displayLabel': _backendLabel(backendId),
      'backendId': backendId,
      'clientId': client.id,
      'binaryName': _binaryName(client),
      'defaultInferenceConfig': defaultConfig.toJson(),
      if (sessionId != null)
        'effectiveInferenceConfig':
            (resolveInferenceConfig(
                      backendId: backendId,
                      sessionId: sessionId,
                    ) ??
                    const LiveEditInferenceConfig())
                .toJson(),
    };
    if (backendId == 'codex_exec') {
      meta['supportedModels'] = LiveEditCodexOptions.supportedModels
          .map((final model) => model.toJson())
          .toList(growable: false);
      meta['supportedReasoningEfforts'] =
          LiveEditCodexOptions.supportedReasoningEfforts;
    }
    return LiveEditAgentBackend(
      id: backendId,
      label: _backendLabel(backendId),
      description: _backendDescription(backendId),
      available: client.isAvailable,
      isDefault: backendId == _defaultBackendId,
      meta: meta,
    );
  }

  static String _backendDescription(final String backendId) =>
      switch (backendId) {
        'codex_exec' => 'OpenAI Codex CLI backend using `codex exec`.',
        'cursor_agent' =>
          'Cursor Agent CLI backend using `cursor-agent --print`.',
        _ => 'Inference backend `$backendId`.',
      };

  static String _backendLabel(final String backendId) => switch (backendId) {
    'codex_exec' => 'Codex',
    'cursor_agent' => 'Cursor',
    _ => backendId,
  };

  static String? _binaryName(final InferenceClient client) => switch (client) {
    CodexExecInferenceClient(:final binaryName) => binaryName,
    CursorAgentInferenceClient(:final binaryName) => binaryName,
    _ => null,
  };

  static String _resolveDefaultBackendId({
    required final Map<String, InferenceClient> clients,
    required final String? requestedBackendId,
  }) {
    final requested = requestedBackendId?.trim();
    if (requested != null &&
        requested.isNotEmpty &&
        clients.containsKey(requested)) {
      return requested;
    }
    return clients.keys.first;
  }
}

final class LiveEditAgentService {
  LiveEditAgentService({
    final LiveEditAgentRegistry? registry,
    final String? storagePath,
  }) : registry = registry ?? LiveEditAgentRegistry.withDefaults(),
       _storagePath =
           storagePath ??
           p.join(Directory.systemTemp.path, 'flutter_live_edit_agent');

  final LiveEditAgentRegistry registry;
  final String _storagePath;
  final Map<String, LiveEditResolutionProposal> _proposals =
      <String, LiveEditResolutionProposal>{};
  final Map<String, LiveEditResolutionRequest> _requests =
      <String, LiveEditResolutionRequest>{};
  final Map<String, LiveEditResolutionStatus> _proposalStatus =
      <String, LiveEditResolutionStatus>{};

  Future<LiveEditResolutionResult> applyProposal(
    final String proposalId, {
    required final String workingDirectory,
  }) async {
    final proposal = getProposal(proposalId);
    final changedFiles = <String>[];

    if (proposal.filePatches.isEmpty) {
      final directResult = LiveEditDirectApplyResult.fromJson(proposal.meta);
      _proposalStatus[proposalId] = LiveEditResolutionStatus.applied;
      _persistProposalState(proposalId);
      return LiveEditResolutionResult(
        proposalId: proposalId,
        status: LiveEditResolutionStatus.applied,
        changedFiles: directResult.changedFiles,
        validation: <String, Object?>{
          'writeCount': directResult.changedFiles.length,
        },
        warnings: directResult.warnings,
        meta: directResult.meta,
      );
    }

    for (final filePatch in proposal.filePatches) {
      final targetPath = p.isAbsolute(filePatch.path)
          ? filePatch.path
          : p.normalize(p.join(workingDirectory, filePatch.path));
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsString(filePatch.content);
      changedFiles.add(targetPath);
    }

    _proposalStatus[proposalId] = LiveEditResolutionStatus.applied;
    _persistProposalState(proposalId);
    return LiveEditResolutionResult(
      proposalId: proposalId,
      status: LiveEditResolutionStatus.applied,
      changedFiles: changedFiles,
      validation: <String, Object?>{'writeCount': changedFiles.length},
      warnings: proposal.warnings,
    );
  }

  LiveEditExecutionPlan buildExecutionPlan(final String proposalId) {
    final proposal = getProposal(proposalId);
    final request = requestForProposal(proposalId);
    final selection = request?.effectivePrimarySelection;
    final requestedChanges = executionRequestedChanges(request, selection);
    final riskNotes = <String>{
      ...proposal.riskFlags,
      ...proposal.warnings,
    }.where(hasText).toList(growable: false);

    return LiveEditExecutionPlan(
      proposalId: proposal.proposalId,
      title: 'Apply this bubble change',
      summary: proposal.summary,
      selectedNode: selectedNodeLabel(selection),
      requestedChanges: requestedChanges,
      affectedFiles: proposal.changedFiles,
      confidence: planConfidence(proposal, request),
      riskNotes: riskNotes,
      agentInstruction: agentInstruction(proposal, request),
      meta: <String, Object?>{
        'backendId': proposal.backendId,
        'validationSteps': proposal.validationSteps,
      },
    );
  }

  LiveEditExecutionPlan buildExecutionPlanForExecution({
    required final LiveEditResolutionRequest request,
    required final LiveEditDirectApplyResult execution,
  }) {
    final selection = request.effectivePrimarySelection;
    return LiveEditExecutionPlan(
      proposalId: execution.executionId,
      title: 'Apply this bubble change',
      summary: execution.summary,
      selectedNode: selectedNodeLabel(selection),
      requestedChanges: executionRequestedChanges(request, selection),
      affectedFiles: execution.changedFiles,
      confidence: execution.changedFiles.isEmpty ? 0.4 : 0.85,
      riskNotes: execution.warnings,
      agentInstruction: execution.summary,
      meta: <String, Object?>{
        'backendId': execution.backendId,
        'validationSteps': execution.validationSteps,
      },
    );
  }

  LiveEditAgentBackend getBackend({
    final String? backendId,
    final String? sessionId,
  }) => registry.getBackend(backendId: backendId, sessionId: sessionId);

  LiveEditResolutionProposal getProposal(final String proposalId) {
    _hydrateProposalState(proposalId);
    final proposal = _proposals[proposalId];
    if (proposal == null) {
      throw StateError('Unknown live edit proposal: $proposalId');
    }
    return proposal;
  }

  List<LiveEditAgentBackend> listBackends() => registry.listBackends();

  LiveEditResolutionStatus proposalStatus(final String proposalId) {
    _hydrateProposalState(proposalId);
    return _proposalStatus[proposalId] ?? LiveEditResolutionStatus.proposed;
  }

  LiveEditResolutionResult rejectProposal(final String proposalId) {
    getProposal(proposalId);
    _proposalStatus[proposalId] = LiveEditResolutionStatus.rejected;
    _persistProposalState(proposalId);
    return LiveEditResolutionResult(
      proposalId: proposalId,
      status: LiveEditResolutionStatus.rejected,
    );
  }

  LiveEditResolutionRequest? requestForProposal(final String proposalId) {
    _hydrateProposalState(proposalId);
    return _requests[proposalId];
  }

  String buildResolvedPrompt(final LiveEditResolutionRequest request) {
    final resolved = _resolveRequestContext(request);
    return buildPrompt(request: resolved.$1, backendId: resolved.$2);
  }

  Future<LiveEditDirectApplyResult> executeDirectApply(
    final LiveEditResolutionRequest request, {
    final void Function(InferenceStructuredTextStreamEvent event)?
    onStreamEvent,
  }) async {
    final resolved = _resolveRequestContext(request);
    final resolvedRequest = resolved.$1;
    final backendId = resolved.$2;
    final effectiveInferenceConfig = resolved.$3;
    final client = registry.clientFor(
      backendId: request.backendId,
      sessionId: request.sessionId,
    );
    final requestSummary = resolutionRequestSummary(
      resolvedRequest,
      backendId: backendId,
    );
    final prompt = buildPrompt(request: resolvedRequest, backendId: backendId);
    final metadata = <String, dynamic>{
      ...requestSummary,
      'promptBytes': utf8.encode(prompt).length,
      if (effectiveInferenceConfig?.model != null)
        'inferenceModel': effectiveInferenceConfig!.model,
      if (effectiveInferenceConfig?.reasoningEffort != null)
        'inferenceReasoningEffort': effectiveInferenceConfig!.reasoningEffort,
    };
    if (backendId == 'codex_exec') {
      if (effectiveInferenceConfig?.model != null) {
        metadata['codexExecModel'] = effectiveInferenceConfig!.model;
      }
      if (effectiveInferenceConfig?.reasoningEffort != null) {
        metadata['codexExecReasoningEffort'] =
            effectiveInferenceConfig!.reasoningEffort;
      }
    }
    final inferenceRequest = InferenceRequest(
      prompt: prompt,
      outputSchema: LiveEditSchemas.directApplyExecution,
      workingDirectory: resolvedRequest.workingDirectory,
      metadata: metadata,
    );

    final inferenceResult = client.supportsStructuredTextStreaming
        ? await _resolveViaStreamingClient(
            client: client,
            request: inferenceRequest,
            onStreamEvent: onStreamEvent,
          )
        : await client.infer(inferenceRequest);
    if (!inferenceResult.success || inferenceResult.data == null) {
      throw LiveEditAgentException(
        code: inferenceResult.error?.code ?? 'inference_failed',
        message: inferenceResult.error?.message ?? 'Inference failed',
        details: _mergeErrorDetails(
          inferenceResult.error?.details,
          request: resolvedRequest,
          backendId: backendId,
        ),
        warnings: inferenceResult.warnings,
        meta: jsonDecodeMapLoose(inferenceResult.meta),
      );
    }

    final rawOutput = Map<String, Object?>.from(inferenceResult.data!.output);
    final response = inferenceResult.data;
    final normalizedOutput = <String, Object?>{
      ...rawOutput,
      'executionId':
          jsonDecodeString(rawOutput['executionId']).trim().isNotEmpty
          ? rawOutput['executionId']
          : rawOutput['proposalId'] ?? _generatedExecutionId(backendId),
      'backendId': backendId,
    };
    return LiveEditDirectApplyResult.fromJson(normalizedOutput).copyWith(
      executionId:
          jsonDecodeString(normalizedOutput['executionId']).trim().isNotEmpty
          ? '${normalizedOutput['executionId']}'
          : _generatedExecutionId(backendId),
      backendId: backendId,
      meta: <String, Object?>{
        ...jsonDecodeMapLoose(rawOutput['meta']),
        ...response?.meta ?? <String, Object?>{},
        'inferenceMeta': inferenceResult.meta,
        'warnings': <String>[
          ...response?.warnings ?? <String>[],
          ...inferenceResult.warnings,
        ],
      },
      warnings: <String>[
        ...response?.warnings ?? <String>[],
        ...inferenceResult.warnings,
        ...switch (rawOutput['warnings']) {
          final List warnings =>
            warnings
                .map((final warning) => '$warning')
                .where((final warning) => warning.isNotEmpty),
          _ => const <String>[],
        },
      ],
    );
  }

  Future<LiveEditResolutionProposal> resolve(
    final LiveEditResolutionRequest request, {
    final void Function(InferenceStructuredTextStreamEvent event)?
    onStreamEvent,
  }) async {
    final resolved = _resolveRequestContext(request);
    final resolvedRequest = resolved.$1;
    final execution = await executeDirectApply(
      resolvedRequest,
      onStreamEvent: onStreamEvent,
    );
    final proposal = LiveEditResolutionProposal(
      proposalId: execution.executionId,
      backendId: execution.backendId,
      summary: execution.summary,
      patch: '',
      changedFiles: execution.changedFiles,
      filePatches: const <LiveEditFilePatch>[],
      expectedRuntimeEffects: const <String>[],
      validationSteps: execution.validationSteps,
      warnings: execution.warnings,
      meta: execution.toJson(),
    );
    _proposals[proposal.proposalId] = proposal;
    _requests[proposal.proposalId] = resolvedRequest;
    _proposalStatus[proposal.proposalId] = LiveEditResolutionStatus.applied;
    _persistProposalState(proposal.proposalId);
    return proposal;
  }

  void setSessionBackend({
    required final String sessionId,
    required final String backendId,
    final LiveEditInferenceConfig? inferenceConfig,
  }) {
    registry.setSessionBackend(
      sessionId: sessionId,
      backendId: backendId,
      inferenceConfig: inferenceConfig,
    );
  }

  (LiveEditResolutionRequest, String, LiveEditInferenceConfig?)
  _resolveRequestContext(final LiveEditResolutionRequest request) {
    final requestValidationError = validateResolutionRequest(request);
    jsonDecodeString(requestValidationError).trim().onNotEmpty((final message) {
      throw LiveEditAgentException(
        code: 'source_context_unavailable',
        message: message,
        details: request.toJson(),
      );
    });
    final backendId = registry.resolveBackendId(
      backendId: request.backendId,
      sessionId: request.sessionId,
    );
    final effectiveInferenceConfig = registry.resolveInferenceConfig(
      backendId: backendId,
      sessionId: request.sessionId,
      requestInferenceConfig: request.inferenceConfig,
    );
    return (
      request.copyWith(
        backendId: backendId,
        inferenceConfig: effectiveInferenceConfig,
      ),
      backendId,
      effectiveInferenceConfig,
    );
  }

  String _generatedExecutionId(final String backendId) =>
      'live_edit_${DateTime.now().millisecondsSinceEpoch}_$backendId';

  void _hydrateProposalState(final String proposalId) {
    if (_proposals.containsKey(proposalId) &&
        _requests.containsKey(proposalId)) {
      return;
    }

    final proposalFile = File(_proposalFilePath(proposalId));
    if (!proposalFile.existsSync()) {
      return;
    }

    try {
      final raw = proposalFile.readAsStringSync();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }

      final json = jsonDecodeMapLoose(decoded);
      final proposalJson = jsonDecodeMapLoose(json['proposal']);
      final requestJson = jsonDecodeMapLoose(json['request']);
      if (proposalJson.isEmpty || requestJson.isEmpty) {
        return;
      }

      _proposals[proposalId] = LiveEditResolutionProposal.fromJson(
        proposalJson,
      );
      _requests[proposalId] = LiveEditResolutionRequest.fromJson(requestJson);
      _proposalStatus[proposalId] = LiveEditResolutionStatus.fromWire(
        json['status'],
      );
    } on FileSystemException {
      // Best-effort cache hydration.
    } on FormatException {
      // Ignore corrupted cache entries.
    }
  }

  void _persistProposalState(final String proposalId) {
    final proposal = _proposals[proposalId];
    final request = _requests[proposalId];
    if (proposal == null || request == null) {
      return;
    }

    try {
      Directory(_storagePath).createSync(recursive: true);
      final payload = <String, Object?>{
        'proposal': proposal.toJson(),
        'request': request.toJson(),
        'status': proposalStatus(proposalId).wireName,
      };
      File(
        _proposalFilePath(proposalId),
      ).writeAsStringSync(jsonEncode(payload));
    } on FileSystemException {
      // Best-effort: in-process flow can still continue.
    }
  }

  String _proposalFilePath(final String proposalId) {
    final encodedId = base64Url.encode(utf8.encode(proposalId));
    return p.join(_storagePath, '$encodedId.json');
  }

  Future<InferenceResult<InferenceResponse>> _resolveViaStreamingClient({
    required final InferenceClient client,
    required final InferenceRequest request,
    final void Function(InferenceStructuredTextStreamEvent event)?
    onStreamEvent,
  }) async {
    final streamDone = Completer<void>();
    final session = await client.streamStructuredText(request);
    final subscription = session.events.listen(
      (final event) {
        onStreamEvent?.call(event);
      },
      onDone: () {
        if (!streamDone.isCompleted) {
          streamDone.complete();
        }
      },
    );
    try {
      final result = await session.result;
      await streamDone.future.timeout(
        const Duration(milliseconds: 100),
        onTimeout: () {},
      );
      return result;
    } finally {
      await subscription.cancel();
      await session.dispose();
    }
  }
}

final class _LiveEditAgentSessionState {
  const _LiveEditAgentSessionState({
    required this.backendId,
    this.inferenceConfig,
  });

  final String backendId;
  final LiveEditInferenceConfig? inferenceConfig;
}

extension on LiveEditDirectApplyResult {
  LiveEditDirectApplyResult copyWith({
    final String? executionId,
    final String? backendId,
    final String? summary,
    final List<String>? changedFiles,
    final List<String>? warnings,
    final List<String>? validationSteps,
    final LiveEditRuntimeRefreshResult? runtimeRefresh,
    final Map<String, Object?>? meta,
  }) => LiveEditDirectApplyResult(
    executionId: executionId ?? this.executionId,
    backendId: backendId ?? this.backendId,
    summary: summary ?? this.summary,
    changedFiles: changedFiles ?? this.changedFiles,
    warnings: warnings ?? this.warnings,
    validationSteps: validationSteps ?? this.validationSteps,
    runtimeRefresh: runtimeRefresh ?? this.runtimeRefresh,
    meta: meta ?? this.meta,
  );
}
