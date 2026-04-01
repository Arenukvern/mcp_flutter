// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter_live_edit_toolkit/src/models/live_edit_interaction_models.dart';
import 'package:flutter_live_edit_toolkit/src/models/live_edit_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

void main() {
  test('flow graph matcher removes JSON-encode bottleneck', () {
    final previous = _buildSnapshot(screenCount: 18, nodesPerScreen: 44);
    final current = _buildSnapshot(screenCount: 18, nodesPerScreen: 44);

    const iterations = 260;
    const frameBudgetUs = 16667;

    final legacySamples = _measureComparator(
      iterations: iterations,
      compare: () => _legacyFlowGraphMatch(previous, current),
    );
    final optimizedSamples = _measureComparator(
      iterations: iterations,
      compare: () => _optimizedFlowGraphMatch(previous, current),
    );

    final legacyP95Us = _p95Micros(legacySamples.samples);
    final optimizedP95Us = _p95Micros(optimizedSamples.samples);
    final legacyJankFrames = _jankFrames(
      legacySamples.samples,
      frameBudgetUs: frameBudgetUs,
    );
    final optimizedJankFrames = _jankFrames(
      optimizedSamples.samples,
      frameBudgetUs: frameBudgetUs,
    );

    print(
      'live_edit_flow_graph_perf '
      'legacy_p95_us=$legacyP95Us '
      'optimized_p95_us=$optimizedP95Us '
      'legacy_jank_frames=$legacyJankFrames '
      'optimized_jank_frames=$optimizedJankFrames '
      'iterations=$iterations',
    );

    expect(legacySamples.allMatched, isTrue);
    expect(optimizedSamples.allMatched, isTrue);
    expect(
      optimizedP95Us,
      lessThan(legacyP95Us),
      reason: 'Optimized matcher should beat legacy JSON encoding matcher.',
    );
    expect(
      optimizedJankFrames,
      lessThanOrEqualTo(legacyJankFrames),
      reason: 'Optimized matcher should not increase frame-budget overruns.',
    );
  });
}

({List<int> samples, bool allMatched}) _measureComparator({
  required final int iterations,
  required final bool Function() compare,
}) {
  final samples = <int>[];
  var allMatched = true;
  for (var i = 0; i < iterations; i += 1) {
    final watch = Stopwatch()..start();
    final matched = compare();
    watch.stop();
    allMatched = allMatched && matched;
    samples.add(watch.elapsedMicroseconds);
  }
  return (samples: samples, allMatched: allMatched);
}

int _p95Micros(final List<int> samples) {
  if (samples.isEmpty) {
    return 0;
  }
  final sorted = List<int>.from(samples)..sort();
  final index = ((sorted.length - 1) * 0.95).round();
  return sorted[index];
}

int _jankFrames(final List<int> samples, {required final int frameBudgetUs}) =>
    samples.where((final elapsed) => elapsed > frameBudgetUs).length;

bool _legacyFlowGraphMatch(
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

bool _optimizedFlowGraphMatch(
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
) {
  return lhs.selectionKey == rhs.selectionKey &&
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
}

bool _routesMatch(final RouteSnapshot lhs, final RouteSnapshot rhs) {
  return lhs.routeId == rhs.routeId &&
      lhs.name == rhs.name &&
      lhs.screenId == rhs.screenId &&
      lhs.presentationKind == rhs.presentationKind &&
      lhs.isActive == rhs.isActive;
}

bool _transitionsMatch(
  final ObservedTransition lhs,
  final ObservedTransition rhs,
) {
  return lhs.transitionId == rhs.transitionId &&
      lhs.kind == rhs.kind &&
      lhs.fromScreenId == rhs.fromScreenId &&
      lhs.toScreenId == rhs.toScreenId &&
      lhs.selectionKey == rhs.selectionKey &&
      lhs.routeId == rhs.routeId;
}

FlowGraphSnapshot _buildSnapshot({
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

  final routes = List<RouteSnapshot>.generate(screenCount, (final index) {
    return RouteSnapshot(
      routeId: 'route-$index',
      name: '/r/$index',
      screenId: 'screen-$index',
      isActive: index == 0,
    );
  });

  final transitions = List<ObservedTransition>.generate(screenCount - 1, (
    final index,
  ) {
    return ObservedTransition(
      transitionId: 't-$index',
      kind: 'tap',
      fromScreenId: 'screen-$index',
      toScreenId: 'screen-${index + 1}',
      selectionKey: 'inspector:$index:0',
      routeId: 'route-$index',
    );
  });

  return FlowGraphSnapshot(
    screens: screens,
    routes: routes,
    transitions: transitions,
    focusedScreenId: 'screen-0',
  );
}
