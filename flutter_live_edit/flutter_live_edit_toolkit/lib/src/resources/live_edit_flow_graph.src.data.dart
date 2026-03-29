import '../models/live_edit_interaction_models.dart';

final class LiveEditFlowGraphResourceData {
  LiveEditFlowGraphResourceData({
    final FlowGraphSnapshot snapshot = FlowGraphSnapshot.empty,
  }) : snapshot = snapshot,
       screens = List<ScreenSnapshot>.unmodifiable(snapshot.screens),
       routes = List<RouteSnapshot>.unmodifiable(snapshot.routes),
       transitions = List<ObservedTransition>.unmodifiable(
         snapshot.transitions,
       ),
       screensById = Map<String, ScreenSnapshot>.unmodifiable(
         <String, ScreenSnapshot>{
           for (final screen in snapshot.screens) screen.screenId: screen,
         },
       ),
       routesById = Map<String, RouteSnapshot>.unmodifiable(
         <String, RouteSnapshot>{
           for (final route in snapshot.routes) route.routeId: route,
         },
       ),
       transitionsById = Map<String, ObservedTransition>.unmodifiable(
         <String, ObservedTransition>{
           for (final transition in snapshot.transitions)
             transition.transitionId: transition,
         },
       ),
       screenByRouteId = Map<String, ScreenSnapshot>.unmodifiable(
         <String, ScreenSnapshot>{
           for (final screen in snapshot.screens) screen.routeId: screen,
         },
       ),
       routeByScreenId = Map<String, RouteSnapshot>.unmodifiable(
         <String, RouteSnapshot>{
           for (final route in snapshot.routes) route.screenId: route,
         },
       ),
       nodeSummariesBySelectionKey =
           Map<String, InteractionNodeSummary>.unmodifiable(
             _indexNodeSummariesBySelectionKey(snapshot.screens),
           ),
       nodeSummariesByScreenId = _freezeNodeSummariesByScreenId(
         snapshot.screens,
       ),
       outgoingTransitionsByScreenId = _freezeTransitionsByScreenId(
         snapshot.transitions,
         outgoing: true,
       ),
       incomingTransitionsByScreenId = _freezeTransitionsByScreenId(
         snapshot.transitions,
         outgoing: false,
       );

  factory LiveEditFlowGraphResourceData.fromSnapshot(
    final FlowGraphSnapshot snapshot,
  ) => LiveEditFlowGraphResourceData(snapshot: snapshot);

  final FlowGraphSnapshot snapshot;
  final List<ScreenSnapshot> screens;
  final List<RouteSnapshot> routes;
  final List<ObservedTransition> transitions;
  final Map<String, ScreenSnapshot> screensById;
  final Map<String, RouteSnapshot> routesById;
  final Map<String, ObservedTransition> transitionsById;
  final Map<String, ScreenSnapshot> screenByRouteId;
  final Map<String, RouteSnapshot> routeByScreenId;
  final Map<String, InteractionNodeSummary> nodeSummariesBySelectionKey;
  final Map<String, List<InteractionNodeSummary>> nodeSummariesByScreenId;
  final Map<String, List<ObservedTransition>> outgoingTransitionsByScreenId;
  final Map<String, List<ObservedTransition>> incomingTransitionsByScreenId;

  static final LiveEditFlowGraphResourceData initial =
      LiveEditFlowGraphResourceData();

  bool get isEmpty => screens.isEmpty && routes.isEmpty && transitions.isEmpty;

  String? get focusedScreenId => snapshot.focusedScreenId;

  ScreenSnapshot? get focusedScreen => screenFor(focusedScreenId);

  ScreenSnapshot? screenFor(final String? screenId) =>
      _hasText(screenId) ? screensById[screenId!.trim()] : null;

  RouteSnapshot? routeFor(final String? routeId) =>
      _hasText(routeId) ? routesById[routeId!.trim()] : null;

  ObservedTransition? transitionFor(final String? transitionId) =>
      _hasText(transitionId) ? transitionsById[transitionId!.trim()] : null;

  ScreenSnapshot? screenForRoute(final String? routeId) =>
      _hasText(routeId) ? screenByRouteId[routeId!.trim()] : null;

  RouteSnapshot? routeForScreen(final String? screenId) =>
      _hasText(screenId) ? routeByScreenId[screenId!.trim()] : null;

  InteractionNodeSummary? nodeSummaryForSelection(final String? selectionKey) =>
      _hasText(selectionKey)
      ? nodeSummariesBySelectionKey[selectionKey!.trim()]
      : null;

  ScreenSnapshot? screenForSelection(final String? selectionKey) =>
      screenFor(nodeSummaryForSelection(selectionKey)?.screenId);

  List<InteractionNodeSummary> nodeSummariesForScreen(final String? screenId) =>
      _hasText(screenId)
      ? nodeSummariesByScreenId[screenId!.trim()] ??
            const <InteractionNodeSummary>[]
      : const <InteractionNodeSummary>[];

  List<ObservedTransition> outgoingTransitionsForScreen(
    final String? screenId,
  ) => _hasText(screenId)
      ? outgoingTransitionsByScreenId[screenId!.trim()] ??
            const <ObservedTransition>[]
      : const <ObservedTransition>[];

  List<ObservedTransition> incomingTransitionsForScreen(
    final String? screenId,
  ) => _hasText(screenId)
      ? incomingTransitionsByScreenId[screenId!.trim()] ??
            const <ObservedTransition>[]
      : const <ObservedTransition>[];

  List<ObservedTransition> connectedTransitionsForScreen(
    final String? screenId,
  ) {
    final outgoing = outgoingTransitionsForScreen(screenId);
    final incoming = incomingTransitionsForScreen(screenId);
    if (outgoing.isEmpty) {
      return incoming;
    }
    if (incoming.isEmpty) {
      return outgoing;
    }
    return List<ObservedTransition>.unmodifiable(<ObservedTransition>[
      ...outgoing,
      ...incoming,
    ]);
  }
}

Map<String, InteractionNodeSummary> _indexNodeSummariesBySelectionKey(
  final List<ScreenSnapshot> screens,
) {
  final summariesBySelectionKey = <String, InteractionNodeSummary>{};
  for (final screen in screens) {
    for (final summary in screen.nodeSummaries) {
      final selectionKey = summary.selectionKey.trim();
      if (selectionKey.isEmpty) {
        continue;
      }
      summariesBySelectionKey[selectionKey] = summary;
    }
  }
  return summariesBySelectionKey;
}

Map<String, List<InteractionNodeSummary>> _freezeNodeSummariesByScreenId(
  final List<ScreenSnapshot> screens,
) => Map<String, List<InteractionNodeSummary>>.unmodifiable(
  <String, List<InteractionNodeSummary>>{
    for (final screen in screens)
      screen.screenId: List<InteractionNodeSummary>.unmodifiable(
        screen.nodeSummaries,
      ),
  },
);

Map<String, List<ObservedTransition>> _freezeTransitionsByScreenId(
  final List<ObservedTransition> transitions, {
  required final bool outgoing,
}) {
  final groupedTransitions = <String, List<ObservedTransition>>{};
  for (final transition in transitions) {
    final screenId = outgoing
        ? transition.fromScreenId.trim()
        : transition.toScreenId.trim();
    if (screenId.isEmpty) {
      continue;
    }
    groupedTransitions
        .putIfAbsent(screenId, () => <ObservedTransition>[])
        .add(transition);
  }
  return Map<String, List<ObservedTransition>>.unmodifiable(
    groupedTransitions.map(
      (final screenId, final items) =>
          MapEntry(screenId, List<ObservedTransition>.unmodifiable(items)),
    ),
  );
}

bool _hasText(final String? value) => value?.trim().isNotEmpty ?? false;
