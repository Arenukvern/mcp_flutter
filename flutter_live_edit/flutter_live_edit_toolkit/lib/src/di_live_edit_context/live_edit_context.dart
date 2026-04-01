import '../resources/live_edit_flow_graph.src.data.dart';
import '../resources/resources.dart';
import '../services/services.dart';
import '../types/live_edit_types.dart';
import 'resource_throttle.dart';

/// Holds Resources and Services for Commands. Passed to [LiveEditCommand.execute].
final class LiveEditContext {
  LiveEditContext({
    required this.sessionResource,
    required this.selectionResource,
    required this.draftResource,
    required this.flowGraphResource,
    required this.bubbleResource,
    required this.panelViewResource,
    required this.backendConfigResource,
    required this.sessionService,
    required this.applyService,
    required this.bubbleStateService,
    this.applyEventSink,
  }) {
    _flowGraphWriter = DebouncedResourceWriter<LiveEditFlowGraphResourceData>(
      flowGraphResource,
      delay: const Duration(milliseconds: 150),
    );
  }

  final LiveEditSessionResource sessionResource;
  final LiveEditSelectionResource selectionResource;
  final LiveEditDraftResource draftResource;
  final LiveEditFlowGraphResource flowGraphResource;
  final LiveEditBubbleResource bubbleResource;
  final LiveEditPanelViewResource panelViewResource;
  final LiveEditBackendConfigResource backendConfigResource;
  final LiveEditSessionService sessionService;
  late final DebouncedResourceWriter<LiveEditFlowGraphResourceData>
      _flowGraphWriter;
  final LiveEditApplyService applyService;
  final LiveEditBubbleStateService bubbleStateService;

  /// Optional sink for apply runtime events (e.g. streamed codex events).
  /// When set, ApplyDraftCommand passes it as [LiveEditApplyDraftRequest.onEvent].
  final void Function(String? bubbleId, LiveEditRuntimeEvent event)?
  applyEventSink;

  /// Applies [update] from session service to resources.
  void applySessionUpdate(final LiveEditSessionUpdate? update) {
    if (update == null) return;
    if (update.sessionData != null) {
      sessionResource.value = update.sessionData!;
    }
    if (update.selectionStore != null) {
      selectionResource.value = update.selectionStore!;
    }
    if (update.draftStore != null) {
      draftResource.value = update.draftStore!;
    }
    if (update.flowGraph != null) {
      _flowGraphWriter.write(
        LiveEditFlowGraphResourceData.fromSnapshot(update.flowGraph!),
      );
    }
  }
}
