import 'package:flutter/material.dart' show Offset;
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

typedef LiveEditApplyDraftDelegate =
    Future<Map<String, Object?>> Function(LiveEditApplyDraftRequest request);

typedef LiveEditBubbleId = String;

typedef LiveEditRuntimeEventSink = void Function(LiveEditRuntimeEvent event);

bool _hasText(final String? value) =>
    value != null && value.trim().isNotEmpty;

const Object _unsetValue = Object();

final class LiveEditActivityEntry {
  const LiveEditActivityEntry({
    required this.step,
    required this.label,
    required this.summary,
    required this.timestamp,
    this.nodeId,
    this.details = const <String>[],
    this.inProgress = false,
    this.errorText,
  });

  final LiveEditActivityStep step;
  final String label;
  final String summary;
  final DateTime timestamp;
  final String? nodeId;
  final List<String> details;
  final bool inProgress;
  final String? errorText;
}

enum LiveEditActivityStep {
  promptReady,
  draftReady,
  preparingRequest,
  readingSourceContext,
  generatingProposal,
  waitingForApproval,
  applyingChanges,
  finished,
  failed,
}

final class LiveEditApplyDraftRequest {
  const LiveEditApplyDraftRequest({
    required this.sessionId,
    this.draftChanges = const <LiveEditDraftChange>[],
    this.bubbleId,
    this.instructionText,
    this.primarySelection,
    this.selectedWidgets = const <LiveEditSelection>[],
    this.sourceTargets = const <LiveEditSourceTarget>[],
    this.stagedPropertyChanges = const <LiveEditDraftChange>[],
    this.applyMode = LiveEditApplyMode.singleBubble,
    this.selection,
    this.proposalId,
    this.backendId,
    this.inferenceConfig,
    this.workingDirectory,
    this.intentText,
    this.approve = false,
    this.onEvent,
  });

  final String sessionId;
  final List<LiveEditDraftChange> draftChanges;
  final String? bubbleId;
  final String? instructionText;
  final LiveEditSelection? primarySelection;
  final List<LiveEditSelection> selectedWidgets;
  final List<LiveEditSourceTarget> sourceTargets;
  final List<LiveEditDraftChange> stagedPropertyChanges;
  final LiveEditApplyMode applyMode;
  final LiveEditSelection? selection;
  final String? proposalId;
  final String? backendId;
  final LiveEditInferenceConfig? inferenceConfig;
  final String? workingDirectory;
  final String? intentText;
  final bool approve;
  final LiveEditRuntimeEventSink? onEvent;

  String? get effectiveBubbleId =>
      bubbleId?.trim().isEmpty == true ? null : bubbleId?.trim();

  String? get effectiveInstructionText =>
      instructionText?.trim().isNotEmpty == true
          ? instructionText!.trim()
          : intentText?.trim().isNotEmpty == true
              ? intentText!.trim()
              : null;

  LiveEditSelection? get effectivePrimarySelection =>
      primarySelection ?? selection;

  List<LiveEditSelection> get effectiveSelectedWidgets {
    if (selectedWidgets.isNotEmpty) return selectedWidgets;
    final primary = effectivePrimarySelection;
    return primary == null
        ? const <LiveEditSelection>[]
        : <LiveEditSelection>[primary];
  }

  List<LiveEditDraftChange> get effectiveStagedPropertyChanges =>
      stagedPropertyChanges.isNotEmpty ? stagedPropertyChanges : draftChanges;

  Map<String, Object?> toJson() => <String, Object?>{
        'sessionId': sessionId,
        if (_hasText(effectiveBubbleId)) 'bubbleId': effectiveBubbleId,
        if (_hasText(effectiveInstructionText))
          'instructionText': effectiveInstructionText,
        if (primarySelection != null)
          'primarySelection': primarySelection!.toJson(),
        if (selectedWidgets.isNotEmpty)
          'selectedWidgets': selectedWidgets
              .map((final s) => s.toJson())
              .toList(growable: false),
        if (sourceTargets.isNotEmpty)
          'sourceTargets': sourceTargets
              .map((final t) => t.toJson())
              .toList(growable: false),
        'stagedPropertyChanges': effectiveStagedPropertyChanges
            .map((final c) => c.toJson())
            .toList(growable: false),
        'applyMode': applyMode.wireName,
        'draftChanges': draftChanges
            .map((final c) => c.toJson())
            .toList(growable: false),
        if (selection != null) 'selection': selection!.toJson(),
        if (_hasText(proposalId)) 'proposalId': proposalId,
        if (_hasText(backendId)) 'backendId': backendId,
        if (inferenceConfig != null)
          'inferenceConfig': inferenceConfig!.toJson(),
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

final class LiveEditBubbleRecord {
  const LiveEditBubbleRecord({
    required this.bubbleId,
    required this.targetDomain,
    required this.targetKey,
    this.primarySelection,
    this.selectedWidgets = const <LiveEditSelection>[],
    this.draftChanges = const <LiveEditDraftChange>[],
    this.instructionText = '',
    this.status = LiveEditBubbleStatus.editing,
    this.displayState = LiveEditBubbleDisplayState.expanded,
    this.changedFiles = const <String>[],
    this.backendId,
    this.inferenceConfig,
    this.executionPlan,
    this.lastError,
    this.history = const <LiveEditTimelineEntry>[],
    this.activity = const <LiveEditActivityEntry>[],
    this.debugTimeline = const <LiveEditTimelineEntry>[],
    this.debugPromptText,
    this.bubbleDragOffset = Offset.zero,
  });

  final LiveEditBubbleId bubbleId;
  final LiveEditTargetDomain targetDomain;
  final String targetKey;
  final LiveEditSelection? primarySelection;
  final List<LiveEditSelection> selectedWidgets;
  final List<LiveEditDraftChange> draftChanges;
  final String instructionText;
  final LiveEditBubbleStatus status;
  final LiveEditBubbleDisplayState displayState;
  final List<String> changedFiles;
  final String? backendId;
  final LiveEditInferenceConfig? inferenceConfig;
  final LiveEditExecutionPlan? executionPlan;
  final String? lastError;
  final List<LiveEditTimelineEntry> history;
  final List<LiveEditActivityEntry> activity;
  final List<LiveEditTimelineEntry> debugTimeline;
  final String? debugPromptText;
  final Offset bubbleDragOffset;

  bool get hasPendingApply =>
      draftChanges.isNotEmpty ||
      (status != LiveEditBubbleStatus.applied &&
          instructionText.trim().isNotEmpty);

  List<String> get nodeIds {
    final nodes = <String>{
      if (primarySelection != null) primarySelection!.nodeId,
      ...selectedWidgets.map((final s) => s.nodeId),
      ...draftChanges.map((final c) => c.nodeId),
    };
    return nodes.where(_hasText).toList(growable: false);
  }

  LiveEditBubbleRecord copyWith({
    final LiveEditSelection? primarySelection,
    final List<LiveEditSelection>? selectedWidgets,
    final List<LiveEditDraftChange>? draftChanges,
    final String? instructionText,
    final LiveEditBubbleStatus? status,
    final LiveEditBubbleDisplayState? displayState,
    final List<String>? changedFiles,
    final String? backendId,
    final Object? inferenceConfig = _unsetValue,
    final LiveEditExecutionPlan? executionPlan,
    final Object? lastError = _unsetValue,
    final List<LiveEditTimelineEntry>? history,
    final List<LiveEditActivityEntry>? activity,
    final List<LiveEditTimelineEntry>? debugTimeline,
    final Object? debugPromptText = _unsetValue,
    final Offset? bubbleDragOffset,
  }) =>
      LiveEditBubbleRecord(
        bubbleId: bubbleId,
        targetDomain: targetDomain,
        targetKey: targetKey,
        primarySelection: primarySelection ?? this.primarySelection,
        selectedWidgets: selectedWidgets ?? this.selectedWidgets,
        draftChanges: draftChanges ?? this.draftChanges,
        instructionText: instructionText ?? this.instructionText,
        status: status ?? this.status,
        displayState: displayState ?? this.displayState,
        changedFiles: changedFiles ?? this.changedFiles,
        backendId: backendId ?? this.backendId,
        inferenceConfig: identical(inferenceConfig, _unsetValue)
            ? this.inferenceConfig
            : inferenceConfig as LiveEditInferenceConfig?,
        executionPlan: executionPlan ?? this.executionPlan,
        lastError: identical(lastError, _unsetValue)
            ? this.lastError
            : lastError as String?,
        history: history ?? this.history,
        activity: activity ?? this.activity,
        debugTimeline: debugTimeline ?? this.debugTimeline,
        debugPromptText: identical(debugPromptText, _unsetValue)
            ? this.debugPromptText
            : debugPromptText as String?,
        bubbleDragOffset: bubbleDragOffset ?? this.bubbleDragOffset,
      );
}

enum LiveEditBubbleStatus {
  editing,
  waiting,
  needsApproval,
  applied,
  failed,
}

final class LiveEditBubbleSummary {
  const LiveEditBubbleSummary({
    required this.bubbleId,
    required this.targetDomain,
    required this.targetKey,
    required this.nodeId,
    required this.label,
    required this.status,
    required this.active,
    required this.displayState,
    this.bounds,
    this.sourceLabel,
  });

  final String bubbleId;
  final LiveEditTargetDomain targetDomain;
  final String targetKey;
  final String nodeId;
  final String label;
  final LiveEditBubbleStatus status;
  final bool active;
  final LiveEditBubbleDisplayState displayState;
  final LiveEditBounds? bounds;
  final String? sourceLabel;
}

final class LiveEditLayerViewState {
  LiveEditLayerViewState({
    this.activeBubbleId,
    this.activePropertyId,
    this.editMode = LiveEditEditMode.inspect,
  });

  LiveEditBubbleId? activeBubbleId;
  String? activePropertyId;
  LiveEditEditMode editMode = LiveEditEditMode.inspect;
}

enum LiveEditPanelDisplayMode { rail, expanded }

final class LiveEditRuntimeEvent {
  const LiveEditRuntimeEvent({
    required this.kind,
    required this.message,
    this.details = const <String>[],
    this.promptText,
    this.debugOnly = false,
  });

  final LiveEditRuntimeEventKind kind;
  final String message;
  final List<String> details;
  final String? promptText;
  final bool debugOnly;
}

enum LiveEditRuntimeEventKind { edit, codex, debug }

final class LiveEditTimelineEntry {
  const LiveEditTimelineEntry({
    required this.role,
    required this.message,
    required this.timestamp,
    this.nodeId,
    this.details = const <String>[],
  });

  final String role;
  final String message;
  final DateTime timestamp;
  final String? nodeId;
  final List<String> details;
}
