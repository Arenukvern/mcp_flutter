import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../di_live_edit_context/live_edit_context.dart';
import '../../types/live_edit_types.dart';

/// Sets active bubble id for the current domain.
final class SetActiveBubbleCommand {
  SetActiveBubbleCommand({this.bubbleId});

  final String? bubbleId;

  void execute(final LiveEditContext context) {
    final domain = context.sessionResource.value.targetDomain;
    final layerState =
        context.bubbleResource.value.layerViewStateByDomain[domain];
    if (layerState == null) return;
    final updated = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      context.bubbleResource.value.layerViewStateByDomain,
    );
    updated[domain] = layerState.copyWith(activeBubbleId: bubbleId);
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      layerViewStateByDomain: updated,
    );
  }
}
