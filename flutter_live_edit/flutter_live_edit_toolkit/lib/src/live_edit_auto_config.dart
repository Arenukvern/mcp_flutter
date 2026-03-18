import 'package:flutter/foundation.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

const _liveEditTestModeFromDefine = bool.fromEnvironment('LIVE_EDIT_TEST_MODE');
const _liveEditBackendIdFromDefine = String.fromEnvironment(
  'LIVE_EDIT_BACKEND',
  defaultValue: 'codex_exec',
);
const _liveEditWorkingDirectoryFromDefine = String.fromEnvironment(
  'LIVE_EDIT_WORKING_DIRECTORY',
);

final class FlutterLiveEditAutoConfig {
  const FlutterLiveEditAutoConfig({
    this.backendId = _liveEditBackendIdFromDefine,
    this.workingDirectory,
    this.intentText,
    this.testMode = false,
    this.availableBackends,
    this.enableRuntimeRefresh = true,
    this.enableWebSemantics = true,
    this.appId,
    this.meta = const <String, Object?>{},
  });

  factory FlutterLiveEditAutoConfig.fromEnvironment({
    final String? intentText,
    final List<LiveEditAgentBackend>? availableBackends,
    final bool enableRuntimeRefresh = true,
    final bool enableWebSemantics = true,
    final String? appId,
    final Map<String, Object?> meta = const <String, Object?>{},
  }) => FlutterLiveEditAutoConfig(
    workingDirectory: _trimToNull(_liveEditWorkingDirectoryFromDefine),
    intentText: intentText,
    testMode:
        _liveEditTestModeFromDefine ||
        (kIsWeb && Uri.base.queryParameters['live_edit_test_mode'] == '1'),
    availableBackends: availableBackends,
    enableRuntimeRefresh: enableRuntimeRefresh,
    enableWebSemantics: enableWebSemantics,
    appId: appId,
    meta: meta,
  );

  final String backendId;
  final String? workingDirectory;
  final String? intentText;
  final bool testMode;
  final List<LiveEditAgentBackend>? availableBackends;
  final bool enableRuntimeRefresh;
  final bool enableWebSemantics;
  final String? appId;
  final Map<String, Object?> meta;

  String? get hostWorkingDirectory =>
      testMode ? null : _trimToNull(workingDirectory);

  String get hostIntentText {
    final explicit = _trimToNull(intentText);
    if (explicit != null) {
      return explicit;
    }
    return testMode
        ? 'Persist live-edit changes for the selected deterministic test fixture.'
        : 'Persist the requested live-edit change in the selected source file.';
  }

  FlutterLiveEditAutoConfig copyWith({
    final String? backendId,
    final String? workingDirectory,
    final String? intentText,
    final bool? testMode,
    final List<LiveEditAgentBackend>? availableBackends,
    final bool? enableRuntimeRefresh,
    final bool? enableWebSemantics,
    final String? appId,
    final Map<String, Object?>? meta,
  }) => FlutterLiveEditAutoConfig(
    backendId: backendId ?? this.backendId,
    workingDirectory: workingDirectory ?? this.workingDirectory,
    intentText: intentText ?? this.intentText,
    testMode: testMode ?? this.testMode,
    availableBackends: availableBackends ?? this.availableBackends,
    enableRuntimeRefresh: enableRuntimeRefresh ?? this.enableRuntimeRefresh,
    enableWebSemantics: enableWebSemantics ?? this.enableWebSemantics,
    appId: appId ?? this.appId,
    meta: meta ?? this.meta,
  );
}

String? _trimToNull(final String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
