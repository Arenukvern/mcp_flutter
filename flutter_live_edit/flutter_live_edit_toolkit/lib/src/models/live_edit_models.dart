import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:live_edit_tooling_ui_kit/src/models/models.dart';

import 'live_edit_interaction_models.dart';

part 'live_edit_models.freezed.dart';
part 'live_edit_models.g.dart';

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

double _asDouble(final Object? value, {final double fallback = 0}) =>
    jsonDecodeDouble(value).whenZeroUse(fallback);

List<Object?> _asList(final Object? value) => jsonDecodeListAs(value);

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

DraftTargetContext? _parseDraftTargetContext(final Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, Object?>) {
    return DraftTargetContext.fromJson(value);
  }
  if (value is Map) {
    return DraftTargetContext.fromJson(
      value.map(
        (final key, final nestedValue) => MapEntry('$key', nestedValue),
      ),
    );
  }
  return null;
}

Map<String, Object?>? _draftTargetContextToJson(
  final DraftTargetContext? value,
) => value?.toJson();

FlowSelectionIntent? _parseFlowSelectionIntent(final Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, Object?>) {
    return FlowSelectionIntent.fromJson(value);
  }
  if (value is Map) {
    return FlowSelectionIntent.fromJson(
      value.map(
        (final key, final nestedValue) => MapEntry('$key', nestedValue),
      ),
    );
  }
  return null;
}

Map<String, Object?>? _flowSelectionIntentToJson(
  final FlowSelectionIntent? value,
) => value?.toJson();

AgentContextEnvelope? _parseAgentContextEnvelope(final Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, Object?>) {
    return AgentContextEnvelope.fromJson(value);
  }
  if (value is Map) {
    return AgentContextEnvelope.fromJson(
      value.map(
        (final key, final nestedValue) => MapEntry('$key', nestedValue),
      ),
    );
  }
  return null;
}

Map<String, Object?>? _agentContextEnvelopeToJson(
  final AgentContextEnvelope? value,
) => value?.toJson();

@Freezed(fromJson: true, toJson: true)
abstract class LiveEditAgentBackend with _$LiveEditAgentBackend {
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
abstract class LiveEditCodexModelOption with _$LiveEditCodexModelOption {
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

  static LiveEditInferenceConfig? normalizeConfig(
    final LiveEditInferenceConfig? value,
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
abstract class LiveEditDraftChange with _$LiveEditDraftChange {
  const factory LiveEditDraftChange({
    required final String nodeId,
    required final String propertyId,
    required final Object? targetValue,
    @Default(LiveEditPreviewMode.none) final LiveEditPreviewMode previewMode,
    @JsonKey(fromJson: _confidenceFromJson) @Default(1) final double confidence,
    final String? intentText,
    @JsonKey(
      fromJson: _parseDraftTargetContext,
      toJson: _draftTargetContextToJson,
    )
    final DraftTargetContext? targetContext,
  }) = _LiveEditDraftChange;

  factory LiveEditDraftChange.fromJson(final Map<String, Object?> json) =>
      _$LiveEditDraftChangeFromJson(json);
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
    '${json['agentInstruction'] ?? ''}';

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
    'meta': meta,
  };
}

@Freezed(fromJson: true, toJson: true)
abstract class LiveEditFilePatch with _$LiveEditFilePatch {
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
abstract class LiveEditInferenceConfig with _$LiveEditInferenceConfig {
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
abstract class LiveEditRuntimeRefreshResult
    with _$LiveEditRuntimeRefreshResult {
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
abstract class LiveEditResolutionProposal with _$LiveEditResolutionProposal {
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
abstract class LiveEditResolutionRequest with _$LiveEditResolutionRequest {
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
    final String? backendId,
    final LiveEditInferenceConfig? inferenceConfig,
    @JsonKey(
      fromJson: _parseFlowSelectionIntent,
      toJson: _flowSelectionIntentToJson,
    )
    final FlowSelectionIntent? selectionIntent,
    @JsonKey(
      fromJson: _parseAgentContextEnvelope,
      toJson: _agentContextEnvelopeToJson,
    )
    final AgentContextEnvelope? contextEnvelope,
  }) = _LiveEditResolutionRequest;
  const LiveEditResolutionRequest._();

  factory LiveEditResolutionRequest.fromJson(final Map<String, Object?> json) {
    final inferenceConfig = _parseInferenceConfig(json['inferenceConfig']);
    return LiveEditResolutionRequest(
      sessionId: '${json['sessionId'] ?? ''}',
      workingDirectory: '${json['workingDirectory'] ?? ''}',
      bubbleId: _asNullableString(json['bubbleId']),
      instructionText: _asNullableString(json['instructionText']),
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
      backendId: _asNullableString(json['backendId']),
      inferenceConfig: inferenceConfig,
      selectionIntent: _parseFlowSelectionIntent(json['selectionIntent']),
      contextEnvelope: _parseAgentContextEnvelope(json['contextEnvelope']),
    );
  }

  String? get effectiveBubbleId => _asNullableString(bubbleId);
  String? get effectiveInstructionText => _asNullableString(instructionText);
  LiveEditSelection? get effectivePrimarySelection => primarySelection;
  List<LiveEditSelection> get effectiveSelectedWidgets {
    if (selectedWidgets.isNotEmpty) return selectedWidgets;
    final primary = primarySelection;
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
    if (backendId != null) 'backendId': backendId,
    if (inferenceConfig != null) 'inferenceConfig': inferenceConfig!.toJson(),
    if (selectionIntent != null) 'selectionIntent': selectionIntent!.toJson(),
    if (contextEnvelope != null) 'contextEnvelope': contextEnvelope!.toJson(),
  };
}

@Freezed(fromJson: true, toJson: true)
abstract class LiveEditSourceTarget with _$LiveEditSourceTarget {
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

@Freezed(fromJson: true, toJson: true)
abstract class LiveEditDirectApplyResult with _$LiveEditDirectApplyResult {
  const factory LiveEditDirectApplyResult({
    required final String executionId,
    required final String backendId,
    required final String summary,
    @Default(<String>[]) final List<String> changedFiles,
    @Default(<String>[]) final List<String> warnings,
    @Default(<String>[]) final List<String> validationSteps,
    final LiveEditRuntimeRefreshResult? runtimeRefresh,
    @Default(<String, Object?>{}) final Map<String, Object?> meta,
  }) = _LiveEditDirectApplyResult;

  factory LiveEditDirectApplyResult.fromJson(final Map<String, Object?> json) =>
      LiveEditDirectApplyResult(
        executionId: '${json['executionId'] ?? ''}',
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
}

@Freezed(fromJson: true, toJson: true)
abstract class LiveEditResolutionResult with _$LiveEditResolutionResult {
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

abstract class LiveEditRuntimeToolNames {
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

/// MCP tool names for the Flutter Inspector MCP server command catalog
/// (`mcp_server_dart`).
///
/// Wire strings for `CommandSpec.name`, MCP `Tool.name`, and executor routing.
/// In-app bridge tools use [LiveEditRuntimeToolNames] instead.
final class LiveEditMcpToolNames {
  const LiveEditMcpToolNames._();

  static const String acceptResolution = 'live_edit_accept_resolution';
  static const String applyDraft = 'live_edit_apply_draft';
  static const String discardDraft = 'live_edit_discard_draft';
  static const String endSession = 'live_edit_end_session';
  static const String getAgentBackend = 'live_edit_get_agent_backend';
  static const String getCapabilities = 'live_edit_get_capabilities';
  static const String getDraft = 'live_edit_get_draft';
  static const String getPreviewState = 'live_edit_get_preview_state';
  static const String getPropertyPanel = 'live_edit_get_property_panel';
  static const String getSelection = 'live_edit_get_selection';
  static const String getSelectionCandidates =
      'live_edit_get_selection_candidates';
  static const String getTree = 'live_edit_get_tree';
  static const String listAgentBackends = 'live_edit_list_agent_backends';
  static const String prepareSession = 'live_edit_prepare_session';
  static const String rejectResolution = 'live_edit_reject_resolution';
  static const String resolveDraft = 'live_edit_resolve_draft';
  static const String selectAtPoint = 'live_edit_select_at_point';
  static const String setActiveSelection = 'live_edit_set_active_selection';
  static const String setAgentBackend = 'live_edit_set_agent_backend';
  static const String setEditMode = 'live_edit_set_edit_mode';
  static const String setOverlay = 'live_edit_set_overlay';
  static const String startSession = 'live_edit_start_session';
  static const String updateDraft = 'live_edit_update_draft';

  /// Sorted lexicographically; used by contract tests to detect drift.
  static const List<String> allSorted = <String>[
    acceptResolution,
    applyDraft,
    discardDraft,
    endSession,
    getAgentBackend,
    getCapabilities,
    getDraft,
    getPreviewState,
    getPropertyPanel,
    getSelection,
    getSelectionCandidates,
    getTree,
    listAgentBackends,
    prepareSession,
    rejectResolution,
    resolveDraft,
    selectAtPoint,
    setActiveSelection,
    setAgentBackend,
    setEditMode,
    setOverlay,
    startSession,
    updateDraft,
  ];
}

@Freezed(fromJson: true, toJson: true)
abstract class LiveEditSelection with _$LiveEditSelection {
  const factory LiveEditSelection({
    required final String sessionId,
    @JsonKey(defaultValue: '') @Default('') final String selectionKey,
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
    map['selectionKey'] =
        _asNullableString(map['selectionKey'] ?? map['nodeId']) ?? '';
    return _$LiveEditSelectionFromJson(map);
  }
}

int _depthFromJson(final Object? v) => _asNullableInt(v) ?? 0;

@Freezed(fromJson: true, toJson: true)
abstract class LiveEditSelectionCandidate with _$LiveEditSelectionCandidate {
  const factory LiveEditSelectionCandidate({
    @JsonKey(defaultValue: '') @Default('') final String selectionKey,
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
  ) => _$LiveEditSelectionCandidateFromJson(<String, Object?>{
    ...json,
    'selectionKey':
        _asNullableString(json['selectionKey'] ?? json['nodeId']) ?? '',
  });
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
abstract class LiveEditSourceLocation with _$LiveEditSourceLocation {
  const factory LiveEditSourceLocation({
    required final String file,
    final int? line,
    final int? column,
    final String? sourceHint,
  }) = _LiveEditSourceLocation;

  factory LiveEditSourceLocation.fromJson(final Map<String, Object?> json) =>
      _$LiveEditSourceLocationFromJson(json);
}

enum LiveEditProtocolVersion {
  v2('live_edit_protocol/v2');

  const LiveEditProtocolVersion(this.wireName);

  final String wireName;

  static LiveEditProtocolVersion fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditProtocolVersion.values.firstWhere(
      (final version) => version.wireName == normalized,
      orElse: () => LiveEditProtocolVersion.v2,
    );
  }
}

enum LiveEditProtocolCompatibilityMode {
  nativeV2('native_v2'),
  pointBubbleV1('point_bubble_v1');

  const LiveEditProtocolCompatibilityMode(this.wireName);

  final String wireName;

  static LiveEditProtocolCompatibilityMode fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditProtocolCompatibilityMode.values.firstWhere(
      (final mode) => mode.wireName == normalized,
      orElse: () => LiveEditProtocolCompatibilityMode.nativeV2,
    );
  }
}

enum LiveEditTargetKindV2 {
  screen('screen'),
  widget('widget'),
  animation('animation'),
  state('state');

  const LiveEditTargetKindV2(this.wireName);

  final String wireName;

  static LiveEditTargetKindV2 fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditTargetKindV2.values.firstWhere(
      (final kind) => kind.wireName == normalized,
      orElse: () => LiveEditTargetKindV2.widget,
    );
  }
}

final class LiveEditTargetAddressV2 {
  const LiveEditTargetAddressV2({
    required this.kind,
    required this.key,
    this.screenId,
    this.widgetId,
    this.animationId,
    this.statePath,
    this.selectionKey,
    this.propertyPath = const <String>[],
    this.metadata = const <String, Object?>{},
  });

  factory LiveEditTargetAddressV2.fromJson(final Map<String, Object?> json) =>
      LiveEditTargetAddressV2(
        kind: LiveEditTargetKindV2.fromWire(json['kind']),
        key: '${json['key'] ?? ''}',
        screenId: _asNullableString(json['screenId']),
        widgetId: _asNullableString(json['widgetId']),
        animationId: _asNullableString(json['animationId']),
        statePath: _asNullableString(json['statePath']),
        selectionKey: _asNullableString(json['selectionKey']),
        propertyPath: _asStringList(json['propertyPath']),
        metadata: _asMap(json['metadata']),
      );

  final LiveEditTargetKindV2 kind;
  final String key;
  final String? screenId;
  final String? widgetId;
  final String? animationId;
  final String? statePath;
  final String? selectionKey;
  final List<String> propertyPath;
  final Map<String, Object?> metadata;

  String get stableAddress {
    final path = propertyPath
        .where((final segment) => segment.isNotEmpty)
        .join('.');
    if (path.isEmpty) {
      return '${kind.wireName}:$key';
    }
    return '${kind.wireName}:$key:$path';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wireName,
    'key': key,
    if (screenId != null) 'screenId': screenId,
    if (widgetId != null) 'widgetId': widgetId,
    if (animationId != null) 'animationId': animationId,
    if (statePath != null) 'statePath': statePath,
    if (selectionKey != null) 'selectionKey': selectionKey,
    if (propertyPath.isNotEmpty) 'propertyPath': propertyPath,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

final class LiveEditIntentV2 {
  const LiveEditIntentV2({
    required this.intentId,
    required this.summary,
    this.author = 'unknown',
    this.issuedAtMs = 0,
    this.tags = const <String>[],
    this.metadata = const <String, Object?>{},
  });

  factory LiveEditIntentV2.fromJson(final Map<String, Object?> json) =>
      LiveEditIntentV2(
        intentId: '${json['intentId'] ?? ''}',
        summary: '${json['summary'] ?? ''}',
        author: _asNullableString(json['author']) ?? 'unknown',
        issuedAtMs: _asNullableInt(json['issuedAtMs']) ?? 0,
        tags: _asStringList(json['tags']),
        metadata: _asMap(json['metadata']),
      );

  final String intentId;
  final String summary;
  final String author;
  final int issuedAtMs;
  final List<String> tags;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'intentId': intentId,
    'summary': summary,
    'author': author,
    'issuedAtMs': issuedAtMs,
    if (tags.isNotEmpty) 'tags': tags,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

enum LiveEditPatchOpV2 {
  set('set'),
  add('add'),
  remove('remove'),
  replace('replace'),
  move('move');

  const LiveEditPatchOpV2(this.wireName);

  final String wireName;

  static LiveEditPatchOpV2 fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditPatchOpV2.values.firstWhere(
      (final op) => op.wireName == normalized,
      orElse: () => LiveEditPatchOpV2.set,
    );
  }
}

final class LiveEditPatchOperationV2 {
  const LiveEditPatchOperationV2({
    required this.operationId,
    required this.op,
    required this.path,
    this.value,
    this.fromPath,
    this.metadata = const <String, Object?>{},
  });

  factory LiveEditPatchOperationV2.fromJson(final Map<String, Object?> json) =>
      LiveEditPatchOperationV2(
        operationId: '${json['operationId'] ?? ''}',
        op: LiveEditPatchOpV2.fromWire(json['op']),
        path: '${json['path'] ?? ''}',
        value: json['value'],
        fromPath: _asNullableString(json['fromPath']),
        metadata: _asMap(json['metadata']),
      );

  final String operationId;
  final LiveEditPatchOpV2 op;
  final String path;
  final Object? value;
  final String? fromPath;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'operationId': operationId,
    'op': op.wireName,
    'path': path,
    if (value != null) 'value': value,
    if (fromPath != null) 'fromPath': fromPath,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

enum LiveEditValidationStatusV2 {
  pending('pending'),
  passed('passed'),
  failed('failed'),
  skipped('skipped');

  const LiveEditValidationStatusV2(this.wireName);

  final String wireName;

  static LiveEditValidationStatusV2 fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditValidationStatusV2.values.firstWhere(
      (final status) => status.wireName == normalized,
      orElse: () => LiveEditValidationStatusV2.pending,
    );
  }
}

final class LiveEditValidationStepV2 {
  const LiveEditValidationStepV2({
    required this.stepId,
    required this.description,
    this.required = true,
    this.status = LiveEditValidationStatusV2.pending,
    this.details = const <String, Object?>{},
  });

  factory LiveEditValidationStepV2.fromJson(final Map<String, Object?> json) =>
      LiveEditValidationStepV2(
        stepId: '${json['stepId'] ?? ''}',
        description: '${json['description'] ?? ''}',
        required: json['required'] == true,
        status: LiveEditValidationStatusV2.fromWire(json['status']),
        details: _asMap(json['details']),
      );

  final String stepId;
  final String description;
  final bool required;
  final LiveEditValidationStatusV2 status;
  final Map<String, Object?> details;

  bool get failed => status == LiveEditValidationStatusV2.failed;

  Map<String, Object?> toJson() => <String, Object?>{
    'stepId': stepId,
    'description': description,
    'required': required,
    'status': status.wireName,
    if (details.isNotEmpty) 'details': details,
  };
}

enum LiveEditApplyStatusV2 {
  pending('pending'),
  applied('applied'),
  failed('failed'),
  rolledBack('rolled_back'),
  skipped('skipped');

  const LiveEditApplyStatusV2(this.wireName);

  final String wireName;

  static LiveEditApplyStatusV2 fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditApplyStatusV2.values.firstWhere(
      (final status) => status.wireName == normalized,
      orElse: () => LiveEditApplyStatusV2.pending,
    );
  }
}

final class LiveEditApplyStateV2 {
  const LiveEditApplyStateV2({
    this.status = LiveEditApplyStatusV2.pending,
    this.appliedAtMs,
    this.runtimeAction = LiveEditRuntimeAction.none,
    this.details = const <String, Object?>{},
  });

  factory LiveEditApplyStateV2.fromJson(final Map<String, Object?> json) =>
      LiveEditApplyStateV2(
        status: LiveEditApplyStatusV2.fromWire(json['status']),
        appliedAtMs: _asNullableInt(json['appliedAtMs']),
        runtimeAction: LiveEditRuntimeAction.fromWire(json['runtimeAction']),
        details: _asMap(json['details']),
      );

  final LiveEditApplyStatusV2 status;
  final int? appliedAtMs;
  final LiveEditRuntimeAction runtimeAction;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.wireName,
    if (appliedAtMs != null) 'appliedAtMs': appliedAtMs,
    'runtimeAction': runtimeAction.wireName,
    if (details.isNotEmpty) 'details': details,
  };
}

enum LiveEditRollbackPolicyV2 {
  never('never'),
  onConflict('on_conflict'),
  onValidationFailure('on_validation_failure'),
  manual('manual');

  const LiveEditRollbackPolicyV2(this.wireName);

  final String wireName;

  static LiveEditRollbackPolicyV2 fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditRollbackPolicyV2.values.firstWhere(
      (final policy) => policy.wireName == normalized,
      orElse: () => LiveEditRollbackPolicyV2.onConflict,
    );
  }
}

final class LiveEditRollbackPlanV2 {
  const LiveEditRollbackPlanV2({
    this.policy = LiveEditRollbackPolicyV2.onConflict,
    this.reason = '',
    this.triggered = false,
    this.compensationPatch = const <LiveEditPatchOperationV2>[],
    this.metadata = const <String, Object?>{},
  });

  factory LiveEditRollbackPlanV2.fromJson(final Map<String, Object?> json) =>
      LiveEditRollbackPlanV2(
        policy: LiveEditRollbackPolicyV2.fromWire(json['policy']),
        reason: '${json['reason'] ?? ''}',
        triggered: json['triggered'] == true,
        compensationPatch: _asList(json['compensationPatch'])
            .whereType<Map>()
            .map(
              (final value) => LiveEditPatchOperationV2.fromJson(_asMap(value)),
            )
            .toList(growable: false),
        metadata: _asMap(json['metadata']),
      );

  final LiveEditRollbackPolicyV2 policy;
  final String reason;
  final bool triggered;
  final List<LiveEditPatchOperationV2> compensationPatch;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'policy': policy.wireName,
    if (reason.isNotEmpty) 'reason': reason,
    'triggered': triggered,
    if (compensationPatch.isNotEmpty)
      'compensationPatch': compensationPatch
          .map((final operation) => operation.toJson())
          .toList(growable: false),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

enum LiveEditConflictKindV2 {
  none('none'),
  staleBaseRevision('stale_base_revision'),
  overlappingTarget('overlapping_target'),
  sequenceMismatch('sequence_mismatch');

  const LiveEditConflictKindV2(this.wireName);

  final String wireName;

  static LiveEditConflictKindV2 fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditConflictKindV2.values.firstWhere(
      (final kind) => kind.wireName == normalized,
      orElse: () => LiveEditConflictKindV2.none,
    );
  }
}

final class LiveEditConflictV2 {
  const LiveEditConflictV2({
    required this.kind,
    required this.message,
    this.conflictingTransactionId,
    this.targetAddresses = const <String>[],
    this.metadata = const <String, Object?>{},
  });

  factory LiveEditConflictV2.fromJson(final Map<String, Object?> json) =>
      LiveEditConflictV2(
        kind: LiveEditConflictKindV2.fromWire(json['kind']),
        message: '${json['message'] ?? ''}',
        conflictingTransactionId: _asNullableString(
          json['conflictingTransactionId'],
        ),
        targetAddresses: _asStringList(json['targetAddresses']),
        metadata: _asMap(json['metadata']),
      );

  final LiveEditConflictKindV2 kind;
  final String message;
  final String? conflictingTransactionId;
  final List<String> targetAddresses;
  final Map<String, Object?> metadata;

  bool get isConflict => kind != LiveEditConflictKindV2.none;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wireName,
    'message': message,
    if (conflictingTransactionId != null)
      'conflictingTransactionId': conflictingTransactionId,
    if (targetAddresses.isNotEmpty) 'targetAddresses': targetAddresses,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

enum LiveEditEditNodeKindV2 {
  intent('intent'),
  target('target'),
  patch('patch'),
  validation('validation'),
  apply('apply'),
  rollback('rollback');

  const LiveEditEditNodeKindV2(this.wireName);

  final String wireName;

  static LiveEditEditNodeKindV2 fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditEditNodeKindV2.values.firstWhere(
      (final kind) => kind.wireName == normalized,
      orElse: () => LiveEditEditNodeKindV2.intent,
    );
  }
}

enum LiveEditEditNodeStatusV2 {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  failed('failed');

  const LiveEditEditNodeStatusV2(this.wireName);

  final String wireName;

  static LiveEditEditNodeStatusV2 fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditEditNodeStatusV2.values.firstWhere(
      (final status) => status.wireName == normalized,
      orElse: () => LiveEditEditNodeStatusV2.pending,
    );
  }
}

final class LiveEditEditNodeV2 {
  const LiveEditEditNodeV2({
    required this.nodeId,
    required this.kind,
    this.status = LiveEditEditNodeStatusV2.pending,
    this.dependsOn = const <String>[],
    this.payload = const <String, Object?>{},
  });

  factory LiveEditEditNodeV2.fromJson(final Map<String, Object?> json) =>
      LiveEditEditNodeV2(
        nodeId: '${json['nodeId'] ?? ''}',
        kind: LiveEditEditNodeKindV2.fromWire(json['kind']),
        status: LiveEditEditNodeStatusV2.fromWire(json['status']),
        dependsOn: _asStringList(json['dependsOn']),
        payload: _asMap(json['payload']),
      );

  final String nodeId;
  final LiveEditEditNodeKindV2 kind;
  final LiveEditEditNodeStatusV2 status;
  final List<String> dependsOn;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
    'nodeId': nodeId,
    'kind': kind.wireName,
    'status': status.wireName,
    if (dependsOn.isNotEmpty) 'dependsOn': dependsOn,
    if (payload.isNotEmpty) 'payload': payload,
  };
}

final class LiveEditEditGraphV2 {
  const LiveEditEditGraphV2({required this.nodes});

  factory LiveEditEditGraphV2.fromJson(final Map<String, Object?> json) =>
      LiveEditEditGraphV2(
        nodes: _asList(json['nodes'])
            .whereType<Map>()
            .map((final value) => LiveEditEditNodeV2.fromJson(_asMap(value)))
            .toList(growable: false),
      );

  factory LiveEditEditGraphV2.linear() => const LiveEditEditGraphV2(
    nodes: <LiveEditEditNodeV2>[
      LiveEditEditNodeV2(nodeId: 'intent', kind: LiveEditEditNodeKindV2.intent),
      LiveEditEditNodeV2(
        nodeId: 'target',
        kind: LiveEditEditNodeKindV2.target,
        dependsOn: <String>['intent'],
      ),
      LiveEditEditNodeV2(
        nodeId: 'patch',
        kind: LiveEditEditNodeKindV2.patch,
        dependsOn: <String>['target'],
      ),
      LiveEditEditNodeV2(
        nodeId: 'validation',
        kind: LiveEditEditNodeKindV2.validation,
        dependsOn: <String>['patch'],
      ),
      LiveEditEditNodeV2(
        nodeId: 'apply',
        kind: LiveEditEditNodeKindV2.apply,
        dependsOn: <String>['validation'],
      ),
      LiveEditEditNodeV2(
        nodeId: 'rollback',
        kind: LiveEditEditNodeKindV2.rollback,
        dependsOn: <String>['apply'],
      ),
    ],
  );

  final List<LiveEditEditNodeV2> nodes;

  Map<String, Object?> toJson() => <String, Object?>{
    'nodes': nodes.map((final node) => node.toJson()).toList(growable: false),
  };
}

enum LiveEditTransportEventTypeV2 {
  transactionOpened('transaction_opened'),
  nodeStatusChanged('node_status_changed'),
  conflictDetected('conflict_detected'),
  rollbackTriggered('rollback_triggered'),
  rollbackCompleted('rollback_completed'),
  projectionUpdated('projection_updated');

  const LiveEditTransportEventTypeV2(this.wireName);

  final String wireName;

  static LiveEditTransportEventTypeV2 fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditTransportEventTypeV2.values.firstWhere(
      (final type) => type.wireName == normalized,
      orElse: () => LiveEditTransportEventTypeV2.transactionOpened,
    );
  }
}

final class LiveEditTransportEventV2 {
  const LiveEditTransportEventV2({
    required this.eventId,
    required this.sessionId,
    required this.transactionId,
    required this.sequence,
    required this.timestampMs,
    required this.type,
    this.payload = const <String, Object?>{},
  });

  factory LiveEditTransportEventV2.fromJson(final Map<String, Object?> json) =>
      LiveEditTransportEventV2(
        eventId: '${json['eventId'] ?? ''}',
        sessionId: '${json['sessionId'] ?? ''}',
        transactionId: '${json['transactionId'] ?? ''}',
        sequence: _asNullableInt(json['sequence']) ?? 0,
        timestampMs: _asNullableInt(json['timestampMs']) ?? 0,
        type: LiveEditTransportEventTypeV2.fromWire(json['type']),
        payload: _asMap(json['payload']),
      );

  final String eventId;
  final String sessionId;
  final String transactionId;
  final int sequence;
  final int timestampMs;
  final LiveEditTransportEventTypeV2 type;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
    'eventId': eventId,
    'sessionId': sessionId,
    'transactionId': transactionId,
    'sequence': sequence,
    'timestampMs': timestampMs,
    'type': type.wireName,
    if (payload.isNotEmpty) 'payload': payload,
  };
}

final class LiveEditPointBubbleProjectionV2 {
  const LiveEditPointBubbleProjectionV2({
    required this.bubbleId,
    required this.transactionId,
    required this.targetAddress,
    required this.status,
    this.summary = '',
    this.pendingPatchCount = 0,
  });

  factory LiveEditPointBubbleProjectionV2.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditPointBubbleProjectionV2(
    bubbleId: '${json['bubbleId'] ?? ''}',
    transactionId: '${json['transactionId'] ?? ''}',
    targetAddress: '${json['targetAddress'] ?? ''}',
    status: '${json['status'] ?? ''}',
    summary: '${json['summary'] ?? ''}',
    pendingPatchCount: _asNullableInt(json['pendingPatchCount']) ?? 0,
  );

  final String bubbleId;
  final String transactionId;
  final String targetAddress;
  final String status;
  final String summary;
  final int pendingPatchCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'bubbleId': bubbleId,
    'transactionId': transactionId,
    'targetAddress': targetAddress,
    'status': status,
    'summary': summary,
    'pendingPatchCount': pendingPatchCount,
  };
}

final class LiveEditTimelineProjectionEntryV2 {
  const LiveEditTimelineProjectionEntryV2({
    required this.eventId,
    required this.transactionId,
    required this.label,
    required this.timestampMs,
    this.detail = '',
    this.state = '',
  });

  factory LiveEditTimelineProjectionEntryV2.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditTimelineProjectionEntryV2(
    eventId: '${json['eventId'] ?? ''}',
    transactionId: '${json['transactionId'] ?? ''}',
    label: '${json['label'] ?? ''}',
    timestampMs: _asNullableInt(json['timestampMs']) ?? 0,
    detail: '${json['detail'] ?? ''}',
    state: '${json['state'] ?? ''}',
  );

  final String eventId;
  final String transactionId;
  final String label;
  final int timestampMs;
  final String detail;
  final String state;

  Map<String, Object?> toJson() => <String, Object?>{
    'eventId': eventId,
    'transactionId': transactionId,
    'label': label,
    'timestampMs': timestampMs,
    if (detail.isNotEmpty) 'detail': detail,
    if (state.isNotEmpty) 'state': state,
  };
}

final class LiveEditUiProjectionV2 {
  const LiveEditUiProjectionV2({
    this.pointToBubble = const <LiveEditPointBubbleProjectionV2>[],
    this.timeline = const <LiveEditTimelineProjectionEntryV2>[],
  });

  factory LiveEditUiProjectionV2.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditUiProjectionV2(
    pointToBubble: _asList(json['pointToBubble'])
        .whereType<Map>()
        .map(
          (final value) =>
              LiveEditPointBubbleProjectionV2.fromJson(_asMap(value)),
        )
        .toList(growable: false),
    timeline: _asList(json['timeline'])
        .whereType<Map>()
        .map(
          (final value) =>
              LiveEditTimelineProjectionEntryV2.fromJson(_asMap(value)),
        )
        .toList(growable: false),
  );

  final List<LiveEditPointBubbleProjectionV2> pointToBubble;
  final List<LiveEditTimelineProjectionEntryV2> timeline;

  Map<String, Object?> toJson() => <String, Object?>{
    'pointToBubble': pointToBubble
        .map((final bubble) => bubble.toJson())
        .toList(growable: false),
    'timeline': timeline
        .map((final entry) => entry.toJson())
        .toList(growable: false),
  };
}

final class LiveEditTransactionV2 {
  const LiveEditTransactionV2({
    required this.transactionId,
    required this.sessionId,
    required this.baseRevision,
    required this.workingRevision,
    required this.intent,
    this.protocolVersion = LiveEditProtocolVersion.v2,
    this.compatibilityMode = LiveEditProtocolCompatibilityMode.nativeV2,
    this.targets = const <LiveEditTargetAddressV2>[],
    this.patch = const <LiveEditPatchOperationV2>[],
    this.validation = const <LiveEditValidationStepV2>[],
    this.apply = const LiveEditApplyStateV2(),
    this.rollback = const LiveEditRollbackPlanV2(),
    this.graph = const LiveEditEditGraphV2(nodes: <LiveEditEditNodeV2>[]),
    this.uiProjection = const LiveEditUiProjectionV2(),
    this.metadata = const <String, Object?>{},
  });

  factory LiveEditTransactionV2.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditTransactionV2(
    protocolVersion: LiveEditProtocolVersion.fromWire(json['protocolVersion']),
    compatibilityMode: LiveEditProtocolCompatibilityMode.fromWire(
      json['compatibilityMode'],
    ),
    transactionId: '${json['transactionId'] ?? ''}',
    sessionId: '${json['sessionId'] ?? ''}',
    baseRevision: _asNullableInt(json['baseRevision']) ?? 0,
    workingRevision: _asNullableInt(json['workingRevision']) ?? 0,
    intent: LiveEditIntentV2.fromJson(_asMap(json['intent'])),
    targets: _asList(json['targets'])
        .whereType<Map>()
        .map((final value) => LiveEditTargetAddressV2.fromJson(_asMap(value)))
        .toList(growable: false),
    patch: _asList(json['patch'])
        .whereType<Map>()
        .map((final value) => LiveEditPatchOperationV2.fromJson(_asMap(value)))
        .toList(growable: false),
    validation: _asList(json['validation'])
        .whereType<Map>()
        .map((final value) => LiveEditValidationStepV2.fromJson(_asMap(value)))
        .toList(growable: false),
    apply: LiveEditApplyStateV2.fromJson(_asMap(json['apply'])),
    rollback: LiveEditRollbackPlanV2.fromJson(_asMap(json['rollback'])),
    graph: LiveEditEditGraphV2.fromJson(_asMap(json['graph'])),
    uiProjection: LiveEditUiProjectionV2.fromJson(_asMap(json['uiProjection'])),
    metadata: _asMap(json['metadata']),
  );

  final LiveEditProtocolVersion protocolVersion;
  final LiveEditProtocolCompatibilityMode compatibilityMode;
  final String transactionId;
  final String sessionId;
  final int baseRevision;
  final int workingRevision;
  final LiveEditIntentV2 intent;
  final List<LiveEditTargetAddressV2> targets;
  final List<LiveEditPatchOperationV2> patch;
  final List<LiveEditValidationStepV2> validation;
  final LiveEditApplyStateV2 apply;
  final LiveEditRollbackPlanV2 rollback;
  final LiveEditEditGraphV2 graph;
  final LiveEditUiProjectionV2 uiProjection;
  final Map<String, Object?> metadata;

  bool overlapsTargetsWith(final LiveEditTransactionV2 other) {
    final currentAddresses = targets
        .map((final target) => target.stableAddress)
        .toSet();
    if (currentAddresses.isEmpty) {
      return false;
    }
    for (final otherTarget in other.targets) {
      if (currentAddresses.contains(otherTarget.stableAddress)) {
        return true;
      }
    }
    return false;
  }

  bool get hasValidationFailure =>
      validation.any((final step) => step.required && step.failed);

  Map<String, Object?> toJson() => <String, Object?>{
    'protocolVersion': protocolVersion.wireName,
    'compatibilityMode': compatibilityMode.wireName,
    'transactionId': transactionId,
    'sessionId': sessionId,
    'baseRevision': baseRevision,
    'workingRevision': workingRevision,
    'intent': intent.toJson(),
    'targets': targets.map((final target) => target.toJson()).toList(),
    'patch': patch.map((final operation) => operation.toJson()).toList(),
    'validation': validation.map((final step) => step.toJson()).toList(),
    'apply': apply.toJson(),
    'rollback': rollback.toJson(),
    'graph': graph.toJson(),
    'uiProjection': uiProjection.toJson(),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

final class LiveEditProtocolV2Resolver {
  const LiveEditProtocolV2Resolver._();

  static LiveEditConflictV2? detectConflict({
    required final LiveEditTransactionV2 incoming,
    required final Iterable<LiveEditTransactionV2> inFlight,
    required final int currentRevision,
  }) {
    if (incoming.baseRevision < currentRevision) {
      return LiveEditConflictV2(
        kind: LiveEditConflictKindV2.staleBaseRevision,
        message:
            'Incoming base revision ${incoming.baseRevision} is behind '
            'current revision $currentRevision.',
        metadata: <String, Object?>{
          'currentRevision': currentRevision,
          'baseRevision': incoming.baseRevision,
        },
      );
    }

    for (final active in inFlight) {
      if (active.transactionId == incoming.transactionId) {
        continue;
      }
      if (incoming.overlapsTargetsWith(active)) {
        final addresses = incoming.targets
            .map((final target) => target.stableAddress)
            .where(
              (final address) => active.targets.any(
                (final target) => target.stableAddress == address,
              ),
            )
            .toList(growable: false);
        return LiveEditConflictV2(
          kind: LiveEditConflictKindV2.overlappingTarget,
          message:
              'Incoming transaction overlaps active transaction target set.',
          conflictingTransactionId: active.transactionId,
          targetAddresses: addresses,
        );
      }
    }

    return null;
  }

  static bool shouldRollback({
    required final LiveEditRollbackPolicyV2 policy,
    required final LiveEditConflictV2? conflict,
    required final bool hasValidationFailure,
  }) => switch (policy) {
    LiveEditRollbackPolicyV2.never => false,
    LiveEditRollbackPolicyV2.manual => false,
    LiveEditRollbackPolicyV2.onConflict => conflict?.isConflict ?? false,
    LiveEditRollbackPolicyV2.onValidationFailure => hasValidationFailure,
  };
}

final class LiveEditProtocolV2Compatibility {
  const LiveEditProtocolV2Compatibility._();

  static LiveEditTransactionV2 fromLegacyResolutionRequest(
    final LiveEditResolutionRequest request, {
    required final int baseRevision,
    final int? workingRevision,
    final String? transactionId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stableTargets = <String, LiveEditTargetAddressV2>{};
    final primary = request.effectivePrimarySelection;
    if (primary != null) {
      final target = _targetFromSelection(primary);
      stableTargets[target.stableAddress] = target;
    }
    for (final selected in request.effectiveSelectedWidgets) {
      final target = _targetFromSelection(selected);
      stableTargets[target.stableAddress] = target;
    }
    for (final sourceTarget in request.sourceTargets) {
      final fallback = LiveEditTargetAddressV2(
        kind: LiveEditTargetKindV2.widget,
        key: sourceTarget.nodeId,
        widgetId: sourceTarget.nodeId,
        metadata: <String, Object?>{
          if (sourceTarget.workspacePath != null)
            'workspacePath': sourceTarget.workspacePath,
          if (sourceTarget.absolutePath != null)
            'absolutePath': sourceTarget.absolutePath,
          if (sourceTarget.line != null) 'line': sourceTarget.line,
          if (sourceTarget.column != null) 'column': sourceTarget.column,
        },
      );
      stableTargets[fallback.stableAddress] = fallback;
    }

    final resolvedId =
        transactionId ??
        request.effectiveBubbleId ??
        'legacy:${request.sessionId}:$timestamp';
    final resolvedSummary =
        request.effectiveInstructionText ?? 'Legacy point->bubble edit';

    return LiveEditTransactionV2(
      compatibilityMode: LiveEditProtocolCompatibilityMode.pointBubbleV1,
      transactionId: resolvedId,
      sessionId: request.sessionId,
      baseRevision: baseRevision,
      workingRevision: workingRevision ?? baseRevision,
      intent: LiveEditIntentV2(
        intentId: 'intent:$resolvedId',
        summary: resolvedSummary,
        author: 'legacy_point_bubble',
        issuedAtMs: timestamp,
        tags: const <String>['compatibility', 'legacy'],
      ),
      targets: stableTargets.values.toList(growable: false),
      rollback: const LiveEditRollbackPlanV2(
        reason: 'Fallback rollback policy for legacy point->bubble payloads.',
      ),
      graph: LiveEditEditGraphV2.linear(),
      metadata: <String, Object?>{
        if (request.effectiveBubbleId != null)
          'legacyBubbleId': request.effectiveBubbleId,
        if (request.backendId != null) 'legacyBackendId': request.backendId,
        'legacyApplyMode': request.applyMode.wireName,
      },
    );
  }

  static LiveEditTargetAddressV2 _targetFromSelection(
    final LiveEditSelection selection,
  ) => LiveEditTargetAddressV2(
    kind: LiveEditTargetKindV2.widget,
    key: selection.selectionKey.isEmpty
        ? selection.nodeId
        : selection.selectionKey,
    screenId:
        _asNullableString(selection.rawNode['screenId']) ??
        _asNullableString(selection.rawNode['routeName']),
    widgetId: selection.nodeId,
    selectionKey: selection.selectionKey,
    metadata: <String, Object?>{
      'widgetType': selection.widgetType,
      'targetDomain': selection.targetDomain.wireName,
      if (selection.source != null) 'source': selection.source!.toJson(),
    },
  );
}
