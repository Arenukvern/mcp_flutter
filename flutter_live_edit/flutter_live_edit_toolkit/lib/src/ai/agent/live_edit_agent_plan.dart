import 'package:path/path.dart' as p;

import '../../models/models.dart';

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

/// Execution plan and instruction helpers. Package-private.

List<String> executionRequestedChanges(
  final LiveEditResolutionRequest? request,
  final LiveEditSelection? selection,
) {
  final requestedChanges = <String>[];
  final intentText = request?.effectiveInstructionText?.trim();
  if (_hasText(intentText)) requestedChanges.add(intentText!);
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
    if (_hasText(widgetType)) 'Update $widgetType',
    if (_hasText(intentText)) 'for request: $intentText',
    if (_hasText(summary))
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
  if (_hasText(file) && line != null) {
    return '$widgetType at ${p.basename(file)}:$line';
  }
  return widgetType.isEmpty ? 'Selected widget' : widgetType;
}
