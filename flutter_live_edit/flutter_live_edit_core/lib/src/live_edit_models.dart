import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_edit_models.freezed.dart';
part 'live_edit_models.g.dart';

const _mapEquality = MapEquality<String, Object?>();

List<Object?> decodeLiveEditJsonList(final String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('Expected JSON list');
  }
  return decoded.cast<Object?>();
}

Map<String, Object?> decodeLiveEditJsonObject(final String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('Expected JSON object');
  }
  return _asMap(decoded);
}

String encodeLiveEditJson(final Map<String, Object?> value) =>
    jsonEncode(value);

bool liveEditJsonMapsEqual(
  final Map<String, Object?> left,
  final Map<String, Object?> right,
) => _mapEquality.equals(left, right);

double _asDouble(final Object? value, {final double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? fallback;
}

List<Object?> _asList(final Object? value) {
  if (value is List<Object?>) {
    return value;
  }
  if (value is List) {
    return value.cast<Object?>();
  }
  return const <Object?>[];
}

Map<String, Object?> _asMap(final Object? value) {
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

int? _asNullableInt(final Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse('$value');
}

String? _asNullableString(final Object? value) {
  final stringValue = '$value'.trim();
  if (value == null || stringValue.isEmpty || stringValue == 'null') {
    return null;
  }
  return stringValue;
}

List<String> _asStringList(final Object? value) => _asList(
  value,
).map((final item) => '$item').where((final item) => item.isNotEmpty).toList();

String? _normalizeCodexModel(final String? value) {
  final normalized = _asNullableString(value)?.toLowerCase();
  return normalized;
}

String? _normalizeCodexReasoningEffort(final String? value) {
  final normalized = _asNullableString(value)?.toLowerCase();
  return switch (normalized) {
    null => null,
    'middle' => 'medium',
    _ => normalized,
  };
}

LiveEditInferenceConfig? _parseInferenceConfig(final Object? value) {
  if (value == null) return null;
  if (value is Map<String, Object?>) {
    return LiveEditInferenceConfig.fromJson(value);
  }
  if (value is Map) {
    return LiveEditInferenceConfig.fromJson(
      value.map((final k, final v) => MapEntry('$k', v)),
    );
  }
  return null;
}

/// Alias for backward compatibility; prefer [LiveEditInferenceConfig].
typedef LiveEditCodexConfig = LiveEditInferenceConfig;

@Freezed(fromJson: true, toJson: true)
class LiveEditAgentBackend with _$LiveEditAgentBackend {
  const factory LiveEditAgentBackend({
    required final String id,
    required final String label,
    required final String description,
    required final bool available,
    @Default(false) final bool isDefault,
    @Default(<String, Object?>{}) final Map<String, Object?> meta,
  }) = _LiveEditAgentBackend;

  factory LiveEditAgentBackend.fromJson(final Map<String, Object?> json) =>
      _$LiveEditAgentBackendFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
class LiveEditBounds with _$LiveEditBounds {
  const factory LiveEditBounds({
    required final double left,
    required final double top,
    required final double right,
    required final double bottom,
    required final double width,
    required final double height,
  }) = _LiveEditBounds;

  factory LiveEditBounds.fromJson(final Map<String, Object?> json) =>
      _$LiveEditBoundsFromJson(json);
}

enum LiveEditBubbleDisplayState {
  expanded('expanded'),
  minimized('minimized');

  const LiveEditBubbleDisplayState(this.wireName);

  final String wireName;

  static LiveEditBubbleDisplayState fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditBubbleDisplayState.values.firstWhere(
      (final state) => state.wireName == normalized,
      orElse: () => LiveEditBubbleDisplayState.expanded,
    );
  }
}

@Freezed(fromJson: true, toJson: true)
class LiveEditCodexModelOption with _$LiveEditCodexModelOption {
  const factory LiveEditCodexModelOption({
    required final String id,
    required final String label,
  }) = _LiveEditCodexModelOption;

  factory LiveEditCodexModelOption.fromJson(final Map<String, Object?> json) =>
      _$LiveEditCodexModelOptionFromJson(json);
}

final class LiveEditCodexOptions {
  const LiveEditCodexOptions._();

  static const List<LiveEditCodexModelOption> supportedModels =
      <LiveEditCodexModelOption>[
        LiveEditCodexModelOption(id: 'gpt-5.4', label: 'GPT-5.4'),
        LiveEditCodexModelOption(id: 'gpt-5.3-codex', label: 'GPT-5.3-Codex'),
        LiveEditCodexModelOption(
          id: 'gpt-5.3-codex-spark',
          label: 'GPT-5.3-Codex-Spark',
        ),
      ];

  static const List<String> supportedReasoningEfforts = <String>[
    'low',
    'medium',
    'high',
  ];

  static bool isSupportedReasoningEffort(final String value) =>
      supportedReasoningEfforts.contains(_normalizeCodexReasoningEffort(value));

  static LiveEditCodexConfig? normalizeConfig(
    final LiveEditCodexConfig? value,
  ) {
    if (value == null) {
      return null;
    }
    final normalized = value.normalized();
    return normalized.isEmpty ? null : normalized;
  }
}

double _confidenceFromJson(final Object? v) => _asDouble(v, fallback: 1);

@Freezed(fromJson: true, toJson: true)
class LiveEditDraftChange with _$LiveEditDraftChange {
  const factory LiveEditDraftChange({
    required final String nodeId,
    required final String propertyId,
    required final Object? targetValue,
    @Default(LiveEditPreviewMode.none) final LiveEditPreviewMode previewMode,
    @JsonKey(fromJson: _confidenceFromJson) @Default(1) final double confidence,
    final String? intentText,
    @Default(<String, Object?>{}) final Map<String, Object?> meta,
  }) = _LiveEditDraftChange;

  factory LiveEditDraftChange.fromJson(final Map<String, Object?> json) =>
      _$LiveEditDraftChangeFromJson(json);
}

enum LiveEditEditMode {
  inspect('inspect'),
  edit('edit'),
  ai('ai');

  const LiveEditEditMode(this.wireName);

  final String wireName;

  static LiveEditEditMode fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditEditMode.values.firstWhere(
      (final mode) => mode.wireName == normalized,
      orElse: () => LiveEditEditMode.inspect,
    );
  }
}

enum LiveEditTargetDomain {
  appScene('app_scene'),
  toolScene('tool_scene');

  const LiveEditTargetDomain(this.wireName);

  final String wireName;

  static LiveEditTargetDomain fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditTargetDomain.values.firstWhere(
      (final domain) => domain.wireName == normalized,
      orElse: () => LiveEditTargetDomain.appScene,
    );
  }
}

enum LiveEditEditSurface {
  inline('inline'),
  panel('panel'),
  aiBubble('aiBubble');

  const LiveEditEditSurface(this.wireName);

  final String wireName;

  static LiveEditEditSurface fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditEditSurface.values.firstWhere(
      (final surface) => surface.wireName.toLowerCase() == normalized,
      orElse: () => LiveEditEditSurface.panel,
    );
  }
}

enum LiveEditApplyMode {
  singleBubble('single_bubble'),
  applyAll('apply_all');

  const LiveEditApplyMode(this.wireName);

  final String wireName;

  static LiveEditApplyMode fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditApplyMode.values.firstWhere(
      (final mode) => mode.wireName == normalized,
      orElse: () => LiveEditApplyMode.singleBubble,
    );
  }
}

String _agentInstructionFromJsonMap(final Map<String, Object?> json) =>
    '${json['agentInstruction'] ?? json['shortAgentInstruction'] ?? ''}';

final class LiveEditExecutionPlan {
  const LiveEditExecutionPlan({
    required this.proposalId,
    required this.title,
    required this.summary,
    required this.selectedNode,
    required this.requestedChanges,
    required this.affectedFiles,
    required this.agentInstruction,
    this.confidence = 0,
    this.riskNotes = const <String>[],
    this.meta = const <String, Object?>{},
  });

  factory LiveEditExecutionPlan.fromJson(final Map<String, Object?> json) =>
      LiveEditExecutionPlan(
        proposalId: '${json['proposalId'] ?? ''}',
        title: '${json['title'] ?? ''}',
        summary: '${json['summary'] ?? ''}',
        selectedNode: '${json['selectedNode'] ?? ''}',
        requestedChanges: _asStringList(json['requestedChanges']),
        affectedFiles: _asStringList(json['affectedFiles']),
        confidence: _asDouble(json['confidence']),
        riskNotes: _asStringList(json['riskNotes']),
        agentInstruction: _agentInstructionFromJsonMap(json),
        meta: _asMap(json['meta']),
      );

  final String proposalId;
  final String title;
  final String summary;
  final String selectedNode;
  final List<String> requestedChanges;
  final List<String> affectedFiles;
  final double confidence;
  final List<String> riskNotes;
  final String agentInstruction;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'proposalId': proposalId,
    'title': title,
    'summary': summary,
    'selectedNode': selectedNode,
    'requestedChanges': requestedChanges,
    'affectedFiles': affectedFiles,
    'confidence': confidence,
    'riskNotes': riskNotes,
    'agentInstruction': agentInstruction,
    'shortAgentInstruction': agentInstruction,
    'meta': meta,
  };
}

@Freezed(fromJson: true, toJson: true)
class LiveEditFilePatch with _$LiveEditFilePatch {
  const factory LiveEditFilePatch({
    required final String path,
    required final String content,
    required final String patch,
    @Default(<String, Object?>{}) final Map<String, Object?> meta,
  }) = _LiveEditFilePatch;

  factory LiveEditFilePatch.fromJson(final Map<String, Object?> json) =>
      _$LiveEditFilePatchFromJson(json);
}

@Freezed(fromJson: false, toJson: false)
class LiveEditInferenceConfig with _$LiveEditInferenceConfig {
  const factory LiveEditInferenceConfig({
    final String? model,
    final String? reasoningEffort,
  }) = _LiveEditInferenceConfig;
  const LiveEditInferenceConfig._();

  factory LiveEditInferenceConfig.fromJson(final Map<String, Object?> json) =>
      LiveEditInferenceConfig(
        model: _normalizeCodexModel(_asNullableString(json['model'])),
        reasoningEffort: _normalizeCodexReasoningEffort(
          _asNullableString(json['reasoningEffort']),
        ),
      );

  bool get isEmpty => model == null && reasoningEffort == null;

  LiveEditInferenceConfig normalized() => LiveEditInferenceConfig(
    model: _normalizeCodexModel(model),
    reasoningEffort: _normalizeCodexReasoningEffort(reasoningEffort),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    if (model != null) 'model': model,
    if (reasoningEffort != null) 'reasoningEffort': reasoningEffort,
  };
}

enum LiveEditRuntimeAction {
  none('none'),
  hotReload('hot_reload'),
  hotRestart('hot_restart');

  const LiveEditRuntimeAction(this.wireName);

  final String wireName;

  static LiveEditRuntimeAction fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditRuntimeAction.values.firstWhere(
      (final action) => action.wireName == normalized,
      orElse: () => LiveEditRuntimeAction.none,
    );
  }
}

@Freezed(fromJson: true, toJson: true)
class LiveEditRuntimeRefreshResult with _$LiveEditRuntimeRefreshResult {
  const factory LiveEditRuntimeRefreshResult({
    @Default(LiveEditRuntimeAction.none) final LiveEditRuntimeAction action,
    @Default(<String, Object?>{}) final Map<String, Object?> validation,
    @Default(<String, Object?>{}) final Map<String, Object?> hotReload,
    @Default(<String, Object?>{}) final Map<String, Object?> hotRestart,
    @Default(<String, Object?>{}) final Map<String, Object?> validationRecovery,
  }) = _LiveEditRuntimeRefreshResult;
  const LiveEditRuntimeRefreshResult._();

  factory LiveEditRuntimeRefreshResult.fromJson(
    final Map<String, Object?> json,
  ) => _$LiveEditRuntimeRefreshResultFromJson(json);

  bool get didRefresh => action != LiveEditRuntimeAction.none;
}

enum LiveEditPreviewMode {
  exact('exact'),
  ghost('ghost'),
  none('none');

  const LiveEditPreviewMode(this.wireName);

  final String wireName;

  static LiveEditPreviewMode fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditPreviewMode.values.firstWhere(
      (final mode) => mode.wireName == normalized,
      orElse: () => LiveEditPreviewMode.none,
    );
  }
}

@Freezed(fromJson: true, toJson: true)
class LiveEditResolutionProposal with _$LiveEditResolutionProposal {
  const factory LiveEditResolutionProposal({
    required final String proposalId,
    required final String backendId,
    required final String summary,
    required final String patch,
    required final List<String> changedFiles,
    required final List<LiveEditFilePatch> filePatches,
    required final List<String> expectedRuntimeEffects,
    required final List<String> validationSteps,
    @Default(<String>[]) final List<String> warnings,
    @Default(<String>[]) final List<String> riskFlags,
    @Default(<String, Object?>{}) final Map<String, Object?> meta,
  }) = _LiveEditResolutionProposal;

  factory LiveEditResolutionProposal.fromJson(
    final Map<String, Object?> json,
  ) => _$LiveEditResolutionProposalFromJson(json);
}

@Freezed(fromJson: false, toJson: false)
class LiveEditResolutionRequest with _$LiveEditResolutionRequest {
  const factory LiveEditResolutionRequest({
    required final String sessionId,
    required final String workingDirectory,
    final String? bubbleId,
    final String? instructionText,
    final LiveEditSelection? primarySelection,
    @Default(<LiveEditSelection>[])
    final List<LiveEditSelection> selectedWidgets,
    @Default(<LiveEditSourceTarget>[])
    final List<LiveEditSourceTarget> sourceTargets,
    @Default(LiveEditApplyMode.singleBubble) final LiveEditApplyMode applyMode,
    final LiveEditSelection? selection,
    final String? backendId,
    final LiveEditInferenceConfig? inferenceConfig,
    final String? intentText,
    @Default(<String, Object?>{}) final Map<String, Object?> evidence,
    @Default(<String, Object?>{}) final Map<String, Object?> meta,
  }) = _LiveEditResolutionRequest;
  const LiveEditResolutionRequest._();

  factory LiveEditResolutionRequest.fromJson(final Map<String, Object?> json) {
    final inferenceConfig = _parseInferenceConfig(
      json['inferenceConfig'] ?? json['codexConfig'],
    );
    return LiveEditResolutionRequest(
      sessionId: '${json['sessionId'] ?? ''}',
      workingDirectory: '${json['workingDirectory'] ?? ''}',
      bubbleId: _asNullableString(json['bubbleId']),
      instructionText: _asNullableString(
        json['instructionText'] ?? json['intentText'],
      ),
      primarySelection: switch (json['primarySelection']) {
        final Map value => LiveEditSelection.fromJson(_asMap(value)),
        _ => null,
      },
      selectedWidgets: _asList(json['selectedWidgets'])
          .whereType<Map>()
          .map((final item) => LiveEditSelection.fromJson(_asMap(item)))
          .toList(growable: false),
      sourceTargets: _asList(json['sourceTargets'])
          .whereType<Map>()
          .map((final item) => LiveEditSourceTarget.fromJson(_asMap(item)))
          .toList(growable: false),
      applyMode: LiveEditApplyMode.fromWire(json['applyMode']),
      selection: switch (json['selection']) {
        final Map value => LiveEditSelection.fromJson(_asMap(value)),
        _ => null,
      },
      backendId: _asNullableString(json['backendId']),
      inferenceConfig: inferenceConfig,
      intentText: _asNullableString(json['intentText']),
      evidence: _asMap(json['evidence']),
      meta: _asMap(json['meta']),
    );
  }

  String? get effectiveBubbleId => _asNullableString(bubbleId);
  String? get effectiveInstructionText =>
      _asNullableString(instructionText) ?? _asNullableString(intentText);
  LiveEditSelection? get effectivePrimarySelection =>
      primarySelection ?? selection;
  List<LiveEditSelection> get effectiveSelectedWidgets {
    if (selectedWidgets.isNotEmpty) return selectedWidgets;
    final primary = effectivePrimarySelection;
    return primary == null
        ? const <LiveEditSelection>[]
        : <LiveEditSelection>[primary];
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'sessionId': sessionId,
    'workingDirectory': workingDirectory,
    if (bubbleId != null) 'bubbleId': bubbleId,
    if (instructionText != null) 'instructionText': instructionText,
    if (primarySelection != null)
      'primarySelection': primarySelection!.toJson(),
    if (selectedWidgets.isNotEmpty)
      'selectedWidgets': selectedWidgets.map((final s) => s.toJson()).toList(),
    if (sourceTargets.isNotEmpty)
      'sourceTargets': sourceTargets.map((final t) => t.toJson()).toList(),
    'applyMode': applyMode.wireName,
    if (selection != null) 'selection': selection!.toJson(),
    if (backendId != null) 'backendId': backendId,
    if (inferenceConfig != null) 'inferenceConfig': inferenceConfig!.toJson(),
    if (intentText != null) 'intentText': intentText,
    'evidence': evidence,
    'meta': meta,
  };
}

@Freezed(fromJson: true, toJson: true)
class LiveEditSourceTarget with _$LiveEditSourceTarget {
  const factory LiveEditSourceTarget({
    required final String nodeId,
    required final String widgetType,
    final String? absolutePath,
    final String? workspacePath,
    final int? line,
    final int? column,
  }) = _LiveEditSourceTarget;

  factory LiveEditSourceTarget.fromJson(final Map<String, Object?> json) =>
      _$LiveEditSourceTargetFromJson(json);
}

final class LiveEditDirectApplyResult {
  const LiveEditDirectApplyResult({
    required this.executionId,
    required this.backendId,
    required this.summary,
    this.changedFiles = const <String>[],
    this.warnings = const <String>[],
    this.validationSteps = const <String>[],
    this.runtimeRefresh,
    this.meta = const <String, Object?>{},
  });

  factory LiveEditDirectApplyResult.fromJson(final Map<String, Object?> json) =>
      LiveEditDirectApplyResult(
        executionId: '${json['executionId'] ?? json['proposalId'] ?? ''}',
        backendId: '${json['backendId'] ?? ''}',
        summary: '${json['summary'] ?? ''}',
        changedFiles: _asStringList(json['changedFiles']),
        warnings: _asStringList(json['warnings']),
        validationSteps: _asStringList(json['validationSteps']),
        runtimeRefresh: switch (json['runtimeRefresh']) {
          final Map value => LiveEditRuntimeRefreshResult.fromJson(
            _asMap(value),
          ),
          _ => null,
        },
        meta: _asMap(json['meta']),
      );

  final String executionId;
  final String backendId;
  final String summary;
  final List<String> changedFiles;
  final List<String> warnings;
  final List<String> validationSteps;
  final LiveEditRuntimeRefreshResult? runtimeRefresh;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'executionId': executionId,
    'backendId': backendId,
    'summary': summary,
    'changedFiles': changedFiles,
    'warnings': warnings,
    'validationSteps': validationSteps,
    if (runtimeRefresh != null) 'runtimeRefresh': runtimeRefresh!.toJson(),
    'meta': meta,
    'proposalId': executionId,
  };
}

@Freezed(fromJson: true, toJson: true)
class LiveEditResolutionResult with _$LiveEditResolutionResult {
  const factory LiveEditResolutionResult({
    required final String proposalId,
    required final LiveEditResolutionStatus status,
    @Default(<String>[]) final List<String> changedFiles,
    @Default(<String, Object?>{}) final Map<String, Object?> validation,
    @Default(<String>[]) final List<String> warnings,
    @Default(<String, Object?>{}) final Map<String, Object?> meta,
  }) = _LiveEditResolutionResult;

  factory LiveEditResolutionResult.fromJson(final Map<String, Object?> json) =>
      _$LiveEditResolutionResultFromJson(json);
}

enum LiveEditResolutionStatus {
  proposed('proposed'),
  accepted('accepted'),
  rejected('rejected'),
  applied('applied'),
  failed('failed');

  const LiveEditResolutionStatus(this.wireName);

  final String wireName;

  static LiveEditResolutionStatus fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditResolutionStatus.values.firstWhere(
      (final status) => status.wireName == normalized,
      orElse: () => LiveEditResolutionStatus.proposed,
    );
  }
}

final class LiveEditRuntimeToolNames {
  const LiveEditRuntimeToolNames._();

  static const String startSession = 'live_edit_runtime_start_session';
  static const String setOverlay = 'live_edit_runtime_set_overlay';
  static const String getTree = 'live_edit_runtime_get_tree';
  static const String selectAtPoint = 'select_widget_at_point';
  static const String getSelection = 'live_edit_runtime_get_selection';
  static const String updateDraft = 'live_edit_runtime_update_draft';
  static const String getDraft = 'live_edit_runtime_get_draft';
  static const String discardDraft = 'live_edit_runtime_discard_draft';
  static const String endSession = 'live_edit_runtime_end_session';
}

@Freezed(fromJson: true, toJson: true)
class LiveEditSelection with _$LiveEditSelection {
  const factory LiveEditSelection({
    required final String sessionId,
    required final String nodeId,
    required final String widgetType,
    @JsonKey(fromJson: _asMap) required final Map<String, Object?> rawNode,
    @JsonKey(name: 'properties')
    @Default(<Object?>[])
    final List<Object?> propertiesForWire,
    @Default(LiveEditTargetDomain.appScene)
    final LiveEditTargetDomain targetDomain,
    final String? renderObjectType,
    final LiveEditBounds? bounds,
    final LiveEditSourceLocation? source,
    @Default(<String, Object?>{}) final Map<String, Object?> layoutContext,
    @Default(<Map<String, Object?>>[])
    final List<Map<String, Object?>> parentChain,
    @Default(<String, Object?>{}) final Map<String, Object?> detailsTree,
    @Default(<String, Object?>{}) final Map<String, Object?> propertiesTree,
    @Default(LiveEditSelectionMode.single)
    final LiveEditSelectionMode selectionMode,
    @Default(<String>[]) final List<String> selectedNodeIds,
  }) = _LiveEditSelection;

  factory LiveEditSelection.fromJson(final Map<String, Object?> json) {
    final map = Map<String, Object?>.from(json);
    map['properties'] = const <Object?>[];
    return _$LiveEditSelectionFromJson(map);
  }
}

int _depthFromJson(final Object? v) => _asNullableInt(v) ?? 0;

@Freezed(fromJson: true, toJson: true)
class LiveEditSelectionCandidate with _$LiveEditSelectionCandidate {
  const factory LiveEditSelectionCandidate({
    required final String nodeId,
    required final String widgetType,
    final LiveEditBounds? bounds,
    @JsonKey(fromJson: _depthFromJson) @Default(0) final int depth,
    final LiveEditSourceLocation? source,
    @Default(false) final bool createdByLocalProject,
    @Default(false) final bool active,
  }) = _LiveEditSelectionCandidate;

  factory LiveEditSelectionCandidate.fromJson(
    final Map<String, Object?> json,
  ) => _$LiveEditSelectionCandidateFromJson(json);
}

enum LiveEditSelectionMode {
  single('single'),
  multi('multi');

  const LiveEditSelectionMode(this.wireName);

  final String wireName;

  static LiveEditSelectionMode fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditSelectionMode.values.firstWhere(
      (final mode) => mode.wireName == normalized,
      orElse: () => LiveEditSelectionMode.single,
    );
  }
}

enum LiveEditSelectionPolicy {
  deepest('deepest'),
  nearestProjectAncestor('nearestProjectAncestor');

  const LiveEditSelectionPolicy(this.wireName);

  final String wireName;

  static LiveEditSelectionPolicy fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditSelectionPolicy.values.firstWhere(
      (final policy) => policy.wireName.toLowerCase() == normalized,
      orElse: () => LiveEditSelectionPolicy.deepest,
    );
  }
}

@Freezed(fromJson: true, toJson: true)
class LiveEditSourceLocation with _$LiveEditSourceLocation {
  const factory LiveEditSourceLocation({
    required final String file,
    final int? line,
    final int? column,
    final String? sourceHint,
  }) = _LiveEditSourceLocation;

  factory LiveEditSourceLocation.fromJson(final Map<String, Object?> json) =>
      _$LiveEditSourceLocationFromJson(json);
}
