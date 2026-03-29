import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';
import '../../resources/live_edit_flow_graph.src.data.dart';

LiveEditFlowGraphResourceData selectFlowGraphStore(final LiveEditContext ctx) =>
    ctx.flowGraphResource.value;

FlowGraphSnapshot selectFlowGraph(final LiveEditContext ctx) =>
    selectFlowGraphStore(ctx).snapshot;

bool selectHasFlowGraph(final LiveEditContext ctx) =>
    !selectFlowGraphStore(ctx).isEmpty;

String? selectFocusedFlowScreenId(final LiveEditContext ctx) =>
    selectFlowGraphStore(ctx).focusedScreenId;

ScreenSnapshot? selectFocusedFlowScreen(final LiveEditContext ctx) =>
    selectFlowGraphStore(ctx).focusedScreen;

List<ScreenSnapshot> selectFlowScreens(final LiveEditContext ctx) =>
    selectFlowGraphStore(ctx).screens;

List<RouteSnapshot> selectFlowRoutes(final LiveEditContext ctx) =>
    selectFlowGraphStore(ctx).routes;

List<ObservedTransition> selectFlowTransitions(final LiveEditContext ctx) =>
    selectFlowGraphStore(ctx).transitions;

ScreenSnapshot? selectFlowScreen(
  final LiveEditContext ctx,
  final String? screenId,
) => selectFlowGraphStore(ctx).screenFor(screenId);

RouteSnapshot? selectFlowRoute(
  final LiveEditContext ctx,
  final String? routeId,
) => selectFlowGraphStore(ctx).routeFor(routeId);

ObservedTransition? selectFlowTransition(
  final LiveEditContext ctx,
  final String? transitionId,
) => selectFlowGraphStore(ctx).transitionFor(transitionId);

ScreenSnapshot? selectFlowScreenForRoute(
  final LiveEditContext ctx,
  final String? routeId,
) => selectFlowGraphStore(ctx).screenForRoute(routeId);

RouteSnapshot? selectFlowRouteForScreen(
  final LiveEditContext ctx,
  final String? screenId,
) => selectFlowGraphStore(ctx).routeForScreen(screenId);

InteractionNodeSummary? selectFlowNodeSummary(
  final LiveEditContext ctx,
  final String? selectionKey,
) => selectFlowGraphStore(ctx).nodeSummaryForSelection(selectionKey);

ScreenSnapshot? selectFlowScreenForSelection(
  final LiveEditContext ctx,
  final String? selectionKey,
) => selectFlowGraphStore(ctx).screenForSelection(selectionKey);

List<InteractionNodeSummary> selectFlowNodeSummariesForScreen(
  final LiveEditContext ctx,
  final String? screenId,
) => selectFlowGraphStore(ctx).nodeSummariesForScreen(screenId);

List<ObservedTransition> selectOutgoingFlowTransitions(
  final LiveEditContext ctx,
  final String? screenId,
) => selectFlowGraphStore(ctx).outgoingTransitionsForScreen(screenId);

List<ObservedTransition> selectIncomingFlowTransitions(
  final LiveEditContext ctx,
  final String? screenId,
) => selectFlowGraphStore(ctx).incomingTransitionsForScreen(screenId);

List<ObservedTransition> selectConnectedFlowTransitions(
  final LiveEditContext ctx,
  final String? screenId,
) => selectFlowGraphStore(ctx).connectedTransitionsForScreen(screenId);
