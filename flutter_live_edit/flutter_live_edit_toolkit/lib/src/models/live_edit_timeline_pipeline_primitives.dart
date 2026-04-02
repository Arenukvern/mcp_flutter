import 'package:flutter/foundation.dart';

import 'live_edit_interaction_models.dart';
import 'live_edit_models.dart';

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

List<Object?> _asList(final Object? value) =>
    value is List ? value.cast<Object?>() : const <Object?>[];

String _asString(final Object? value, {final String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

String? _asNullableString(final Object? value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

bool _asBool(final Object? value, {final bool fallback = false}) =>
    switch (value) {
      final bool resolved => resolved,
      final String resolved => resolved.trim().toLowerCase() == 'true',
      final num resolved => resolved != 0,
      _ => fallback,
    };

double _asDouble(final Object? value, {final double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(_asString(value)) ?? fallback;
}

int _asInt(final Object? value, {final int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_asString(value)) ?? fallback;
}

List<String> _normalizeTokens(final Iterable<Object?> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final token = _asString(value);
    if (token.isEmpty || !seen.add(token)) {
      continue;
    }
    normalized.add(token);
  }
  normalized.sort();
  return List<String>.unmodifiable(normalized);
}

List<String> _pathSegments(final String path) => path
    .split('/')
    .map((final segment) => segment.trim())
    .where((final segment) => segment.isNotEmpty)
    .toList(growable: false);

String _decodePathSegment(final String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return value;
  }
}

int _compareGraphNodeKinds(
  final LiveEditEditNodeKindV2 lhs,
  final LiveEditEditNodeKindV2 rhs,
) {
  final order = <LiveEditEditNodeKindV2, int>{
    LiveEditEditNodeKindV2.intent: 0,
    LiveEditEditNodeKindV2.target: 1,
    LiveEditEditNodeKindV2.patch: 2,
    LiveEditEditNodeKindV2.validation: 3,
    LiveEditEditNodeKindV2.apply: 4,
    LiveEditEditNodeKindV2.rollback: 5,
  };
  return order[lhs]!.compareTo(order[rhs]!);
}

enum LiveEditCanvasLinkKind {
  screen('screen'),
  action('action'),
  animation('animation'),
  data('data');

  const LiveEditCanvasLinkKind(this.wireName);

  final String wireName;

  static LiveEditCanvasLinkKind fromWire(final Object? value) {
    final normalized = _asString(value).toLowerCase();
    return LiveEditCanvasLinkKind.values.firstWhere(
      (final item) => item.wireName == normalized,
      orElse: () => LiveEditCanvasLinkKind.screen,
    );
  }
}

enum LiveEditCanvasViewportMode {
  overview('overview'),
  focusScreen('focus_screen'),
  focusGroup('focus_group');

  const LiveEditCanvasViewportMode(this.wireName);

  final String wireName;

  static LiveEditCanvasViewportMode fromWire(final Object? value) {
    final normalized = _asString(value).toLowerCase();
    return LiveEditCanvasViewportMode.values.firstWhere(
      (final item) => item.wireName == normalized,
      orElse: () => LiveEditCanvasViewportMode.overview,
    );
  }
}

enum LiveEditCanvasActionKind {
  wrapSelection('wrap_selection'),
  unwrapGroup('unwrap_group'),
  toggleGroup('toggle_group'),
  setGroupCollapsed('set_group_collapsed'),
  focusNode('focus_node');

  const LiveEditCanvasActionKind(this.wireName);

  final String wireName;

  static LiveEditCanvasActionKind fromWire(final Object? value) {
    final normalized = _asString(value).toLowerCase();
    return LiveEditCanvasActionKind.values.firstWhere(
      (final item) => item.wireName == normalized,
      orElse: () => LiveEditCanvasActionKind.focusNode,
    );
  }
}

@immutable
final class LiveEditCanvasViewportV2 {
  const LiveEditCanvasViewportV2({
    this.centerX = 0,
    this.centerY = 0,
    this.zoom = 1,
    this.mode = LiveEditCanvasViewportMode.overview,
  });

  factory LiveEditCanvasViewportV2.fromJson(final Map<String, Object?> json) =>
      LiveEditCanvasViewportV2(
        centerX: _asDouble(json['centerX']),
        centerY: _asDouble(json['centerY']),
        zoom: _asDouble(json['zoom'], fallback: 1),
        mode: LiveEditCanvasViewportMode.fromWire(json['mode']),
      );

  static const LiveEditCanvasViewportV2 initial = LiveEditCanvasViewportV2();

  final double centerX;
  final double centerY;
  final double zoom;
  final LiveEditCanvasViewportMode mode;

  LiveEditCanvasViewportV2 copyWith({
    final double? centerX,
    final double? centerY,
    final double? zoom,
    final LiveEditCanvasViewportMode? mode,
  }) => LiveEditCanvasViewportV2(
    centerX: centerX ?? this.centerX,
    centerY: centerY ?? this.centerY,
    zoom: zoom ?? this.zoom,
    mode: mode ?? this.mode,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'centerX': centerX,
    'centerY': centerY,
    'zoom': zoom,
    'mode': mode.wireName,
  };
}

@immutable
final class LiveEditCanvasScreenNodeV2 {
  const LiveEditCanvasScreenNodeV2({
    required this.nodeId,
    required this.screenId,
    required this.routeId,
    required this.title,
    required this.x,
    required this.y,
    this.groupId,
    this.hidden = false,
  });

  factory LiveEditCanvasScreenNodeV2.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditCanvasScreenNodeV2(
    nodeId: _asString(json['nodeId']),
    screenId: _asString(json['screenId']),
    routeId: _asString(json['routeId']),
    title: _asString(json['title']),
    x: _asDouble(json['x']),
    y: _asDouble(json['y']),
    groupId: _asNullableString(json['groupId']),
    hidden: _asBool(json['hidden']),
  );

  final String nodeId;
  final String screenId;
  final String routeId;
  final String title;
  final double x;
  final double y;
  final String? groupId;
  final bool hidden;

  LiveEditCanvasScreenNodeV2 copyWith({
    final String? groupId,
    final bool? hidden,
  }) => LiveEditCanvasScreenNodeV2(
    nodeId: nodeId,
    screenId: screenId,
    routeId: routeId,
    title: title,
    x: x,
    y: y,
    groupId: groupId ?? this.groupId,
    hidden: hidden ?? this.hidden,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'nodeId': nodeId,
    'screenId': screenId,
    'routeId': routeId,
    'title': title,
    'x': x,
    'y': y,
    if (groupId != null) 'groupId': groupId,
    'hidden': hidden,
  };
}

@immutable
final class LiveEditCanvasGroupNodeV2 {
  const LiveEditCanvasGroupNodeV2({
    required this.nodeId,
    required this.memberScreenIds,
    this.collapsed = true,
  });

  factory LiveEditCanvasGroupNodeV2.fromJson(final Map<String, Object?> json) =>
      LiveEditCanvasGroupNodeV2(
        nodeId: _asString(json['nodeId']),
        memberScreenIds: _normalizeTokens(_asList(json['memberScreenIds'])),
        collapsed: _asBool(json['collapsed'], fallback: true),
      );

  final String nodeId;
  final List<String> memberScreenIds;
  final bool collapsed;

  LiveEditCanvasGroupNodeV2 copyWith({
    final List<String>? memberScreenIds,
    final bool? collapsed,
  }) => LiveEditCanvasGroupNodeV2(
    nodeId: nodeId,
    memberScreenIds: memberScreenIds ?? this.memberScreenIds,
    collapsed: collapsed ?? this.collapsed,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'nodeId': nodeId,
    'memberScreenIds': memberScreenIds,
    'collapsed': collapsed,
  };
}

@immutable
final class LiveEditCanvasLinkV2 {
  const LiveEditCanvasLinkV2({
    required this.linkId,
    required this.kind,
    required this.fromNodeId,
    required this.toNodeId,
    required this.qualifier,
  });

  factory LiveEditCanvasLinkV2.fromJson(final Map<String, Object?> json) =>
      LiveEditCanvasLinkV2(
        linkId: _asString(json['linkId']),
        kind: LiveEditCanvasLinkKind.fromWire(json['kind']),
        fromNodeId: _asString(json['fromNodeId']),
        toNodeId: _asString(json['toNodeId']),
        qualifier: _asString(json['qualifier']),
      );

  final String linkId;
  final LiveEditCanvasLinkKind kind;
  final String fromNodeId;
  final String toNodeId;
  final String qualifier;

  Map<String, Object?> toJson() => <String, Object?>{
    'linkId': linkId,
    'kind': kind.wireName,
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
    'qualifier': qualifier,
  };
}

@immutable
final class LiveEditCanvasProjectionV2 {
  const LiveEditCanvasProjectionV2({
    this.screenNodes = const <LiveEditCanvasScreenNodeV2>[],
    this.groupNodes = const <LiveEditCanvasGroupNodeV2>[],
    this.links = const <LiveEditCanvasLinkV2>[],
    this.focusedNodeId,
    this.selectionScreenIds = const <String>[],
    this.viewport = LiveEditCanvasViewportV2.initial,
  });

  factory LiveEditCanvasProjectionV2.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditCanvasProjectionV2(
    screenNodes: _asList(json['screenNodes'])
        .whereType<Map>()
        .map((final item) => LiveEditCanvasScreenNodeV2.fromJson(_asMap(item)))
        .toList(growable: false),
    groupNodes: _asList(json['groupNodes'])
        .whereType<Map>()
        .map((final item) => LiveEditCanvasGroupNodeV2.fromJson(_asMap(item)))
        .toList(growable: false),
    links: _asList(json['links'])
        .whereType<Map>()
        .map((final item) => LiveEditCanvasLinkV2.fromJson(_asMap(item)))
        .toList(growable: false),
    focusedNodeId: _asNullableString(json['focusedNodeId']),
    selectionScreenIds: _normalizeTokens(_asList(json['selectionScreenIds'])),
    viewport: switch (json['viewport']) {
      final Map value => LiveEditCanvasViewportV2.fromJson(_asMap(value)),
      _ => LiveEditCanvasViewportV2.initial,
    },
  );

  static const LiveEditCanvasProjectionV2 empty = LiveEditCanvasProjectionV2();

  final List<LiveEditCanvasScreenNodeV2> screenNodes;
  final List<LiveEditCanvasGroupNodeV2> groupNodes;
  final List<LiveEditCanvasLinkV2> links;
  final String? focusedNodeId;
  final List<String> selectionScreenIds;
  final LiveEditCanvasViewportV2 viewport;

  bool containsNode(final String? nodeId) {
    final resolved = _asNullableString(nodeId);
    if (resolved == null) {
      return false;
    }
    return screenNodes.any((final node) => node.nodeId == resolved) ||
        groupNodes.any((final node) => node.nodeId == resolved);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'screenNodes': screenNodes.map((final node) => node.toJson()).toList(),
    'groupNodes': groupNodes.map((final node) => node.toJson()).toList(),
    'links': links.map((final link) => link.toJson()).toList(),
    if (focusedNodeId != null) 'focusedNodeId': focusedNodeId,
    if (selectionScreenIds.isNotEmpty) 'selectionScreenIds': selectionScreenIds,
    'viewport': viewport.toJson(),
  };
}

@immutable
final class LiveEditCanvasActionV2 {
  const LiveEditCanvasActionV2({
    required this.kind,
    this.screenIds = const <String>[],
    this.groupId,
    this.nodeId,
    this.collapsed,
  });

  factory LiveEditCanvasActionV2.fromJson(final Map<String, Object?> json) =>
      LiveEditCanvasActionV2(
        kind: LiveEditCanvasActionKind.fromWire(json['kind']),
        screenIds: _normalizeTokens(_asList(json['screenIds'])),
        groupId: _asNullableString(json['groupId']),
        nodeId: _asNullableString(json['nodeId']),
        collapsed: json.containsKey('collapsed')
            ? _asBool(json['collapsed'])
            : null,
      );

  factory LiveEditCanvasActionV2.wrapSelection({
    required final Iterable<String> screenIds,
  }) => LiveEditCanvasActionV2(
    kind: LiveEditCanvasActionKind.wrapSelection,
    screenIds: _normalizeTokens(screenIds),
  );

  factory LiveEditCanvasActionV2.unwrapGroup({required final String groupId}) =>
      LiveEditCanvasActionV2(
        kind: LiveEditCanvasActionKind.unwrapGroup,
        groupId: _asString(groupId),
      );

  factory LiveEditCanvasActionV2.toggleGroup({required final String groupId}) =>
      LiveEditCanvasActionV2(
        kind: LiveEditCanvasActionKind.toggleGroup,
        groupId: _asString(groupId),
      );

  factory LiveEditCanvasActionV2.setGroupCollapsed({
    required final String groupId,
    required final bool collapsed,
  }) => LiveEditCanvasActionV2(
    kind: LiveEditCanvasActionKind.setGroupCollapsed,
    groupId: _asString(groupId),
    collapsed: collapsed,
  );

  factory LiveEditCanvasActionV2.focusNode({required final String nodeId}) =>
      LiveEditCanvasActionV2(
        kind: LiveEditCanvasActionKind.focusNode,
        nodeId: _asString(nodeId),
      );

  final LiveEditCanvasActionKind kind;
  final List<String> screenIds;
  final String? groupId;
  final String? nodeId;
  final bool? collapsed;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wireName,
    if (screenIds.isNotEmpty) 'screenIds': screenIds,
    if (groupId != null) 'groupId': groupId,
    if (nodeId != null) 'nodeId': nodeId,
    if (collapsed != null) 'collapsed': collapsed,
  };
}

@immutable
final class LiveEditTimelinePatchPrimitiveV2 {
  const LiveEditTimelinePatchPrimitiveV2({
    required this.primitiveId,
    required this.transactionId,
    required this.stage,
    required this.forwardPatch,
    required this.inversePatch,
    this.graphNodeIds = const <String>[],
    this.graphLinkIds = const <String>[],
  });

  factory LiveEditTimelinePatchPrimitiveV2.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditTimelinePatchPrimitiveV2(
    primitiveId: _asString(json['primitiveId']),
    transactionId: _asString(json['transactionId']),
    stage: LiveEditEditNodeKindV2.fromWire(json['stage']),
    forwardPatch: LiveEditPatchOperationV2.fromJson(
      _asMap(json['forwardPatch']),
    ),
    inversePatch: LiveEditPatchOperationV2.fromJson(
      _asMap(json['inversePatch']),
    ),
    graphNodeIds: _normalizeTokens(_asList(json['graphNodeIds'])),
    graphLinkIds: _normalizeTokens(_asList(json['graphLinkIds'])),
  );

  final String primitiveId;
  final String transactionId;
  final LiveEditEditNodeKindV2 stage;
  final LiveEditPatchOperationV2 forwardPatch;
  final LiveEditPatchOperationV2 inversePatch;
  final List<String> graphNodeIds;
  final List<String> graphLinkIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'primitiveId': primitiveId,
    'transactionId': transactionId,
    'stage': stage.wireName,
    'forwardPatch': forwardPatch.toJson(),
    'inversePatch': inversePatch.toJson(),
    if (graphNodeIds.isNotEmpty) 'graphNodeIds': graphNodeIds,
    if (graphLinkIds.isNotEmpty) 'graphLinkIds': graphLinkIds,
  };
}

@immutable
final class LiveEditTimelinePipelineMappingV2 {
  const LiveEditTimelinePipelineMappingV2({
    required this.projection,
    required this.actions,
    required this.timelineEntries,
    required this.patchPrimitives,
  });

  factory LiveEditTimelinePipelineMappingV2.fromJson(
    final Map<String, Object?> json,
  ) => LiveEditTimelinePipelineMappingV2(
    projection: LiveEditCanvasProjectionV2.fromJson(_asMap(json['projection'])),
    actions: _asList(json['actions'])
        .whereType<Map>()
        .map((final item) => LiveEditCanvasActionV2.fromJson(_asMap(item)))
        .toList(growable: false),
    timelineEntries: _asList(json['timelineEntries'])
        .whereType<Map>()
        .map(
          (final item) =>
              LiveEditTimelineProjectionEntryV2.fromJson(_asMap(item)),
        )
        .toList(growable: false),
    patchPrimitives: _asList(json['patchPrimitives'])
        .whereType<Map>()
        .map(
          (final item) =>
              LiveEditTimelinePatchPrimitiveV2.fromJson(_asMap(item)),
        )
        .toList(growable: false),
  );

  final LiveEditCanvasProjectionV2 projection;
  final List<LiveEditCanvasActionV2> actions;
  final List<LiveEditTimelineProjectionEntryV2> timelineEntries;
  final List<LiveEditTimelinePatchPrimitiveV2> patchPrimitives;

  Map<String, Object?> toJson() => <String, Object?>{
    'projection': projection.toJson(),
    'actions': actions.map((final action) => action.toJson()).toList(),
    'timelineEntries': timelineEntries
        .map((final entry) => entry.toJson())
        .toList(),
    'patchPrimitives': patchPrimitives
        .map((final primitive) => primitive.toJson())
        .toList(),
  };
}

final class LiveEditTimelinePipelinePrimitivesV2 {
  const LiveEditTimelinePipelinePrimitivesV2._();

  static String screenNodeId(final String screenId) =>
      'screen:${screenId.trim()}';

  static String canonicalGroupId(final Iterable<String> screenIds) {
    final members = _normalizeTokens(screenIds);
    if (members.isEmpty) {
      return 'group:';
    }
    return 'group:${members.join('+')}';
  }

  static LiveEditCanvasProjectionV2 projectCanvas({
    required final FlowGraphSnapshot graph,
    final LiveEditCanvasProjectionV2 previous =
        LiveEditCanvasProjectionV2.empty,
    final LiveEditTransactionV2? transaction,
    final Iterable<LiveEditCanvasActionV2> actions =
        const <LiveEditCanvasActionV2>[],
  }) {
    var state = _CanvasProjectionState.fromProjection(previous);
    state = _syncStateToGraph(state: state, graph: graph);
    for (final action in actions) {
      state = _applyCanvasAction(state: state, graph: graph, action: action);
      state = _syncStateToGraph(state: state, graph: graph);
    }
    return _materializeProjection(
      state: state,
      graph: graph,
      transaction: transaction,
    );
  }

  static List<LiveEditCanvasActionV2> deriveCanvasActionsFromPatch(
    final Iterable<LiveEditPatchOperationV2> patch,
  ) {
    final operations = patch.toList(growable: false)
      ..sort((final lhs, final rhs) {
        final idCompare = lhs.operationId.compareTo(rhs.operationId);
        if (idCompare != 0) {
          return idCompare;
        }
        final pathCompare = lhs.path.compareTo(rhs.path);
        if (pathCompare != 0) {
          return pathCompare;
        }
        return lhs.op.wireName.compareTo(rhs.op.wireName);
      });

    final actions = <LiveEditCanvasActionV2>[];
    for (final operation in operations) {
      final path = operation.path.trim();
      if (path.isEmpty) {
        continue;
      }
      final segments = _pathSegments(path);
      if (segments.isEmpty || segments.first != 'canvas') {
        continue;
      }
      if (segments.length >= 2 && segments[1] == 'groups') {
        if (segments.length == 2 &&
            (operation.op == LiveEditPatchOpV2.add ||
                operation.op == LiveEditPatchOpV2.set ||
                operation.op == LiveEditPatchOpV2.replace)) {
          final screenIds = _screenIdsFromPatchValue(operation.value);
          if (screenIds.length >= 2) {
            actions.add(
              LiveEditCanvasActionV2.wrapSelection(screenIds: screenIds),
            );
          }
          continue;
        }
        final groupId = segments.length >= 3
            ? _decodePathSegment(segments[2])
            : '';
        if (groupId.isEmpty) {
          continue;
        }
        if (operation.op == LiveEditPatchOpV2.remove && segments.length == 3) {
          actions.add(LiveEditCanvasActionV2.unwrapGroup(groupId: groupId));
          continue;
        }
        if (segments.length >= 4 && segments[3] == 'collapsed') {
          actions.add(
            LiveEditCanvasActionV2.setGroupCollapsed(
              groupId: groupId,
              collapsed: _asBool(operation.value, fallback: true),
            ),
          );
          continue;
        }
        if (operation.op == LiveEditPatchOpV2.add ||
            operation.op == LiveEditPatchOpV2.set ||
            operation.op == LiveEditPatchOpV2.replace) {
          final screenIds = _screenIdsFromPatchValue(operation.value);
          if (screenIds.length >= 2) {
            actions.add(
              LiveEditCanvasActionV2.wrapSelection(screenIds: screenIds),
            );
          }
        }
        continue;
      }
      if (segments.length >= 2 && segments[1] == 'wrap') {
        final screenIds = _screenIdsFromPatchValue(operation.value);
        if (screenIds.length >= 2) {
          actions.add(
            LiveEditCanvasActionV2.wrapSelection(screenIds: screenIds),
          );
        }
        continue;
      }
      if (segments.length >= 2 && segments[1] == 'unwrap') {
        final groupId =
            _asNullableString(operation.value) ??
            (segments.length >= 3 ? _decodePathSegment(segments[2]) : null);
        if (groupId != null) {
          actions.add(LiveEditCanvasActionV2.unwrapGroup(groupId: groupId));
        }
        continue;
      }
      if (segments.length >= 2 && segments[1] == 'focus') {
        final nodeId =
            _asNullableString(operation.value) ??
            (segments.length >= 3 ? _decodePathSegment(segments[2]) : null);
        if (nodeId != null) {
          actions.add(LiveEditCanvasActionV2.focusNode(nodeId: nodeId));
        }
      }
    }
    return List<LiveEditCanvasActionV2>.unmodifiable(actions);
  }

  static List<LiveEditPatchOperationV2> buildCompensationPatch(
    final Iterable<LiveEditPatchOperationV2> operations,
  ) {
    final inverse = <LiveEditPatchOperationV2>[];
    for (final operation in operations.toList(growable: false).reversed) {
      inverse.add(_invertPatchOperation(operation));
    }
    return List<LiveEditPatchOperationV2>.unmodifiable(inverse);
  }

  static LiveEditTimelinePipelineMappingV2 mapTransactionToPipeline({
    required final LiveEditTransactionV2 transaction,
    required final FlowGraphSnapshot graph,
    final LiveEditCanvasProjectionV2 previous =
        LiveEditCanvasProjectionV2.empty,
    final Iterable<LiveEditCanvasActionV2> additionalActions =
        const <LiveEditCanvasActionV2>[],
  }) {
    final actions = <LiveEditCanvasActionV2>[
      ...deriveCanvasActionsFromPatch(transaction.patch),
      ...additionalActions,
    ];
    final projection = projectCanvas(
      graph: graph,
      previous: previous,
      transaction: transaction,
      actions: actions,
    );
    final patchPrimitives = _buildPatchPrimitives(
      transaction: transaction,
      graph: graph,
      projection: projection,
    );
    final timelineEntries = _buildTimelineEntries(
      transaction: transaction,
      patchPrimitives: patchPrimitives,
    );
    return LiveEditTimelinePipelineMappingV2(
      projection: projection,
      actions: List<LiveEditCanvasActionV2>.unmodifiable(actions),
      timelineEntries: timelineEntries,
      patchPrimitives: patchPrimitives,
    );
  }

  static _CanvasProjectionState _syncStateToGraph({
    required final _CanvasProjectionState state,
    required final FlowGraphSnapshot graph,
  }) {
    final existingScreenIds = graph.screens
        .map((final screen) => screen.screenId.trim())
        .where((final screenId) => screenId.isNotEmpty)
        .toSet();
    final groups = _normalizeGroups(
      groups: state.groups.values,
      existingScreenIds: existingScreenIds,
    );
    final selectionScreenIds =
        state.selectionScreenIds
            .where(existingScreenIds.contains)
            .toList(growable: false)
          ..sort();
    return _CanvasProjectionState(
      groups: groups,
      focusedNodeId: state.focusedNodeId,
      selectionScreenIds: List<String>.unmodifiable(selectionScreenIds),
      viewport: state.viewport.copyWith(
        zoom: state.viewport.zoom.clamp(0.4, 2.5),
      ),
    );
  }

  static _CanvasProjectionState _applyCanvasAction({
    required final _CanvasProjectionState state,
    required final FlowGraphSnapshot graph,
    required final LiveEditCanvasActionV2 action,
  }) {
    final existingScreenIds = graph.screens
        .map((final screen) => screen.screenId.trim())
        .where((final screenId) => screenId.isNotEmpty)
        .toSet();
    final groups = Map<String, LiveEditCanvasGroupNodeV2>.from(state.groups);
    switch (action.kind) {
      case LiveEditCanvasActionKind.wrapSelection:
        final members = action.screenIds
            .where(existingScreenIds.contains)
            .toList(growable: false);
        final normalizedMembers = _normalizeTokens(members);
        if (normalizedMembers.length < 2) {
          return state;
        }
        final detachedGroups = <String, LiveEditCanvasGroupNodeV2>{};
        for (final entry in groups.entries) {
          final remainingMembers = entry.value.memberScreenIds
              .where((final item) => !normalizedMembers.contains(item))
              .toList(growable: false);
          if (remainingMembers.length < 2) {
            continue;
          }
          final canonicalId = canonicalGroupId(remainingMembers);
          detachedGroups[canonicalId] = LiveEditCanvasGroupNodeV2(
            nodeId: canonicalId,
            memberScreenIds: _normalizeTokens(remainingMembers),
            collapsed: entry.value.collapsed,
          );
        }
        final groupId = canonicalGroupId(normalizedMembers);
        final existingGroup = groups[groupId];
        detachedGroups[groupId] = LiveEditCanvasGroupNodeV2(
          nodeId: groupId,
          memberScreenIds: normalizedMembers,
          collapsed: existingGroup?.collapsed ?? true,
        );
        return _CanvasProjectionState(
          groups: detachedGroups,
          focusedNodeId: groupId,
          selectionScreenIds: normalizedMembers,
          viewport: state.viewport.copyWith(
            mode: LiveEditCanvasViewportMode.focusGroup,
          ),
        );
      case LiveEditCanvasActionKind.unwrapGroup:
        final groupId = _asNullableString(action.groupId);
        if (groupId == null || !groups.containsKey(groupId)) {
          return state;
        }
        final group = groups.remove(groupId)!;
        final focusTarget = group.memberScreenIds.isEmpty
            ? state.focusedNodeId
            : screenNodeId(group.memberScreenIds.first);
        return _CanvasProjectionState(
          groups: groups,
          focusedNodeId: focusTarget,
          selectionScreenIds: group.memberScreenIds,
          viewport: state.viewport.copyWith(
            mode: LiveEditCanvasViewportMode.focusScreen,
          ),
        );
      case LiveEditCanvasActionKind.toggleGroup:
        final groupId = _asNullableString(action.groupId);
        if (groupId == null || !groups.containsKey(groupId)) {
          return state;
        }
        final group = groups[groupId]!;
        groups[groupId] = group.copyWith(collapsed: !group.collapsed);
        return _CanvasProjectionState(
          groups: groups,
          focusedNodeId: groupId,
          selectionScreenIds: group.memberScreenIds,
          viewport: state.viewport.copyWith(
            mode: LiveEditCanvasViewportMode.focusGroup,
          ),
        );
      case LiveEditCanvasActionKind.setGroupCollapsed:
        final groupId = _asNullableString(action.groupId);
        if (groupId == null || !groups.containsKey(groupId)) {
          return state;
        }
        groups[groupId] = groups[groupId]!.copyWith(
          collapsed: action.collapsed ?? true,
        );
        return _CanvasProjectionState(
          groups: groups,
          focusedNodeId: groupId,
          selectionScreenIds: groups[groupId]!.memberScreenIds,
          viewport: state.viewport.copyWith(
            mode: LiveEditCanvasViewportMode.focusGroup,
          ),
        );
      case LiveEditCanvasActionKind.focusNode:
        final nodeId = _asNullableString(action.nodeId);
        if (nodeId == null) {
          return state;
        }
        return _CanvasProjectionState(
          groups: groups,
          focusedNodeId: nodeId,
          selectionScreenIds: state.selectionScreenIds,
          viewport: state.viewport.copyWith(
            mode: nodeId.startsWith('group:')
                ? LiveEditCanvasViewportMode.focusGroup
                : LiveEditCanvasViewportMode.focusScreen,
          ),
        );
    }
  }

  static LiveEditCanvasProjectionV2 _materializeProjection({
    required final _CanvasProjectionState state,
    required final FlowGraphSnapshot graph,
    required final LiveEditTransactionV2? transaction,
  }) {
    final groupedByMember = <String, LiveEditCanvasGroupNodeV2>{};
    for (final group in state.groups.values) {
      for (final member in group.memberScreenIds) {
        groupedByMember.putIfAbsent(member, () => group);
      }
    }
    final routeOrder = graph.routes.toList(growable: false)
      ..sort((final lhs, final rhs) => lhs.routeId.compareTo(rhs.routeId));
    final screenById = <String, ScreenSnapshot>{
      for (final screen in graph.screens)
        if (screen.screenId.trim().isNotEmpty) screen.screenId.trim(): screen,
    };
    final orderedScreenIds = <String>[
      ...routeOrder
          .map((final route) => route.screenId.trim())
          .where(
            (final screenId) =>
                screenId.isNotEmpty && screenById.containsKey(screenId),
          ),
      ...screenById.keys.where(
        (final screenId) =>
            !routeOrder.any((final route) => route.screenId.trim() == screenId),
      ),
    ];
    final uniqueScreenIds = _normalizeTokens(orderedScreenIds);
    final screenNodes = <LiveEditCanvasScreenNodeV2>[
      for (var index = 0; index < uniqueScreenIds.length; index += 1)
        _buildScreenNode(
          screen: screenById[uniqueScreenIds[index]]!,
          orderIndex: index,
          group: groupedByMember[uniqueScreenIds[index]],
        ),
    ]..sort((final lhs, final rhs) => lhs.nodeId.compareTo(rhs.nodeId));

    final groupNodes = state.groups.values.toList(growable: false)
      ..sort((final lhs, final rhs) => lhs.nodeId.compareTo(rhs.nodeId));

    final links = _buildLinks(
      graph: graph,
      screenNodes: screenNodes,
      groupNodes: groupNodes,
      transaction: transaction,
    );
    final focus = _resolveFocusedNode(
      requestedFocus: state.focusedNodeId,
      graph: graph,
      screenNodes: screenNodes,
      groupNodes: groupNodes,
    );
    final viewport = _resolveViewport(
      graph: graph,
      focus: focus,
      screenNodes: screenNodes,
      groupsById: {for (final group in groupNodes) group.nodeId: group},
      base: state.viewport,
    );
    final validSelection =
        state.selectionScreenIds
            .where((final screenId) => screenById.containsKey(screenId))
            .toList(growable: false)
          ..sort();
    return LiveEditCanvasProjectionV2(
      screenNodes: List<LiveEditCanvasScreenNodeV2>.unmodifiable(screenNodes),
      groupNodes: List<LiveEditCanvasGroupNodeV2>.unmodifiable(groupNodes),
      links: links,
      focusedNodeId: focus,
      selectionScreenIds: List<String>.unmodifiable(validSelection),
      viewport: viewport,
    );
  }

  static LiveEditCanvasScreenNodeV2 _buildScreenNode({
    required final ScreenSnapshot screen,
    required final int orderIndex,
    required final LiveEditCanvasGroupNodeV2? group,
  }) => LiveEditCanvasScreenNodeV2(
    nodeId: screenNodeId(screen.screenId),
    screenId: screen.screenId,
    routeId: screen.routeId,
    title: screen.title,
    x: orderIndex * 320,
    y: 0,
    groupId: group?.nodeId,
    hidden: group?.collapsed == true,
  );

  static String? _resolveFocusedNode({
    required final String? requestedFocus,
    required final FlowGraphSnapshot graph,
    required final List<LiveEditCanvasScreenNodeV2> screenNodes,
    required final List<LiveEditCanvasGroupNodeV2> groupNodes,
  }) {
    final hasFocusNode = (final String? nodeId) =>
        nodeId != null &&
        (screenNodes.any((final node) => node.nodeId == nodeId) ||
            groupNodes.any((final node) => node.nodeId == nodeId));
    if (hasFocusNode(requestedFocus)) {
      return requestedFocus;
    }
    final focusedScreen = _asNullableString(graph.focusedScreenId);
    if (focusedScreen != null) {
      final screenNode = screenNodes.firstWhere(
        (final node) => node.screenId == focusedScreen,
        orElse: () => const LiveEditCanvasScreenNodeV2(
          nodeId: '',
          screenId: '',
          routeId: '',
          title: '',
          x: 0,
          y: 0,
        ),
      );
      if (screenNode.nodeId.isNotEmpty) {
        if (screenNode.groupId != null) {
          final group = groupNodes.firstWhere(
            (final node) => node.nodeId == screenNode.groupId,
            orElse: () => const LiveEditCanvasGroupNodeV2(
              nodeId: '',
              memberScreenIds: <String>[],
            ),
          );
          if (group.nodeId.isNotEmpty && group.collapsed) {
            return group.nodeId;
          }
        }
        return screenNode.nodeId;
      }
    }
    if (screenNodes.isNotEmpty) {
      return screenNodes.first.nodeId;
    }
    if (groupNodes.isNotEmpty) {
      return groupNodes.first.nodeId;
    }
    return null;
  }

  static LiveEditCanvasViewportV2 _resolveViewport({
    required final FlowGraphSnapshot graph,
    required final String? focus,
    required final List<LiveEditCanvasScreenNodeV2> screenNodes,
    required final Map<String, LiveEditCanvasGroupNodeV2> groupsById,
    required final LiveEditCanvasViewportV2 base,
  }) {
    final screenByNodeId = <String, LiveEditCanvasScreenNodeV2>{
      for (final node in screenNodes) node.nodeId: node,
    };
    if (focus == null) {
      return base.copyWith(
        mode: LiveEditCanvasViewportMode.overview,
        zoom: base.zoom.clamp(0.4, 2.5),
      );
    }
    if (focus.startsWith('group:')) {
      final group = groupsById[focus];
      if (group == null || group.memberScreenIds.isEmpty) {
        return base.copyWith(
          mode: LiveEditCanvasViewportMode.focusGroup,
          zoom: base.zoom.clamp(0.4, 2.5),
        );
      }
      final memberNodes = group.memberScreenIds
          .map((final screenId) => screenByNodeId[screenNodeId(screenId)])
          .whereType<LiveEditCanvasScreenNodeV2>()
          .toList(growable: false);
      if (memberNodes.isEmpty) {
        return base.copyWith(
          mode: LiveEditCanvasViewportMode.focusGroup,
          zoom: base.zoom.clamp(0.4, 2.5),
        );
      }
      final centerX =
          memberNodes
              .map((final node) => node.x)
              .reduce((final lhs, final rhs) => lhs + rhs) /
          memberNodes.length;
      final centerY =
          memberNodes
              .map((final node) => node.y)
              .reduce((final lhs, final rhs) => lhs + rhs) /
          memberNodes.length;
      return base.copyWith(
        centerX: centerX,
        centerY: centerY,
        mode: LiveEditCanvasViewportMode.focusGroup,
        zoom: base.zoom.clamp(0.4, 2.5),
      );
    }
    final screenNode = screenByNodeId[focus];
    if (screenNode != null) {
      return base.copyWith(
        centerX: screenNode.x,
        centerY: screenNode.y,
        mode: LiveEditCanvasViewportMode.focusScreen,
        zoom: base.zoom.clamp(0.4, 2.5),
      );
    }
    final focusedScreenId = _asNullableString(graph.focusedScreenId);
    final fallback = focusedScreenId == null
        ? null
        : screenByNodeId[screenNodeId(focusedScreenId)];
    if (fallback != null) {
      return base.copyWith(
        centerX: fallback.x,
        centerY: fallback.y,
        mode: LiveEditCanvasViewportMode.focusScreen,
        zoom: base.zoom.clamp(0.4, 2.5),
      );
    }
    return base.copyWith(zoom: base.zoom.clamp(0.4, 2.5));
  }

  static List<LiveEditCanvasLinkV2> _buildLinks({
    required final FlowGraphSnapshot graph,
    required final List<LiveEditCanvasScreenNodeV2> screenNodes,
    required final List<LiveEditCanvasGroupNodeV2> groupNodes,
    required final LiveEditTransactionV2? transaction,
  }) {
    final screenNodeByScreenId = <String, LiveEditCanvasScreenNodeV2>{
      for (final node in screenNodes) node.screenId: node,
    };
    final collapsedGroupByScreenId = <String, LiveEditCanvasGroupNodeV2>{};
    for (final group in groupNodes) {
      if (!group.collapsed) {
        continue;
      }
      for (final screenId in group.memberScreenIds) {
        collapsedGroupByScreenId[screenId] = group;
      }
    }
    String? anchorForScreen(final String? screenId) {
      final resolved = _asNullableString(screenId);
      if (resolved == null) {
        return null;
      }
      final group = collapsedGroupByScreenId[resolved];
      if (group != null) {
        return group.nodeId;
      }
      return screenNodeByScreenId[resolved]?.nodeId;
    }

    final summaryBySelectionKey = <String, InteractionNodeSummary>{};
    for (final screen in graph.screens) {
      for (final summary in screen.nodeSummaries) {
        final key = summary.selectionKey.trim();
        if (key.isEmpty) {
          continue;
        }
        summaryBySelectionKey[key] = summary;
      }
    }

    final linksById = <String, LiveEditCanvasLinkV2>{};
    final orderedTransitions = graph.transitions.toList(growable: false)
      ..sort(
        (final lhs, final rhs) => lhs.transitionId.compareTo(rhs.transitionId),
      );
    for (final transition in orderedTransitions) {
      final fromAnchor = anchorForScreen(transition.fromScreenId);
      final toAnchor = anchorForScreen(transition.toScreenId);
      if (fromAnchor == null || toAnchor == null || fromAnchor == toAnchor) {
        continue;
      }
      final qualifier = transition.transitionId.trim().isNotEmpty
          ? transition.transitionId.trim()
          : '${_asString(transition.routeId, fallback: 'none')}:${_asString(transition.selectionKey, fallback: 'none')}';
      final screenLinkId = _linkId(
        kind: LiveEditCanvasLinkKind.screen,
        fromNodeId: fromAnchor,
        toNodeId: toAnchor,
        qualifier: qualifier,
      );
      linksById[screenLinkId] = LiveEditCanvasLinkV2(
        linkId: screenLinkId,
        kind: LiveEditCanvasLinkKind.screen,
        fromNodeId: fromAnchor,
        toNodeId: toAnchor,
        qualifier: qualifier,
      );
      final selectionKey = _asNullableString(transition.selectionKey);
      if (selectionKey == null ||
          !summaryBySelectionKey.containsKey(selectionKey)) {
        continue;
      }
      final sourceSummary = summaryBySelectionKey[selectionKey]!;
      final actionFromAnchor =
          anchorForScreen(sourceSummary.screenId) ?? fromAnchor;
      if (actionFromAnchor == toAnchor) {
        continue;
      }
      final actionLinkId = _linkId(
        kind: LiveEditCanvasLinkKind.action,
        fromNodeId: actionFromAnchor,
        toNodeId: toAnchor,
        qualifier: selectionKey,
      );
      linksById[actionLinkId] = LiveEditCanvasLinkV2(
        linkId: actionLinkId,
        kind: LiveEditCanvasLinkKind.action,
        fromNodeId: actionFromAnchor,
        toNodeId: toAnchor,
        qualifier: selectionKey,
      );
    }

    if (transaction != null) {
      final orderedTargets = transaction.targets.toList(growable: false)
        ..sort(
          (final lhs, final rhs) =>
              lhs.stableAddress.compareTo(rhs.stableAddress),
        );
      for (final target in orderedTargets) {
        if (target.kind != LiveEditTargetKindV2.animation &&
            target.kind != LiveEditTargetKindV2.state) {
          continue;
        }
        final sourceScreenId = _targetScreenId(
          target: target,
          graph: graph,
          summaryBySelectionKey: summaryBySelectionKey,
        );
        final fromAnchor = anchorForScreen(sourceScreenId);
        if (fromAnchor == null) {
          continue;
        }
        final toNodeId = switch (target.kind) {
          LiveEditTargetKindV2.animation =>
            'animation:${_asString(target.animationId ?? target.key)}',
          LiveEditTargetKindV2.state =>
            'state:${_asString(target.statePath ?? target.key)}',
          _ => '',
        };
        if (toNodeId.isEmpty) {
          continue;
        }
        final kind = target.kind == LiveEditTargetKindV2.animation
            ? LiveEditCanvasLinkKind.animation
            : LiveEditCanvasLinkKind.data;
        final linkId = _linkId(
          kind: kind,
          fromNodeId: fromAnchor,
          toNodeId: toNodeId,
          qualifier: target.stableAddress,
        );
        linksById[linkId] = LiveEditCanvasLinkV2(
          linkId: linkId,
          kind: kind,
          fromNodeId: fromAnchor,
          toNodeId: toNodeId,
          qualifier: target.stableAddress,
        );
      }
    }

    final links = linksById.values.toList(growable: false)
      ..sort((final lhs, final rhs) => lhs.linkId.compareTo(rhs.linkId));
    return List<LiveEditCanvasLinkV2>.unmodifiable(links);
  }

  static String _linkId({
    required final LiveEditCanvasLinkKind kind,
    required final String fromNodeId,
    required final String toNodeId,
    required final String qualifier,
  }) => 'link:${kind.wireName}:$fromNodeId->$toNodeId:$qualifier';

  static String? _targetScreenId({
    required final LiveEditTargetAddressV2 target,
    required final FlowGraphSnapshot graph,
    required final Map<String, InteractionNodeSummary> summaryBySelectionKey,
  }) {
    final screenId = _asNullableString(target.screenId);
    if (screenId != null) {
      return screenId;
    }
    final selectionKey = _asNullableString(target.selectionKey);
    if (selectionKey != null) {
      final summaryScreenId = _asNullableString(
        summaryBySelectionKey[selectionKey]?.screenId,
      );
      if (summaryScreenId != null) {
        return summaryScreenId;
      }
    }
    final metadataScreenId = _asNullableString(target.metadata['screenId']);
    if (metadataScreenId != null) {
      return metadataScreenId;
    }
    final focused = _asNullableString(graph.focusedScreenId);
    if (focused != null) {
      return focused;
    }
    if (graph.screens.isNotEmpty) {
      return _asNullableString(graph.screens.first.screenId);
    }
    return null;
  }

  static Map<String, LiveEditCanvasGroupNodeV2> _normalizeGroups({
    required final Iterable<LiveEditCanvasGroupNodeV2> groups,
    required final Set<String> existingScreenIds,
  }) {
    final normalized = <String, LiveEditCanvasGroupNodeV2>{};
    final claimedMembers = <String>{};
    final ordered = groups.toList(growable: false)
      ..sort((final lhs, final rhs) => lhs.nodeId.compareTo(rhs.nodeId));
    for (final group in ordered) {
      final members = group.memberScreenIds
          .where(existingScreenIds.contains)
          .where(claimedMembers.add)
          .toList(growable: false);
      final normalizedMembers = _normalizeTokens(members);
      if (normalizedMembers.length < 2) {
        continue;
      }
      final groupId = canonicalGroupId(normalizedMembers);
      normalized[groupId] = LiveEditCanvasGroupNodeV2(
        nodeId: groupId,
        memberScreenIds: normalizedMembers,
        collapsed: group.collapsed,
      );
    }
    return normalized;
  }

  static List<String> _screenIdsFromPatchValue(final Object? value) {
    if (value is List) {
      return _normalizeTokens(value);
    }
    if (value is Map) {
      final map = _asMap(value);
      final screenIds = map['screenIds'] ?? map['members'];
      if (screenIds is List) {
        return _normalizeTokens(screenIds);
      }
      final single = _asNullableString(screenIds);
      if (single != null) {
        return _normalizeTokens(single.split(','));
      }
    }
    final asString = _asNullableString(value);
    if (asString == null) {
      return const <String>[];
    }
    return _normalizeTokens(asString.split(','));
  }

  static List<LiveEditTimelinePatchPrimitiveV2> _buildPatchPrimitives({
    required final LiveEditTransactionV2 transaction,
    required final FlowGraphSnapshot graph,
    required final LiveEditCanvasProjectionV2 projection,
  }) {
    final operations = transaction.patch.toList(growable: false)
      ..sort((final lhs, final rhs) {
        final idCompare = lhs.operationId.compareTo(rhs.operationId);
        if (idCompare != 0) {
          return idCompare;
        }
        return lhs.path.compareTo(rhs.path);
      });
    final primitives = <LiveEditTimelinePatchPrimitiveV2>[];
    for (var index = 0; index < operations.length; index += 1) {
      final operation = operations[index];
      final refs = _resolveGraphRefsForPatch(
        operation: operation,
        graph: graph,
        projection: projection,
        targets: transaction.targets,
      );
      final primitiveId = operation.operationId.trim().isEmpty
          ? 'patch:$index'
          : operation.operationId.trim();
      primitives.add(
        LiveEditTimelinePatchPrimitiveV2(
          primitiveId: primitiveId,
          transactionId: transaction.transactionId,
          stage: _stageForPatchPath(operation.path),
          forwardPatch: operation,
          inversePatch: _invertPatchOperation(operation),
          graphNodeIds: refs.nodeIds,
          graphLinkIds: refs.linkIds,
        ),
      );
    }
    return List<LiveEditTimelinePatchPrimitiveV2>.unmodifiable(primitives);
  }

  static LiveEditEditNodeKindV2 _stageForPatchPath(final String path) {
    final segments = _pathSegments(path);
    if (segments.isEmpty) {
      return LiveEditEditNodeKindV2.patch;
    }
    return switch (segments.first) {
      'targets' => LiveEditEditNodeKindV2.target,
      'validation' => LiveEditEditNodeKindV2.validation,
      'apply' => LiveEditEditNodeKindV2.apply,
      'rollback' => LiveEditEditNodeKindV2.rollback,
      _ => LiveEditEditNodeKindV2.patch,
    };
  }

  static ({List<String> nodeIds, List<String> linkIds})
  _resolveGraphRefsForPatch({
    required final LiveEditPatchOperationV2 operation,
    required final FlowGraphSnapshot graph,
    required final LiveEditCanvasProjectionV2 projection,
    required final List<LiveEditTargetAddressV2> targets,
  }) {
    final nodeIds = <String>{};
    final linkIds = <String>{};
    final segments = _pathSegments(operation.path);
    if (segments.isNotEmpty &&
        segments.first == 'screens' &&
        segments.length >= 2) {
      nodeIds.add(screenNodeId(_decodePathSegment(segments[1])));
    }
    if (segments.isNotEmpty &&
        segments.first == 'canvas' &&
        segments.length >= 3 &&
        segments[1] == 'groups') {
      nodeIds.add(_decodePathSegment(segments[2]));
    }
    if (segments.isNotEmpty && segments.first == 'links') {
      final linkKind = _linkKindForPatchPath(segments);
      if (linkKind != null) {
        linkIds.addAll(
          projection.links
              .where((final link) => link.kind == linkKind)
              .map((final link) => link.linkId),
        );
      }
    }
    if (segments.isNotEmpty &&
        (segments.first == 'routes' || segments.first == 'transitions')) {
      linkIds.addAll(
        projection.links
            .where((final link) => link.kind == LiveEditCanvasLinkKind.screen)
            .map((final link) => link.linkId),
      );
    }
    final summaryBySelectionKey = <String, InteractionNodeSummary>{
      for (final screen in graph.screens)
        for (final summary in screen.nodeSummaries)
          if (summary.selectionKey.trim().isNotEmpty)
            summary.selectionKey.trim(): summary,
    };
    for (final target in targets) {
      final screenId = _targetScreenId(
        target: target,
        graph: graph,
        summaryBySelectionKey: summaryBySelectionKey,
      );
      if (screenId != null) {
        nodeIds.add(screenNodeId(screenId));
      }
    }
    if (nodeIds.isEmpty && projection.focusedNodeId != null) {
      nodeIds.add(projection.focusedNodeId!);
    }
    final orderedNodeIds = nodeIds.toList(growable: false)..sort();
    final orderedLinkIds = linkIds.toList(growable: false)..sort();
    return (
      nodeIds: List<String>.unmodifiable(orderedNodeIds),
      linkIds: List<String>.unmodifiable(orderedLinkIds),
    );
  }

  static LiveEditCanvasLinkKind? _linkKindForPatchPath(
    final List<String> segments,
  ) {
    if (segments.length < 3) {
      return LiveEditCanvasLinkKind.screen;
    }
    final role = _decodePathSegment(segments[2]).toLowerCase();
    return switch (role) {
      'action' => LiveEditCanvasLinkKind.action,
      'binding' || 'data' => LiveEditCanvasLinkKind.data,
      'animation_trigger' || 'animation' => LiveEditCanvasLinkKind.animation,
      _ => LiveEditCanvasLinkKind.screen,
    };
  }

  static LiveEditPatchOperationV2 _invertPatchOperation(
    final LiveEditPatchOperationV2 operation,
  ) {
    final inverseOperationId = operation.operationId.trim().isEmpty
        ? 'inverse:${operation.path}'
        : 'inverse:${operation.operationId}';
    switch (operation.op) {
      case LiveEditPatchOpV2.add:
        return LiveEditPatchOperationV2(
          operationId: inverseOperationId,
          op: LiveEditPatchOpV2.remove,
          path: operation.path,
          metadata: <String, Object?>{
            ...operation.metadata,
            'sourceOperationId': operation.operationId,
          },
        );
      case LiveEditPatchOpV2.remove:
        return LiveEditPatchOperationV2(
          operationId: inverseOperationId,
          op: LiveEditPatchOpV2.add,
          path: operation.path,
          value: operation.metadata['previousValue'],
          metadata: <String, Object?>{
            ...operation.metadata,
            'sourceOperationId': operation.operationId,
          },
        );
      case LiveEditPatchOpV2.move:
        final fromPath = _asNullableString(operation.fromPath);
        return LiveEditPatchOperationV2(
          operationId: inverseOperationId,
          op: LiveEditPatchOpV2.move,
          path: fromPath ?? operation.path,
          fromPath: operation.path,
          metadata: <String, Object?>{
            ...operation.metadata,
            'sourceOperationId': operation.operationId,
          },
        );
      case LiveEditPatchOpV2.replace:
      case LiveEditPatchOpV2.set:
        final previousValue = operation.metadata['previousValue'];
        final restoreOp = previousValue == null
            ? LiveEditPatchOpV2.remove
            : LiveEditPatchOpV2.set;
        return LiveEditPatchOperationV2(
          operationId: inverseOperationId,
          op: restoreOp,
          path: operation.path,
          value: previousValue,
          metadata: <String, Object?>{
            ...operation.metadata,
            'sourceOperationId': operation.operationId,
          },
        );
    }
  }

  static List<LiveEditTimelineProjectionEntryV2> _buildTimelineEntries({
    required final LiveEditTransactionV2 transaction,
    required final List<LiveEditTimelinePatchPrimitiveV2> patchPrimitives,
  }) {
    final graphNodes = transaction.graph.nodes.isNotEmpty
        ? transaction.graph.nodes
        : LiveEditEditGraphV2.linear().nodes;
    final orderedGraphNodes = graphNodes.toList(growable: false)
      ..sort((final lhs, final rhs) {
        final kindCompare = _compareGraphNodeKinds(lhs.kind, rhs.kind);
        if (kindCompare != 0) {
          return kindCompare;
        }
        return lhs.nodeId.compareTo(rhs.nodeId);
      });
    final baseTimestamp = transaction.intent.issuedAtMs;
    final entries = <LiveEditTimelineProjectionEntryV2>[];
    for (var index = 0; index < orderedGraphNodes.length; index += 1) {
      final node = orderedGraphNodes[index];
      entries.add(
        LiveEditTimelineProjectionEntryV2(
          eventId: 'graph:${transaction.transactionId}:${node.nodeId}',
          transactionId: transaction.transactionId,
          label: node.kind.wireName,
          timestampMs: baseTimestamp + index,
          detail: node.dependsOn.isEmpty
              ? ''
              : 'dependsOn:${node.dependsOn.join(',')}',
          state: node.status.wireName,
        ),
      );
    }
    for (var index = 0; index < patchPrimitives.length; index += 1) {
      final primitive = patchPrimitives[index];
      final detailParts = <String>[primitive.forwardPatch.path];
      if (primitive.graphNodeIds.isNotEmpty) {
        detailParts.add('nodes:${primitive.graphNodeIds.join('|')}');
      }
      if (primitive.graphLinkIds.isNotEmpty) {
        detailParts.add('links:${primitive.graphLinkIds.join('|')}');
      }
      entries.add(
        LiveEditTimelineProjectionEntryV2(
          eventId: 'patch:${primitive.primitiveId}',
          transactionId: transaction.transactionId,
          label: 'patch:${primitive.forwardPatch.op.wireName}',
          timestampMs: baseTimestamp + orderedGraphNodes.length + index,
          detail: detailParts.join(' '),
          state:
              primitive.graphNodeIds.isNotEmpty ||
                  primitive.graphLinkIds.isNotEmpty
              ? 'linked'
              : 'unlinked',
        ),
      );
    }
    return List<LiveEditTimelineProjectionEntryV2>.unmodifiable(entries);
  }
}

final class _CanvasProjectionState {
  const _CanvasProjectionState({
    required this.groups,
    required this.focusedNodeId,
    required this.selectionScreenIds,
    required this.viewport,
  });

  factory _CanvasProjectionState.fromProjection(
    final LiveEditCanvasProjectionV2 projection,
  ) => _CanvasProjectionState(
    groups: {for (final group in projection.groupNodes) group.nodeId: group},
    focusedNodeId: projection.focusedNodeId,
    selectionScreenIds: projection.selectionScreenIds,
    viewport: projection.viewport,
  );

  final Map<String, LiveEditCanvasGroupNodeV2> groups;
  final String? focusedNodeId;
  final List<String> selectionScreenIds;
  final LiveEditCanvasViewportV2 viewport;
}
