import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';
import '../live_edit_types.dart';

/// Sets bubble display state to minimized; clears active bubble if it was this one.
final class HideBubbleCommand {
  HideBubbleCommand({this.bubbleId});

  final String? bubbleId;

  void execute(final LiveEditContext context) {
    final bid = bubbleId;
    if (bid == null || bid.isEmpty) return;
    final bubbleData = context.bubbleResource.value;
    final bubble = bubbleData.bubbleRecordsById[bid];
    if (bubble == null) return;

    final records = Map<String, LiveEditBubbleRecord>.from(
      bubbleData.bubbleRecordsById,
    );
    records[bid] = bubble.copyWith(
      displayState: LiveEditBubbleDisplayState.minimized,
    );

    final domain = context.sessionResource.value.targetDomain;
    var layerState = bubbleData.layerViewStateByDomain[domain];
    var layerMap = bubbleData.layerViewStateByDomain;
    if (layerState != null && layerState.activeBubbleId == bid) {
      layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
        layerMap,
      );
      layerMap[domain] = layerState.copyWith(activeBubbleId: null);
    }

    context.bubbleResource.value = bubbleData.copyWith(
      bubbleRecordsById: records,
      layerViewStateByDomain: layerMap,
    );
  }
}
