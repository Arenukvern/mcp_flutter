import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../di_live_edit_context/live_edit_context.dart';
import '../../types/live_edit_types.dart';

/// Opens AI bubble: edit mode AI, panel expanded, clear apply error, set default prompt if empty.
final class OpenAiBubbleCommand {
  OpenAiBubbleCommand({this.defaultPrompt});

  final String? defaultPrompt;

  void execute(final LiveEditContext context) {
    final domain = context.sessionResource.value.targetDomain;
    final bubbleData = context.bubbleResource.value;
    final layerState = bubbleData.layerViewStateByDomain[domain];
    if (layerState == null) return;

    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      editMode: LiveEditEditMode.ai,
      panelDisplayMode: LiveEditPanelDisplayMode.expanded,
    );

    final updatedLayer = layerState.copyWith(editMode: LiveEditEditMode.ai);
    final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      context.bubbleResource.value.layerViewStateByDomain,
    );
    layerMap[domain] = updatedLayer;
    var newBubbleData = context.bubbleResource.value.copyWith(
      layerViewStateByDomain: layerMap,
    );

    final activeId = updatedLayer.activeBubbleId;
    final phase = newBubbleData.applyPhase;
    final notBusy =
        phase != LiveEditApplyPhase.preparing &&
        phase != LiveEditApplyPhase.applying;
    if (notBusy) {
      newBubbleData = newBubbleData.copyWith(
        applyPhase: LiveEditApplyPhase.idle,
        lastError: null,
      );
      if (activeId != null) {
        final bubble = newBubbleData.bubbleRecordsById[activeId];
        if (bubble != null) {
          final records = Map<String, LiveEditBubbleRecord>.from(
            newBubbleData.bubbleRecordsById,
          );
          records[activeId] = bubble.copyWith(
            status: LiveEditBubbleStatus.editing,
            lastError: null,
          );
          newBubbleData = newBubbleData.copyWith(bubbleRecordsById: records);
        }
      }
    }

    final composer = activeId != null
        ? newBubbleData.bubbleRecordsById[activeId]?.instructionText ?? ''
        : newBubbleData.globalComposerText;
    final hasText = composer.trim().isNotEmpty;
    if (!hasText && defaultPrompt != null && defaultPrompt!.trim().isNotEmpty) {
      if (activeId != null) {
        final bubble = newBubbleData.bubbleRecordsById[activeId];
        if (bubble != null) {
          final records = Map<String, LiveEditBubbleRecord>.from(
            newBubbleData.bubbleRecordsById,
          );
          records[activeId] = bubble.copyWith(instructionText: defaultPrompt);
          newBubbleData = newBubbleData.copyWith(bubbleRecordsById: records);
        }
      } else {
        newBubbleData = newBubbleData.copyWith(
          globalComposerText: defaultPrompt,
        );
      }
    }

    context.bubbleResource.value = newBubbleData;
  }
}
