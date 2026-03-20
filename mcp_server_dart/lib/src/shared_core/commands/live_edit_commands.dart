part of 'commands.dart';

/// Live-edit commands; handled by the live-edit executor when enabled.
sealed class LiveEditCommand extends CoreCommand {
  const LiveEditCommand();
}

final class LiveEditAcceptResolutionCommand extends LiveEditCommand {
  const LiveEditAcceptResolutionCommand({
    required this.proposalId,
    this.sessionId,
    this.workingDirectory,
  });

  final String proposalId;
  final String? sessionId;
  final String? workingDirectory;

  @override
  String get name => LiveEditMcpToolNames.acceptResolution;
}

final class LiveEditApplyDraftCommand extends LiveEditCommand {
  const LiveEditApplyDraftCommand({
    this.sessionId,
    this.backendId,
    this.inferenceConfig,
    this.workingDirectory,
    this.intentText,
    this.proposalId,
    this.approve = false,
  });

  final String? sessionId;
  final String? backendId;
  final LiveEditInferenceConfig? inferenceConfig;
  final String? workingDirectory;
  final String? intentText;
  final String? proposalId;
  final bool approve;

  @override
  String get name => LiveEditMcpToolNames.applyDraft;
}

final class LiveEditDiscardDraftCommand extends LiveEditCommand {
  const LiveEditDiscardDraftCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => LiveEditMcpToolNames.discardDraft;
}

final class LiveEditEndSessionCommand extends LiveEditCommand {
  const LiveEditEndSessionCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => LiveEditMcpToolNames.endSession;
}

final class LiveEditGetAgentBackendCommand extends LiveEditCommand {
  const LiveEditGetAgentBackendCommand({this.sessionId, this.backendId});

  final String? sessionId;
  final String? backendId;

  @override
  String get name => LiveEditMcpToolNames.getAgentBackend;
}

final class LiveEditGetCapabilitiesCommand extends LiveEditCommand {
  const LiveEditGetCapabilitiesCommand({this.sessionId, this.targetDomain});

  final String? sessionId;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.getCapabilities;
}

final class LiveEditGetDraftCommand extends LiveEditCommand {
  const LiveEditGetDraftCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => LiveEditMcpToolNames.getDraft;
}

final class LiveEditGetPreviewStateCommand extends LiveEditCommand {
  const LiveEditGetPreviewStateCommand({this.sessionId, this.targetDomain});

  final String? sessionId;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.getPreviewState;
}

final class LiveEditGetPropertyPanelCommand extends LiveEditCommand {
  const LiveEditGetPropertyPanelCommand({this.sessionId, this.targetDomain});

  final String? sessionId;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.getPropertyPanel;
}

final class LiveEditGetSelectionCandidatesCommand extends LiveEditCommand {
  const LiveEditGetSelectionCandidatesCommand({
    this.sessionId,
    this.targetDomain,
  });

  final String? sessionId;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.getSelectionCandidates;
}

final class LiveEditGetSelectionCommand extends LiveEditCommand {
  const LiveEditGetSelectionCommand({this.sessionId, this.targetDomain});

  final String? sessionId;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.getSelection;
}

final class LiveEditGetTreeCommand extends LiveEditCommand {
  const LiveEditGetTreeCommand({this.sessionId, this.targetDomain});

  final String? sessionId;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.getTree;
}

final class LiveEditListAgentBackendsCommand extends LiveEditCommand {
  const LiveEditListAgentBackendsCommand();

  @override
  String get name => LiveEditMcpToolNames.listAgentBackends;
}

final class LiveEditPrepareSessionCommand extends LiveEditCommand {
  const LiveEditPrepareSessionCommand({
    this.sessionId,
    this.backendId,
    this.inferenceConfig,
    this.workingDirectory,
    this.targetDomain,
  });

  final String? sessionId;
  final String? backendId;
  final LiveEditInferenceConfig? inferenceConfig;
  final String? workingDirectory;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.prepareSession;
}

final class LiveEditRejectResolutionCommand extends LiveEditCommand {
  const LiveEditRejectResolutionCommand({required this.proposalId});

  final String proposalId;

  @override
  String get name => LiveEditMcpToolNames.rejectResolution;
}

final class LiveEditResolveDraftCommand extends LiveEditCommand {
  const LiveEditResolveDraftCommand({
    this.sessionId,
    this.backendId,
    this.inferenceConfig,
    this.workingDirectory,
    this.intentText,
    this.targetDomain,
  });

  final String? sessionId;
  final String? backendId;
  final LiveEditInferenceConfig? inferenceConfig;
  final String? workingDirectory;
  final String? intentText;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.resolveDraft;
}

final class LiveEditSelectAtPointCommand extends LiveEditCommand {
  const LiveEditSelectAtPointCommand({
    required this.x,
    required this.y,
    this.sessionId,
    this.viewId,
    this.selectionPolicy = LiveEditSelectionPolicy.deepest,
    this.targetDomain,
  });

  final String? sessionId;
  final int x;
  final int y;
  final int? viewId;
  final LiveEditSelectionPolicy selectionPolicy;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.selectAtPoint;
}

final class LiveEditSetActiveSelectionCommand extends LiveEditCommand {
  const LiveEditSetActiveSelectionCommand({
    this.sessionId,
    this.nodeId,
    this.index,
    this.targetDomain,
  });

  final String? sessionId;
  final String? nodeId;
  final int? index;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.setActiveSelection;
}

final class LiveEditSetAgentBackendCommand extends LiveEditCommand {
  const LiveEditSetAgentBackendCommand({
    required this.sessionId,
    required this.backendId,
    this.inferenceConfig,
  });

  final String sessionId;
  final String backendId;
  final LiveEditInferenceConfig? inferenceConfig;

  @override
  String get name => LiveEditMcpToolNames.setAgentBackend;
}

final class LiveEditSetEditModeCommand extends LiveEditCommand {
  const LiveEditSetEditModeCommand({
    required this.mode,
    this.sessionId,
    this.targetDomain,
  });

  final String? sessionId;
  final String mode;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.setEditMode;
}

final class LiveEditSetOverlayCommand extends LiveEditCommand {
  const LiveEditSetOverlayCommand({required this.enabled, this.sessionId});

  final String? sessionId;
  final bool enabled;

  @override
  String get name => LiveEditMcpToolNames.setOverlay;
}

final class LiveEditStartSessionCommand extends LiveEditCommand {
  const LiveEditStartSessionCommand({this.sessionId, this.targetDomain});

  final String? sessionId;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.startSession;
}

final class LiveEditUpdateDraftCommand extends LiveEditCommand {
  const LiveEditUpdateDraftCommand({
    required this.change,
    this.sessionId,
    this.targetDomain,
  });

  final String? sessionId;
  final LiveEditDraftChange change;
  final String? targetDomain;

  @override
  String get name => LiveEditMcpToolNames.updateDraft;
}
