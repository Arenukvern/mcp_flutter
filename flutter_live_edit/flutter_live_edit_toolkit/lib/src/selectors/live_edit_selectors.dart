import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';
import '../live_edit_controller_adapter.dart';
import '../live_edit_types.dart';
import '../services/live_edit_bubble_state_service.dart';

// --- Pure helpers (no context) ---

bool hasText(final String? value) =>
    value != null && value.trim().isNotEmpty;

double maxDouble(final double left, final double right) =>
    left > right ? left : right;

double minDouble(final double left, final double right) =>
    left < right ? left : right;

List<LiveEditPropertyDescriptor> commonEditableProperties(
  final List<LiveEditSelection> selections,
) {
  if (selections.isEmpty) {
    return const <LiveEditPropertyDescriptor>[];
  }
  final base = selections.first.propertyGroups
      .where((final property) => property.editable)
      .toList(growable: false);
  return base
      .where(
        (final property) => selections.skip(1).every(
              (final selection) => selection.propertyGroups.any(
                (final candidate) =>
                    candidate.id == property.id &&
                    candidate.kind == property.kind &&
                    candidate.editable,
              ),
            ),
      )
      .toList(growable: false);
}

// --- Selectors (ctx + controller) ---

final _bubbleStateService = LiveEditBubbleStateService();

String? selectActiveSessionId(final LiveEditContext ctx) =>
    ctx.sessionResource.value.activeSessionId;

LiveEditTargetDomain selectTargetDomain(final LiveEditContext ctx) =>
    ctx.sessionResource.value.targetDomain;

LiveEditSelection? selectSelectionForDomain(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain domain,
  final String? sessionId,
}) =>
    controller.selectionForDomain(
      targetDomain: domain,
      sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
    );

String? selectBubbleIdForSelection(
  final LiveEditContext ctx,
  final LiveEditSelection? selection,
) =>
    _bubbleStateService.bubbleIdForSelection(ctx, selection);

LiveEditBubbleId? selectActiveBubbleId(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final sessionId_ = sessionId ?? ctx.sessionResource.value.activeSessionId;
  final selection = controller.selectionForDomain(
    targetDomain: presentationDomain,
    sessionId: sessionId_,
  );
  return selectBubbleIdForSelection(ctx, selection);
}

List<LiveEditPropertyDescriptor> selectEffectiveProperties(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain domain,
  final String? sessionId,
}) {
  final multi = controller.multiSelectionForDomain(
    targetDomain: domain,
    sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
  );
  if (multi.length > 1) {
    return commonEditableProperties(multi);
  }
  final selection = controller.selectionForDomain(
    targetDomain: domain,
    sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
  );
  return selection?.propertyGroups ?? const <LiveEditPropertyDescriptor>[];
}

List<LiveEditSelection> selectMultiSelectionForDomain(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain domain,
  final String? sessionId,
}) =>
    controller.multiSelectionForDomain(
      targetDomain: domain,
      sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
    );

List<LiveEditDraftChange> selectDraftChangesForDomain(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain domain,
  final String? sessionId,
}) =>
    controller.draftChangesForDomain(
      targetDomain: domain,
      sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
    );

bool selectOverlayVisible(final LiveEditContext ctx) =>
    ctx.sessionResource.value.overlayVisible;

LiveEditLayerViewState selectLayerViewState(
  final LiveEditContext ctx, {
  required final LiveEditTargetDomain domain,
}) =>
    ctx.bubbleResource.value.layerViewStateByDomain[domain] ??
    LiveEditLayerViewState();
