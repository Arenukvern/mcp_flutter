import 'package:flutter_live_edit_toolkit/src/models/live_edit_interaction_models.dart';
import 'package:flutter_live_edit_toolkit/src/resources/live_edit_flow_graph.src.data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('indexes graph content for read-only selectors', () {
    const primaryKey = 'inspector:node-1';
    const secondaryKey = 'inspector:node-2';
    const snapshot = FlowGraphSnapshot(
      screens: <ScreenSnapshot>[
        ScreenSnapshot(
          screenId: 'screen-home',
          routeId: 'route-home',
          title: 'Home',
          surfaceId: 'surface-home',
          nodeSummaries: <InteractionNodeSummary>[
            InteractionNodeSummary(
              selectionKey: primaryKey,
              nodeId: 'node-1',
              widgetType: 'Scaffold',
              screenId: 'screen-home',
              routeId: 'route-home',
              surfaceId: 'surface-home',
            ),
          ],
        ),
        ScreenSnapshot(
          screenId: 'screen-settings',
          routeId: 'route-settings',
          title: 'Settings',
          nodeSummaries: <InteractionNodeSummary>[
            InteractionNodeSummary(
              selectionKey: secondaryKey,
              nodeId: 'node-2',
              widgetType: 'ListView',
              screenId: 'screen-settings',
              routeId: 'route-settings',
            ),
          ],
        ),
      ],
      routes: <RouteSnapshot>[
        RouteSnapshot(
          routeId: 'route-home',
          name: '/home',
          screenId: 'screen-home',
        ),
        RouteSnapshot(
          routeId: 'route-settings',
          name: '/settings',
          screenId: 'screen-settings',
          isActive: false,
        ),
      ],
      transitions: <ObservedTransition>[
        ObservedTransition(
          transitionId: 'transition-next',
          kind: 'tap',
          fromScreenId: 'screen-home',
          toScreenId: 'screen-settings',
        ),
        ObservedTransition(
          transitionId: 'transition-back',
          kind: 'system_back',
          fromScreenId: 'screen-settings',
          toScreenId: 'screen-home',
        ),
      ],
      focusedScreenId: 'screen-home',
    );

    final store = LiveEditFlowGraphResourceData.fromSnapshot(snapshot);

    expect(store.isEmpty, isFalse);
    expect(store.focusedScreen?.screenId, 'screen-home');
    expect(store.screenFor('screen-home')?.title, 'Home');
    expect(store.routeFor('route-settings')?.name, '/settings');
    expect(store.transitionFor('transition-next')?.kind, 'tap');
    expect(store.screenForRoute('route-home')?.screenId, 'screen-home');
    expect(store.routeForScreen('screen-settings')?.routeId, 'route-settings');
    expect(store.nodeSummaryForSelection(primaryKey)?.nodeId, 'node-1');
    expect(store.screenForSelection(secondaryKey)?.screenId, 'screen-settings');
    expect(store.nodeSummariesForScreen('screen-home'), hasLength(1));
    expect(store.outgoingTransitionsForScreen('screen-home'), hasLength(1));
    expect(store.incomingTransitionsForScreen('screen-home'), hasLength(1));
    expect(store.connectedTransitionsForScreen('screen-home'), hasLength(2));
    expect(
      () => store.screens.add(
        const ScreenSnapshot(
          screenId: 'screen-extra',
          routeId: 'route-extra',
          title: 'Extra',
        ),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => store
          .nodeSummariesForScreen('screen-home')
          .add(
            const InteractionNodeSummary(
              selectionKey: 'inspector:node-3',
              nodeId: 'node-3',
              widgetType: 'Text',
              screenId: 'screen-home',
            ),
          ),
      throwsUnsupportedError,
    );
  });
}
