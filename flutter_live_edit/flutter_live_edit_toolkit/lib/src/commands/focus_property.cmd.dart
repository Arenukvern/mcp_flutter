import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';
import '../live_edit_types.dart';

/// Begin inline edit: set active property, edit mode from surface, default prompt if AI and empty.
final class FocusPropertyCommand {
  FocusPropertyCommand({
    required this.property,
    this.surface,
    this.defaultPrompt,
    this.expandPanel = true,
  });

  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface? surface;
  final String? defaultPrompt;
  final bool expandPanel;

  void execute(final LiveEditContext context) {
    final domain = context.sessionResource.value.targetDomain;
    final bubbleData = context.bubbleResource.value;
    var layerState = bubbleData.layerViewStateByDomain[domain];
    if (layerState == null) return;

    final updatedLayer = layerState.copyWith(activePropertyId: property.id);
    final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      bubbleData.layerViewStateByDomain,
    );
    layerMap[domain] = updatedLayer;

    final resolvedSurface = surface ?? property.preferredEditSurface;
    final editMode = resolvedSurface == LiveEditEditSurface.aiBubble ||
            property.requiresAgentForPersistence
        ? LiveEditEditMode.ai
        : LiveEditEditMode.edit;

    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      editMode: editMode,
      panelDisplayMode: expandPanel
          ? LiveEditPanelDisplayMode.expanded
          : context.panelViewResource.value.panelDisplayMode,
    );

    final finalLayer = updatedLayer.copyWith(editMode: editMode);
    layerMap[domain] = finalLayer;
    var newBubbleData = context.bubbleResource.value.copyWith(
      layerViewStateByDomain: layerMap,
    );

    if (editMode == LiveEditEditMode.ai && defaultPrompt != null) {
      final activeId = finalLayer.activeBubbleId;
      final composer = activeId != null
          ? newBubbleData.bubbleRecordsById[activeId]?.instructionText ?? ''
          : newBubbleData.globalComposerText;
      if (composer.trim().isEmpty) {
        if (activeId != null) {
          final bubble = newBubbleData.bubbleRecordsById[activeId];
          if (bubble != null) {
            final records = Map<String, LiveEditBubbleRecord>.from(
              newBubbleData.bubbleRecordsById,
            );
            records[activeId] =
                bubble.copyWith(instructionText: defaultPrompt!);
            newBubbleData = newBubbleData.copyWith(bubbleRecordsById: records);
          }
        } else {
          newBubbleData = newBubbleData.copyWith(
            globalComposerText: defaultPrompt!,
          );
        }
      }
    }

    context.bubbleResource.value = newBubbleData;
  }
}
