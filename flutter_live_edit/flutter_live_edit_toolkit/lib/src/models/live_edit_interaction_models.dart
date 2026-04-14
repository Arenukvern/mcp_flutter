import 'package:collection/collection.dart';
import 'package:live_edit_tooling_ui_kit/src/models/models.dart';
import 'package:meta/meta.dart';

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
      _ => fallback,
    };

int _asInt(final Object? value, {final int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_asString(value)) ?? fallback;
}

String _normalizeWireToken(final Object? value) =>
    _asString(value).replaceAll('-', '_').replaceAll(' ', '_').toLowerCase();

String? _wireName(final Object? value) {
  final direct = _asNullableString(value);
  if (direct != null) {
    return direct;
  }
  return switch (value) {
    final LiveEditTargetDomain value => value.wireName,
    _ => null,
  };
}

Map<String, Object?>? _toJsonMapOrNull(final Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return _asMap(value);
  }
  return switch (value) {
    final LiveEditSourceLocation value => value.toJson(),
    final LiveEditSourceTarget value => value.toJson(),
    final LiveEditSelection value => value.toJson(),
    _ => null,
  };
}

List<Map<String, Object?>> _jsonMapsFromIterable(
  final Iterable<Object?> values,
) {
  final maps = <Map<String, Object?>>[];
  for (final value in values) {
    final json = _toJsonMapOrNull(value);
    if (json == null || json.isEmpty) {
      continue;
    }
    maps.add(json);
  }
  return List<Map<String, Object?>>.unmodifiable(maps);
}

String? _selectionKeyOrNull(final Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
  final parsed = SelectionKey.fromJson(value);
  return parsed.isEmpty ? null : parsed;
}

String _selectionKeyText(final Object? value, {final String fallback = ''}) =>
    _selectionKeyOrNull(value) ?? _asString(value, fallback: fallback);

List<String> _normalizeSelectionKeys(final Iterable<Object?> keys) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final key in keys) {
    final parsed = _selectionKeyOrNull(key);
    if (parsed == null || !seen.add(parsed)) {
      continue;
    }
    normalized.add(parsed);
  }
  normalized.sort();
  return List<String>.unmodifiable(normalized);
}

List<EvidenceRef> _evidenceRefsFromIterable(final Iterable<Object?> values) {
  final refs = <EvidenceRef>[];
  for (final value in values) {
    refs.add(EvidenceRef.fromAny(value));
  }
  return List<EvidenceRef>.unmodifiable(refs);
}

@immutable
final class SelectionKey {
  const SelectionKey._();

  static String fromJson(final Object? value) {
    if (value is String) {
      return value.trim();
    }
    return _asString(value);
  }

  static String inspector(final String nodeId) => 'inspector:${nodeId.trim()}';

  static String surface(final String surfaceId) =>
      'surface:${surfaceId.trim()}';

  static String fallback({
    required final String sessionId,
    required final int ordinal,
  }) => 'fallback:${sessionId.trim()}:$ordinal';
}

enum InteractionSelectionOrigin {
  idle('idle'),
  hover('hover'),
  tap('tap'),
  marquee('marquee'),
  command('command'),
  bubble('bubble');

  const InteractionSelectionOrigin(this.wireName);

  final String wireName;

  static InteractionSelectionOrigin fromWire(final Object? value) {
    final normalized = _normalizeWireToken(value);
    return InteractionSelectionOrigin.values.firstWhere(
      (final item) => item.wireName == normalized,
      orElse: () => InteractionSelectionOrigin.idle,
    );
  }
}

enum InteractionFocusKind {
  node('node'),
  selectionSet('selection_set'),
  screen('screen'),
  transition('transition'),
  flow('flow');

  const InteractionFocusKind(this.wireName);

  final String wireName;

  static InteractionFocusKind fromWire(final Object? value) {
    final normalized = _normalizeWireToken(value);
    return InteractionFocusKind.values.firstWhere(
      (final item) => item.wireName == normalized,
      orElse: () => InteractionFocusKind.node,
    );
  }
}

typedef FlowFocusKind = InteractionFocusKind;

@immutable
final class InteractionSelectionSet {

  factory InteractionSelectionSet({
    final Object? primaryKey,
    final Iterable<Object?> memberKeys = const <Object?>[],
    final InteractionSelectionOrigin origin = InteractionSelectionOrigin.idle,
    final InteractionFocusKind focusKind = InteractionFocusKind.node,
  }) {
    final normalizedMembers = _normalizeSelectionKeys(memberKeys);
    if (normalizedMembers.isEmpty) {
      return InteractionSelectionSet._raw(
        primaryKey: null,
        memberKeys: const <String>[],
        origin: origin,
        focusKind: focusKind,
      );
    }
    final resolvedPrimary = _selectionKeyOrNull(primaryKey);
    return InteractionSelectionSet._raw(
      primaryKey: normalizedMembers.contains(resolvedPrimary)
          ? resolvedPrimary
          : normalizedMembers.first,
      memberKeys: normalizedMembers,
      origin: origin,
      focusKind: focusKind,
    );
  }
  const InteractionSelectionSet._raw({
    required this.primaryKey,
    required this.memberKeys,
    required this.origin,
    required this.focusKind,
  });

  factory InteractionSelectionSet.fromJson(final Map<String, Object?> json) =>
      InteractionSelectionSet(
        primaryKey: json['primaryKey'],
        memberKeys: _asList(json['memberKeys']),
        origin: InteractionSelectionOrigin.fromWire(json['origin']),
        focusKind: InteractionFocusKind.fromWire(json['focusKind']),
      );

  static const InteractionSelectionSet empty = InteractionSelectionSet._raw(
    primaryKey: null,
    memberKeys: <String>[],
    origin: InteractionSelectionOrigin.idle,
    focusKind: InteractionFocusKind.node,
  );

  final String? primaryKey;
  final List<String> memberKeys;
  final InteractionSelectionOrigin origin;
  final InteractionFocusKind focusKind;

  bool get isEmpty => memberKeys.isEmpty;

  bool get isSingle => memberKeys.length == 1;

  bool get isMulti => memberKeys.length > 1;

  bool contains(final Object? key) {
    final selectionKey = _selectionKeyOrNull(key);
    return selectionKey != null && memberKeys.contains(selectionKey);
  }

  bool sameMembers(final InteractionSelectionSet? other) {
    if (other == null || memberKeys.length != other.memberKeys.length) {
      return false;
    }
    final left = memberKeys.toList()..sort();
    final right = other.memberKeys.toList()..sort();
    return const ListEquality<String>().equals(left, right);
  }

  InteractionSelectionSet normalized({
    final String? primaryKey,
    final InteractionSelectionOrigin? origin,
    final InteractionFocusKind? focusKind,
  }) {
    final normalizedMembers = _normalizeSelectionKeys(memberKeys);
    if (normalizedMembers.isEmpty) {
      return InteractionSelectionSet(
        origin: origin ?? this.origin,
        focusKind: focusKind ?? this.focusKind,
      );
    }
    final resolvedPrimary =
        normalizedMembers.contains(primaryKey ?? this.primaryKey)
        ? primaryKey ?? this.primaryKey
        : normalizedMembers.first;
    return InteractionSelectionSet(
      primaryKey: resolvedPrimary,
      memberKeys: normalizedMembers,
      origin: origin ?? this.origin,
      focusKind: focusKind ?? this.focusKind,
    );
  }

  InteractionSelectionSet activate(final Object? key) {
    final selectionKey = _selectionKeyOrNull(key);
    if (selectionKey == null ||
        !contains(selectionKey) ||
        selectionKey == primaryKey) {
      return this;
    }
    return copyWith(primaryKey: selectionKey);
  }

  InteractionSelectionSet copyWith({
    final String? primaryKey,
    final List<String>? memberKeys,
    final InteractionSelectionOrigin? origin,
    final InteractionFocusKind? focusKind,
  }) => InteractionSelectionSet(
    primaryKey: primaryKey ?? this.primaryKey,
    memberKeys: memberKeys ?? this.memberKeys,
    origin: origin ?? this.origin,
    focusKind: focusKind ?? this.focusKind,
  ).normalized();

  Map<String, Object?> toJson() => <String, Object?>{
    if (primaryKey != null) 'primaryKey': primaryKey,
    'memberKeys': memberKeys,
    'origin': origin.wireName,
    'focusKind': focusKind.wireName,
  };
}

@immutable
final class InteractionNodeSummary {
  const InteractionNodeSummary({
    required this.selectionKey,
    required this.nodeId,
    required this.widgetType,
    this.bounds,
    this.routeId,
    this.screenId,
    this.surfaceId,
    this.source,
    this.ownedByLocalProject = false,
    this.hasProjectSourceHint = false,
    this.actionable = false,
    this.structural = false,
  });

  factory InteractionNodeSummary.fromJson(final Map<String, Object?> json) =>
      InteractionNodeSummary(
        selectionKey: _selectionKeyText(json['selectionKey'] ?? json['nodeId']),
        nodeId: _asString(json['nodeId']),
        widgetType: _asString(json['widgetType']),
        bounds: switch (json['bounds']) {
          final Map value => LiveEditBounds.fromJson(_asMap(value)),
          _ => null,
        },
        routeId: _asNullableString(json['routeId']),
        screenId: _asNullableString(json['screenId']),
        surfaceId: _asNullableString(json['surfaceId']),
        source: json['source'],
        ownedByLocalProject: _asBool(json['ownedByLocalProject']),
        hasProjectSourceHint: _asBool(json['hasProjectSourceHint']),
        actionable: _asBool(json['actionable']),
        structural: _asBool(json['structural']),
      );

  factory InteractionNodeSummary.fromSelection(
    final LiveEditSelection selection,
  ) {
    final selectionKey = selection.selectionKey.isEmpty
        ? selection.nodeId
        : selection.selectionKey;
    final source = selection.source;
    return InteractionNodeSummary(
      selectionKey: _selectionKeyText(selectionKey),
      nodeId: selection.nodeId,
      widgetType: selection.widgetType,
      bounds: selection.bounds,
      routeId: _asNullableString(selection.rawNode['routeId']),
      screenId: _asNullableString(selection.rawNode['screenId']),
      surfaceId: _asNullableString(selection.rawNode['surfaceId']),
      source: source,
      ownedByLocalProject: source != null,
      hasProjectSourceHint:
          _asNullableString(_toJsonMapOrNull(source)?['sourceHint']) != null,
      actionable: selection.propertiesForWire.isNotEmpty,
    );
  }

  final String selectionKey;
  final String nodeId;
  final String widgetType;
  final LiveEditBounds? bounds;
  final String? routeId;
  final String? screenId;
  final String? surfaceId;
  final Object? source;
  final bool ownedByLocalProject;
  final bool hasProjectSourceHint;
  final bool actionable;
  final bool structural;

  String? get sourceLabel {
    final json = _toJsonMapOrNull(source);
    final file = _asNullableString(json?['file']);
    if (file == null) {
      return _asNullableString(json?['sourceHint']);
    }
    final line = _asNullableString(json?['line']);
    return line == null ? file : '$file:$line';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'selectionKey': selectionKey,
    'nodeId': nodeId,
    'widgetType': widgetType,
    if (bounds != null) 'bounds': bounds!.toJson(),
    if (routeId != null) 'routeId': routeId,
    if (screenId != null) 'screenId': screenId,
    if (surfaceId != null) 'surfaceId': surfaceId,
    if (source != null)
      'source':
          _toJsonMapOrNull(source) ?? <String, Object?>{'value': '$source'},
    'ownedByLocalProject': ownedByLocalProject,
    'hasProjectSourceHint': hasProjectSourceHint,
    'actionable': actionable,
    'structural': structural,
  };
}

@immutable
final class RouteSnapshot {
  const RouteSnapshot({
    required this.routeId,
    required this.name,
    required this.screenId,
    this.presentationKind = 'route',
    this.isActive = true,
  });

  factory RouteSnapshot.fromJson(final Map<String, Object?> json) =>
      RouteSnapshot(
        routeId: _asString(json['routeId']),
        name: _asString(json['name'] ?? json['label']),
        screenId: _asString(json['screenId']),
        presentationKind: _asString(
          json['presentationKind'],
          fallback: 'route',
        ),
        isActive: _asBool(json['isActive'], fallback: true),
      );

  final String routeId;
  final String name;
  final String screenId;
  final String presentationKind;
  final bool isActive;

  Map<String, Object?> toJson() => <String, Object?>{
    'routeId': routeId,
    'name': name,
    'screenId': screenId,
    'presentationKind': presentationKind,
    'isActive': isActive,
  };
}

@immutable
final class ScreenSnapshot {
  const ScreenSnapshot({
    required this.screenId,
    required this.routeId,
    final String? title,
    final String? label,
    this.surfaceId,
    this.nodeSummaries = const <InteractionNodeSummary>[],
  }) : assert(title == null || label == null || title == label),
       title = title ?? label ?? '';

  factory ScreenSnapshot.fromJson(final Map<String, Object?> json) =>
      ScreenSnapshot(
        screenId: _asString(json['screenId']),
        routeId: _asString(json['routeId']),
        title: _asNullableString(json['title'] ?? json['label']),
        surfaceId: _asNullableString(json['surfaceId']),
        nodeSummaries: _asList(json['nodeSummaries'])
            .whereType<Map>()
            .map((final item) => InteractionNodeSummary.fromJson(_asMap(item)))
            .toList(growable: false),
      );

  final String screenId;
  final String routeId;
  final String title;
  final String? surfaceId;
  final List<InteractionNodeSummary> nodeSummaries;

  String get label => title;

  Map<String, Object?> toJson() => <String, Object?>{
    'screenId': screenId,
    'routeId': routeId,
    'title': title,
    'label': title,
    if (surfaceId != null) 'surfaceId': surfaceId,
    'nodeSummaries': nodeSummaries.map((final item) => item.toJson()).toList(),
  };
}

@immutable
final class ObservedTransition {
  const ObservedTransition({
    required this.transitionId,
    required this.kind,
    required this.fromScreenId,
    required this.toScreenId,
    this.selectionKey,
    this.routeId,
  });

  factory ObservedTransition.fromJson(final Map<String, Object?> json) =>
      ObservedTransition(
        transitionId: _asString(json['transitionId']),
        kind: _asString(json['kind']),
        fromScreenId: _asString(json['fromScreenId']),
        toScreenId: _asString(json['toScreenId']),
        selectionKey: _asNullableString(json['selectionKey']),
        routeId: _asNullableString(json['routeId']),
      );

  final String transitionId;
  final String kind;
  final String fromScreenId;
  final String toScreenId;
  final String? selectionKey;
  final String? routeId;

  Map<String, Object?> toJson() => <String, Object?>{
    'transitionId': transitionId,
    'kind': kind,
    'fromScreenId': fromScreenId,
    'toScreenId': toScreenId,
    if (selectionKey != null) 'selectionKey': selectionKey,
    if (routeId != null) 'routeId': routeId,
  };
}

@immutable
final class FlowGraphSnapshot {
  const FlowGraphSnapshot({
    this.screens = const <ScreenSnapshot>[],
    this.routes = const <RouteSnapshot>[],
    this.transitions = const <ObservedTransition>[],
    this.focusedScreenId,
  });

  factory FlowGraphSnapshot.fromJson(final Map<String, Object?> json) =>
      FlowGraphSnapshot(
        screens: _asList(json['screens'])
            .whereType<Map>()
            .map((final item) => ScreenSnapshot.fromJson(_asMap(item)))
            .toList(growable: false),
        routes: _asList(json['routes'])
            .whereType<Map>()
            .map((final item) => RouteSnapshot.fromJson(_asMap(item)))
            .toList(growable: false),
        transitions: _asList(json['transitions'])
            .whereType<Map>()
            .map((final item) => ObservedTransition.fromJson(_asMap(item)))
            .toList(growable: false),
        focusedScreenId: _asNullableString(
          json['focusedScreenId'] ?? json['currentScreenId'],
        ),
      );

  static const FlowGraphSnapshot empty = FlowGraphSnapshot();

  final List<ScreenSnapshot> screens;
  final List<RouteSnapshot> routes;
  final List<ObservedTransition> transitions;
  final String? focusedScreenId;

  Map<String, Object?> toJson() => <String, Object?>{
    'screens': screens.map((final item) => item.toJson()).toList(),
    'routes': routes.map((final item) => item.toJson()).toList(),
    'transitions': transitions.map((final item) => item.toJson()).toList(),
    if (focusedScreenId != null) 'focusedScreenId': focusedScreenId,
  };
}

enum FlowSelectionIntentKind {
  changeWidget('widget_change'),
  changeTransition('transition_change'),
  changeFlow('flow_change'),
  changeOutcome('outcome_change');

  const FlowSelectionIntentKind(this.wireName);

  final String wireName;

  static FlowSelectionIntentKind fromWire(final Object? value) => switch (_normalizeWireToken(value)) {
      'widget_change' ||
      'change_widget' ||
      'changewidget' => FlowSelectionIntentKind.changeWidget,
      'transition_change' ||
      'change_transition' ||
      'changetransition' => FlowSelectionIntentKind.changeTransition,
      'flow_change' ||
      'change_flow' ||
      'changeflow' => FlowSelectionIntentKind.changeFlow,
      'outcome_change' ||
      'change_outcome' ||
      'changeoutcome' => FlowSelectionIntentKind.changeOutcome,
      _ => FlowSelectionIntentKind.changeWidget,
    };
}

@immutable
final class FlowSelectionIntent {
  const FlowSelectionIntent({
    required this.kind,
    this.fromSelectionKey,
    this.toSelectionKey,
    this.transitionId,
    this.instructions = '',
  });

  factory FlowSelectionIntent.fromJson(final Map<String, Object?> json) =>
      FlowSelectionIntent(
        kind: FlowSelectionIntentKind.fromWire(json['kind']),
        fromSelectionKey: _selectionKeyOrNull(json['fromSelectionKey']),
        toSelectionKey: _selectionKeyOrNull(json['toSelectionKey']),
        transitionId: _asNullableString(json['transitionId']),
        instructions: _asString(json['instructions']),
      );

  final FlowSelectionIntentKind kind;
  final String? fromSelectionKey;
  final String? toSelectionKey;
  final String? transitionId;
  final String instructions;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wireName,
    if (fromSelectionKey != null) 'fromSelectionKey': fromSelectionKey,
    if (toSelectionKey != null) 'toSelectionKey': toSelectionKey,
    if (transitionId != null) 'transitionId': transitionId,
    if (instructions.isNotEmpty) 'instructions': instructions,
  };
}

@immutable
final class DraftTargetContext {

  factory DraftTargetContext({
    final Object? targetDomain,
    final Object? selectionKey,
    final String? screenId,
    final String? routeId,
    final String? surfaceId,
    final String? transitionId,
    final Iterable<Object?> sourceTargets = const <Object?>[],
  }) => DraftTargetContext._raw(
    targetDomain: _wireName(targetDomain),
    selectionKey: _selectionKeyOrNull(selectionKey),
    screenId: _asNullableString(screenId),
    routeId: _asNullableString(routeId),
    surfaceId: _asNullableString(surfaceId),
    transitionId: _asNullableString(transitionId),
    sourceTargets: _jsonMapsFromIterable(sourceTargets),
  );
  const DraftTargetContext._raw({
    required this.targetDomain,
    required this.selectionKey,
    required this.screenId,
    required this.routeId,
    required this.surfaceId,
    required this.transitionId,
    required this.sourceTargets,
  });

  factory DraftTargetContext.fromJson(final Map<String, Object?> json) =>
      DraftTargetContext(
        targetDomain: json['targetDomain'],
        selectionKey: json['selectionKey'],
        screenId: _asNullableString(json['screenId']),
        routeId: _asNullableString(json['routeId']),
        surfaceId: _asNullableString(json['surfaceId']),
        transitionId: _asNullableString(json['transitionId']),
        sourceTargets: _asList(json['sourceTargets']),
      );

  static const DraftTargetContext empty = DraftTargetContext._raw(
    targetDomain: null,
    selectionKey: null,
    screenId: null,
    routeId: null,
    surfaceId: null,
    transitionId: null,
    sourceTargets: <Map<String, Object?>>[],
  );

  final String? targetDomain;
  final String? selectionKey;
  final String? screenId;
  final String? routeId;
  final String? surfaceId;
  final String? transitionId;
  final List<Map<String, Object?>> sourceTargets;

  Map<String, Object?> toJson() => <String, Object?>{
    if (targetDomain != null) 'targetDomain': targetDomain,
    if (selectionKey != null) 'selectionKey': selectionKey,
    if (screenId != null) 'screenId': screenId,
    if (routeId != null) 'routeId': routeId,
    if (surfaceId != null) 'surfaceId': surfaceId,
    if (transitionId != null) 'transitionId': transitionId,
    if (sourceTargets.isNotEmpty) 'sourceTargets': sourceTargets,
  };
}

@immutable
final class EvidenceRef {
  const EvidenceRef({
    required this.kind,
    required this.refId,
    required this.summary,
    this.compactSummary = const <String, Object?>{},
  });

  factory EvidenceRef.fromAny(final Object? value) {
    if (value is EvidenceRef) {
      return value;
    }
    return EvidenceRef.fromJson(_asMap(value));
  }

  factory EvidenceRef.fromJson(final Map<String, Object?> json) => EvidenceRef(
    kind: _asString(json['kind']),
    refId: _asString(json['refId']),
    summary: _asString(json['summary']),
    compactSummary: _asMap(json['compactSummary']),
  );

  final String kind;
  final String refId;
  final String summary;
  final Map<String, Object?> compactSummary;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind,
    'refId': refId,
    'summary': summary,
    if (compactSummary.isNotEmpty) 'compactSummary': compactSummary,
  };
}

@immutable
final class AgentContextBudget {
  const AgentContextBudget({
    this.maxScreens = 3,
    this.maxNodesPerScreen = 12,
    this.maxSelectedNodes = 8,
    this.maxTransitions = 8,
    this.maxSourceTargets = 6,
    this.maxEvidenceItems = 4,
  });

  factory AgentContextBudget.fromJson(final Map<String, Object?> json) =>
      AgentContextBudget(
        maxScreens: _asInt(json['maxScreens'], fallback: 3),
        maxNodesPerScreen: _asInt(json['maxNodesPerScreen'], fallback: 12),
        maxSelectedNodes: _asInt(json['maxSelectedNodes'], fallback: 8),
        maxTransitions: _asInt(json['maxTransitions'], fallback: 8),
        maxSourceTargets: _asInt(json['maxSourceTargets'], fallback: 6),
        maxEvidenceItems: _asInt(json['maxEvidenceItems'], fallback: 4),
      );

  final int maxScreens;
  final int maxNodesPerScreen;
  final int maxSelectedNodes;
  final int maxTransitions;
  final int maxSourceTargets;
  final int maxEvidenceItems;

  Map<String, Object?> toJson() => <String, Object?>{
    'maxScreens': maxScreens,
    'maxNodesPerScreen': maxNodesPerScreen,
    'maxSelectedNodes': maxSelectedNodes,
    'maxTransitions': maxTransitions,
    'maxSourceTargets': maxSourceTargets,
    'maxEvidenceItems': maxEvidenceItems,
  };
}

@immutable
final class FlowFocus {

  factory FlowFocus({
    final String? currentScreenId,
    final String? screenId,
    final InteractionSelectionSet? activeSelectionSet,
    final InteractionSelectionSet? selectionSet,
    final String? transitionId,
    final FlowSelectionIntent? userIntent,
    final FlowSelectionIntent? intent,
  }) => FlowFocus._raw(
    currentScreenId: currentScreenId ?? screenId,
    activeSelectionSet: activeSelectionSet ?? selectionSet,
    transitionId: _asNullableString(transitionId),
    userIntent: userIntent ?? intent,
  );
  const FlowFocus._raw({
    required this.currentScreenId,
    required this.activeSelectionSet,
    required this.transitionId,
    required this.userIntent,
  });

  factory FlowFocus.fromJson(final Map<String, Object?> json) => FlowFocus(
    currentScreenId: _asNullableString(
      json['currentScreenId'] ?? json['screenId'],
    ),
    activeSelectionSet: switch (json['activeSelectionSet'] ??
        json['selectionSet']) {
      final Map value => InteractionSelectionSet.fromJson(_asMap(value)),
      _ => null,
    },
    transitionId: _asNullableString(json['transitionId']),
    userIntent: switch (json['userIntent'] ?? json['intent']) {
      final Map value => FlowSelectionIntent.fromJson(_asMap(value)),
      _ => null,
    },
  );

  final String? currentScreenId;
  final InteractionSelectionSet? activeSelectionSet;
  final String? transitionId;
  final FlowSelectionIntent? userIntent;

  String? get screenId => currentScreenId;

  InteractionSelectionSet? get selectionSet => activeSelectionSet;

  FlowSelectionIntent? get intent => userIntent;

  Map<String, Object?> toJson() => <String, Object?>{
    if (currentScreenId != null) 'currentScreenId': currentScreenId,
    if (activeSelectionSet != null)
      'activeSelectionSet': activeSelectionSet!.toJson(),
    if (transitionId != null) 'transitionId': transitionId,
    if (userIntent != null) 'userIntent': userIntent!.toJson(),
  };
}

@immutable
final class AgentContextEnvelope {

  factory AgentContextEnvelope({
    required final FlowFocus focus,
    final List<ScreenSnapshot> screenSlice = const <ScreenSnapshot>[],
    final List<ObservedTransition> flowSlice = const <ObservedTransition>[],
    final Iterable<Object?> sourceTargets = const <Object?>[],
    final Iterable<Object?> evidenceRefs = const <Object?>[],
    final AgentContextBudget budget = const AgentContextBudget(),
  }) => AgentContextEnvelope._raw(
    focus: focus,
    screenSlice: List<ScreenSnapshot>.unmodifiable(screenSlice),
    flowSlice: List<ObservedTransition>.unmodifiable(flowSlice),
    sourceTargets: _jsonMapsFromIterable(sourceTargets),
    evidenceRefs: _evidenceRefsFromIterable(evidenceRefs),
    budget: budget,
  );
  const AgentContextEnvelope._raw({
    required this.focus,
    required this.screenSlice,
    required this.flowSlice,
    required this.sourceTargets,
    required this.evidenceRefs,
    required this.budget,
  });

  factory AgentContextEnvelope.fromJson(final Map<String, Object?> json) =>
      AgentContextEnvelope(
        focus: FlowFocus.fromJson(_asMap(json['focus'])),
        screenSlice: _asList(json['screenSlice'])
            .whereType<Map>()
            .map((final item) => ScreenSnapshot.fromJson(_asMap(item)))
            .toList(growable: false),
        flowSlice: _asList(json['flowSlice'])
            .whereType<Map>()
            .map((final item) => ObservedTransition.fromJson(_asMap(item)))
            .toList(growable: false),
        sourceTargets: _asList(json['sourceTargets']),
        evidenceRefs: _asList(json['evidenceRefs']),
        budget: switch (json['budget']) {
          final Map value => AgentContextBudget.fromJson(_asMap(value)),
          _ => const AgentContextBudget(),
        },
      );

  final FlowFocus focus;
  final List<ScreenSnapshot> screenSlice;
  final List<ObservedTransition> flowSlice;
  final List<Map<String, Object?>> sourceTargets;
  final List<EvidenceRef> evidenceRefs;
  final AgentContextBudget budget;

  Map<String, Object?> toJson() => <String, Object?>{
    'focus': focus.toJson(),
    'screenSlice': screenSlice.map((final item) => item.toJson()).toList(),
    'flowSlice': flowSlice.map((final item) => item.toJson()).toList(),
    if (sourceTargets.isNotEmpty) 'sourceTargets': sourceTargets,
    if (evidenceRefs.isNotEmpty)
      'evidenceRefs': evidenceRefs.map((final item) => item.toJson()).toList(),
    'budget': budget.toJson(),
  };
}
