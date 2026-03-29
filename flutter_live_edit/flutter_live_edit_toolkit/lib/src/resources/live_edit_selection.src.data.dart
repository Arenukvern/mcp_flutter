import 'dart:ui' show Rect;

import '../models/models.dart';

/// Per-layer selection state (serializable; no Element references).
final class LiveEditSelectionLayerData {
  const LiveEditSelectionLayerData({
    this.selection,
    this.hoverSelection,
    this.marqueeRect,
    this.marqueeSelections = const <LiveEditSelection>[],
    this.multiSelections = const <LiveEditSelection>[],
    this.selectionCandidates = const <LiveEditSelectionCandidate>[],
    this.selectionSet = InteractionSelectionSet.empty,
    this.selectedNodeSummaries = const <InteractionNodeSummary>[],
    this.marqueeNodeSummaries = const <InteractionNodeSummary>[],
    this.selectionCandidateSummaries = const <InteractionNodeSummary>[],
  });

  final LiveEditSelection? selection;
  final LiveEditSelection? hoverSelection;
  final Rect? marqueeRect;
  final List<LiveEditSelection> marqueeSelections;
  final List<LiveEditSelection> multiSelections;
  final List<LiveEditSelectionCandidate> selectionCandidates;
  final InteractionSelectionSet selectionSet;
  final List<InteractionNodeSummary> selectedNodeSummaries;
  final List<InteractionNodeSummary> marqueeNodeSummaries;
  final List<InteractionNodeSummary> selectionCandidateSummaries;

  static const LiveEditSelectionLayerData empty = LiveEditSelectionLayerData();

  LiveEditSelectionLayerData copyWith({
    final LiveEditSelection? selection,
    final LiveEditSelection? hoverSelection,
    final Rect? marqueeRect,
    final List<LiveEditSelection>? marqueeSelections,
    final List<LiveEditSelection>? multiSelections,
    final List<LiveEditSelectionCandidate>? selectionCandidates,
    final InteractionSelectionSet? selectionSet,
    final List<InteractionNodeSummary>? selectedNodeSummaries,
    final List<InteractionNodeSummary>? marqueeNodeSummaries,
    final List<InteractionNodeSummary>? selectionCandidateSummaries,
  }) => LiveEditSelectionLayerData(
    selection: selection ?? this.selection,
    hoverSelection: hoverSelection ?? this.hoverSelection,
    marqueeRect: marqueeRect ?? this.marqueeRect,
    marqueeSelections: marqueeSelections ?? this.marqueeSelections,
    multiSelections: multiSelections ?? this.multiSelections,
    selectionCandidates: selectionCandidates ?? this.selectionCandidates,
    selectionSet: selectionSet ?? this.selectionSet,
    selectedNodeSummaries: selectedNodeSummaries ?? this.selectedNodeSummaries,
    marqueeNodeSummaries: marqueeNodeSummaries ?? this.marqueeNodeSummaries,
    selectionCandidateSummaries:
        selectionCandidateSummaries ?? this.selectionCandidateSummaries,
  );

  bool get hasSelection => !selectionSet.isEmpty;
}

final class LiveEditSelectionSessionState {
  const LiveEditSelectionSessionState({
    this.layers = const <LiveEditTargetDomain, LiveEditSelectionLayerData>{},
  });

  final Map<LiveEditTargetDomain, LiveEditSelectionLayerData> layers;

  static const LiveEditSelectionSessionState empty =
      LiveEditSelectionSessionState();

  LiveEditSelectionLayerData layerFor(final LiveEditTargetDomain domain) =>
      layers[domain] ?? LiveEditSelectionLayerData.empty;

  LiveEditSelectionSessionState copyWith({
    final Map<LiveEditTargetDomain, LiveEditSelectionLayerData>? layers,
  }) => LiveEditSelectionSessionState(layers: layers ?? this.layers);
}

final class LiveEditSelectionStore {
  const LiveEditSelectionStore({
    this.sessions = const <String, LiveEditSelectionSessionState>{},
  });

  final Map<String, LiveEditSelectionSessionState> sessions;

  static const LiveEditSelectionStore empty = LiveEditSelectionStore();

  LiveEditSelectionLayerData layerFor(
    final String? sessionId,
    final LiveEditTargetDomain domain,
  ) {
    final resolvedId = sessionId?.trim();
    if (resolvedId == null || resolvedId.isEmpty) {
      return LiveEditSelectionLayerData.empty;
    }
    return sessions[resolvedId]?.layerFor(domain) ??
        LiveEditSelectionLayerData.empty;
  }

  LiveEditSelectionStore copyWith({
    final Map<String, LiveEditSelectionSessionState>? sessions,
  }) => LiveEditSelectionStore(sessions: sessions ?? this.sessions);
}
