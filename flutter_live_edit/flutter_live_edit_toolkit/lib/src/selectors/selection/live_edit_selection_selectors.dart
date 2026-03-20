import 'dart:ui' show Rect;

import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../live_edit_context.dart';
import '../../live_edit_controller_adapter.dart';
import '../../live_edit_types.dart';
import '../shared/live_edit_selectors_shared.dart';

String? selectActivePropertyId(
  final LiveEditContext ctx, {
  required final LiveEditTargetDomain domain,
}) => ctx.bubbleResource.value.layerViewStateByDomain[domain]?.activePropertyId;

Object? selectActiveProperty(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => null;

bool selectHasMultiSelection(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) =>
    selectMultiSelectionForDomain(
      ctx,
      controller,
      domain: presentationDomain,
      sessionId: sessionId,
    ).length >
    1;

Object? selectEffectiveValueForProperty(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final Object? property, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => null;

bool selectIsPropertyWaiting(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final Object? property, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => false;

bool selectHasDraftForProperty(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final Object? property, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => false;

Rect? selectMarqueeRect(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => controller.marqueeRectForDomain(
  targetDomain: presentationDomain,
  sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
);

List<LiveEditSelection> selectMarqueePreviewSelections(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => controller.marqueeSelectionsForDomain(
  targetDomain: presentationDomain,
  sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
);

bool selectHasMarqueePreview(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final rect = selectMarqueeRect(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final list = selectMarqueePreviewSelections(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  return rect != null && list.isNotEmpty;
}

String? selectDebugPromptForActiveSelection(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final prompt = selectBubbleRecord(ctx, bubbleId)?.debugPromptText?.trim();
  return hasText(prompt) ? prompt : null;
}

List<LiveEditTimelineEntry> selectDebugTimelineForActiveSelection(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => List<LiveEditTimelineEntry>.unmodifiable(
  selectBubbleRecord(
        ctx,
        selectActiveBubbleId(
          ctx,
          controller,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        ),
      )?.debugTimeline ??
      const <LiveEditTimelineEntry>[],
);

String selectDefaultAiPrompt(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? intentText,
  final String? sessionId,
}) {
  final sessionId_ = sessionId ?? ctx.sessionResource.value.activeSessionId;
  final multi = controller.multiSelectionForDomain(
    targetDomain: presentationDomain,
    sessionId: sessionId_,
  );
  final selection = controller.selectionForDomain(
    targetDomain: presentationDomain,
    sessionId: sessionId_,
  );
  final buffer = StringBuffer();
  if (multi.length > 1) {
    buffer.write('Update ${multi.length} selected widgets');
  } else if (selection != null) {
    buffer.write('Update ${selection.widgetType}');
    if (hasText(selection.source?.file)) {
      buffer.write(' in ${selection.source!.file}');
      if (selection.source?.line != null) {
        buffer.write(':${selection.source!.line}');
      }
    }
    final draftChanges = controller.draftChangesForDomain(
      targetDomain: presentationDomain,
      sessionId: sessionId_,
    );
    final draftSummary = draftChanges
        .map((final d) => '${d.propertyId}=${d.targetValue}')
        .join(', ');
    if (draftSummary.isNotEmpty) {
      buffer.write(' for $draftSummary');
    }
  }
  if (hasText(intentText)) {
    if (buffer.isNotEmpty) buffer.write('. ');
    buffer.write(intentText!.trim());
  }
  return buffer.isEmpty
      ? 'Persist the current live-edit changes.'
      : buffer.toString();
}
