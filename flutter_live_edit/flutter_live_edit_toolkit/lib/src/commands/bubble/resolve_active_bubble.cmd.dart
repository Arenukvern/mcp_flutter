import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import '../../di_live_edit_context/live_edit_context.dart';
import '../../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../../models/models.dart';
import '../../resources/live_edit_bubble.src.data.dart';
import '../../types/live_edit_types.dart';

/// Removes active bubble from records, clears pending/apply state, resets panel and composer.
final class ResolveActiveBubbleCommand {
  void execute(final LiveEditContext context) {
    final domain = context.sessionResource.value.targetDomain;
    final bubbleData = context.bubbleResource.value;
    final layerState = bubbleData.layerViewStateByDomain[domain];
    final activeId =
        layerState?.activeBubbleId ??
        context.bubbleStateService.bubbleIdForSelection(
          context,
          LiveEditController(context).selectionForDomain(
            targetDomain: domain,
            sessionId: context.sessionResource.value.activeSessionId,
          ),
        );

    final records = Map<String, LiveEditBubbleRecord>.from(
      bubbleData.bubbleRecordsById,
    );
    if (activeId != null) {
      records.remove(activeId);
    }

    final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      bubbleData.layerViewStateByDomain,
    );
    if (layerState != null) {
      // copyWith cannot clear activeBubbleId (null falls back to previous).
      layerMap[domain] = LiveEditLayerViewState(
        activePropertyId: layerState.activePropertyId,
      );
    }

    context.bubbleResource.value = LiveEditBubbleResourceData(
      bubbleRecordsById: records,
      layerViewStateByDomain: layerMap,
      resolvedBubbleIds: bubbleData.resolvedBubbleIds,
    );

    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      panelDisplayMode: LiveEditPanelDisplayMode.rail,
      editMode: LiveEditEditMode.inspect,
      lastSelectionIdentity: null,
    );
  }
}
