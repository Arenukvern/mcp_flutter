import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:path/path.dart' as p;
import 'package:xsoulspace_inference_codex_exec/xsoulspace_inference_codex_exec.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';
import 'package:xsoulspace_inference_cursor_agent/xsoulspace_inference_cursor_agent.dart';

String _agentInstruction(
  final LiveEditResolutionProposal proposal,
  final LiveEditResolutionRequest? request,
) {
  final requestedChanges =
      (request?.draftChanges ?? const <LiveEditDraftChange>[])
          .map((final change) => '${change.propertyId}=${change.targetValue}')
          .join(', ');
  final intentText = request?.intentText?.trim();
  final widgetType = request?.selection?.widgetType.trim();
  final summary = proposal.summary.trim();
  final parts = <String>[
    if (_hasText(widgetType)) 'Update $widgetType',
    if (_hasText(requestedChanges)) 'with $requestedChanges',
    if (_hasText(intentText)) 'for request: $intentText',
    if (_hasText(summary))
      'and persist the source change described as: $summary',
  ];
  return parts.join(' ').trim();
}

List<Map<String, Object?>> _asMapList(final Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  return value.whereType<Map>().map(_normalizeMap).toList(growable: false);
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
  if (request.inferenceConfig != null) {
    promptRequest['inferenceConfig'] = request.inferenceConfig!.toJson();
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

String _draftChangeSummary(
  final LiveEditDraftChange change,
  final LiveEditSelection? selection,
) {
  final property = selection?.propertyGroups.firstWhere(
    (final candidate) => candidate.id == change.propertyId,
    orElse: () => LiveEditPropertyDescriptor(
      id: change.propertyId,
      label: change.propertyId,
      group: LiveEditPropertyGroup.diagnostics,
      kind: LiveEditPropertyKind.object,
    ),
  );
  final label = property?.label.trim().isNotEmpty == true
      ? property!.label
      : change.propertyId;
  return 'Set $label to ${change.targetValue}';
}

List<String> _executionRequestedChanges(
  final LiveEditResolutionRequest? request,
  final LiveEditSelection? selection,
) {
  final requestedChanges = <String>[
    ...(request?.draftChanges ?? const <LiveEditDraftChange>[]).map(
      (final change) => _draftChangeSummary(change, selection),
    ),
  ];
  final intentText = request?.intentText?.trim();
  if (_hasText(intentText)) {
    requestedChanges.add(intentText!);
  }
  return requestedChanges;
}

bool _hasResolveIntent(final LiveEditResolutionRequest request) =>
    request.draftChanges.isNotEmpty || _trimmedIntentText(request) != null;

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

bool _isLargePayloadKey(final String key) =>
    key.contains('base64') ||
    key.contains('bytes') ||
    key.contains('image') ||
    key.contains('screenshot') ||
    key.contains('png') ||
    key.contains('jpeg');

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

Map<String, Object?> _mergeErrorDetails(
  final Object? details, {
  required final LiveEditResolutionRequest request,
  required final String backendId,
}) {
  final merged = <String, Object?>{
    'requestSummary': _resolutionRequestSummary(request, backendId: backendId),
    'request': request.toJson(),
  };
  if (details is Map) {
    merged.addAll(_normalizeMap(details));
    return merged;
  }
  if (details != null) {
    merged['rawDetails'] = details;
  }
  return merged;
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

Map<String, Object?> _normalizeMap(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (final key, final nestedValue) => MapEntry('$key', nestedValue),
    );
  }
  return const <String, Object?>{};
}

double _planConfidence(
  final LiveEditResolutionProposal proposal,
  final LiveEditResolutionRequest? request,
) {
  final changeConfidences =
      (request?.draftChanges ?? const <LiveEditDraftChange>[])
          .map((final change) => change.confidence)
          .toList(growable: false);
  if (changeConfidences.isEmpty) {
    return proposal.riskFlags.isEmpty ? 0.8 : 0.6;
  }
  final average =
      changeConfidences.reduce((final left, final right) => left + right) /
      changeConfidences.length;
  return average.clamp(0, 1).toDouble();
}

Map<String, Object?> _resolutionRequestSummary(
  final LiveEditResolutionRequest request, {
  required final String backendId,
}) => <String, Object?>{
  'sessionId': request.sessionId,
  'backendId': backendId,
  'workingDirectory': request.workingDirectory,
  'selectionNodeId': request.selection?.nodeId,
  'draftChangeCount': request.draftChanges.length,
  'intentTextPresent': _trimmedIntentText(request) != null,
  'requestMode': request.draftChanges.isEmpty ? 'prompt-only' : 'draft-backed',
  if (request.inferenceConfig?.model != null)
    'inferenceModel': request.inferenceConfig!.model,
  if (request.inferenceConfig?.reasoningEffort != null)
    'inferenceReasoningEffort': request.inferenceConfig!.reasoningEffort,
};

String _selectedNodeLabel(final LiveEditSelection? selection) {
  if (selection == null) {
    return 'Selected widget';
  }
  final widgetType = selection.widgetType.trim();
  final file = selection.source?.file.trim() ?? '';
  final line = selection.source?.line;
  if (_hasText(file) && line != null) {
    return '$widgetType at ${p.basename(file)}:$line';
  }
  return widgetType.isEmpty ? 'Selected widget' : widgetType;
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
      maxListItems: 4,
    );
  }
  if (evidence.containsKey('uiSnapshotError')) {
    summary['uiSnapshotError'] = _compactJson(
      evidence['uiSnapshotError'],
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

String? _trimmedIntentText(final LiveEditResolutionRequest request) {
  final value = request.intentText?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String? _validateResolutionRequest(final LiveEditResolutionRequest request) {
  final workingDirectory = request.workingDirectory.trim();
  if (workingDirectory.isEmpty || !Directory(workingDirectory).existsSync()) {
    return 'Live edit working directory is unavailable for source persistence.';
  }
  if (!_hasResolveIntent(request)) {
    return 'Live edit needs either draft changes or a prompt before the selected backend can resolve it.';
  }

  final selection = request.selection;
  final source = selection?.source;
  if (selection == null || source == null) {
    return null;
  }

  final normalizedPath = _normalizeFilePath(source.file);
  if (!_hasText(normalizedPath)) {
    return 'The selected element does not expose a source file, so the selected backend cannot persist this change yet.';
  }

  final absolutePath = p.isAbsolute(normalizedPath!)
      ? normalizedPath
      : p.normalize(p.join(workingDirectory, normalizedPath));
  if (!_isWithinWorkspace(absolutePath, workingDirectory)) {
    return 'The selected source file is outside the live edit workspace.';
  }
  if (!File(absolutePath).existsSync()) {
    return 'The selected source file could not be found in the live edit workspace.';
  }
  return null;
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
      executionTimeout: const Duration(minutes: 6),
      maxTimeoutRetries: 0,
    );
    final cursorClient = CursorAgentInferenceClient(
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
    final meta = <String, Object?>{
      'displayLabel': _backendLabel(backendId),
      'backendId': backendId,
      'clientId': client.id,
      'binaryName': _binaryName(client),
    };
    if (backendId == 'codex_exec') {
      meta['supportedModels'] = LiveEditCodexOptions.supportedModels
          .map((final model) => model.toJson())
          .toList(growable: false);
      meta['supportedReasoningEfforts'] =
          LiveEditCodexOptions.supportedReasoningEfforts;
      meta['defaultInferenceConfig'] =
          (resolveInferenceConfig(backendId: backendId) ??
                  const LiveEditInferenceConfig())
              .toJson();
      if (sessionId != null) {
        meta['effectiveInferenceConfig'] =
            (resolveInferenceConfig(
                      backendId: backendId,
                      sessionId: sessionId,
                    ) ??
                    const LiveEditInferenceConfig())
                .toJson();
      }
    } else {
      meta['defaultInferenceConfig'] =
          (resolveInferenceConfig(backendId: backendId) ??
                  const LiveEditInferenceConfig())
              .toJson();
      if (sessionId != null) {
        meta['effectiveInferenceConfig'] =
            (resolveInferenceConfig(
                      backendId: backendId,
                      sessionId: sessionId,
                    ) ??
                    const LiveEditInferenceConfig())
                .toJson();
      }
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
    final selection = request?.selection;
    final requestedChanges = _executionRequestedChanges(request, selection);
    final riskNotes = <String>{
      ...proposal.riskFlags,
      ...proposal.warnings,
    }.where(_hasText).toList(growable: false);

    return LiveEditExecutionPlan(
      proposalId: proposal.proposalId,
      title: 'Apply live edit',
      summary: proposal.summary,
      selectedNode: _selectedNodeLabel(selection),
      requestedChanges: requestedChanges,
      affectedFiles: proposal.changedFiles,
      confidence: _planConfidence(proposal, request),
      riskNotes: riskNotes,
      agentInstruction: _agentInstruction(proposal, request),
      meta: <String, Object?>{
        'backendId': proposal.backendId,
        'validationSteps': proposal.validationSteps,
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

  Future<LiveEditResolutionProposal> resolve(
    final LiveEditResolutionRequest request, {
    final void Function(InferenceStructuredTextStreamEvent event)?
    onStreamEvent,
  }) async {
    final requestValidationError = _validateResolutionRequest(request);
    if (_hasText(requestValidationError)) {
      throw LiveEditAgentException(
        code: 'source_context_unavailable',
        message: requestValidationError!,
        details: request.toJson(),
      );
    }

    final backendId = registry.resolveBackendId(
      backendId: request.backendId,
      sessionId: request.sessionId,
    );
    final effectiveInferenceConfig = registry.resolveInferenceConfig(
      backendId: backendId,
      sessionId: request.sessionId,
      requestInferenceConfig: request.inferenceConfig,
    );
    final client = registry.clientFor(
      backendId: request.backendId,
      sessionId: request.sessionId,
    );
    final resolvedRequest = request.copyWith(
      backendId: backendId,
      inferenceConfig: effectiveInferenceConfig,
    );
    final requestSummary = _resolutionRequestSummary(
      resolvedRequest,
      backendId: backendId,
    );

    final prompt = _buildPrompt(request: resolvedRequest, backendId: backendId);
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
      outputSchema: LiveEditSchemas.resolutionProposal,
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
    _requests[proposal.proposalId] = resolvedRequest;
    _proposalStatus[proposal.proposalId] = LiveEditResolutionStatus.proposed;
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
- Prompt-only requests are valid when intentText is present, even if draftChanges is empty.
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

      final json = _normalizeMap(decoded);
      final proposalJson = _normalizeMap(json['proposal']);
      final requestJson = _normalizeMap(json['request']);
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
      final directory = Directory(_storagePath);
      directory.createSync(recursive: true);
      final payload = <String, Object?>{
        'proposal': proposal.toJson(),
        'request': request.toJson(),
        'status': proposalStatus(proposalId).wireName,
      };
      File(
        _proposalFilePath(proposalId),
      ).writeAsStringSync(jsonEncode(payload));
    } on FileSystemException {
      // Proposal persistence is best-effort; in-process flow can still continue.
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

extension on LiveEditResolutionRequest {
  LiveEditResolutionRequest copyWith({
    final String? sessionId,
    final String? workingDirectory,
    final List<LiveEditDraftChange>? draftChanges,
    final LiveEditSelection? selection,
    final String? backendId,
    final LiveEditInferenceConfig? inferenceConfig,
    final String? intentText,
    final Map<String, Object?>? evidence,
    final Map<String, Object?>? meta,
  }) => LiveEditResolutionRequest(
    sessionId: sessionId ?? this.sessionId,
    workingDirectory: workingDirectory ?? this.workingDirectory,
    draftChanges: draftChanges ?? this.draftChanges,
    selection: selection ?? this.selection,
    backendId: backendId ?? this.backendId,
    inferenceConfig: inferenceConfig ?? this.inferenceConfig,
    intentText: intentText ?? this.intentText,
    evidence: evidence ?? this.evidence,
    meta: meta ?? this.meta,
  );
}
