import 'dart:ui' show Offset, Rect;

import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

/// Adapter for integration tests: exposes test-friendly getters and actions
/// backed by selectors and commands so tests compile against the post-cleanup API.
final class LiveEditIntegrationHarness {
  LiveEditIntegrationHarness(this.ctx, this.controller);

  final LiveEditContext ctx;
  final LiveEditController controller;

  /// Exposes context for commands that are not wrapped by the harness.
  LiveEditContext get context => ctx;

  LiveEditTargetDomain get _domain => selectTargetDomain(ctx);
  String? get _sid => ctx.sessionResource.value.activeSessionId;

  // --- Getters (selectors) ---

  bool get overlayVisible => selectOverlayVisible(ctx);
  bool get panelExpanded => selectPanelExpanded(ctx);
  LiveEditSelection? get activeSelection => selectSelectionForDomain(
    ctx,
    controller,
    domain: _domain,
    sessionId: _sid,
  );
  List<LiveEditSelectionCandidate> get activeSelectionCandidates => controller
      .selectionCandidatesForDomain(targetDomain: _domain, sessionId: _sid);
  List<LiveEditDraftChange> get activeDraftChanges =>
      selectDraftChangesForDomain(
        ctx,
        controller,
        domain: _domain,
        sessionId: _sid,
      );
  LiveEditApplyPhase get applyPhase => selectApplyPhase(ctx);
  LiveEditActivityEntry? get currentActivity => selectCurrentActivity(
    ctx,
    controller,
    presentationDomain: _domain,
    sessionId: _sid,
  );
  String? get lastError => selectLastError(ctx);
  LiveEditExecutionPlan? get pendingExecutionPlan =>
      selectPendingExecutionPlan(ctx);
  bool get canSubmitAiPrompt => selectCanSubmitAiPrompt(
    ctx,
    controller,
    presentationDomain: _domain,
    sessionId: _sid,
  );
  LiveEditTargetDomain get targetDomain => _domain;
  String? get debugPromptForActiveSelection =>
      selectDebugPromptForActiveSelection(
        ctx,
        controller,
        presentationDomain: _domain,
        sessionId: _sid,
      );
  Rect? get marqueeRect => selectMarqueeRect(
    ctx,
    controller,
    presentationDomain: _domain,
    sessionId: _sid,
  );
  List<LiveEditSelection> get activeMultiSelection =>
      selectMultiSelectionForDomain(
        ctx,
        controller,
        domain: _domain,
        sessionId: _sid,
      );

  /// Current AI composer / instruction text for the active bubble.
  String get aiComposer => selectInstructionTextForBubble(ctx, null);

  // --- Actions (commands) ---

  void selectNode(
    final Offset offset, {
    final bool preferHoverPreview = false,
    final LiveEditSelectionPolicy selectionPolicy =
        LiveEditSelectionPolicy.nearestProjectAncestor,
  }) {
    SelectNodeCommand(
      x: offset.dx.toInt(),
      y: offset.dy.toInt(),
      controller: controller,
      preferHoverPreview: preferHoverPreview,
      selectionPolicy: selectionPolicy,
    ).execute(ctx);
  }

  void setTargetDomain(final LiveEditTargetDomain domain) {
    SetTargetDomainCommand(targetDomain: domain).execute(ctx);
  }

  Future<void> applyDraft({final String? message}) async {
    await ApplyDraftCommand(message: message).execute(ctx);
  }

  Future<void> submitAiPrompt() async {
    await SubmitAiPromptCommand(controller: controller).execute(ctx);
  }

  void selectCandidateAt(final int index) {
    SelectCandidateAtCommand(controller: controller, index: index).execute(ctx);
  }

  void selectTrackedBubble(final String bubbleId) {
    SelectTrackedBubbleCommand(
      bubbleId: bubbleId,
      controller: controller,
    ).execute(ctx);
  }

  void hoverNode(final Offset offset, {final bool deeperMode = false}) {
    HoverAtPointCommand(
      x: offset.dx.toInt(),
      y: offset.dy.toInt(),
      deeperMode: deeperMode,
    ).execute(ctx);
  }

  /// Starts session if needed; returns active session id after pump.
  String? ensureSession() {
    StartSessionCommand(
      targetDomain: LiveEditTargetDomain.appScene,
    ).execute(ctx);
    return ctx.sessionResource.value.activeSessionId;
  }

  /// Selects parent candidate; returns service result map.
  Map<String, Object?> selectParent() {
    final result = ctx.sessionService.selectParent(
      sessionId: _sid,
      targetDomain: _domain,
    );
    ctx.applySessionUpdate(ctx.sessionService.lastUpdate);
    return result;
  }

  /// Selects child candidate; returns service result map.
  Map<String, Object?> selectChild() {
    final result = ctx.sessionService.selectChild(
      sessionId: _sid,
      targetDomain: _domain,
    );
    ctx.applySessionUpdate(ctx.sessionService.lastUpdate);
    return result;
  }

  /// Selects candidate at index; returns service result map.
  Map<String, Object?> selectCandidate({required final int index}) {
    final result = ctx.sessionService.selectCandidate(
      sessionId: _sid,
      index: index,
      targetDomain: _domain,
    );
    ctx.applySessionUpdate(ctx.sessionService.lastUpdate);
    return result;
  }
}
