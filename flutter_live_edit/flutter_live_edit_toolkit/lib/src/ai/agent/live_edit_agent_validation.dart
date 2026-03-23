import 'dart:io';

import 'package:from_json_to_json/from_json_to_json.dart';

import '../../models/models.dart';
import 'live_edit_agent_request_summary.dart';
import 'live_edit_agent_utils.dart';

/// Request validation. Package-private.

bool hasResolveIntent(final LiveEditResolutionRequest request) =>
    trimmedIntentText(request) != null;

String? validateResolutionRequest(final LiveEditResolutionRequest request) {
  final workingDirectory = jsonDecodeString(request.workingDirectory).trim();
  if (workingDirectory.isEmpty || !Directory(workingDirectory).existsSync()) {
    return 'Live edit working directory is unavailable for source '
        'persistence.';
  }
  if (!hasResolveIntent(request)) {
    return 'Live edit needs a prompt before the selected backend can '
        'resolve it.';
  }
  final selection = request.effectivePrimarySelection;
  final source = selection?.source;
  if (selection == null || source == null) return null;

  final normalizedPath = normalizeFilePath(source.file);
  final absolutePath = absolutePathInWorkspace(
    normalizedPath,
    workingDirectory,
  );
  if (absolutePath == null) {
    return 'The selected element does not expose a source file, so the '
        'selected backend cannot persist this change yet.';
  }
  if (!isWithinWorkspace(absolutePath, workingDirectory)) {
    return 'The selected source file is outside the live edit workspace.';
  }
  if (!File(absolutePath).existsSync()) {
    return 'The selected source file could not be found in the live edit '
        'workspace.';
  }
  return null;
}
