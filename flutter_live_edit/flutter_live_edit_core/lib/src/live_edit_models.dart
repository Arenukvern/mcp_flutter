import 'dart:convert';

import 'package:collection/collection.dart';

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

final class LiveEditAgentBackend {
  const LiveEditAgentBackend({
    required this.id,
    required this.label,
    required this.description,
    required this.available,
    this.isDefault = false,
    this.meta = const <String, Object?>{},
  });

  factory LiveEditAgentBackend.fromJson(final Map<String, Object?> json) =>
      LiveEditAgentBackend(
        id: '${json['id'] ?? ''}',
        label: '${json['label'] ?? ''}',
        description: '${json['description'] ?? ''}',
        available: json['available'] == true,
        isDefault: json['isDefault'] == true,
        meta: _asMap(json['meta']),
      );

  final String id;
  final String label;
  final String description;
  final bool available;
  final bool isDefault;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'description': description,
    'available': available,
    'isDefault': isDefault,
    'meta': meta,
  };
}

final class LiveEditBounds {
  const LiveEditBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.width,
    required this.height,
  });

  factory LiveEditBounds.fromJson(final Map<String, Object?> json) =>
      LiveEditBounds(
        left: _asDouble(json['left']),
        top: _asDouble(json['top']),
        right: _asDouble(json['right']),
        bottom: _asDouble(json['bottom']),
        width: _asDouble(json['width']),
        height: _asDouble(json['height']),
      );

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double width;
  final double height;

  Map<String, Object?> toJson() => <String, Object?>{
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
    'width': width,
    'height': height,
  };
}

final class LiveEditDraftChange {
  const LiveEditDraftChange({
    required this.nodeId,
    required this.propertyId,
    required this.targetValue,
    this.previewMode = LiveEditPreviewMode.none,
    this.confidence = 1,
    this.intentText,
    this.meta = const <String, Object?>{},
  });

  factory LiveEditDraftChange.fromJson(final Map<String, Object?> json) =>
      LiveEditDraftChange(
        nodeId: '${json['nodeId'] ?? ''}',
        propertyId: '${json['propertyId'] ?? ''}',
        targetValue: json['targetValue'],
        previewMode: LiveEditPreviewMode.fromWire(json['previewMode']),
        confidence: _asDouble(json['confidence'], fallback: 1),
        intentText: _asNullableString(json['intentText']),
        meta: _asMap(json['meta']),
      );

  final String nodeId;
  final String propertyId;
  final Object? targetValue;
  final LiveEditPreviewMode previewMode;
  final double confidence;
  final String? intentText;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'nodeId': nodeId,
    'propertyId': propertyId,
    'targetValue': targetValue,
    'previewMode': previewMode.wireName,
    'confidence': confidence,
    if (intentText != null) 'intentText': intentText,
    'meta': meta,
  };
}

final class LiveEditExecutionPlan {
  const LiveEditExecutionPlan({
    required this.proposalId,
    required this.title,
    required this.summary,
    required this.selectedNode,
    required this.requestedChanges,
    required this.affectedFiles,
    required this.shortAgentInstruction,
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
        shortAgentInstruction: '${json['shortAgentInstruction'] ?? ''}',
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
  final String shortAgentInstruction;
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
    'shortAgentInstruction': shortAgentInstruction,
    'meta': meta,
  };
}

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
        agentInstruction: '${json['agentInstruction'] ?? ''}',
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

final class LiveEditFilePatch {
  const LiveEditFilePatch({
    required this.path,
    required this.content,
    required this.patch,
    this.meta = const <String, Object?>{},
  });

  factory LiveEditFilePatch.fromJson(final Map<String, Object?> json) =>
      LiveEditFilePatch(
        path: '${json['path'] ?? ''}',
        content: '${json['content'] ?? ''}',
        patch: '${json['patch'] ?? ''}',
        meta: _asMap(json['meta']),
      );

  final String path;
  final String content;
  final String patch;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'content': content,
    'patch': patch,
    'meta': meta,
  };
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

final class LiveEditPropertyDescriptor {
  const LiveEditPropertyDescriptor({
    required this.id,
    required this.label,
    required this.group,
    required this.kind,
    this.value,
    this.options = const <String>[],
    this.editable = false,
    this.previewMode = LiveEditPreviewMode.none,
    this.persistable = false,
    this.canPreviewExactly = false,
    this.requiresAgentForPersistence = false,
    this.safeToAutoGroupInApply = false,
    this.meta = const <String, Object?>{},
  });

  factory LiveEditPropertyDescriptor.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditPropertyDescriptor(
    id: '${json['id'] ?? ''}',
    label: '${json['label'] ?? ''}',
    group: LiveEditPropertyGroup.fromWire(json['group']),
    kind: LiveEditPropertyKind.fromWire(json['kind']),
    value: json['value'],
    options: _asStringList(json['options']),
    editable: json['editable'] == true,
    previewMode: LiveEditPreviewMode.fromWire(json['previewMode']),
    persistable: json['persistable'] == true,
    canPreviewExactly: json['canPreviewExactly'] == true,
    requiresAgentForPersistence: json['requiresAgentForPersistence'] == true,
    safeToAutoGroupInApply: json['safeToAutoGroupInApply'] == true,
    meta: _asMap(json['meta']),
  );

  final String id;
  final String label;
  final LiveEditPropertyGroup group;
  final LiveEditPropertyKind kind;
  final Object? value;
  final List<String> options;
  final bool editable;
  final LiveEditPreviewMode previewMode;
  final bool persistable;
  final bool canPreviewExactly;
  final bool requiresAgentForPersistence;
  final bool safeToAutoGroupInApply;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'group': group.wireName,
    'kind': kind.wireName,
    'value': value,
    'options': options,
    'editable': editable,
    'previewMode': previewMode.wireName,
    'persistable': persistable,
    'canPreviewExactly': canPreviewExactly,
    'requiresAgentForPersistence': requiresAgentForPersistence,
    'safeToAutoGroupInApply': safeToAutoGroupInApply,
    'meta': meta,
  };
}

enum LiveEditPropertyGroup {
  layout('layout'),
  style('style'),
  content('content'),
  diagnostics('diagnostics');

  const LiveEditPropertyGroup(this.wireName);

  final String wireName;

  static LiveEditPropertyGroup fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditPropertyGroup.values.firstWhere(
      (final group) => group.wireName == normalized,
      orElse: () => LiveEditPropertyGroup.diagnostics,
    );
  }
}

enum LiveEditPropertyKind {
  integer('integer'),
  number('number'),
  string('string'),
  boolean('boolean'),
  color('color'),
  enumValue('enum'),
  edgeInsets('edge_insets'),
  alignment('alignment'),
  bounds('bounds'),
  object('object');

  const LiveEditPropertyKind(this.wireName);

  final String wireName;

  static LiveEditPropertyKind fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditPropertyKind.values.firstWhere(
      (final kind) => kind.wireName == normalized,
      orElse: () => LiveEditPropertyKind.object,
    );
  }
}

final class LiveEditResolutionProposal {
  const LiveEditResolutionProposal({
    required this.proposalId,
    required this.backendId,
    required this.summary,
    required this.patch,
    required this.changedFiles,
    required this.filePatches,
    required this.expectedRuntimeEffects,
    required this.validationSteps,
    this.warnings = const <String>[],
    this.riskFlags = const <String>[],
    this.meta = const <String, Object?>{},
  });

  factory LiveEditResolutionProposal.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditResolutionProposal(
    proposalId: '${json['proposalId'] ?? ''}',
    backendId: '${json['backendId'] ?? ''}',
    summary: '${json['summary'] ?? ''}',
    patch: '${json['patch'] ?? ''}',
    changedFiles: _asStringList(json['changedFiles']),
    filePatches: _asList(json['filePatches'])
        .whereType<Map>()
        .map((final item) => LiveEditFilePatch.fromJson(_asMap(item)))
        .toList(growable: false),
    expectedRuntimeEffects: _asStringList(json['expectedRuntimeEffects']),
    validationSteps: _asStringList(json['validationSteps']),
    warnings: _asStringList(json['warnings']),
    riskFlags: _asStringList(json['riskFlags']),
    meta: _asMap(json['meta']),
  );

  final String proposalId;
  final String backendId;
  final String summary;
  final String patch;
  final List<String> changedFiles;
  final List<LiveEditFilePatch> filePatches;
  final List<String> expectedRuntimeEffects;
  final List<String> validationSteps;
  final List<String> warnings;
  final List<String> riskFlags;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'proposalId': proposalId,
    'backendId': backendId,
    'summary': summary,
    'patch': patch,
    'changedFiles': changedFiles,
    'filePatches': filePatches.map((final patch) => patch.toJson()).toList(),
    'expectedRuntimeEffects': expectedRuntimeEffects,
    'validationSteps': validationSteps,
    'warnings': warnings,
    'riskFlags': riskFlags,
    'meta': meta,
  };
}

final class LiveEditResolutionRequest {
  const LiveEditResolutionRequest({
    required this.sessionId,
    required this.workingDirectory,
    required this.draftChanges,
    this.selection,
    this.backendId,
    this.intentText,
    this.evidence = const <String, Object?>{},
    this.meta = const <String, Object?>{},
  });

  factory LiveEditResolutionRequest.fromJson(final Map<String, Object?> json) =>
      LiveEditResolutionRequest(
        sessionId: '${json['sessionId'] ?? ''}',
        workingDirectory: '${json['workingDirectory'] ?? ''}',
        draftChanges: _asList(json['draftChanges'])
            .whereType<Map>()
            .map((final item) => LiveEditDraftChange.fromJson(_asMap(item)))
            .toList(growable: false),
        selection: switch (json['selection']) {
          final Map value => LiveEditSelection.fromJson(_asMap(value)),
          _ => null,
        },
        backendId: _asNullableString(json['backendId']),
        intentText: _asNullableString(json['intentText']),
        evidence: _asMap(json['evidence']),
        meta: _asMap(json['meta']),
      );

  final String sessionId;
  final String workingDirectory;
  final List<LiveEditDraftChange> draftChanges;
  final LiveEditSelection? selection;
  final String? backendId;
  final String? intentText;
  final Map<String, Object?> evidence;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'sessionId': sessionId,
    'workingDirectory': workingDirectory,
    'draftChanges': draftChanges
        .map((final change) => change.toJson())
        .toList(),
    if (selection != null) 'selection': selection!.toJson(),
    if (backendId != null) 'backendId': backendId,
    if (intentText != null) 'intentText': intentText,
    'evidence': evidence,
    'meta': meta,
  };
}

final class LiveEditResolutionResult {
  const LiveEditResolutionResult({
    required this.proposalId,
    required this.status,
    this.changedFiles = const <String>[],
    this.validation = const <String, Object?>{},
    this.warnings = const <String>[],
    this.meta = const <String, Object?>{},
  });

  factory LiveEditResolutionResult.fromJson(final Map<String, Object?> json) =>
      LiveEditResolutionResult(
        proposalId: '${json['proposalId'] ?? ''}',
        status: LiveEditResolutionStatus.fromWire(json['status']),
        changedFiles: _asStringList(json['changedFiles']),
        validation: _asMap(json['validation']),
        warnings: _asStringList(json['warnings']),
        meta: _asMap(json['meta']),
      );

  final String proposalId;
  final LiveEditResolutionStatus status;
  final List<String> changedFiles;
  final Map<String, Object?> validation;
  final List<String> warnings;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
    'proposalId': proposalId,
    'status': status.wireName,
    'changedFiles': changedFiles,
    'validation': validation,
    'warnings': warnings,
    'meta': meta,
  };
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
  static const String selectAtPoint = 'live_edit_runtime_select_at_point';
  static const String getSelection = 'live_edit_runtime_get_selection';
  static const String updateDraft = 'live_edit_runtime_update_draft';
  static const String getDraft = 'live_edit_runtime_get_draft';
  static const String discardDraft = 'live_edit_runtime_discard_draft';
  static const String endSession = 'live_edit_runtime_end_session';
}

final class LiveEditSelection {
  const LiveEditSelection({
    required this.sessionId,
    required this.nodeId,
    required this.widgetType,
    required this.propertyGroups,
    required this.rawNode,
    this.renderObjectType,
    this.bounds,
    this.source,
    this.layoutContext = const <String, Object?>{},
    this.parentChain = const <Map<String, Object?>>[],
    this.detailsTree = const <String, Object?>{},
    this.propertiesTree = const <String, Object?>{},
  });

  factory LiveEditSelection.fromJson(final Map<String, Object?> json) =>
      LiveEditSelection(
        sessionId: '${json['sessionId'] ?? ''}',
        nodeId: '${json['nodeId'] ?? ''}',
        widgetType: '${json['widgetType'] ?? ''}',
        renderObjectType: _asNullableString(json['renderObjectType']),
        bounds: switch (json['bounds']) {
          final Map value => LiveEditBounds.fromJson(_asMap(value)),
          _ => null,
        },
        source: switch (json['source']) {
          final Map value => LiveEditSourceLocation.fromJson(_asMap(value)),
          _ => null,
        },
        propertyGroups: _asList(json['properties'])
            .whereType<Map>()
            .map(
              (final item) => LiveEditPropertyDescriptor.fromJson(_asMap(item)),
            )
            .toList(growable: false),
        layoutContext: _asMap(json['layoutContext']),
        parentChain: _asList(
          json['parentChain'],
        ).whereType<Map>().map(_asMap).toList(growable: false),
        detailsTree: _asMap(json['detailsTree']),
        propertiesTree: _asMap(json['propertiesTree']),
        rawNode: _asMap(json['rawNode']),
      );

  final String sessionId;
  final String nodeId;
  final String widgetType;
  final String? renderObjectType;
  final LiveEditBounds? bounds;
  final LiveEditSourceLocation? source;
  final List<LiveEditPropertyDescriptor> propertyGroups;
  final Map<String, Object?> layoutContext;
  final List<Map<String, Object?>> parentChain;
  final Map<String, Object?> detailsTree;
  final Map<String, Object?> propertiesTree;
  final Map<String, Object?> rawNode;

  Map<String, Object?> toJson() => <String, Object?>{
    'sessionId': sessionId,
    'nodeId': nodeId,
    'widgetType': widgetType,
    if (renderObjectType != null) 'renderObjectType': renderObjectType,
    if (bounds != null) 'bounds': bounds!.toJson(),
    if (source != null) 'source': source!.toJson(),
    'properties': propertyGroups
        .map((final property) => property.toJson())
        .toList(),
    'layoutContext': layoutContext,
    'parentChain': parentChain,
    'detailsTree': detailsTree,
    'propertiesTree': propertiesTree,
    'rawNode': rawNode,
  };
}

final class LiveEditSourceLocation {
  const LiveEditSourceLocation({
    required this.file,
    this.line,
    this.column,
    this.sourceHint,
  });

  factory LiveEditSourceLocation.fromJson(final Map<String, Object?> json) =>
      LiveEditSourceLocation(
        file: '${json['file'] ?? ''}',
        line: _asNullableInt(json['line']),
        column: _asNullableInt(json['column']),
        sourceHint: _asNullableString(json['sourceHint']),
      );

  final String file;
  final int? line;
  final int? column;
  final String? sourceHint;

  Map<String, Object?> toJson() => <String, Object?>{
    'file': file,
    if (line != null) 'line': line,
    if (column != null) 'column': column,
    if (sourceHint != null) 'sourceHint': sourceHint,
  };
}
