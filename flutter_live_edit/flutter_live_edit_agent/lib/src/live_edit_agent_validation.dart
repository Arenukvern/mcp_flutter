import 'dart:io';

import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:path/path.dart' as p;

import 'live_edit_agent_request_summary.dart';
import 'live_edit_agent_utils.dart';

/// Request validation. Package-private.

bool hasResolveIntent(final LiveEditResolutionRequest request) =>
    trimmedIntentText(request) != null;

String? validateResolutionRequest(final LiveEditResolutionRequest request) {
  final workingDirectory = request.workingDirectory.trim();
  if (workingDirectory.isEmpty || !Directory(workingDirectory).existsSync()) {
    return 'Live edit working directory is unavailable for source persistence.';
  }
  if (!hasResolveIntent(request)) {
    return 'Live edit needs a prompt before the selected backend can resolve it.';
  }
  final selection = request.effectivePrimarySelection;
  final source = selection?.source;
  if (selection == null || source == null) return null;

  final normalizedPath = normalizeFilePath(source.file);
  if (!hasText(normalizedPath)) {
    return 'The selected element does not expose a source file, so the selected backend cannot persist this change yet.';
  }
  final absolutePath = p.isAbsolute(normalizedPath!)
      ? normalizedPath
      : p.normalize(p.join(workingDirectory, normalizedPath));
  if (!isWithinWorkspace(absolutePath, workingDirectory)) {
    return 'The selected source file is outside the live edit workspace.';
  }
  if (!File(absolutePath).existsSync()) {
    return 'The selected source file could not be found in the live edit workspace.';
  }
  return null;
}
