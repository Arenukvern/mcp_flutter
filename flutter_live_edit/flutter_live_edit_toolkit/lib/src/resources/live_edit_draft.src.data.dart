import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

/// Per-layer draft state.
final class LiveEditDraftLayerData {
  const LiveEditDraftLayerData({
    this.draftChanges = const <LiveEditDraftChange>[],
    this.meaningfulNodeIds = const <String>{},
  });

  final List<LiveEditDraftChange> draftChanges;
  final Set<String> meaningfulNodeIds;

  static const LiveEditDraftLayerData empty = LiveEditDraftLayerData();

  LiveEditDraftLayerData copyWith({
    final List<LiveEditDraftChange>? draftChanges,
    final Set<String>? meaningfulNodeIds,
  }) => LiveEditDraftLayerData(
    draftChanges: draftChanges ?? this.draftChanges,
    meaningfulNodeIds: meaningfulNodeIds ?? this.meaningfulNodeIds,
  );
}

/// Key: sessionId, value: map of domain -> draft layer data.
typedef LiveEditDraftState =
    Map<String, Map<LiveEditTargetDomain, LiveEditDraftLayerData>>;
