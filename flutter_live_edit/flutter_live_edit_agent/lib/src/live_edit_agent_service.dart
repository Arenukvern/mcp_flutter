import 'dart:convert';
import 'dart:io';

import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:path/path.dart' as p;
import 'package:xsoulspace_inference_codex_exec/xsoulspace_inference_codex_exec.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

final class LiveEditAgentRegistry {
  LiveEditAgentRegistry({
    required Map<String, InferenceClient> clients,
    String? defaultBackendId,
  }) : _clients = Map<String, InferenceClient>.unmodifiable(clients),
       _defaultBackendId = defaultBackendId ?? clients.keys.first;

  factory LiveEditAgentRegistry.withDefaults() {
    final codexClient = CodexExecInferenceClient();
    return LiveEditAgentRegistry(
      clients: <String, InferenceClient>{'codex_exec': codexClient},
      defaultBackendId: 'codex_exec',
    );
  }

  final Map<String, InferenceClient> _clients;
  final String _defaultBackendId;
  final Map<String, String> _sessionBackendIds = <String, String>{};

  List<LiveEditAgentBackend> listBackends() => _clients.entries
      .map(
        (final entry) => LiveEditAgentBackend(
          id: entry.key,
          label: entry.key,
          description: 'Inference backend `${entry.key}`',
          available: entry.value.isAvailable,
          isDefault: entry.key == _defaultBackendId,
          meta: <String, Object?>{'clientId': entry.value.id},
        ),
      )
      .toList(growable: false);

  LiveEditAgentBackend getBackend({
    final String? backendId,
    final String? sessionId,
  }) {
    final resolvedId = resolveBackendId(
      backendId: backendId,
      sessionId: sessionId,
    );
    return listBackends().firstWhere(
      (final backend) => backend.id == resolvedId,
    );
  }

  String resolveBackendId({final String? backendId, final String? sessionId}) {
    final requested = backendId?.trim();
    if (requested != null && requested.isNotEmpty) {
      if (!_clients.containsKey(requested)) {
        throw StateError('Unknown live edit backend: $requested');
      }
      return requested;
    }
    if (sessionId != null && _sessionBackendIds.containsKey(sessionId)) {
      return _sessionBackendIds[sessionId]!;
    }
    return _defaultBackendId;
  }

  void setSessionBackend({
    required final String sessionId,
    required final String backendId,
  }) {
    if (!_clients.containsKey(backendId)) {
      throw StateError('Unknown live edit backend: $backendId');
    }
    _sessionBackendIds[sessionId] = backendId;
  }

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
}

final class LiveEditAgentService {
  LiveEditAgentService({LiveEditAgentRegistry? registry})
    : registry = registry ?? LiveEditAgentRegistry.withDefaults();

  final LiveEditAgentRegistry registry;
  final Map<String, LiveEditResolutionProposal> _proposals =
      <String, LiveEditResolutionProposal>{};
  final Map<String, LiveEditResolutionRequest> _requests =
      <String, LiveEditResolutionRequest>{};
  final Map<String, LiveEditResolutionStatus> _proposalStatus =
      <String, LiveEditResolutionStatus>{};

  List<LiveEditAgentBackend> listBackends() => registry.listBackends();

  LiveEditAgentBackend getBackend({
    final String? backendId,
    final String? sessionId,
  }) => registry.getBackend(backendId: backendId, sessionId: sessionId);

  void setSessionBackend({
    required final String sessionId,
    required final String backendId,
  }) {
    registry.setSessionBackend(sessionId: sessionId, backendId: backendId);
  }

  Future<LiveEditResolutionProposal> resolve(
    final LiveEditResolutionRequest request,
  ) async {
    final backendId = registry.resolveBackendId(
      backendId: request.backendId,
      sessionId: request.sessionId,
    );
    final client = registry.clientFor(
      backendId: request.backendId,
      sessionId: request.sessionId,
    );

    final inferenceRequest = InferenceRequest(
      prompt: _buildPrompt(request: request, backendId: backendId),
      outputSchema: LiveEditSchemas.resolutionProposal,
      workingDirectory: request.workingDirectory,
      metadata: <String, dynamic>{
        'sessionId': request.sessionId,
        'backendId': backendId,
        'draftChangeCount': request.draftChanges.length,
      },
    );

    final inferenceResult = await client.infer(inferenceRequest);
    if (!inferenceResult.success || inferenceResult.data == null) {
      throw StateError(
        '${inferenceResult.error?.code ?? 'inference_failed'}: '
        '${inferenceResult.error?.message ?? 'Inference failed'}',
      );
    }

    final rawOutput = Map<String, Object?>.from(inferenceResult.data!.output);
    final response = inferenceResult.data!;
    final proposal = LiveEditResolutionProposal.fromJson(rawOutput).copyWith(
      backendId: backendId,
      meta: <String, Object?>{
        ..._normalizeMap(rawOutput['meta']),
        ...response.meta,
        'inferenceMeta': inferenceResult.meta,
        'warnings': <String>[...response.warnings, ...inferenceResult.warnings],
      },
    );
    _proposals[proposal.proposalId] = proposal;
    _requests[proposal.proposalId] = request;
    _proposalStatus[proposal.proposalId] = LiveEditResolutionStatus.proposed;
    return proposal;
  }

  LiveEditResolutionProposal getProposal(final String proposalId) {
    final proposal = _proposals[proposalId];
    if (proposal == null) {
      throw StateError('Unknown live edit proposal: $proposalId');
    }
    return proposal;
  }

  LiveEditResolutionResult rejectProposal(final String proposalId) {
    getProposal(proposalId);
    _proposalStatus[proposalId] = LiveEditResolutionStatus.rejected;
    return LiveEditResolutionResult(
      proposalId: proposalId,
      status: LiveEditResolutionStatus.rejected,
    );
  }

  Future<LiveEditResolutionResult> applyProposal(
    final String proposalId, {
    required final String workingDirectory,
  }) async {
    final proposal = getProposal(proposalId);
    final changedFiles = <String>[];

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
    return LiveEditResolutionResult(
      proposalId: proposalId,
      status: LiveEditResolutionStatus.applied,
      changedFiles: changedFiles,
      validation: <String, Object?>{'writeCount': changedFiles.length},
      warnings: proposal.warnings,
    );
  }

  LiveEditResolutionStatus proposalStatus(final String proposalId) =>
      _proposalStatus[proposalId] ?? LiveEditResolutionStatus.proposed;

  LiveEditResolutionRequest? requestForProposal(final String proposalId) =>
      _requests[proposalId];

  String _buildPrompt({
    required final LiveEditResolutionRequest request,
    required final String backendId,
  }) {
    final requestJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(request.toJson());
    return '''
You are resolving a Flutter live edit draft into real source changes inside a Dart/Flutter workspace.

Return JSON only and make it match the provided schema exactly.

Rules:
- Respect existing app abstractions, theme usage, and state management.
- Prefer minimal edits that implement the draft intent.
- Produce complete replacement contents for every changed file under filePatches[].content.
- Always include a readable unified patch summary in patch.
- If a request is ambiguous or risky, keep filePatches empty and explain it in warnings/riskFlags.
- Do not invent unsupported backends or tooling assumptions.

Active backend: $backendId

Resolution request:
$requestJson
''';
  }
}

extension on LiveEditResolutionProposal {
  LiveEditResolutionProposal copyWith({
    final String? proposalId,
    final String? backendId,
    final String? summary,
    final String? patch,
    final List<String>? changedFiles,
    final List<LiveEditFilePatch>? filePatches,
    final List<String>? expectedRuntimeEffects,
    final List<String>? validationSteps,
    final List<String>? warnings,
    final List<String>? riskFlags,
    final Map<String, Object?>? meta,
  }) => LiveEditResolutionProposal(
    proposalId: proposalId ?? this.proposalId,
    backendId: backendId ?? this.backendId,
    summary: summary ?? this.summary,
    patch: patch ?? this.patch,
    changedFiles: changedFiles ?? this.changedFiles,
    filePatches: filePatches ?? this.filePatches,
    expectedRuntimeEffects:
        expectedRuntimeEffects ?? this.expectedRuntimeEffects,
    validationSteps: validationSteps ?? this.validationSteps,
    warnings: warnings ?? this.warnings,
    riskFlags: riskFlags ?? this.riskFlags,
    meta: meta ?? this.meta,
  );
}

Map<String, Object?> _normalizeMap(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((final key, final nestedValue) {
      return MapEntry('$key', nestedValue);
    });
  }
  return const <String, Object?>{};
}
