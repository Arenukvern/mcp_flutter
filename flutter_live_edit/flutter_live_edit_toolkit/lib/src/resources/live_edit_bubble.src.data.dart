import '../models/models.dart';
import '../types/live_edit_types.dart';

/// Bubble and apply state for UI.
final class LiveEditBubbleResourceData {
  LiveEditBubbleResourceData({
    this.bubbleRecordsById = const <LiveEditBubbleId, LiveEditBubbleRecord>{},
    final Map<LiveEditTargetDomain, LiveEditLayerViewState>?
    layerViewStateByDomain,
    this.applyPhase = LiveEditApplyPhase.idle,
    this.pendingExecutionPlan,
    this.pendingProposalId,
    this.pendingBubbleId,
    this.pendingPropertyId,
    this.lastError,
    this.resolvedBubbleIds = const <String>{},
    this.globalComposerText = '',
  }) : layerViewStateByDomain =
           layerViewStateByDomain ?? _initialLayerViewState;

  final Map<LiveEditBubbleId, LiveEditBubbleRecord> bubbleRecordsById;
  final Map<LiveEditTargetDomain, LiveEditLayerViewState>
  layerViewStateByDomain;
  final LiveEditApplyPhase applyPhase;
  final LiveEditExecutionPlan? pendingExecutionPlan;
  final String? pendingProposalId;
  final String? pendingBubbleId;
  final String? pendingPropertyId;
  final String? lastError;
  final Set<String> resolvedBubbleIds;
  final String globalComposerText;

  static LiveEditBubbleResourceData get initial => LiveEditBubbleResourceData();

  LiveEditBubbleResourceData copyWith({
    final Map<LiveEditBubbleId, LiveEditBubbleRecord>? bubbleRecordsById,
    final Map<LiveEditTargetDomain, LiveEditLayerViewState>?
    layerViewStateByDomain,
    final LiveEditApplyPhase? applyPhase,
    final LiveEditExecutionPlan? pendingExecutionPlan,
    final String? pendingProposalId,
    final String? pendingBubbleId,
    final String? pendingPropertyId,
    final Object? lastError = _unset,
    final Set<String>? resolvedBubbleIds,
    final String? globalComposerText,
  }) => LiveEditBubbleResourceData(
    bubbleRecordsById: bubbleRecordsById ?? this.bubbleRecordsById,
    layerViewStateByDomain:
        layerViewStateByDomain ?? this.layerViewStateByDomain,
    applyPhase: applyPhase ?? this.applyPhase,
    pendingExecutionPlan: pendingExecutionPlan ?? this.pendingExecutionPlan,
    pendingProposalId: pendingProposalId ?? this.pendingProposalId,
    pendingBubbleId: pendingBubbleId ?? this.pendingBubbleId,
    pendingPropertyId: pendingPropertyId ?? this.pendingPropertyId,
    lastError: identical(lastError, _unset)
        ? this.lastError
        : lastError as String?,
    resolvedBubbleIds: resolvedBubbleIds ?? this.resolvedBubbleIds,
    globalComposerText: globalComposerText ?? this.globalComposerText,
  );
}

final Map<LiveEditTargetDomain, LiveEditLayerViewState> _initialLayerViewState =
    <LiveEditTargetDomain, LiveEditLayerViewState>{
      LiveEditTargetDomain.appScene: LiveEditLayerViewState(),
      LiveEditTargetDomain.toolScene: LiveEditLayerViewState(),
    };

const Object _unset = Object();
