import '../models/models.dart';

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

final class LiveEditDraftSessionState {
  const LiveEditDraftSessionState({
    this.layers = const <LiveEditTargetDomain, LiveEditDraftLayerData>{},
  });

  final Map<LiveEditTargetDomain, LiveEditDraftLayerData> layers;

  static const LiveEditDraftSessionState empty = LiveEditDraftSessionState();

  LiveEditDraftLayerData layerFor(final LiveEditTargetDomain domain) =>
      layers[domain] ?? LiveEditDraftLayerData.empty;

  LiveEditDraftSessionState copyWith({
    final Map<LiveEditTargetDomain, LiveEditDraftLayerData>? layers,
  }) => LiveEditDraftSessionState(layers: layers ?? this.layers);
}

final class LiveEditDraftStore {
  const LiveEditDraftStore({
    this.sessions = const <String, LiveEditDraftSessionState>{},
  });

  final Map<String, LiveEditDraftSessionState> sessions;

  static const LiveEditDraftStore empty = LiveEditDraftStore();

  LiveEditDraftLayerData layerFor(
    final String? sessionId,
    final LiveEditTargetDomain domain,
  ) {
    final resolvedId = sessionId?.trim();
    if (resolvedId == null || resolvedId.isEmpty) {
      return LiveEditDraftLayerData.empty;
    }
    return sessions[resolvedId]?.layerFor(domain) ??
        LiveEditDraftLayerData.empty;
  }

  LiveEditDraftStore copyWith({
    final Map<String, LiveEditDraftSessionState>? sessions,
  }) => LiveEditDraftStore(sessions: sessions ?? this.sessions);
}
