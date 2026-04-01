import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';
import '../../ui_workbench/live_edit_overlay_theme.dart';

/// Updates bubble dimensions in panel resource and overlay theme draft.
final class ResizeBubbleCommand {
  ResizeBubbleCommand({required this.width, required this.height});

  final double width;
  final double height;

  void execute(final LiveEditContext context) {
    final w = width.clamp(260.0, 520.0);
    final h = height.clamp(200.0, 520.0);
    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      bubbleWidth: w,
      bubbleHeight: h,
    );

    final editMode = context.panelViewResource.value.editMode;
    final surfaceId = editMode == LiveEditEditMode.ai
        ? kLiveEditAiBubbleSurfaceId
        : kLiveEditSelectionBubbleSurfaceId;
    final toolContext = DraftTargetContext(
      targetDomain: LiveEditTargetDomain.toolScene,
      surfaceId: surfaceId,
    );
    LiveEditOverlayThemeModel.instance.applyDraft(
      LiveEditDraftChange(
        nodeId: surfaceId,
        propertyId: 'width',
        targetValue: w,
        previewMode: LiveEditPreviewMode.exact,
        targetContext: toolContext,
      ),
    );
    LiveEditOverlayThemeModel.instance.applyDraft(
      LiveEditDraftChange(
        nodeId: surfaceId,
        propertyId: 'height',
        targetValue: h,
        previewMode: LiveEditPreviewMode.exact,
        targetContext: toolContext,
      ),
    );
  }
}
