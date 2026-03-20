import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../di_live_edit_context/live_edit_context.dart';
import '../../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../../types/live_edit_types.dart';
import '../../selectors/live_edit_selectors.dart';
import '../../services/live_edit_bubble_state_service.dart';
import '../bubble/update_ai_composer.cmd.dart';

/// Selects a tracked bubble by id (expands it and sets active).
final class SelectTrackedBubbleCommand {
  SelectTrackedBubbleCommand({
    required this.bubbleId,
    required this.controller,
  });

  final String bubbleId;
  final LiveEditController controller;

  void execute(final LiveEditContext context) {
    final service = context.bubbleStateService;
    final resolvedBubbleId = service.resolveBubbleId(context, bubbleId);
    if (resolvedBubbleId == null || resolvedBubbleId.isEmpty) return;

    final sessionId = context.sessionResource.value.activeSessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final nextResolved = Set<String>.from(
      context.bubbleResource.value.resolvedBubbleIds,
    )..remove(resolvedBubbleId);
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      resolvedBubbleIds: nextResolved,
    );

    final bubble = service.bubbleRecordFor(context, resolvedBubbleId);
    final targetDomain = context.sessionResource.value.targetDomain;
    final bubbleDomain = bubble?.targetDomain ?? targetDomain;
    final trackedNodeId = bubble?.primarySelection?.nodeId ?? resolvedBubbleId;

    if (bubbleDomain == LiveEditTargetDomain.toolScene) {
      context.panelViewResource.value = context.panelViewResource.value
          .copyWith(toolPresentationArmed: true);
    }

    final currentSelection = controller.selectionForDomain(
      targetDomain: selectPresentedLayer(context),
      sessionId: sessionId,
    );
    final currentBubbleId = service.bubbleIdForSelection(
      context,
      currentSelection,
    );
    if (currentBubbleId != null &&
        currentSelection != null &&
        resolvedBubbleId != currentBubbleId) {
      service.finalizeCurrentBubbleOnBlur(
        context,
        bubbleId: currentBubbleId,
        nextNodeId: resolvedBubbleId,
        selection: currentSelection,
        selectedWidgets:
            controller
                    .multiSelectionForDomain(
                      targetDomain: selectPresentedLayer(context),
                      sessionId: sessionId,
                    )
                    .length >
                1
            ? controller.multiSelectionForDomain(
                targetDomain: selectPresentedLayer(context),
                sessionId: sessionId,
              )
            : <LiveEditSelection>[currentSelection],
        instructionText:
            bubble?.instructionText ??
            context.bubbleResource.value.globalComposerText,
        lastError: service.bubbleRecordFor(context, currentBubbleId)?.lastError,
        keepPinned: true,
      );
    }

    context.sessionService.selectTrackedNode(
      sessionId: sessionId,
      nodeId: trackedNodeId,
      targetDomain: bubbleDomain,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);

    final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      context.bubbleResource.value.layerViewStateByDomain,
    );
    layerMap[bubbleDomain] =
        (layerMap[bubbleDomain] ?? LiveEditLayerViewState()).copyWith(
          activeBubbleId: resolvedBubbleId,
        );
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      layerViewStateByDomain: layerMap,
    );

    service.restoreBubbleState(context, resolvedBubbleId);

    if (service.bubbleRecordFor(context, resolvedBubbleId) == null) {
      final selection = controller.selectionForDomain(
        targetDomain: bubbleDomain,
        sessionId: sessionId,
      );
      service.ensureBubbleState(
        context,
        resolvedBubbleId,
        selection: selection,
        selectedWidgets: selection != null
            ? <LiveEditSelection>[selection]
            : const <LiveEditSelection>[],
      );
      final record = service.bubbleRecordFor(context, resolvedBubbleId)!;
      final records = Map<String, LiveEditBubbleRecord>.from(
        context.bubbleResource.value.bubbleRecordsById,
      );
      records[resolvedBubbleId] = record.copyWith(
        displayState: LiveEditBubbleDisplayState.expanded,
      );
      context.bubbleResource.value = context.bubbleResource.value.copyWith(
        bubbleRecordsById: records,
      );
    }

    final presentationLayer = selectPresentedLayer(context);
    final activeSelection = controller.selectionForDomain(
      targetDomain: presentationLayer,
      sessionId: sessionId,
    );
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
      context.panelViewResource.value = context.panelViewResource.value
          .copyWith(lastSelectionIdentity: newIdentity);
    }
  }
}
