import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';
import '../live_edit_types.dart';

/// Sets active property id for the current domain in layer view state.
final class SetActivePropertyCommand {
  SetActivePropertyCommand({this.activePropertyId});

  final String? activePropertyId;

  void execute(final LiveEditContext context) {
    final domain = context.sessionResource.value.targetDomain;
    final layerState =
        context.bubbleResource.value.layerViewStateByDomain[domain];
    if (layerState == null) return;
    final updated = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      context.bubbleResource.value.layerViewStateByDomain,
    );
    updated[domain] = layerState.copyWith(activePropertyId: activePropertyId);
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      layerViewStateByDomain: updated,
    );
  }
}
