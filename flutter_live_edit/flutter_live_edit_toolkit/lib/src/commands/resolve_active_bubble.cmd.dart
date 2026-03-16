import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';
import '../live_edit_types.dart';

/// Removes active bubble from records, clears pending/apply state, resets panel and composer.
final class ResolveActiveBubbleCommand {
  void execute(final LiveEditContext context) {
    final domain = context.sessionResource.value.targetDomain;
    final bubbleData = context.bubbleResource.value;
    final layerState = bubbleData.layerViewStateByDomain[domain];
    final activeId = layerState?.activeBubbleId;

    var records = Map<String, LiveEditBubbleRecord>.from(
      bubbleData.bubbleRecordsById,
    );
    if (activeId != null) {
      records.remove(activeId);
    }

    final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      bubbleData.layerViewStateByDomain,
    );
    if (layerState != null) {
      layerMap[domain] = layerState.copyWith(
        activeBubbleId: null,
        editMode: LiveEditEditMode.inspect,
      );
    }

    context.bubbleResource.value = bubbleData.copyWith(
      bubbleRecordsById: records,
      layerViewStateByDomain: layerMap,
      applyPhase: LiveEditApplyPhase.idle,
      pendingExecutionPlan: null,
      pendingProposalId: null,
      pendingBubbleId: null,
      pendingPropertyId: null,
      lastError: null,
      globalComposerText: '',
    );

    context.panelViewResource.value = context.panelViewResource.value
        .copyWith(
          panelDisplayMode: LiveEditPanelDisplayMode.rail,
          editMode: LiveEditEditMode.inspect,
        );
  }
}
