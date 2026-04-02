import 'dart:convert';

import 'package:flutter_live_edit_toolkit/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveEditTimelinePipelinePrimitivesV2 canvas projection', () {
    test('wraps and unwraps screens deterministically', () {
      final graph = _fixtureFlowGraph();
      final wrapped = LiveEditTimelinePipelinePrimitivesV2.projectCanvas(
        graph: graph,
        actions: <LiveEditCanvasActionV2>[
          LiveEditCanvasActionV2.wrapSelection(
            screenIds: <String>['product', 'home'],
          ),
        ],
      );

      expect(wrapped.groupNodes, hasLength(1));
      expect(wrapped.groupNodes.single.nodeId, 'group:home+product');
      final homeNode = wrapped.screenNodes.firstWhere(
        (final node) => node.screenId == 'home',
      );
      final productNode = wrapped.screenNodes.firstWhere(
        (final node) => node.screenId == 'product',
      );
      expect(homeNode.hidden, isTrue);
      expect(productNode.hidden, isTrue);
      expect(wrapped.focusedNodeId, 'group:home+product');
      expect(
        wrapped.links.any(
          (final link) =>
              link.kind == LiveEditCanvasLinkKind.screen &&
              link.fromNodeId == 'group:home+product' &&
              link.toNodeId == 'screen:cart',
        ),
        isTrue,
      );
      expect(
        wrapped.links.any(
          (final link) =>
              link.kind == LiveEditCanvasLinkKind.screen &&
              link.fromNodeId == 'screen:home' &&
              link.toNodeId == 'screen:product',
        ),
        isFalse,
      );

      final replay = LiveEditTimelinePipelinePrimitivesV2.projectCanvas(
        graph: graph,
        actions: <LiveEditCanvasActionV2>[
          LiveEditCanvasActionV2.wrapSelection(
            screenIds: <String>['home', 'product'],
          ),
        ],
      );
      expect(jsonEncode(replay.toJson()), jsonEncode(wrapped.toJson()));

      final unwrapped = LiveEditTimelinePipelinePrimitivesV2.projectCanvas(
        graph: graph,
        previous: wrapped,
        actions: <LiveEditCanvasActionV2>[
          LiveEditCanvasActionV2.unwrapGroup(groupId: 'group:home+product'),
        ],
      );
      expect(unwrapped.groupNodes, isEmpty);
      expect(unwrapped.focusedNodeId, 'screen:home');
      expect(
        unwrapped.screenNodes
            .where(
              (final node) =>
                  node.screenId == 'home' || node.screenId == 'product',
            )
            .every((final node) => node.hidden == false),
        isTrue,
      );
    });

    test(
      'preserves route adjacency order when route ids are non-alphabetical',
      () {
        final projection = LiveEditTimelinePipelinePrimitivesV2.projectCanvas(
          graph: _fixtureFlowGraph(),
        );

        final orderedByX = projection.screenNodes.toList(growable: false)
          ..sort((final lhs, final rhs) => lhs.x.compareTo(rhs.x));
        expect(
          orderedByX.map((final node) => node.screenId).toList(growable: false),
          <String>['home', 'product', 'cart'],
        );
      },
    );
  });

  group('LiveEditTimelinePipelinePrimitivesV2 patch mapping', () {
    test('derives deterministic canvas actions from patch plan', () {
      final patch = <LiveEditPatchOperationV2>[
        const LiveEditPatchOperationV2(
          operationId: '01-wrap',
          op: LiveEditPatchOpV2.add,
          path: '/canvas/groups',
          value: <String, Object?>{
            'screenIds': <String>['product', 'home'],
          },
        ),
        const LiveEditPatchOperationV2(
          operationId: '02-set-collapsed',
          op: LiveEditPatchOpV2.set,
          path: '/canvas/groups/group%3Ahome%2Bproduct/collapsed',
          value: false,
        ),
        const LiveEditPatchOperationV2(
          operationId: '03-focus',
          op: LiveEditPatchOpV2.set,
          path: '/canvas/focus',
          value: 'group:home+product',
        ),
      ];

      final actions =
          LiveEditTimelinePipelinePrimitivesV2.deriveCanvasActionsFromPatch(
            patch,
          );
      expect(actions, hasLength(3));
      expect(actions[0].kind, LiveEditCanvasActionKind.wrapSelection);
      expect(actions[0].screenIds, <String>['home', 'product']);
      expect(actions[1].kind, LiveEditCanvasActionKind.setGroupCollapsed);
      expect(actions[1].groupId, 'group:home+product');
      expect(actions[1].collapsed, isFalse);
      expect(actions[2].kind, LiveEditCanvasActionKind.focusNode);
      expect(actions[2].nodeId, 'group:home+product');

      final transaction = _fixtureTransaction(patch: patch);
      final first =
          LiveEditTimelinePipelinePrimitivesV2.mapTransactionToPipeline(
            transaction: transaction,
            graph: _fixtureFlowGraph(),
          );
      final second =
          LiveEditTimelinePipelinePrimitivesV2.mapTransactionToPipeline(
            transaction: transaction,
            graph: _fixtureFlowGraph(),
          );

      expect(jsonEncode(first.toJson()), jsonEncode(second.toJson()));
      expect(first.projection.focusedNodeId, 'group:home+product');
      expect(first.timelineEntries, isNotEmpty);
      expect(
        first.timelineEntries.map((final entry) => entry.label),
        containsAll(<String>['intent', 'target', 'patch', 'validation']),
      );
    });

    test('builds reversible patch primitives linked to graph references', () {
      final patch = <LiveEditPatchOperationV2>[
        const LiveEditPatchOperationV2(
          operationId: '01-title',
          op: LiveEditPatchOpV2.set,
          path: '/screens/home/title',
          value: 'Home v2',
          metadata: <String, Object?>{'previousValue': 'Home'},
        ),
        const LiveEditPatchOperationV2(
          operationId: '02-link-action',
          op: LiveEditPatchOpV2.add,
          path: '/links/widget%3Acta-button->screen%3Acart/action/onTap',
          value: 'navigate',
        ),
        const LiveEditPatchOperationV2(
          operationId: '03-state-remove',
          op: LiveEditPatchOpV2.remove,
          path: '/state/cart/total',
          metadata: <String, Object?>{'previousValue': 42},
        ),
      ];

      final transaction = _fixtureTransaction(patch: patch);
      final mapping =
          LiveEditTimelinePipelinePrimitivesV2.mapTransactionToPipeline(
            transaction: transaction,
            graph: _fixtureFlowGraph(),
          );

      final setPrimitive = mapping.patchPrimitives.firstWhere(
        (final primitive) => primitive.primitiveId == '01-title',
      );
      final addPrimitive = mapping.patchPrimitives.firstWhere(
        (final primitive) => primitive.primitiveId == '02-link-action',
      );
      final removePrimitive = mapping.patchPrimitives.firstWhere(
        (final primitive) => primitive.primitiveId == '03-state-remove',
      );

      expect(setPrimitive.inversePatch.op, LiveEditPatchOpV2.set);
      expect(setPrimitive.inversePatch.value, 'Home');
      expect(setPrimitive.graphNodeIds, contains('screen:home'));

      expect(addPrimitive.inversePatch.op, LiveEditPatchOpV2.remove);
      expect(addPrimitive.graphLinkIds, isNotEmpty);
      expect(
        mapping.projection.links.any(
          (final link) => link.kind == LiveEditCanvasLinkKind.action,
        ),
        isTrue,
      );

      expect(removePrimitive.inversePatch.op, LiveEditPatchOpV2.add);
      expect(removePrimitive.inversePatch.value, 42);

      final compensation =
          LiveEditTimelinePipelinePrimitivesV2.buildCompensationPatch(patch);
      expect(
        compensation.map((final operation) => operation.operationId),
        <String>[
          'inverse:03-state-remove',
          'inverse:02-link-action',
          'inverse:01-title',
        ],
      );
    });
  });
}

FlowGraphSnapshot _fixtureFlowGraph() => FlowGraphSnapshot(
  screens: <ScreenSnapshot>[
    ScreenSnapshot(
      screenId: 'home',
      routeId: 'route-home',
      title: 'Home',
      nodeSummaries: const <InteractionNodeSummary>[
        InteractionNodeSummary(
          selectionKey: 'inspector:cta-button',
          nodeId: 'node-home-cta',
          widgetType: 'ElevatedButton',
          screenId: 'home',
          routeId: 'route-home',
        ),
      ],
    ),
    ScreenSnapshot(
      screenId: 'product',
      routeId: 'route-product',
      title: 'Product',
      nodeSummaries: const <InteractionNodeSummary>[
        InteractionNodeSummary(
          selectionKey: 'inspector:product-card',
          nodeId: 'node-product-card',
          widgetType: 'ListTile',
          screenId: 'product',
          routeId: 'route-product',
        ),
      ],
    ),
    ScreenSnapshot(
      screenId: 'cart',
      routeId: 'route-cart',
      title: 'Cart',
      nodeSummaries: const <InteractionNodeSummary>[
        InteractionNodeSummary(
          selectionKey: 'inspector:cart-root',
          nodeId: 'node-cart-root',
          widgetType: 'Scaffold',
          screenId: 'cart',
          routeId: 'route-cart',
        ),
      ],
    ),
  ],
  routes: const <RouteSnapshot>[
    RouteSnapshot(routeId: 'route-home', name: '/home', screenId: 'home'),
    RouteSnapshot(
      routeId: 'route-product',
      name: '/product',
      screenId: 'product',
    ),
    RouteSnapshot(routeId: 'route-cart', name: '/cart', screenId: 'cart'),
  ],
  transitions: const <ObservedTransition>[
    ObservedTransition(
      transitionId: 'transition-home-product',
      kind: 'tap',
      fromScreenId: 'home',
      toScreenId: 'product',
      selectionKey: 'inspector:cta-button',
      routeId: 'route-home',
    ),
    ObservedTransition(
      transitionId: 'transition-product-cart',
      kind: 'tap',
      fromScreenId: 'product',
      toScreenId: 'cart',
      selectionKey: 'inspector:product-card',
      routeId: 'route-product',
    ),
  ],
  focusedScreenId: 'home',
);

LiveEditTransactionV2 _fixtureTransaction({
  required final List<LiveEditPatchOperationV2> patch,
}) => LiveEditTransactionV2(
  transactionId: 'tx-primitive-1',
  sessionId: 'session-1',
  baseRevision: 10,
  workingRevision: 11,
  intent: const LiveEditIntentV2(
    intentId: 'intent-1',
    summary: 'Adjust timeline + canvas primitive state',
    issuedAtMs: 1710000000,
  ),
  targets: const <LiveEditTargetAddressV2>[
    LiveEditTargetAddressV2(
      kind: LiveEditTargetKindV2.animation,
      key: 'fade-in',
      animationId: 'fade-in',
      screenId: 'home',
    ),
    LiveEditTargetAddressV2(
      kind: LiveEditTargetKindV2.state,
      key: 'cart.total',
      statePath: 'cart.total',
      screenId: 'cart',
    ),
  ],
  patch: patch,
  graph: LiveEditEditGraphV2.linear(),
);
