import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';
import '../live_edit_controller_adapter.dart';
import '../selectors/live_edit_selectors.dart';
import '../services/live_edit_bubble_state_service.dart';
import 'update_ai_composer.cmd.dart';

void runAfterSelectionChange(
  final LiveEditContext context,
  final LiveEditController controller,
) {
  final service = context.bubbleStateService;
  final sessionId = context.sessionResource.value.activeSessionId;
  if (sessionId == null) return;
  final presentationLayer = selectPresentedLayer(context);
  final activeSelection = controller.selectionForDomain(
    targetDomain: presentationLayer,
    sessionId: sessionId,
  );
  final bubbleId = service.bubbleIdForSelection(context, activeSelection);
  service.restoreBubbleState(context, bubbleId);

  final activeSelectedWidgets =
      controller
              .multiSelectionForDomain(
                targetDomain: presentationLayer,
                sessionId: sessionId,
              )
              .length >
          1
      ? controller.multiSelectionForDomain(
          targetDomain: presentationLayer,
          sessionId: sessionId,
        )
      : (activeSelection != null
            ? <LiveEditSelection>[activeSelection]
            : const <LiveEditSelection>[]);
  final effectiveProperties = selectEffectiveProperties(
    context,
    controller,
    domain: presentationLayer,
    sessionId: sessionId,
  );
  final activeProperty = selectActiveProperty(
    context,
    controller,
    presentationDomain: presentationLayer,
    sessionId: sessionId,
  );
  final draftChanges = selectDraftChangesForDomain(
    context,
    controller,
    domain: presentationLayer,
    sessionId: sessionId,
  );
  String defaultAiPrompt() {
    final sel = activeSelection;
    if (sel == null) return 'Persist the current live-edit changes.';
    final buf = StringBuffer();
    buf.write('Update ${sel.widgetType}');
    if (sel.source?.file != null && sel.source!.file.trim().isNotEmpty) {
      buf.write(' in ${sel.source!.file}');
      if (sel.source?.line != null) buf.write(':${sel.source!.line}');
    }
    return buf.isEmpty
        ? 'Persist the current live-edit changes.'
        : buf.toString();
  }

  final newIdentity = service.syncSelectionState(
    context,
    SyncSelectionStateParams(
      activeSelection: activeSelection,
      activeSelectedWidgets: activeSelectedWidgets,
      presentationLayer: presentationLayer,
      lastSelectionIdentity:
          context.panelViewResource.value.lastSelectionIdentity,
      effectiveProperties: effectiveProperties,
      activeProperty: activeProperty,
      draftChanges: draftChanges,
      getBackendIdForBubble: (final id) =>
          selectBackendIdForBubble(context, id),
      getInferenceConfigForBubble: (final id) =>
          selectInferenceConfigForBubble(context, id),
      defaultAiPrompt: defaultAiPrompt(),
      updateAiComposer: (final v) =>
          UpdateAiComposerCommand(value: v).execute(context),
    ),
  );
  if (newIdentity != null) {
    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      lastSelectionIdentity: newIdentity,
    );
  }
}
