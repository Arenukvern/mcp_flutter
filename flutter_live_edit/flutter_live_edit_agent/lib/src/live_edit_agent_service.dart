import 'dart:convert';
import 'dart:io';

import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:path/path.dart' as p;
import 'package:xsoulspace_inference_codex_exec/xsoulspace_inference_codex_exec.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

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
    required Map<String, InferenceClient> clients,
    String? defaultBackendId,
  }) : _clients = Map<String, InferenceClient>.unmodifiable(clients),
       _defaultBackendId = defaultBackendId ?? clients.keys.first;

  factory LiveEditAgentRegistry.withDefaults() {
    final codexClient = CodexExecInferenceClient(
      executionTimeout: const Duration(minutes: 6),
      maxTimeoutRetries: 0,
    );
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
  LiveEditAgentService({LiveEditAgentRegistry? registry, String? storagePath})
    : registry = registry ?? LiveEditAgentRegistry.withDefaults(),
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

    final prompt = _buildPrompt(request: request, backendId: backendId);
    final inferenceRequest = InferenceRequest(
      prompt: prompt,
      outputSchema: LiveEditSchemas.resolutionProposal,
      workingDirectory: request.workingDirectory,
      metadata: <String, dynamic>{
        'sessionId': request.sessionId,
        'backendId': backendId,
        'draftChangeCount': request.draftChanges.length,
        'promptBytes': utf8.encode(prompt).length,
      },
    );

    final inferenceResult = await client.infer(inferenceRequest);
    if (!inferenceResult.success || inferenceResult.data == null) {
      throw LiveEditAgentException(
        code: inferenceResult.error?.code ?? 'inference_failed',
        message: inferenceResult.error?.message ?? 'Inference failed',
        details: inferenceResult.error?.details,
        warnings: inferenceResult.warnings,
        meta: _normalizeMap(inferenceResult.meta),
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
    _persistProposalState(proposal.proposalId);
    return proposal;
  }

  LiveEditResolutionProposal getProposal(final String proposalId) {
    _hydrateProposalState(proposalId);
    final proposal = _proposals[proposalId];
    if (proposal == null) {
      throw StateError('Unknown live edit proposal: $proposalId');
    }
    return proposal;
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
    _persistProposalState(proposalId);
    return LiveEditResolutionResult(
      proposalId: proposalId,
      status: LiveEditResolutionStatus.applied,
      changedFiles: changedFiles,
      validation: <String, Object?>{'writeCount': changedFiles.length},
      warnings: proposal.warnings,
    );
  }

  LiveEditResolutionStatus proposalStatus(final String proposalId) {
    _hydrateProposalState(proposalId);
    return _proposalStatus[proposalId] ?? LiveEditResolutionStatus.proposed;
  }

  LiveEditResolutionRequest? requestForProposal(final String proposalId) {
    _hydrateProposalState(proposalId);
    return _requests[proposalId];
  }

  String _buildPrompt({
    required final LiveEditResolutionRequest request,
    required final String backendId,
  }) {
    final promptRequest = _buildPromptRequest(request);
    final requestJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(promptRequest);
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
- Use the source location and workspace files to inspect the real implementation before proposing changes.
- The request payload is intentionally summarized; treat it as guidance, not the complete widget tree dump.

Active backend: $backendId

Resolution request:
$requestJson
''';
  }

  void _hydrateProposalState(final String proposalId) {
    if (_proposals.containsKey(proposalId) && _requests.containsKey(proposalId)) {
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

      final json = _normalizeMap(decoded);
      final proposalJson = _normalizeMap(json['proposal']);
      final requestJson = _normalizeMap(json['request']);
      if (proposalJson.isEmpty || requestJson.isEmpty) {
        return;
      }

      _proposals[proposalId] = LiveEditResolutionProposal.fromJson(proposalJson);
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
      final directory = Directory(_storagePath);
      directory.createSync(recursive: true);
      final payload = <String, Object?>{
        'proposal': proposal.toJson(),
        'request': request.toJson(),
        'status': proposalStatus(proposalId).wireName,
      };
      File(_proposalFilePath(proposalId)).writeAsStringSync(jsonEncode(payload));
    } on FileSystemException {
      // Proposal persistence is best-effort; in-process flow can still continue.
    }
  }

  String _proposalFilePath(final String proposalId) {
    final encodedId = base64Url.encode(utf8.encode(proposalId));
    return p.join(_storagePath, '$encodedId.json');
  }
}

Map<String, Object?> _buildPromptRequest(
  final LiveEditResolutionRequest request,
) {
  final promptRequest = <String, Object?>{
    'sessionId': request.sessionId,
    'workingDirectory': request.workingDirectory,
    'draftChanges': request.draftChanges
        .map((final change) => change.toJson())
        .toList(growable: false),
  };

  final selection = request.selection;
  if (selection != null) {
    promptRequest['selection'] = _summarizeSelection(
      selection,
      workingDirectory: request.workingDirectory,
    );
  }
  if (_hasText(request.backendId)) {
    promptRequest['backendId'] = request.backendId;
  }
  if (_hasText(request.intentText)) {
    promptRequest['intentText'] = request.intentText;
  }
  if (request.evidence.isNotEmpty) {
    promptRequest['evidence'] = _summarizeEvidence(request.evidence);
  }
  if (request.meta.isNotEmpty) {
    promptRequest['meta'] = _compactMap(
      request.meta,
      maxDepth: 1,
      maxListItems: 6,
    );
  }
  return promptRequest;
}

Map<String, Object?> _summarizeSelection(
  final LiveEditSelection selection, {
  required final String workingDirectory,
}) {
  final summary = <String, Object?>{
    'sessionId': selection.sessionId,
    'nodeId': selection.nodeId,
    'widgetType': selection.widgetType,
    'properties': selection.propertyGroups
        .map((final property) => property.toJson())
        .toList(growable: false),
  };

  if (_hasText(selection.renderObjectType)) {
    summary['renderObjectType'] = selection.renderObjectType;
  }
  if (selection.bounds != null) {
    summary['bounds'] = selection.bounds!.toJson();
  }
  if (selection.source != null) {
    summary['source'] = _summarizeSourceLocation(
      selection.source!,
      workingDirectory: workingDirectory,
    );
    final sourceExcerpt = _loadSourceExcerpt(
      selection.source!,
      workingDirectory: workingDirectory,
    );
    if (sourceExcerpt != null) {
      summary['sourceExcerpt'] = sourceExcerpt;
    }
  }
  if (selection.layoutContext.isNotEmpty) {
    summary['layoutContext'] = _compactMap(selection.layoutContext);
  }
  if (selection.parentChain.isNotEmpty) {
    summary['parentChain'] = _summarizeParentChain(selection.parentChain);
  }
  if (selection.rawNode.isNotEmpty) {
    summary['rawNode'] = _summarizeInspectorNode(selection.rawNode);
  }
  return summary;
}

Map<String, Object?> _summarizeSourceLocation(
  final LiveEditSourceLocation source, {
  required final String workingDirectory,
}) {
  final summary = Map<String, Object?>.from(source.toJson());
  final normalizedPath = _normalizeFilePath(source.file);
  if (_hasText(normalizedPath)) {
    summary['absolutePath'] = normalizedPath;
    if (_isWithinWorkspace(normalizedPath!, workingDirectory)) {
      summary['workspacePath'] = p.relative(
        normalizedPath,
        from: workingDirectory,
      );
    }
  }
  return summary;
}

Map<String, Object?>? _loadSourceExcerpt(
  final LiveEditSourceLocation source, {
  required final String workingDirectory,
}) {
  final normalizedPath = _normalizeFilePath(source.file);
  if (!_hasText(normalizedPath)) {
    return null;
  }

  final absolutePath = p.isAbsolute(normalizedPath!)
      ? normalizedPath
      : p.normalize(p.join(workingDirectory, normalizedPath));
  final file = File(absolutePath);
  if (!file.existsSync()) {
    return null;
  }

  try {
    final lines = file.readAsLinesSync();
    final focusLine = source.line ?? 1;
    final startLine = (focusLine - 12).clamp(1, lines.length);
    final endLine = (focusLine + 12).clamp(1, lines.length);
    final excerpt = <String>[];
    for (var index = startLine; index <= endLine; index++) {
      excerpt.add('${index.toString().padLeft(4)}: ${lines[index - 1]}');
    }
    return <String, Object?>{
      'startLine': startLine,
      'endLine': endLine,
      'lineCount': lines.length,
      'text': excerpt.join('\n'),
    };
  } on FileSystemException {
    return null;
  }
}

List<Map<String, Object?>> _summarizeParentChain(
  final List<Map<String, Object?>> parentChain,
) {
  final summaries = parentChain
      .take(6)
      .map((final entry) {
        final node = _normalizeMap(entry['node']);
        if (node.isNotEmpty) {
          return <String, Object?>{'node': _summarizeInspectorNode(node)};
        }
        return _compactMap(entry, maxDepth: 1, maxListItems: 4);
      })
      .toList(growable: false);
  if (parentChain.length > summaries.length) {
    return <Map<String, Object?>>[
      ...summaries,
      <String, Object?>{
        'truncatedEntries': parentChain.length - summaries.length,
      },
    ];
  }
  return summaries;
}

Map<String, Object?> _summarizeEvidence(final Map<String, Object?> evidence) {
  final summary = <String, Object?>{};
  final tree = _normalizeMap(evidence['tree']);
  if (tree.isNotEmpty) {
    summary['tree'] = _summarizeInspectorNode(tree, maxDepth: 2);
  }

  if (evidence.containsKey('uiSnapshot')) {
    summary['uiSnapshot'] = _compactJson(
      evidence['uiSnapshot'],
      maxDepth: 2,
      maxListItems: 4,
    );
  }
  if (evidence.containsKey('uiSnapshotError')) {
    summary['uiSnapshotError'] = _compactJson(
      evidence['uiSnapshotError'],
      maxDepth: 2,
      maxListItems: 4,
    );
  }
  return summary;
}

Map<String, Object?> _summarizeInspectorNode(
  final Map<String, Object?> node, {
  final int depth = 0,
  final int maxDepth = 1,
}) {
  final summary = <String, Object?>{};
  for (final key in const <String>[
    'description',
    'widgetRuntimeType',
    'type',
    'style',
    'valueId',
    'locationId',
    'stateful',
    'createdByLocalProject',
  ]) {
    if (node.containsKey(key)) {
      summary[key] = node[key];
    }
  }

  final creationLocation = _normalizeMap(node['creationLocation']);
  if (creationLocation.isNotEmpty) {
    summary['creationLocation'] = _compactMap(
      creationLocation,
      maxDepth: 1,
      maxListItems: 4,
      maxStringChars: 180,
    );
  }

  final properties = _asMapList(node['properties']);
  if (properties.isNotEmpty) {
    final propertySummaries = properties
        .take(4)
        .map(_summarizeInspectorProperty)
        .where((final property) => property.isNotEmpty)
        .toList(growable: false);
    if (propertySummaries.isNotEmpty) {
      summary['properties'] = propertySummaries;
    }
    if (properties.length > propertySummaries.length) {
      summary['propertyCount'] = properties.length;
    }
  }

  final children = _asMapList(node['children']);
  if (children.isNotEmpty) {
    if (depth >= maxDepth) {
      summary['childCount'] = children.length;
    } else {
      final childSummaries = children
          .take(4)
          .map(
            (final child) => _summarizeInspectorNode(
              child,
              depth: depth + 1,
              maxDepth: maxDepth,
            ),
          )
          .toList(growable: false);
      summary['children'] = childSummaries;
      if (children.length > childSummaries.length) {
        summary['childrenTruncated'] = children.length - childSummaries.length;
      }
    }
  }

  return summary;
}

Map<String, Object?> _summarizeInspectorProperty(
  final Map<String, Object?> property,
) {
  final summary = <String, Object?>{};
  for (final key in const <String>[
    'name',
    'description',
    'propertyType',
    'type',
    'value',
    'numberToString',
    'quoted',
    'ifTrue',
    'ifFalse',
  ]) {
    if (!property.containsKey(key)) {
      continue;
    }
    summary[key] = _compactJson(
      property[key],
      maxDepth: 1,
      maxListItems: 4,
      maxStringChars: 180,
    );
  }
  return summary;
}

Map<String, Object?> _compactMap(
  final Map<String, Object?> value, {
  final int depth = 0,
  final int maxDepth = 2,
  final int maxListItems = 8,
  final int maxStringChars = 240,
}) {
  final compacted = _compactJson(
    value,
    depth: depth,
    maxDepth: maxDepth,
    maxListItems: maxListItems,
    maxStringChars: maxStringChars,
  );
  return compacted is Map<String, Object?>
      ? compacted
      : const <String, Object?>{};
}

Object? _compactJson(
  final Object? value, {
  final int depth = 0,
  final int maxDepth = 2,
  final int maxListItems = 8,
  final int maxStringChars = 240,
}) {
  if (value == null || value is num || value is bool) {
    return value;
  }

  if (value is String) {
    if (value.length <= maxStringChars) {
      return value;
    }
    return '${value.substring(0, maxStringChars)}...[truncated ${value.length - maxStringChars} chars]';
  }

  if (value is Map) {
    final map = value.map(
      (final key, final nestedValue) => MapEntry('$key', nestedValue),
    );
    if (depth >= maxDepth) {
      return <String, Object?>{
        'truncated': true,
        'keys': map.keys.take(maxListItems).toList(growable: false),
      };
    }
    final result = <String, Object?>{};
    for (final entry in map.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (_isLargePayloadKey(lowerKey)) {
        result[entry.key] = '<omitted large payload>';
        continue;
      }
      result[entry.key] = _compactJson(
        entry.value,
        depth: depth + 1,
        maxDepth: maxDepth,
        maxListItems: maxListItems,
        maxStringChars: maxStringChars,
      );
    }
    return result;
  }

  if (value is List) {
    final items = value
        .take(maxListItems)
        .map(
          (final item) => _compactJson(
            item,
            depth: depth + 1,
            maxDepth: maxDepth,
            maxListItems: maxListItems,
            maxStringChars: maxStringChars,
          ),
        )
        .toList(growable: true);
    if (value.length > items.length) {
      items.add('<truncated ${value.length - items.length} items>');
    }
    return items;
  }

  return _compactJson(
    '$value',
    depth: depth,
    maxDepth: maxDepth,
    maxListItems: maxListItems,
    maxStringChars: maxStringChars,
  );
}

String? _normalizeFilePath(final String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.scheme == 'file') {
    return uri.toFilePath();
  }
  if (rawPath.trim().isEmpty) {
    return null;
  }
  return rawPath;
}

bool _isWithinWorkspace(
  final String absolutePath,
  final String workingDirectory,
) {
  if (!p.isAbsolute(absolutePath)) {
    return false;
  }
  final normalizedFile = p.normalize(absolutePath);
  final normalizedWorkspace = p.normalize(workingDirectory);
  return normalizedFile == normalizedWorkspace ||
      p.isWithin(normalizedWorkspace, normalizedFile);
}

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

bool _isLargePayloadKey(final String key) {
  return key.contains('base64') ||
      key.contains('bytes') ||
      key.contains('image') ||
      key.contains('screenshot') ||
      key.contains('png') ||
      key.contains('jpeg');
}

List<Map<String, Object?>> _asMapList(final Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  return value
      .whereType<Map>()
      .map((final entry) => _normalizeMap(entry))
      .toList(growable: false);
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
