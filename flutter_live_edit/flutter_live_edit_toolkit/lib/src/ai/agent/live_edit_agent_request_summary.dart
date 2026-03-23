import 'dart:convert';
import 'dart:io';

import 'package:from_json_to_json/from_json_to_json.dart';

import '../../models/models.dart';
import '../../ui_selectors/shared/live_edit_selectors_shared.dart';
import 'live_edit_agent_utils.dart';

/// Request summarization and prompt building. Package-private.

String? trimmedIntentText(final LiveEditResolutionRequest request) {
  final value = jsonDecodeString(request.effectiveInstructionText).trim();
  return value.isEmpty ? null : value;
}

Map<String, Object?> resolutionRequestSummary(
  final LiveEditResolutionRequest request, {
  required final String backendId,
}) => <String, Object?>{
  'sessionId': request.sessionId,
  'backendId': backendId,
  'workingDirectory': request.workingDirectory,
  'bubbleId': request.effectiveBubbleId,
  'selectionNodeId': request.effectivePrimarySelection?.nodeId,
  'selectedWidgetCount': request.effectiveSelectedWidgets.length,
  'draftChangeCount': 0,
  'intentTextPresent': trimmedIntentText(request) != null,
  'applyMode': request.applyMode.wireName,
  'requestMode': 'prompt-only',
  if (request.inferenceConfig?.model != null)
    'inferenceModel': request.inferenceConfig!.model,
  if (request.inferenceConfig?.reasoningEffort != null)
    'inferenceReasoningEffort': request.inferenceConfig!.reasoningEffort,
};

List<LiveEditSourceTarget> sourceTargetsForRequest(
  final LiveEditResolutionRequest request,
) {
  if (request.sourceTargets.isNotEmpty) return request.sourceTargets;
  final deduped = <String, LiveEditSourceTarget>{};
  for (final selection in request.effectiveSelectedWidgets) {
    final source = selection.source;
    if (source == null) continue;
    final normalizedPath = normalizeFilePath(source.file);
    final absolutePath = absolutePathInWorkspace(
      normalizedPath,
      request.workingDirectory,
    );
    if (absolutePath == null) continue;
    final workspacePath = workspaceRelativePathIfInside(
      absolutePath: absolutePath,
      workingDirectory: request.workingDirectory,
    );
    final key = workspacePath ?? absolutePath;
    deduped[key] = LiveEditSourceTarget(
      nodeId: selection.nodeId,
      widgetType: selection.widgetType,
      absolutePath: absolutePath,
      workspacePath: workspacePath,
      line: source.line,
      column: source.column,
    );
  }
  return deduped.values.toList(growable: false);
}

Map<String, Object?>? loadSourceExcerpt(
  final LiveEditSourceLocation source, {
  required final String workingDirectory,
}) {
  final normalizedPath = normalizeFilePath(source.file);
  final absolutePath = absolutePathInWorkspace(
    normalizedPath,
    workingDirectory,
  );
  if (absolutePath == null) return null;
  final file = File(absolutePath);
  if (!file.existsSync()) return null;
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

Map<String, Object?> summarizeSourceLocation(
  final LiveEditSourceLocation source, {
  required final String workingDirectory,
}) {
  final summary = Map<String, Object?>.from(source.toJson());
  final normalizedPath = normalizeFilePath(source.file);
  final absolute = absolutePathInWorkspace(normalizedPath, workingDirectory);
  if (absolute != null) {
    summary['absolutePath'] = absolute;
    final rel = workspaceRelativePathIfInside(
      absolutePath: absolute,
      workingDirectory: workingDirectory,
    );
    if (rel != null) summary['workspacePath'] = rel;
  }
  return summary;
}

Map<String, Object?> summarizeInspectorProperty(
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
    if (!property.containsKey(key)) continue;
    summary[key] = compactJson(
      property[key],
      maxDepth: 1,
      maxListItems: 4,
      maxStringChars: 180,
    );
  }
  return summary;
}

Map<String, Object?> summarizeInspectorNode(
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
    if (node.containsKey(key)) summary[key] = node[key];
  }
  final creationLocation = jsonDecodeMapLoose(node['creationLocation']);
  if (creationLocation.isNotEmpty) {
    summary['creationLocation'] = compactMap(
      creationLocation,
      maxDepth: 1,
      maxListItems: 4,
      maxStringChars: 180,
    );
  }
  final properties = jsonDecodeMapListLoose(node['properties']);
  if (properties.isNotEmpty) {
    final propertySummaries = properties
        .take(4)
        .map(summarizeInspectorProperty)
        .where((final property) => property.isNotEmpty)
        .toList(growable: false);
    if (propertySummaries.isNotEmpty) summary['properties'] = propertySummaries;
    if (properties.length > propertySummaries.length) {
      summary['propertyCount'] = properties.length;
    }
  }
  final children = jsonDecodeMapListLoose(node['children']);
  if (children.isNotEmpty) {
    if (depth >= maxDepth) {
      summary['childCount'] = children.length;
    } else {
      final childSummaries = children
          .take(4)
          .map(
            (final child) => summarizeInspectorNode(
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

List<Map<String, Object?>> summarizeParentChain(
  final List<Map<String, Object?>> parentChain,
) {
  final summaries = parentChain
      .take(6)
      .map((final entry) {
        final node = jsonDecodeMapLoose(entry['node']);
        if (node.isNotEmpty) {
          return <String, Object?>{'node': summarizeInspectorNode(node)};
        }
        return compactMap(entry, maxDepth: 1, maxListItems: 4);
      })
      .toList(growable: false);
  if (parentChain.length > summaries.length) {
    return [
      ...summaries,
      <String, Object?>{
        'truncatedEntries': parentChain.length - summaries.length,
      },
    ];
  }
  return summaries;
}

Map<String, Object?> summarizeEvidence(final Map<String, Object?> evidence) {
  final summary = <String, Object?>{};
  final tree = jsonDecodeMapLoose(evidence['tree']);
  if (tree.isNotEmpty) {
    summary['tree'] = summarizeInspectorNode(tree, maxDepth: 2);
  }
  if (evidence.containsKey('uiSnapshot')) {
    summary['uiSnapshot'] = compactJson(
      evidence['uiSnapshot'],
      maxListItems: 4,
    );
  }
  if (evidence.containsKey('uiSnapshotError')) {
    summary['uiSnapshotError'] = compactJson(
      evidence['uiSnapshotError'],
      maxListItems: 4,
    );
  }
  return summary;
}

Map<String, Object?> summarizeSelection(
  final LiveEditSelection selection, {
  required final String workingDirectory,
}) {
  final summary = <String, Object?>{
    'sessionId': selection.sessionId,
    'nodeId': selection.nodeId,
    'widgetType': selection.widgetType,
    'properties': selection.propertiesForWire,
  };
  if (hasText(selection.renderObjectType)) {
    summary['renderObjectType'] = selection.renderObjectType;
  }
  if (selection.bounds != null) {
    summary['bounds'] = selection.bounds!.toJson();
  }
  if (selection.source != null) {
    summary['source'] = summarizeSourceLocation(
      selection.source!,
      workingDirectory: workingDirectory,
    );
    final sourceExcerpt = loadSourceExcerpt(
      selection.source!,
      workingDirectory: workingDirectory,
    );
    if (sourceExcerpt != null) summary['sourceExcerpt'] = sourceExcerpt;
  }
  if (selection.layoutContext.isNotEmpty) {
    summary['layoutContext'] = compactMap(selection.layoutContext);
  }
  if (selection.parentChain.isNotEmpty) {
    summary['parentChain'] = summarizeParentChain(selection.parentChain);
  }
  if (selection.rawNode.isNotEmpty) {
    summary['rawNode'] = summarizeInspectorNode(selection.rawNode);
  }
  return summary;
}

List<Map<String, Object?>> summarizeSelectedWidgets(
  final List<LiveEditSelection> selections, {
  required final String workingDirectory,
}) {
  final summaries = selections
      .take(6)
      .map((final selection) {
        final source = selection.source;
        return <String, Object?>{
          'nodeId': selection.nodeId,
          'widgetType': selection.widgetType,
          if (hasText(source?.file))
            'source': summarizeSourceLocation(
              source!,
              workingDirectory: workingDirectory,
            ),
        };
      })
      .toList(growable: false);
  if (selections.length > summaries.length) {
    return [
      ...summaries,
      <String, Object?>{
        'truncatedWidgets': selections.length - summaries.length,
      },
    ];
  }
  return summaries;
}

Map<String, Object?> buildPromptRequest(
  final LiveEditResolutionRequest request,
) {
  final primarySelection = request.effectivePrimarySelection;
  final promptRequest = <String, Object?>{
    'sessionId': request.sessionId,
    'applyMode': request.applyMode.wireName,
    'workingDirectory': request.workingDirectory,
    'stagedPropertyChanges': <Object?>[],
  };
  if (hasText(request.effectiveBubbleId)) {
    promptRequest['bubbleId'] = request.effectiveBubbleId;
  }
  if (hasText(request.effectiveInstructionText)) {
    promptRequest['instructionText'] = request.effectiveInstructionText;
  }
  if (primarySelection != null) {
    promptRequest['primarySelection'] = summarizeSelection(
      primarySelection,
      workingDirectory: request.workingDirectory,
    );
  }
  final selectedWidgets = request.effectiveSelectedWidgets;
  if (selectedWidgets.isNotEmpty) {
    promptRequest['selectedWidgets'] = summarizeSelectedWidgets(
      selectedWidgets,
      workingDirectory: request.workingDirectory,
    );
  }
  final sourceTargets = sourceTargetsForRequest(request);
  if (sourceTargets.isNotEmpty) {
    promptRequest['sourceTargets'] = sourceTargets
        .map((final t) => t.toJson())
        .toList(growable: false);
  }
  if (hasText(request.backendId)) {
    promptRequest['backendId'] = request.backendId;
  }
  if (request.inferenceConfig != null) {
    promptRequest['inferenceConfig'] = request.inferenceConfig!.toJson();
  }
  if (request.evidence.isNotEmpty) {
    promptRequest['evidence'] = summarizeEvidence(request.evidence);
  }
  if (request.meta.isNotEmpty) {
    promptRequest['meta'] = compactMap(
      request.meta,
      maxDepth: 1,
      maxListItems: 6,
    );
  }
  return promptRequest;
}

String buildPrompt({
  required final LiveEditResolutionRequest request,
  required final String backendId,
}) {
  final promptRequest = buildPromptRequest(request);
  final requestJson = const JsonEncoder.withIndent('  ').convert(promptRequest);
  return '''
You are an agent working directly inside a Dart/Flutter workspace.

Implement the requested UI change immediately in the real source files, keep edits minimal, and leave the workspace hot-reload ready.

Return only a compact JSON execution report that matches the schema.
Prompt-only requests still must return the full JSON object with summary, changedFiles, warnings, and validationSteps.

Rules:
- Inspect the referenced files before editing.
- Respect existing app abstractions, theme usage, and state management.
- Prefer the smallest edit that satisfies the request.
- Use the primary selection and source targets as the main context; the widget summaries are intentionally compact.
- If the request is ambiguous or risky, make no code changes and explain it in warnings.
- Do not invent unsupported tooling assumptions or rewrite unrelated code.

Active backend: $backendId

Direct apply request:
$requestJson
''';
}
