import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../live_edit_context.dart';
import '../../live_edit_types.dart';

/// Sets the global edit mode and syncs to layer view state for current domain.
final class SetEditModeCommand {
  SetEditModeCommand({required this.editMode});

  final LiveEditEditMode editMode;

  void execute(final LiveEditContext context) {
    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      editMode: editMode,
    );
    final domain = context.sessionResource.value.targetDomain;
    final layerState =
        context.bubbleResource.value.layerViewStateByDomain[domain];
    if (layerState != null) {
      final updated = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
        context.bubbleResource.value.layerViewStateByDomain,
      );
      updated[domain] = layerState.copyWith(editMode: editMode);
      context.bubbleResource.value = context.bubbleResource.value.copyWith(
        layerViewStateByDomain: updated,
      );
    }
  }
}
