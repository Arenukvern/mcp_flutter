import 'package:path/path.dart' as p;

import '../../models/models.dart';
import '../../ui_selectors/ui_selectors.dart';

/// Execution plan and instruction helpers. Package-private.

List<String> executionRequestedChanges(
  final LiveEditResolutionRequest? request,
  final LiveEditSelection? selection,
) {
  final requestedChanges = <String>[];
  final intentText = request?.effectiveInstructionText?.trim();
  if (hasText(intentText)) requestedChanges.add(intentText!);
  return requestedChanges;
}

String agentInstruction(
  final LiveEditResolutionProposal proposal,
  final LiveEditResolutionRequest? request,
) {
  final intentText = request?.effectiveInstructionText?.trim();
  final widgetType = request?.effectivePrimarySelection?.widgetType.trim();
  final summary = proposal.summary.trim();
  final parts = <String>[
    if (hasText(widgetType)) 'Update $widgetType',
    if (hasText(intentText)) 'for request: $intentText',
    if (hasText(summary))
      'and persist the source change described as: $summary',
  ];
  return parts.join(' ').trim();
}

double planConfidence(
  final LiveEditResolutionProposal proposal,
  final LiveEditResolutionRequest? request,
) => proposal.riskFlags.isEmpty ? 0.8 : 0.6;

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
