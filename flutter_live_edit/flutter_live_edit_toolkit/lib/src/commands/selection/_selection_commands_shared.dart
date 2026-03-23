import '../../di_live_edit_context/live_edit_context.dart';
import '../../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../../models/models.dart';
import '../../services/live_edit_bubble_state_service.dart';
import '../../ui_selectors/ui_selectors.dart';
import '../bubble/update_ai_composer.cmd.dart';

bool _sameNodeSet(
  final List<LiveEditSelection> left,
  final List<LiveEditSelection> right,
) {
  if (left.length != right.length) return false;
  final leftIds = left.map((final item) => item.nodeId).toList()..sort();
  final rightIds = right.map((final item) => item.nodeId).toList()..sort();
  for (var index = 0; index < leftIds.length; index += 1) {
    if (leftIds[index] != rightIds[index]) return false;
  }
  return true;
}

bool _sameSelectionIdentity(
  final LiveEditSelection? left,
  final LiveEditSelection? right,
) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return left == right;
  return left.nodeId == right.nodeId &&
      left.targetDomain == right.targetDomain &&
      left.selectionMode == right.selectionMode;
}

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
  final unchangedSelectionState =
      context.panelViewResource.value.lastSelectionIdentity == bubbleId &&
      _sameSelectionIdentity(
        activeSelection,
        selectBubbleRecord(context, bubbleId)?.primarySelection,
      ) &&
      _sameNodeSet(
        activeSelectedWidgets,
        selectBubbleRecord(context, bubbleId)?.selectedWidgets ??
            const <LiveEditSelection>[],
      );
  if (unchangedSelectionState) {
    return;
  }
  service.restoreBubbleState(context, bubbleId);

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
