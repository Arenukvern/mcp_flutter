import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_backend_utils.dart';
import '../live_edit_context.dart';
import '../live_edit_types.dart';
import '../services/live_edit_bubble_state_service.dart';
import 'set_active_property.cmd.dart';
import 'set_edit_mode.cmd.dart';
import 'update_ai_composer.cmd.dart';

/// Full UI update-draft flow: ensure session, update draft, sync bubble state.
/// Use from orchestrator or host instead of reimplementing the flow.
final class UpdateDraftFromUiCommand {
  UpdateDraftFromUiCommand({
    required this.property,
    required this.targetValue,
    this.surface,
    this.intentText,
  });

  final LiveEditPropertyDescriptor property;
  final Object? targetValue;
  final LiveEditEditSurface? surface;
  final String? intentText;

  void execute(final LiveEditContext context) {
    final bubbleStateService = context.bubbleStateService;
    var sessionId = context.sessionResource.value.activeSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      final result = context.sessionService.startSession(
        targetDomain: context.sessionResource.value.targetDomain,
      );
      context.applySessionUpdate(context.sessionService.lastUpdate);
      sessionId = '${result['sessionId'] ?? ''}';
    }
    final targetDomain = context.sessionResource.value.targetDomain;
    final selectionLayer =
        context.selectionResource.value[sessionId]?[targetDomain];
    final selection = selectionLayer?.selection;
    final multi = selectionLayer?.multiSelections ?? const <LiveEditSelection>[];

    if (selection == null) {
      bubbleStateService.setErrorForBubble(
        context,
        null,
        'No live-edit selection is active.',
        getBackendLabel: (final id) => backendLabelFromContext(context, id),
      );
      return;
    }

    final previewMode = property.canPreviewExactly
        ? LiveEditPreviewMode.exact
        : (property.previewMode == LiveEditPreviewMode.none
            ? LiveEditPreviewMode.ghost
            : property.previewMode);
    final meta = <String, Object?>{
      'requiresAgentForPersistence': property.requiresAgentForPersistence,
      'editSurface': (surface ?? property.preferredEditSurface).wireName,
      'targetDomain': selection.targetDomain.wireName,
      'selectionNodeId': selection.nodeId,
      if (hasText('${property.meta['surfaceId'] ?? ''}'))
        'surfaceId': '${property.meta['surfaceId']}',
    };
    final intent = intentText?.trim().isNotEmpty == true
        ? intentText!
        : (context.bubbleResource.value.globalComposerText.trim().isNotEmpty
            ? context.bubbleResource.value.globalComposerText
            : '');

    if (multi.length > 1) {
      context.sessionService.updateDraftBatch(
        sessionId: sessionId,
        nodeIds: multi.map((e) => e.nodeId).toList(growable: false),
        propertyId: property.id,
        targetValue: targetValue,
        previewMode: previewMode,
        intentText: intent,
        meta: meta,
      );
    } else {
      context.sessionService.updateDraft(
        sessionId: sessionId,
        change: LiveEditDraftChange(
          nodeId: selection.nodeId,
          propertyId: property.id,
          targetValue: targetValue,
          previewMode: previewMode,
          confidence: property.safeToAutoGroupInApply ? 0.95 : 0.75,
          intentText: intent,
          meta: meta,
        ),
      );
    }
    context.applySessionUpdate(context.sessionService.lastUpdate);

    SetActivePropertyCommand(activePropertyId: property.id).execute(context);
    final editMode =
        property.requiresAgentForPersistence ||
            (surface ?? property.preferredEditSurface) ==
                LiveEditEditSurface.aiBubble
        ? LiveEditEditMode.ai
        : LiveEditEditMode.edit;
    SetEditModeCommand(editMode: editMode).execute(context);
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      lastError: null,
      applyPhase: LiveEditApplyPhase.idle,
    );
    final bubbleId = bubbleStateService.bubbleIdForSelection(context, selection);
    if (hasText(bubbleId)) {
      final next = Set<LiveEditBubbleId>.from(
        context.bubbleResource.value.resolvedBubbleIds,
      )..remove(bubbleId);
      context.bubbleResource.value = context.bubbleResource.value.copyWith(
        resolvedBubbleIds: next,
      );
    }

    final draftChanges = _draftChangesForSelection(
      context,
      sessionId,
      targetDomain,
      selection,
      multi,
    );
    final backendId = _backendIdForBubble(bubbleStateService, context, bubbleId);
    final inferenceConfig =
        _inferenceConfigForBubble(bubbleStateService, context, bubbleId);
    final bubble = bubbleStateService.bubbleRecordFor(context, bubbleId);
    bubbleStateService.captureBubbleState(
      context,
      selection,
      multi.isEmpty ? <LiveEditSelection>[selection] : multi,
      instructionText: bubble?.instructionText ??
          context.bubbleResource.value.globalComposerText,
      status: LiveEditBubbleStatus.editing,
      draftChanges: draftChanges,
      backendId: backendId,
      inferenceConfig: inferenceConfig,
    );
    if (editMode == LiveEditEditMode.ai &&
        !hasText(bubble?.instructionText ?? context.bubbleResource.value.globalComposerText)) {
      final defaultPrompt = _defaultAiPrompt(selection, multi);
      UpdateAiComposerCommand(value: defaultPrompt).execute(context);
    }
    bubbleStateService.appendDebug(
      context,
      message: 'Edited ${property.label}.',
      details: <String>[
        'Value: $targetValue',
        'Preview: ${previewMode.wireName}',
        if (hasText(selection.source?.file))
          'Source: ${selection.source!.file}${selection.source?.line == null ? '' : ':${selection.source!.line}'}',
      ],
      nodeId: bubbleId,
    );
  }

  static bool hasText(final String? value) =>
      value != null && value.trim().isNotEmpty;

  static List<LiveEditDraftChange> _draftChangesForSelection(
    final LiveEditContext context,
    final String sessionId,
    final LiveEditTargetDomain domain,
    final LiveEditSelection selection,
    final List<LiveEditSelection> multi,
  ) {
    final byDomain = context.draftResource.value[sessionId]?[domain];
    final drafts = byDomain?.draftChanges ?? const <LiveEditDraftChange>[];
    final nodeIds = <String>{
      selection.nodeId,
      ...selection.selectedNodeIds,
      ...multi.map((e) => e.nodeId),
    };
    return drafts
        .where((d) => nodeIds.contains(d.nodeId))
        .toList(growable: false);
  }

  static String? _backendIdForBubble(
    final LiveEditBubbleStateService service,
    final LiveEditContext context,
    final String? bubbleId,
  ) {
    final bid = service.bubbleRecordFor(context, bubbleId)?.backendId?.trim();
    if (hasText(bid)) return bid;
    return context.backendConfigResource.value.globalBackendId;
  }

  static LiveEditInferenceConfig? _inferenceConfigForBubble(
    final LiveEditBubbleStateService service,
    final LiveEditContext context,
    final String? bubbleId,
  ) {
    final bubble = service.bubbleRecordFor(context, bubbleId);
    if (bubble?.inferenceConfig != null) return bubble!.inferenceConfig;
    final backendId = _backendIdForBubble(service, context, bubbleId);
    if (backendId == null) return null;
    LiveEditAgentBackend? backend;
    for (final b in context.backendConfigResource.value.availableBackends) {
      if (b.id == backendId) {
        backend = b;
        break;
      }
    }
    if (backend == null) return null;
    return context.backendConfigResource.value.inferenceConfigByBackendId[backend.id] ??
        backendEffectiveConfig(backend);
  }

  static String _defaultAiPrompt(
    final LiveEditSelection selection,
    final List<LiveEditSelection> multi,
  ) {
    final buffer = StringBuffer();
    if (multi.length > 1) {
      buffer.write('Update ${multi.length} selected widgets');
    } else {
      buffer.write('Update ${selection.widgetType}');
      if (hasText(selection.source?.file)) {
        buffer.write(' in ${selection.source!.file}');
        if (selection.source?.line != null) {
          buffer.write(':${selection.source!.line}');
        }
      }
    }
    return buffer.isEmpty ? 'Persist the current live-edit changes.' : buffer.toString();
  }
}
