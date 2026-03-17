// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_edit_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LiveEditAgentBackendImpl _$$LiveEditAgentBackendImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditAgentBackendImpl(
  id: json['id'] as String,
  label: json['label'] as String,
  description: json['description'] as String,
  available: json['available'] as bool,
  isDefault: json['isDefault'] as bool? ?? false,
  meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
);

Map<String, dynamic> _$$LiveEditAgentBackendImplToJson(
  _$LiveEditAgentBackendImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'description': instance.description,
  'available': instance.available,
  'isDefault': instance.isDefault,
  'meta': instance.meta,
};

_$LiveEditBoundsImpl _$$LiveEditBoundsImplFromJson(Map<String, dynamic> json) =>
    _$LiveEditBoundsImpl(
      left: (json['left'] as num).toDouble(),
      top: (json['top'] as num).toDouble(),
      right: (json['right'] as num).toDouble(),
      bottom: (json['bottom'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );

Map<String, dynamic> _$$LiveEditBoundsImplToJson(
  _$LiveEditBoundsImpl instance,
) => <String, dynamic>{
  'left': instance.left,
  'top': instance.top,
  'right': instance.right,
  'bottom': instance.bottom,
  'width': instance.width,
  'height': instance.height,
};

_$LiveEditCodexModelOptionImpl _$$LiveEditCodexModelOptionImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditCodexModelOptionImpl(
  id: json['id'] as String,
  label: json['label'] as String,
);

Map<String, dynamic> _$$LiveEditCodexModelOptionImplToJson(
  _$LiveEditCodexModelOptionImpl instance,
) => <String, dynamic>{'id': instance.id, 'label': instance.label};

_$LiveEditDraftChangeImpl _$$LiveEditDraftChangeImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditDraftChangeImpl(
  nodeId: json['nodeId'] as String,
  propertyId: json['propertyId'] as String,
  targetValue: json['targetValue'],
  previewMode: json['previewMode'] == null
      ? LiveEditPreviewMode.none
      : _previewModeFromJson(json['previewMode']),
  confidence: json['confidence'] == null
      ? 1
      : _confidenceFromJson(json['confidence']),
  intentText: json['intentText'] as String?,
  meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
);

Map<String, dynamic> _$$LiveEditDraftChangeImplToJson(
  _$LiveEditDraftChangeImpl instance,
) => <String, dynamic>{
  'nodeId': instance.nodeId,
  'propertyId': instance.propertyId,
  'targetValue': instance.targetValue,
  'previewMode': _enumToWire(instance.previewMode),
  'confidence': instance.confidence,
  'intentText': instance.intentText,
  'meta': instance.meta,
};

_$LiveEditFilePatchImpl _$$LiveEditFilePatchImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditFilePatchImpl(
  path: json['path'] as String,
  content: json['content'] as String,
  patch: json['patch'] as String,
  meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
);

Map<String, dynamic> _$$LiveEditFilePatchImplToJson(
  _$LiveEditFilePatchImpl instance,
) => <String, dynamic>{
  'path': instance.path,
  'content': instance.content,
  'patch': instance.patch,
  'meta': instance.meta,
};

_$LiveEditRuntimeRefreshResultImpl _$$LiveEditRuntimeRefreshResultImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditRuntimeRefreshResultImpl(
  action: json['action'] == null
      ? LiveEditRuntimeAction.none
      : _runtimeActionFromJson(json['action']),
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

Map<String, dynamic> _$$LiveEditRuntimeRefreshResultImplToJson(
  _$LiveEditRuntimeRefreshResultImpl instance,
) => <String, dynamic>{
  'action': _enumToWire(instance.action),
  'validation': instance.validation,
  'hotReload': instance.hotReload,
  'hotRestart': instance.hotRestart,
  'validationRecovery': instance.validationRecovery,
};

_$LiveEditPropertyDescriptorImpl _$$LiveEditPropertyDescriptorImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditPropertyDescriptorImpl(
  id: json['id'] as String,
  label: json['label'] as String,
  group: _propertyGroupFromJson(json['group']),
  kind: _propertyKindFromJson(json['kind']),
  value: json['value'],
  options:
      (json['options'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  editable: json['editable'] as bool? ?? false,
  previewMode: json['previewMode'] == null
      ? LiveEditPreviewMode.none
      : _previewModeFromJson(json['previewMode']),
  persistable: json['persistable'] as bool? ?? false,
  canPreviewExactly: json['canPreviewExactly'] as bool? ?? false,
  requiresAgentForPersistence:
      json['requiresAgentForPersistence'] as bool? ?? false,
  safeToAutoGroupInApply: json['safeToAutoGroupInApply'] as bool? ?? false,
  meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
);

Map<String, dynamic> _$$LiveEditPropertyDescriptorImplToJson(
  _$LiveEditPropertyDescriptorImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'group': _enumToWire(instance.group),
  'kind': _enumToWire(instance.kind),
  'value': instance.value,
  'options': instance.options,
  'editable': instance.editable,
  'previewMode': _enumToWire(instance.previewMode),
  'persistable': instance.persistable,
  'canPreviewExactly': instance.canPreviewExactly,
  'requiresAgentForPersistence': instance.requiresAgentForPersistence,
  'safeToAutoGroupInApply': instance.safeToAutoGroupInApply,
  'meta': instance.meta,
};

_$LiveEditResolutionProposalImpl _$$LiveEditResolutionProposalImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditResolutionProposalImpl(
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

Map<String, dynamic> _$$LiveEditResolutionProposalImplToJson(
  _$LiveEditResolutionProposalImpl instance,
) => <String, dynamic>{
  'proposalId': instance.proposalId,
  'backendId': instance.backendId,
  'summary': instance.summary,
  'patch': instance.patch,
  'changedFiles': instance.changedFiles,
  'filePatches': instance.filePatches.map((e) => e.toJson()).toList(),
  'expectedRuntimeEffects': instance.expectedRuntimeEffects,
  'validationSteps': instance.validationSteps,
  'warnings': instance.warnings,
  'riskFlags': instance.riskFlags,
  'meta': instance.meta,
};

_$LiveEditSourceTargetImpl _$$LiveEditSourceTargetImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditSourceTargetImpl(
  nodeId: json['nodeId'] as String,
  widgetType: json['widgetType'] as String,
  absolutePath: json['absolutePath'] as String?,
  workspacePath: json['workspacePath'] as String?,
  line: (json['line'] as num?)?.toInt(),
  column: (json['column'] as num?)?.toInt(),
);

Map<String, dynamic> _$$LiveEditSourceTargetImplToJson(
  _$LiveEditSourceTargetImpl instance,
) => <String, dynamic>{
  'nodeId': instance.nodeId,
  'widgetType': instance.widgetType,
  'absolutePath': instance.absolutePath,
  'workspacePath': instance.workspacePath,
  'line': instance.line,
  'column': instance.column,
};

_$LiveEditResolutionResultImpl _$$LiveEditResolutionResultImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditResolutionResultImpl(
  proposalId: json['proposalId'] as String,
  status: _resolutionStatusFromJson(json['status']),
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

Map<String, dynamic> _$$LiveEditResolutionResultImplToJson(
  _$LiveEditResolutionResultImpl instance,
) => <String, dynamic>{
  'proposalId': instance.proposalId,
  'status': _enumToWire(instance.status),
  'changedFiles': instance.changedFiles,
  'validation': instance.validation,
  'warnings': instance.warnings,
  'meta': instance.meta,
};

_$LiveEditSelectionImpl _$$LiveEditSelectionImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditSelectionImpl(
  sessionId: json['sessionId'] as String,
  nodeId: json['nodeId'] as String,
  widgetType: json['widgetType'] as String,
  propertyGroups: (json['properties'] as List<dynamic>)
      .map(
        (e) => LiveEditPropertyDescriptor.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  rawNode: _asMap(json['rawNode']),
  targetDomain: json['targetDomain'] == null
      ? LiveEditTargetDomain.appScene
      : _targetDomainFromJson(json['targetDomain']),
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
  selectionMode: json['selectionMode'] == null
      ? LiveEditSelectionMode.single
      : _selectionModeFromJson(json['selectionMode']),
  selectedNodeIds:
      (json['selectedNodeIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
);

Map<String, dynamic> _$$LiveEditSelectionImplToJson(
  _$LiveEditSelectionImpl instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'nodeId': instance.nodeId,
  'widgetType': instance.widgetType,
  'properties': instance.propertyGroups.map((e) => e.toJson()).toList(),
  'rawNode': instance.rawNode,
  'targetDomain': _enumToWire(instance.targetDomain),
  'renderObjectType': instance.renderObjectType,
  'bounds': instance.bounds?.toJson(),
  'source': instance.source?.toJson(),
  'layoutContext': instance.layoutContext,
  'parentChain': instance.parentChain,
  'detailsTree': instance.detailsTree,
  'propertiesTree': instance.propertiesTree,
  'selectionMode': _enumToWire(instance.selectionMode),
  'selectedNodeIds': instance.selectedNodeIds,
};

_$LiveEditSelectionCandidateImpl _$$LiveEditSelectionCandidateImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditSelectionCandidateImpl(
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

Map<String, dynamic> _$$LiveEditSelectionCandidateImplToJson(
  _$LiveEditSelectionCandidateImpl instance,
) => <String, dynamic>{
  'nodeId': instance.nodeId,
  'widgetType': instance.widgetType,
  'bounds': instance.bounds?.toJson(),
  'depth': instance.depth,
  'source': instance.source?.toJson(),
  'createdByLocalProject': instance.createdByLocalProject,
  'active': instance.active,
};

_$LiveEditSourceLocationImpl _$$LiveEditSourceLocationImplFromJson(
  Map<String, dynamic> json,
) => _$LiveEditSourceLocationImpl(
  file: json['file'] as String,
  line: (json['line'] as num?)?.toInt(),
  column: (json['column'] as num?)?.toInt(),
  sourceHint: json['sourceHint'] as String?,
);

Map<String, dynamic> _$$LiveEditSourceLocationImplToJson(
  _$LiveEditSourceLocationImpl instance,
) => <String, dynamic>{
  'file': instance.file,
  'line': instance.line,
  'column': instance.column,
  'sourceHint': instance.sourceHint,
};
