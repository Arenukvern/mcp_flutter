import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_types.dart';

/// Bubble and apply state for UI.
final class LiveEditBubbleResourceData {
  LiveEditBubbleResourceData({
    this.bubbleRecordsById = const <LiveEditBubbleId, LiveEditBubbleRecord>{},
    final Map<LiveEditTargetDomain, LiveEditLayerViewState>?
    layerViewStateByDomain,
    this.applyPhase = LiveEditApplyPhase.idle,
    this.pendingExecutionPlan,
    this.pendingProposalId,
    this.lastError,
    this.resolvedBubbleIds = const <String>{},
  }) : layerViewStateByDomain =
           layerViewStateByDomain ?? _initialLayerViewState;

  final Map<LiveEditBubbleId, LiveEditBubbleRecord> bubbleRecordsById;
  final Map<LiveEditTargetDomain, LiveEditLayerViewState>
  layerViewStateByDomain;
  final LiveEditApplyPhase applyPhase;
  final LiveEditExecutionPlan? pendingExecutionPlan;
  final String? pendingProposalId;
  final String? lastError;
  final Set<String> resolvedBubbleIds;

  static LiveEditBubbleResourceData get initial => LiveEditBubbleResourceData();

  LiveEditBubbleResourceData copyWith({
    final Map<LiveEditBubbleId, LiveEditBubbleRecord>? bubbleRecordsById,
    final Map<LiveEditTargetDomain, LiveEditLayerViewState>?
    layerViewStateByDomain,
    final LiveEditApplyPhase? applyPhase,
    final LiveEditExecutionPlan? pendingExecutionPlan,
    final String? pendingProposalId,
    final Object? lastError = _unset,
    final Set<String>? resolvedBubbleIds,
  }) => LiveEditBubbleResourceData(
    bubbleRecordsById: bubbleRecordsById ?? this.bubbleRecordsById,
    layerViewStateByDomain:
        layerViewStateByDomain ?? this.layerViewStateByDomain,
    applyPhase: applyPhase ?? this.applyPhase,
    pendingExecutionPlan: pendingExecutionPlan ?? this.pendingExecutionPlan,
    pendingProposalId: pendingProposalId ?? this.pendingProposalId,
    lastError: identical(lastError, _unset)
        ? this.lastError
        : lastError as String?,
    resolvedBubbleIds: resolvedBubbleIds ?? this.resolvedBubbleIds,
  );
}

final Map<LiveEditTargetDomain, LiveEditLayerViewState> _initialLayerViewState =
    <LiveEditTargetDomain, LiveEditLayerViewState>{
      LiveEditTargetDomain.appScene: LiveEditLayerViewState(),
      LiveEditTargetDomain.toolScene: LiveEditLayerViewState(),
    };

const Object _unset = Object();
