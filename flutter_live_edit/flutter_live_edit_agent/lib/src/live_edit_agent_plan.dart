import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:path/path.dart' as p;

import 'live_edit_agent_utils.dart';

/// Execution plan and instruction helpers. Package-private.

String draftChangeSummary(
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

List<String> executionRequestedChanges(
  final LiveEditResolutionRequest? request,
  final LiveEditSelection? selection,
) {
  final requestedChanges = <String>[
    ...(request?.effectiveStagedPropertyChanges ??
            const <LiveEditDraftChange>[])
        .map((final change) => draftChangeSummary(change, selection)),
  ];
  final intentText = request?.effectiveInstructionText?.trim();
  if (hasText(intentText)) requestedChanges.add(intentText!);
  return requestedChanges;
}

String agentInstruction(
  final LiveEditResolutionProposal proposal,
  final LiveEditResolutionRequest? request,
) {
  final requestedChanges =
      (request?.effectiveStagedPropertyChanges ?? const <LiveEditDraftChange>[])
          .map((final change) => '${change.propertyId}=${change.targetValue}')
          .join(', ');
  final intentText = request?.effectiveInstructionText?.trim();
  final widgetType = request?.effectivePrimarySelection?.widgetType.trim();
  final summary = proposal.summary.trim();
  final parts = <String>[
    if (hasText(widgetType)) 'Update $widgetType',
    if (hasText(requestedChanges)) 'with $requestedChanges',
    if (hasText(intentText)) 'for request: $intentText',
    if (hasText(summary))
      'and persist the source change described as: $summary',
  ];
  return parts.join(' ').trim();
}

double planConfidence(
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

String selectedNodeLabel(final LiveEditSelection? selection) {
  if (selection == null) return 'Selected widget';
  final widgetType = selection.widgetType.trim();
  final file = selection.source?.file.trim() ?? '';
  final line = selection.source?.line;
  if (hasText(file) && line != null) {
    return '$widgetType at ${p.basename(file)}:$line';
  }
  return widgetType.isEmpty ? 'Selected widget' : widgetType;
}
