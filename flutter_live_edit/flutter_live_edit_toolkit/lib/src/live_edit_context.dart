import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_types.dart';
import 'resources/live_edit_draft.src.data.dart';
import 'resources/live_edit_selection.src.data.dart';
import 'resources/resources.dart';
import 'services/services.dart';

/// Holds Resources and Services for Commands. Passed to [LiveEditCommand.execute].
final class LiveEditContext {
  LiveEditContext({
    required this.sessionResource,
    required this.selectionResource,
    required this.draftResource,
    required this.bubbleResource,
    required this.panelViewResource,
    required this.backendConfigResource,
    required this.sessionService,
    required this.applyService,
    this.applyEventSink,
  });

  final LiveEditSessionResource sessionResource;
  final LiveEditSelectionResource selectionResource;
  final LiveEditDraftResource draftResource;
  final LiveEditBubbleResource bubbleResource;
  final LiveEditPanelViewResource panelViewResource;
  final LiveEditBackendConfigResource backendConfigResource;
  final LiveEditSessionService sessionService;
  final LiveEditApplyService applyService;

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
    if (update.selectionLayer != null) {
      final (sessionId, domain, data) = update.selectionLayer!;
      final state =
          Map<
            String,
            Map<LiveEditTargetDomain, LiveEditSelectionLayerData>
          >.from(selectionResource.value);
      state[sessionId] =
          Map<LiveEditTargetDomain, LiveEditSelectionLayerData>.from(
            state[sessionId] ??
                <LiveEditTargetDomain, LiveEditSelectionLayerData>{},
          );
      state[sessionId]![domain] = data;
      selectionResource.value = state;
    }
    if (update.draftLayer != null) {
      final (sessionId, domain, data) = update.draftLayer!;
      final state =
          Map<String, Map<LiveEditTargetDomain, LiveEditDraftLayerData>>.from(
            draftResource.value,
          );
      state[sessionId] = Map<LiveEditTargetDomain, LiveEditDraftLayerData>.from(
        state[sessionId] ?? <LiveEditTargetDomain, LiveEditDraftLayerData>{},
      );
      state[sessionId]![domain] = data;
      draftResource.value = state;
    }
  }
}
