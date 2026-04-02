import 'package:flutter_live_edit_toolkit/src/models/live_edit_flow_graph_helpers.dart';
import 'package:flutter_live_edit_toolkit/src/models/live_edit_interaction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('live edit flow graph helpers', () {
    test('legacy and optimized match equivalent fixtures', () {
      final previous = buildFlowGraphBenchmarkSnapshot(
        screenCount: 6,
        nodesPerScreen: 8,
      );
      final current = buildFlowGraphBenchmarkSnapshot(
        screenCount: 6,
        nodesPerScreen: 8,
      );

      expect(legacyFlowGraphSnapshotsMatch(previous, current), isTrue);
      expect(flowGraphSnapshotsMatch(previous, current), isTrue);
    });

    test('optimized matcher detects a node mutation', () {
      final previous = buildFlowGraphBenchmarkSnapshot(
        screenCount: 4,
        nodesPerScreen: 5,
      );
      final current = _withMutatedFirstNode(previous);

      expect(legacyFlowGraphSnapshotsMatch(previous, current), isFalse);
      expect(flowGraphSnapshotsMatch(previous, current), isFalse);
    });

    test(
      'optimized matcher returns false when previous snapshot is missing',
      () {
        final current = buildFlowGraphBenchmarkSnapshot(
          screenCount: 2,
          nodesPerScreen: 3,
        );

        expect(flowGraphSnapshotsMatch(null, current), isFalse);
      },
    );
  });
}

FlowGraphSnapshot _withMutatedFirstNode(final FlowGraphSnapshot original) {
  final firstScreen = original.screens.first;
  final firstNode = firstScreen.nodeSummaries.first;
  final mutatedNode = InteractionNodeSummary(
    selectionKey: firstNode.selectionKey,
    nodeId: firstNode.nodeId,
    widgetType: 'SizedBox',
    bounds: firstNode.bounds,
    routeId: firstNode.routeId,
    screenId: firstNode.screenId,
    surfaceId: firstNode.surfaceId,
    source: firstNode.source,
    ownedByLocalProject: firstNode.ownedByLocalProject,
    hasProjectSourceHint: firstNode.hasProjectSourceHint,
    actionable: firstNode.actionable,
    structural: firstNode.structural,
  );

  final updatedScreens = <ScreenSnapshot>[
    ScreenSnapshot(
      screenId: firstScreen.screenId,
      routeId: firstScreen.routeId,
      title: firstScreen.title,
      surfaceId: firstScreen.surfaceId,
      nodeSummaries: <InteractionNodeSummary>[
        mutatedNode,
        ...firstScreen.nodeSummaries.skip(1),
      ],
    ),
    ...original.screens.skip(1),
  ];

  return FlowGraphSnapshot(
    screens: updatedScreens,
    routes: original.routes,
    transitions: original.transitions,
    focusedScreenId: original.focusedScreenId,
  );
}
