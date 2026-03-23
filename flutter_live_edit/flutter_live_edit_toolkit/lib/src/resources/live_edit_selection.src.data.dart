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
  });

  final LiveEditSelection? selection;
  final LiveEditSelection? hoverSelection;
  final Rect? marqueeRect;
  final List<LiveEditSelection> marqueeSelections;
  final List<LiveEditSelection> multiSelections;
  final List<LiveEditSelectionCandidate> selectionCandidates;

  static const LiveEditSelectionLayerData empty = LiveEditSelectionLayerData();

  LiveEditSelectionLayerData copyWith({
    final LiveEditSelection? selection,
    final LiveEditSelection? hoverSelection,
    final Rect? marqueeRect,
    final List<LiveEditSelection>? marqueeSelections,
    final List<LiveEditSelection>? multiSelections,
    final List<LiveEditSelectionCandidate>? selectionCandidates,
  }) => LiveEditSelectionLayerData(
    selection: selection ?? this.selection,
    hoverSelection: hoverSelection ?? this.hoverSelection,
    marqueeRect: marqueeRect ?? this.marqueeRect,
    marqueeSelections: marqueeSelections ?? this.marqueeSelections,
    multiSelections: multiSelections ?? this.multiSelections,
    selectionCandidates: selectionCandidates ?? this.selectionCandidates,
  );
}

/// Key: sessionId, value: map of domain -> layer data.
typedef LiveEditSelectionState =
    Map<String, Map<LiveEditTargetDomain, LiveEditSelectionLayerData>>;
