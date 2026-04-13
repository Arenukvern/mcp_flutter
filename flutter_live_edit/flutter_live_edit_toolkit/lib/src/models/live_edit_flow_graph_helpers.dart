import 'dart:convert';

import 'package:live_edit_tooling_ui_kit/src/models/models.dart';

import 'live_edit_interaction_models.dart';
import 'live_edit_models.dart';

bool flowGraphSnapshotsMatch(
  final FlowGraphSnapshot? previous,
  final FlowGraphSnapshot current,
) {
  if (previous == null) {
    return false;
  }
  if (previous.focusedScreenId != current.focusedScreenId ||
      previous.screens.length != current.screens.length ||
      previous.routes.length != current.routes.length ||
      previous.transitions.length != current.transitions.length) {
    return false;
  }
  for (var index = 0; index < previous.screens.length; index += 1) {
    if (!_screensMatch(previous.screens[index], current.screens[index])) {
      return false;
    }
  }
  for (var index = 0; index < previous.routes.length; index += 1) {
    if (!_routesMatch(previous.routes[index], current.routes[index])) {
      return false;
    }
  }
  for (var index = 0; index < previous.transitions.length; index += 1) {
    if (!_transitionsMatch(
      previous.transitions[index],
      current.transitions[index],
    )) {
      return false;
    }
  }
  return true;
}

bool legacyFlowGraphSnapshotsMatch(
  final FlowGraphSnapshot previous,
  final FlowGraphSnapshot current,
) {
  if (previous.focusedScreenId != current.focusedScreenId ||
      previous.screens.length != current.screens.length ||
      previous.routes.length != current.routes.length ||
      previous.transitions.length != current.transitions.length) {
    return false;
  }
  for (var index = 0; index < previous.screens.length; index += 1) {
    if (jsonEncode(previous.screens[index].toJson()) !=
        jsonEncode(current.screens[index].toJson())) {
      return false;
    }
  }
  for (var index = 0; index < previous.routes.length; index += 1) {
    if (jsonEncode(previous.routes[index].toJson()) !=
        jsonEncode(current.routes[index].toJson())) {
      return false;
    }
  }
  for (var index = 0; index < previous.transitions.length; index += 1) {
    if (jsonEncode(previous.transitions[index].toJson()) !=
        jsonEncode(current.transitions[index].toJson())) {
      return false;
    }
  }
  return true;
}

FlowGraphSnapshot buildFlowGraphBenchmarkSnapshot({
  required final int screenCount,
  required final int nodesPerScreen,
}) {
  final screens = List<ScreenSnapshot>.generate(screenCount, (
    final screenIndex,
  ) {
    final screenId = 'screen-$screenIndex';
    final routeId = 'route-$screenIndex';
    final nodes = List<InteractionNodeSummary>.generate(nodesPerScreen, (
      final nodeIndex,
    ) {
      final left = (nodeIndex % 11) * 13.0;
      final top = (nodeIndex % 7) * 9.0;
      return InteractionNodeSummary(
        selectionKey: 'inspector:$screenIndex:$nodeIndex',
        nodeId: 'node-$screenIndex-$nodeIndex',
        widgetType: nodeIndex.isEven ? 'Text' : 'Container',
        bounds: LiveEditBounds(
          left: left,
          top: top,
          right: left + 120,
          bottom: top + 34,
          width: 120,
          height: 34,
        ),
        routeId: routeId,
        screenId: screenId,
        surfaceId: 'surface-$screenIndex',
        source: LiveEditSourceLocation(
          file: 'lib/screen_$screenIndex.dart',
          line: nodeIndex + 1,
          column: 1,
          sourceHint: 'screen_$screenIndex',
        ),
        ownedByLocalProject: true,
        hasProjectSourceHint: true,
        actionable: true,
      );
    });
    return ScreenSnapshot(
      screenId: screenId,
      routeId: routeId,
      title: 'Screen $screenIndex',
      surfaceId: 'surface-$screenIndex',
      nodeSummaries: nodes,
    );
  });

  final routes = List<RouteSnapshot>.generate(
    screenCount,
    (final index) => RouteSnapshot(
      routeId: 'route-$index',
      name: '/r/$index',
      screenId: 'screen-$index',
      isActive: index == 0,
    ),
  );

  final transitions = List<ObservedTransition>.generate(
    screenCount - 1,
    (final index) => ObservedTransition(
      transitionId: 't-$index',
      kind: 'tap',
      fromScreenId: 'screen-$index',
      toScreenId: 'screen-${index + 1}',
      selectionKey: 'inspector:$index:0',
      routeId: 'route-$index',
    ),
  );

  return FlowGraphSnapshot(
    screens: screens,
    routes: routes,
    transitions: transitions,
    focusedScreenId: 'screen-0',
  );
}

bool _screensMatch(final ScreenSnapshot lhs, final ScreenSnapshot rhs) {
  if (lhs.screenId != rhs.screenId ||
      lhs.routeId != rhs.routeId ||
      lhs.title != rhs.title ||
      lhs.surfaceId != rhs.surfaceId ||
      lhs.nodeSummaries.length != rhs.nodeSummaries.length) {
    return false;
  }
  for (var index = 0; index < lhs.nodeSummaries.length; index += 1) {
    if (!_nodeSummariesMatch(
      lhs.nodeSummaries[index],
      rhs.nodeSummaries[index],
    )) {
      return false;
    }
  }
  return true;
}

bool _nodeSummariesMatch(
  final InteractionNodeSummary lhs,
  final InteractionNodeSummary rhs,
) =>
    lhs.selectionKey == rhs.selectionKey &&
    lhs.nodeId == rhs.nodeId &&
    lhs.widgetType == rhs.widgetType &&
    lhs.bounds == rhs.bounds &&
    lhs.routeId == rhs.routeId &&
    lhs.screenId == rhs.screenId &&
    lhs.surfaceId == rhs.surfaceId &&
    lhs.source == rhs.source &&
    lhs.ownedByLocalProject == rhs.ownedByLocalProject &&
    lhs.hasProjectSourceHint == rhs.hasProjectSourceHint &&
    lhs.actionable == rhs.actionable &&
    lhs.structural == rhs.structural;

bool _routesMatch(final RouteSnapshot lhs, final RouteSnapshot rhs) =>
    lhs.routeId == rhs.routeId &&
    lhs.name == rhs.name &&
    lhs.screenId == rhs.screenId &&
    lhs.presentationKind == rhs.presentationKind &&
    lhs.isActive == rhs.isActive;

bool _transitionsMatch(
  final ObservedTransition lhs,
  final ObservedTransition rhs,
) =>
    lhs.transitionId == rhs.transitionId &&
    lhs.kind == rhs.kind &&
    lhs.fromScreenId == rhs.fromScreenId &&
    lhs.toScreenId == rhs.toScreenId &&
    lhs.selectionKey == rhs.selectionKey &&
    lhs.routeId == rhs.routeId;
