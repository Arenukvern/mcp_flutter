// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_edit_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveEditAgentBackend _$LiveEditAgentBackendFromJson(
  Map<String, dynamic> json,
) => _LiveEditAgentBackend(
  id: json['id'] as String,
  label: json['label'] as String,
  description: json['description'] as String,
  available: json['available'] as bool,
  isDefault: json['isDefault'] as bool? ?? false,
  meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
);

Map<String, dynamic> _$LiveEditAgentBackendToJson(
  _LiveEditAgentBackend instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'description': instance.description,
  'available': instance.available,
  'isDefault': instance.isDefault,
  'meta': instance.meta,
};

_LiveEditCodexModelOption _$LiveEditCodexModelOptionFromJson(
  Map<String, dynamic> json,
) => _LiveEditCodexModelOption(
  id: json['id'] as String,
  label: json['label'] as String,
);

Map<String, dynamic> _$LiveEditCodexModelOptionToJson(
  _LiveEditCodexModelOption instance,
) => <String, dynamic>{'id': instance.id, 'label': instance.label};

_LiveEditDraftChange _$LiveEditDraftChangeFromJson(Map<String, dynamic> json) =>
    _LiveEditDraftChange(
      nodeId: json['nodeId'] as String,
      propertyId: json['propertyId'] as String,
      targetValue: json['targetValue'],
      previewMode:
          $enumDecodeNullable(
            _$LiveEditPreviewModeEnumMap,
            json['previewMode'],
          ) ??
          LiveEditPreviewMode.none,
      confidence: json['confidence'] == null
          ? 1
          : _confidenceFromJson(json['confidence']),
      intentText: json['intentText'] as String?,
      meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
    );

Map<String, dynamic> _$LiveEditDraftChangeToJson(
  _LiveEditDraftChange instance,
) => <String, dynamic>{
  'nodeId': instance.nodeId,
  'propertyId': instance.propertyId,
  'targetValue': instance.targetValue,
  'previewMode': _$LiveEditPreviewModeEnumMap[instance.previewMode]!,
  'confidence': instance.confidence,
  'intentText': instance.intentText,
  'meta': instance.meta,
};

const _$LiveEditPreviewModeEnumMap = {
  LiveEditPreviewMode.exact: 'exact',
  LiveEditPreviewMode.ghost: 'ghost',
  LiveEditPreviewMode.none: 'none',
};

_LiveEditFilePatch _$LiveEditFilePatchFromJson(Map<String, dynamic> json) =>
    _LiveEditFilePatch(
      path: json['path'] as String,
      content: json['content'] as String,
      patch: json['patch'] as String,
      meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
    );

Map<String, dynamic> _$LiveEditFilePatchToJson(_LiveEditFilePatch instance) =>
    <String, dynamic>{
      'path': instance.path,
      'content': instance.content,
      'patch': instance.patch,
      'meta': instance.meta,
    };

_LiveEditRuntimeRefreshResult _$LiveEditRuntimeRefreshResultFromJson(
  Map<String, dynamic> json,
) => _LiveEditRuntimeRefreshResult(
  action:
      $enumDecodeNullable(_$LiveEditRuntimeActionEnumMap, json['action']) ??
      LiveEditRuntimeAction.none,
  validation:
      json['validation'] as Map<String, dynamic>? ?? const <String, Object?>{},
  hotReload:
      json['hotReload'] as Map<String, dynamic>? ?? const <String, Object?>{},
  hotRestart:
      json['hotRestart'] as Map<String, dynamic>? ?? const <String, Object?>{},
  validationRecovery:
      json['validationRecovery'] as Map<String, dynamic>? ??
      const <String, Object?>{},
);

Map<String, dynamic> _$LiveEditRuntimeRefreshResultToJson(
  _LiveEditRuntimeRefreshResult instance,
) => <String, dynamic>{
  'action': _$LiveEditRuntimeActionEnumMap[instance.action]!,
  'validation': instance.validation,
  'hotReload': instance.hotReload,
  'hotRestart': instance.hotRestart,
  'validationRecovery': instance.validationRecovery,
};

const _$LiveEditRuntimeActionEnumMap = {
  LiveEditRuntimeAction.none: 'none',
  LiveEditRuntimeAction.hotReload: 'hotReload',
  LiveEditRuntimeAction.hotRestart: 'hotRestart',
};

_LiveEditResolutionProposal _$LiveEditResolutionProposalFromJson(
  Map<String, dynamic> json,
) => _LiveEditResolutionProposal(
  proposalId: json['proposalId'] as String,
  backendId: json['backendId'] as String,
  summary: json['summary'] as String,
  patch: json['patch'] as String,
  changedFiles: (json['changedFiles'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  filePatches: (json['filePatches'] as List<dynamic>)
      .map((e) => LiveEditFilePatch.fromJson(e as Map<String, dynamic>))
      .toList(),
  expectedRuntimeEffects: (json['expectedRuntimeEffects'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  validationSteps: (json['validationSteps'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  riskFlags:
      (json['riskFlags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
);

Map<String, dynamic> _$LiveEditResolutionProposalToJson(
  _LiveEditResolutionProposal instance,
) => <String, dynamic>{
  'proposalId': instance.proposalId,
  'backendId': instance.backendId,
  'summary': instance.summary,
  'patch': instance.patch,
  'changedFiles': instance.changedFiles,
  'filePatches': instance.filePatches,
  'expectedRuntimeEffects': instance.expectedRuntimeEffects,
  'validationSteps': instance.validationSteps,
  'warnings': instance.warnings,
  'riskFlags': instance.riskFlags,
  'meta': instance.meta,
};

_LiveEditSourceTarget _$LiveEditSourceTargetFromJson(
  Map<String, dynamic> json,
) => _LiveEditSourceTarget(
  nodeId: json['nodeId'] as String,
  widgetType: json['widgetType'] as String,
  absolutePath: json['absolutePath'] as String?,
  workspacePath: json['workspacePath'] as String?,
  line: (json['line'] as num?)?.toInt(),
  column: (json['column'] as num?)?.toInt(),
);

Map<String, dynamic> _$LiveEditSourceTargetToJson(
  _LiveEditSourceTarget instance,
) => <String, dynamic>{
  'nodeId': instance.nodeId,
  'widgetType': instance.widgetType,
  'absolutePath': instance.absolutePath,
  'workspacePath': instance.workspacePath,
  'line': instance.line,
  'column': instance.column,
};

_LiveEditDirectApplyResult _$LiveEditDirectApplyResultFromJson(
  Map<String, dynamic> json,
) => _LiveEditDirectApplyResult(
  executionId: json['executionId'] as String,
  backendId: json['backendId'] as String,
  summary: json['summary'] as String,
  changedFiles:
      (json['changedFiles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  validationSteps:
      (json['validationSteps'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  runtimeRefresh: json['runtimeRefresh'] == null
      ? null
      : LiveEditRuntimeRefreshResult.fromJson(
          json['runtimeRefresh'] as Map<String, dynamic>,
        ),
  meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
);

Map<String, dynamic> _$LiveEditDirectApplyResultToJson(
  _LiveEditDirectApplyResult instance,
) => <String, dynamic>{
  'executionId': instance.executionId,
  'backendId': instance.backendId,
  'summary': instance.summary,
  'changedFiles': instance.changedFiles,
  'warnings': instance.warnings,
  'validationSteps': instance.validationSteps,
  'runtimeRefresh': instance.runtimeRefresh,
  'meta': instance.meta,
};

_LiveEditResolutionResult _$LiveEditResolutionResultFromJson(
  Map<String, dynamic> json,
) => _LiveEditResolutionResult(
  proposalId: json['proposalId'] as String,
  status: $enumDecode(_$LiveEditResolutionStatusEnumMap, json['status']),
  changedFiles:
      (json['changedFiles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  validation:
      json['validation'] as Map<String, dynamic>? ?? const <String, Object?>{},
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
);

Map<String, dynamic> _$LiveEditResolutionResultToJson(
  _LiveEditResolutionResult instance,
) => <String, dynamic>{
  'proposalId': instance.proposalId,
  'status': _$LiveEditResolutionStatusEnumMap[instance.status]!,
  'changedFiles': instance.changedFiles,
  'validation': instance.validation,
  'warnings': instance.warnings,
  'meta': instance.meta,
};

const _$LiveEditResolutionStatusEnumMap = {
  LiveEditResolutionStatus.proposed: 'proposed',
  LiveEditResolutionStatus.accepted: 'accepted',
  LiveEditResolutionStatus.rejected: 'rejected',
  LiveEditResolutionStatus.applied: 'applied',
  LiveEditResolutionStatus.failed: 'failed',
};

_LiveEditSelection _$LiveEditSelectionFromJson(
  Map<String, dynamic> json,
) => _LiveEditSelection(
  sessionId: json['sessionId'] as String,
  nodeId: json['nodeId'] as String,
  widgetType: json['widgetType'] as String,
  rawNode: _asMap(json['rawNode']),
  propertiesForWire: json['properties'] as List<dynamic>? ?? const <Object?>[],
  targetDomain:
      $enumDecodeNullable(
        _$LiveEditTargetDomainEnumMap,
        json['targetDomain'],
      ) ??
      LiveEditTargetDomain.appScene,
  renderObjectType: json['renderObjectType'] as String?,
  bounds: json['bounds'] == null
      ? null
      : LiveEditBounds.fromJson(json['bounds'] as Map<String, dynamic>),
  source: json['source'] == null
      ? null
      : LiveEditSourceLocation.fromJson(json['source'] as Map<String, dynamic>),
  layoutContext:
      json['layoutContext'] as Map<String, dynamic>? ??
      const <String, Object?>{},
  parentChain:
      (json['parentChain'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const <Map<String, Object?>>[],
  detailsTree:
      json['detailsTree'] as Map<String, dynamic>? ?? const <String, Object?>{},
  propertiesTree:
      json['propertiesTree'] as Map<String, dynamic>? ??
      const <String, Object?>{},
  selectionMode:
      $enumDecodeNullable(
        _$LiveEditSelectionModeEnumMap,
        json['selectionMode'],
      ) ??
      LiveEditSelectionMode.single,
  selectedNodeIds:
      (json['selectedNodeIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
);

Map<String, dynamic> _$LiveEditSelectionToJson(_LiveEditSelection instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'nodeId': instance.nodeId,
      'widgetType': instance.widgetType,
      'rawNode': instance.rawNode,
      'properties': instance.propertiesForWire,
      'targetDomain': _$LiveEditTargetDomainEnumMap[instance.targetDomain]!,
      'renderObjectType': instance.renderObjectType,
      'bounds': instance.bounds,
      'source': instance.source,
      'layoutContext': instance.layoutContext,
      'parentChain': instance.parentChain,
      'detailsTree': instance.detailsTree,
      'propertiesTree': instance.propertiesTree,
      'selectionMode': _$LiveEditSelectionModeEnumMap[instance.selectionMode]!,
      'selectedNodeIds': instance.selectedNodeIds,
    };

const _$LiveEditTargetDomainEnumMap = {
  LiveEditTargetDomain.appScene: 'appScene',
  LiveEditTargetDomain.toolScene: 'toolScene',
};

const _$LiveEditSelectionModeEnumMap = {
  LiveEditSelectionMode.single: 'single',
  LiveEditSelectionMode.multi: 'multi',
};

_LiveEditSelectionCandidate _$LiveEditSelectionCandidateFromJson(
  Map<String, dynamic> json,
) => _LiveEditSelectionCandidate(
  nodeId: json['nodeId'] as String,
  widgetType: json['widgetType'] as String,
  bounds: json['bounds'] == null
      ? null
      : LiveEditBounds.fromJson(json['bounds'] as Map<String, dynamic>),
  depth: json['depth'] == null ? 0 : _depthFromJson(json['depth']),
  source: json['source'] == null
      ? null
      : LiveEditSourceLocation.fromJson(json['source'] as Map<String, dynamic>),
  createdByLocalProject: json['createdByLocalProject'] as bool? ?? false,
  active: json['active'] as bool? ?? false,
);

Map<String, dynamic> _$LiveEditSelectionCandidateToJson(
  _LiveEditSelectionCandidate instance,
) => <String, dynamic>{
  'nodeId': instance.nodeId,
  'widgetType': instance.widgetType,
  'bounds': instance.bounds,
  'depth': instance.depth,
  'source': instance.source,
  'createdByLocalProject': instance.createdByLocalProject,
  'active': instance.active,
};

_LiveEditSourceLocation _$LiveEditSourceLocationFromJson(
  Map<String, dynamic> json,
) => _LiveEditSourceLocation(
  file: json['file'] as String,
  line: (json['line'] as num?)?.toInt(),
  column: (json['column'] as num?)?.toInt(),
  sourceHint: json['sourceHint'] as String?,
);

Map<String, dynamic> _$LiveEditSourceLocationToJson(
  _LiveEditSourceLocation instance,
) => <String, dynamic>{
  'file': instance.file,
  'line': instance.line,
  'column': instance.column,
  'sourceHint': instance.sourceHint,
};
