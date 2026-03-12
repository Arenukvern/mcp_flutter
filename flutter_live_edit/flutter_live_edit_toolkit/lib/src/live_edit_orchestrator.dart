import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_controller.dart';

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

typedef LiveEditApplyDraftDelegate =
    Future<Map<String, Object?>> Function(LiveEditApplyDraftRequest request);

final class LiveEditApplyDraftRequest {
  const LiveEditApplyDraftRequest({
    required this.sessionId,
    this.proposalId,
    this.backendId,
    this.workingDirectory,
    this.intentText,
    this.approve = false,
  });

  final String sessionId;
  final String? proposalId;
  final String? backendId;
  final String? workingDirectory;
  final String? intentText;
  final bool approve;

  Map<String, Object?> toJson() => <String, Object?>{
    'sessionId': sessionId,
    if (_hasText(proposalId)) 'proposalId': proposalId,
    if (_hasText(backendId)) 'backendId': backendId,
    if (_hasText(workingDirectory)) 'workingDirectory': workingDirectory,
    if (_hasText(intentText)) 'intentText': intentText,
    'approve': approve,
  };
}

enum LiveEditApplyPhase {
  idle,
  preparing,
  awaitingApproval,
  applying,
  success,
  failed,
}

final class LiveEditOrchestrator extends ChangeNotifier {
  LiveEditOrchestrator({
    final LiveEditController? controller,
    this.applyDraftDelegate,
    this.backendId,
    this.workingDirectory,
    this.intentText,
  }) : controller = controller ?? LiveEditController.instance {
    this.controller.addListener(_onControllerChanged);
  }

  final LiveEditController controller;
  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final String? backendId;
  final String? workingDirectory;
  final String? intentText;

  LiveEditApplyPhase _applyPhase = LiveEditApplyPhase.idle;
  LiveEditExecutionPlan? _pendingExecutionPlan;
  String? _pendingProposalId;
  String? _lastError;
  bool _disposed = false;

  List<LiveEditDraftChange> get activeDraftChanges =>
      controller.activeDraftChanges;
  LiveEditSelection? get activeSelection => controller.activeSelection;
  String? get activeSessionId => controller.activeSessionId;
  LiveEditApplyPhase get applyPhase => _applyPhase;
  bool get hasDraftChanges => activeDraftChanges.isNotEmpty;
  String? get lastError => _lastError;
  bool get needsApproval =>
      _applyPhase == LiveEditApplyPhase.awaitingApproval &&
      _pendingExecutionPlan != null &&
      _hasText(_pendingProposalId);
  bool get overlayVisible => controller.overlayVisible;
  LiveEditExecutionPlan? get pendingExecutionPlan => _pendingExecutionPlan;

  Future<void> applyDraft({final bool approve = false}) async {
    final sessionId = ensureSession();
    if (!hasDraftChanges) {
      _setError('No draft changes to apply.');
      return;
    }
    if (applyDraftDelegate == null) {
      _setError('Apply transport is not configured for this host app.');
      return;
    }

    _applyPhase = approve
        ? LiveEditApplyPhase.applying
        : LiveEditApplyPhase.preparing;
    _lastError = null;
    notifyListeners();

    try {
      final response = await applyDraftDelegate!(
        LiveEditApplyDraftRequest(
          sessionId: sessionId,
          proposalId: _pendingProposalId,
          backendId: backendId,
          workingDirectory: workingDirectory,
          intentText: intentText,
          approve: approve,
        ),
      );

      final responseError = _extractError(response);
      if (_hasText(responseError)) {
        _setError(responseError!);
        return;
      }

      final proposalId = '${response['proposalId'] ?? ''}'.trim();
      if (_hasText(proposalId)) {
        _pendingProposalId = proposalId;
      }

      final executionPlan = _decodeExecutionPlan(response['executionPlan']);
      if (executionPlan != null) {
        _pendingExecutionPlan = executionPlan;
      }

      if (approve) {
        _applyPhase = LiveEditApplyPhase.success;
        _pendingExecutionPlan = null;
        _pendingProposalId = null;
        controller.discardDraft(sessionId: sessionId);
      } else {
        _applyPhase = LiveEditApplyPhase.awaitingApproval;
      }
      notifyListeners();
    } on Exception catch (error) {
      _setError('Apply failed: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  String ensureSession() {
    final current = activeSessionId;
    if (_hasText(current)) {
      return current!;
    }
    final started = controller.startSession();
    return '${started['sessionId'] ?? ''}';
  }

  Future<void> retryApply() async {
    if (_hasText(_pendingProposalId)) {
      await applyDraft(approve: true);
      return;
    }
    await applyDraft();
  }

  void selectNode(final Offset globalOffset, {final GlobalKey? contentKey}) {
    final sessionId = ensureSession();
    final contentRoot = contentKey?.currentContext;
    controller.selectAtPoint(
      sessionId: sessionId,
      x: globalOffset.dx.round(),
      y: globalOffset.dy.round(),
      contentRoot: contentRoot is Element ? contentRoot : null,
    );
    _resetApplyState(clearError: true);
  }

  void setOverlayEnabled(final bool enabled) {
    final sessionId = ensureSession();
    controller.setOverlay(sessionId: sessionId, enabled: enabled);
    if (!enabled) {
      _resetApplyState(clearError: false);
    }
  }

  Future<void> showApprovalSheet(final BuildContext context) async {
    if (!hasDraftChanges) {
      _setError('No draft changes to apply.');
      return;
    }

    if (_pendingExecutionPlan == null || !_hasText(_pendingProposalId)) {
      await applyDraft();
    }
    if (_pendingExecutionPlan == null || !_hasText(_pendingProposalId)) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (final _) => AnimatedBuilder(
        animation: this,
        builder: (final context, final child) {
          final plan = _pendingExecutionPlan;
          if (plan == null) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(plan.summary),
                  const SizedBox(height: 8),
                  Text('Target: ${plan.selectedNode}'),
                  const SizedBox(height: 8),
                  for (final change in plan.requestedChanges) Text('- $change'),
                  const SizedBox(height: 8),
                  Text(
                    'Files: ${plan.affectedFiles.isEmpty ? 'none' : plan.affectedFiles.join(', ')}',
                  ),
                  if (plan.riskNotes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('Risk: ${plan.riskNotes.join(' | ')}'),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _applyPhase == LiveEditApplyPhase.applying
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _applyPhase == LiveEditApplyPhase.applying
                              ? null
                              : () async {
                                  await applyDraft(approve: true);
                                  if (context.mounted &&
                                      _applyPhase ==
                                          LiveEditApplyPhase.success) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          child: Text(
                            _applyPhase == LiveEditApplyPhase.applying
                                ? 'Applying...'
                                : 'Approve & Apply',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void undoDraft() {
    final sessionId = ensureSession();
    controller.discardDraft(sessionId: sessionId);
    _resetApplyState(clearError: true);
  }

  void updateDraft({
    required final LiveEditPropertyDescriptor property,
    required final Object? targetValue,
  }) {
    final sessionId = ensureSession();
    final selection = activeSelection;
    if (selection == null) {
      _setError('No live-edit selection is active.');
      return;
    }

    final previewMode = property.canPreviewExactly
        ? LiveEditPreviewMode.exact
        : (property.previewMode == LiveEditPreviewMode.none
              ? LiveEditPreviewMode.ghost
              : property.previewMode);

    controller.updateDraft(
      sessionId: sessionId,
      change: LiveEditDraftChange(
        nodeId: selection.nodeId,
        propertyId: property.id,
        targetValue: targetValue,
        previewMode: previewMode,
        confidence: property.safeToAutoGroupInApply ? 0.95 : 0.75,
        intentText: intentText,
        meta: <String, Object?>{
          'requiresAgentForPersistence': property.requiresAgentForPersistence,
        },
      ),
    );

    _resetApplyState(clearError: true);
  }

  LiveEditExecutionPlan? _decodeExecutionPlan(final Object? value) {
    if (value is Map) {
      final normalized = value.map(
        (final key, final nested) => MapEntry('$key', nested),
      );
      return LiveEditExecutionPlan.fromJson(normalized);
    }

    final selection = activeSelection;
    if (selection == null) {
      return null;
    }
    return LiveEditExecutionPlan(
      proposalId: _pendingProposalId ?? '',
      title: 'Apply live edit',
      summary: 'Persist current draft changes.',
      selectedNode: selection.widgetType,
      requestedChanges: activeDraftChanges
          .map((final draft) => '${draft.propertyId}: ${draft.targetValue}')
          .toList(growable: false),
      affectedFiles: const <String>[],
      confidence: activeDraftChanges.isEmpty ? 0 : 0.7,
      agentInstruction: 'Apply current live-edit draft changes.',
    );
  }

  String? _extractError(final Map<String, Object?> response) {
    if (response['ok'] == false) {
      return '${response['message'] ?? 'Unknown apply failure'}';
    }
    final nestedError = response['error'];
    if (nestedError is Map) {
      final message = '${nestedError['message'] ?? ''}'.trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  void _onControllerChanged() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  void _resetApplyState({required final bool clearError}) {
    _applyPhase = LiveEditApplyPhase.idle;
    _pendingExecutionPlan = null;
    _pendingProposalId = null;
    if (clearError) {
      _lastError = null;
    }
    notifyListeners();
  }

  void _setError(final String error) {
    _applyPhase = LiveEditApplyPhase.failed;
    _lastError = error;
    notifyListeners();
  }
}
