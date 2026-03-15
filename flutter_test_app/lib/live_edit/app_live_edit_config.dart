import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

const liveEditTestModeFromDefine = bool.fromEnvironment('LIVE_EDIT_TEST_MODE');
const liveEditBackendIdFromDefine = String.fromEnvironment(
  'LIVE_EDIT_BACKEND',
  defaultValue: 'codex_exec',
);
const liveEditWorkingDirectoryFromDefine = String.fromEnvironment(
  'LIVE_EDIT_WORKING_DIRECTORY',
);

bool get isLiveEditTestMode =>
    liveEditTestModeFromDefine ||
    (kIsWeb && Uri.base.queryParameters['live_edit_test_mode'] == '1');

final class TestAppLiveEditConfig {
  const TestAppLiveEditConfig({
    required this.testMode,
    required this.backendId,
    required this.workingDirectoryFromDefine,
  });

  factory TestAppLiveEditConfig.fromEnvironment() {
    return const TestAppLiveEditConfig(
      testMode: false,
      backendId: liveEditBackendIdFromDefine,
      workingDirectoryFromDefine: liveEditWorkingDirectoryFromDefine,
    ).copyWith(testMode: isLiveEditTestMode);
  }

  final bool testMode;
  final String backendId;
  final String workingDirectoryFromDefine;

  String? get hostWorkingDirectory =>
      testMode ? null : _trimToNull(workingDirectoryFromDefine);

  String get hostIntentText => testMode
      ? 'Persist live-edit changes for the Maestro test fixture.'
      : 'Persist the requested live-edit change in the selected source file.';

  TestAppLiveEditConfig copyWith({
    final bool? testMode,
    final String? backendId,
    final String? workingDirectoryFromDefine,
  }) {
    return TestAppLiveEditConfig(
      testMode: testMode ?? this.testMode,
      backendId: backendId ?? this.backendId,
      workingDirectoryFromDefine:
          workingDirectoryFromDefine ?? this.workingDirectoryFromDefine,
    );
  }
}

String? resolveLiveEditWorkingDirectory(
  final LiveEditApplyDraftRequest request, {
  required final TestAppLiveEditConfig config,
}) {
  final requested = _trimToNull(request.workingDirectory);
  if (requested != null) {
    return requested;
  }

  final definedWorkingDirectory = _trimToNull(
    config.workingDirectoryFromDefine,
  );
  if (definedWorkingDirectory != null) {
    return definedWorkingDirectory;
  }

  final inferred = workingDirectoryFromSelection(request.selection);
  if (inferred != null) {
    return inferred;
  }

  final cwd = Directory.current.path;
  return File('$cwd/pubspec.yaml').existsSync() ? cwd : null;
}

String? workingDirectoryFromSelection(final LiveEditSelection? selection) {
  final sourceFile = _trimToNull(selection?.source?.file);
  if (sourceFile == null) {
    return null;
  }

  final normalized = normalizePath(sourceFile);
  final file = File(normalized);
  Directory? cursor = file.existsSync() ? file.parent : Directory(normalized);
  while (cursor != null) {
    final pubspec = File('${cursor.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      return cursor.path;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      break;
    }
    cursor = parent;
  }
  return null;
}

String normalizePath(final String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.scheme == 'file') {
    return uri.toFilePath();
  }
  return rawPath;
}

String? _trimToNull(final String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
