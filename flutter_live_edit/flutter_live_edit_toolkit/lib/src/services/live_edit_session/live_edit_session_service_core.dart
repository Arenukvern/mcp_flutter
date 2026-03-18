// ignore_for_file: invalid_use_of_protected_member, unused_element

part of '../live_edit_session_service.dart';

class _LiveEditSessionServiceCore {
  _LiveEditSessionServiceCore();

  final Map<String, _LiveEditSessionState> _sessions =
      <String, _LiveEditSessionState>{};
  String? _activeSessionId;
  LiveEditSessionUpdate? _lastUpdate;

  LiveEditSessionUpdate? get lastUpdate => _lastUpdate;

  LiveEditSessionUpdate? _buildLastUpdate() {
    final session = this._activeSessionOrNull();
    if (session == null) return null;
    final sessionData = LiveEditSessionResourceData(
      activeSessionId: _activeSessionId,
      overlayVisible: session.overlayEnabled,
      targetDomain: session.targetDomain,
      sessionIds: _sessions.keys.toList(growable: false),
    );
    final layer = session.currentLayer;
    final selectionLayer = (
      session.sessionId,
      session.targetDomain,
      LiveEditSelectionLayerData(
        selection: layer.selection,
        hoverSelection: layer.hoverSelection,
        marqueeRect: layer.marqueeRect,
        marqueeSelections: List<LiveEditSelection>.from(
          layer.marqueeSelections,
        ),
        multiSelections: List<LiveEditSelection>.from(layer.multiSelections),
        selectionCandidates: List<LiveEditSelectionCandidate>.from(
          layer.selectionCandidates,
        ),
      ),
    );
    final draftLayer = (
      session.sessionId,
      session.targetDomain,
      LiveEditDraftLayerData(
        meaningfulNodeIds: Set<String>.from(layer.meaningfulNodeIds),
      ),
    );
    return LiveEditSessionUpdate(
      sessionData: sessionData,
      selectionLayer: selectionLayer,
      draftLayer: draftLayer,
    );
  }

  _LiveEditLayerState _activeLayerOrNull() {
    final session = this._activeSessionOrNull();
    if (session == null) {
      return _LiveEditLayerState();
    }
    return session.layerFor(session.targetDomain);
  }

  _LiveEditLayerState _layerForRequest(
    final _LiveEditSessionState session, {
    final LiveEditTargetDomain? requested,
  }) => session.layerFor(requested ?? session.targetDomain);

  List<LiveEditDraftChange> get activeDraftChanges =>
      const <LiveEditDraftChange>[];

  LiveEditSelection? get activeSelection => _activeLayerOrNull().selection;

  LiveEditSelection? get hoverSelection => _activeLayerOrNull().hoverSelection;

  Rect? get activeMarqueeRect => _activeLayerOrNull().marqueeRect;

  List<LiveEditSelection> get activeMarqueeSelections =>
      List<LiveEditSelection>.unmodifiable(
        _activeLayerOrNull().marqueeSelections,
      );

  List<LiveEditSelection> get activeMultiSelection =>
      List<LiveEditSelection>.unmodifiable(
        _activeLayerOrNull().multiSelections,
      );

  List<LiveEditSelectionCandidate> get activeSelectionCandidates =>
      List<LiveEditSelectionCandidate>.unmodifiable(
        _activeLayerOrNull().selectionCandidates,
      );

  String? get activeSessionId => _activeSessionId;

  bool get overlayVisible => this._activeSessionOrNull()?.overlayEnabled ?? false;

  LiveEditTargetDomain currentTargetDomain({final String? sessionId}) =>
      this._requireSession(sessionId).targetDomain;

  bool isMeaningfulNode(final String nodeId, {final String? sessionId}) =>
      _layerForRequest(
        this._requireSession(sessionId),
      ).meaningfulNodeIds.contains(nodeId);

  LiveEditSelection? selectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => _layerForRequest(
    this._requireSession(sessionId),
    requested: targetDomain,
  ).selection;

  LiveEditSelection? hoverSelectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => _layerForRequest(
    this._requireSession(sessionId),
    requested: targetDomain,
  ).hoverSelection;

  Rect? marqueeRectForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => _layerForRequest(
    this._requireSession(sessionId),
    requested: targetDomain,
  ).marqueeRect;

  List<LiveEditSelection> marqueeSelectionsForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => List<LiveEditSelection>.unmodifiable(
    _layerForRequest(
      this._requireSession(sessionId),
      requested: targetDomain,
    ).marqueeSelections,
  );

  List<LiveEditDraftChange> draftChangesForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => const <LiveEditDraftChange>[];

  List<LiveEditSelection> multiSelectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => List<LiveEditSelection>.unmodifiable(
    _layerForRequest(
      this._requireSession(sessionId),
      requested: targetDomain,
    ).multiSelections,
  );

  List<LiveEditSelectionCandidate> selectionCandidatesForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => List<LiveEditSelectionCandidate>.unmodifiable(
    _layerForRequest(
      this._requireSession(sessionId),
      requested: targetDomain,
    ).selectionCandidates,
  );

  Map<String, Object?> discardDraft({final String? sessionId}) {
    final session = this._requireSession(sessionId);
    final layer = _layerForRequest(session);
    this._revertExactPreview(session, layer: layer);
    layer.meaningfulNodeIds.remove(layer.selection?.nodeId);
    session.lastTouchedAt = DateTime.now().toUtc();
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'discarded': true,
      'draftChanges': const <Object?>[],
    };
  }

  Map<String, Object?> discardDraftNodes({
    required final List<String> nodeIds,
    final String? sessionId,
  }) {
    final session = this._requireSession(sessionId);
    final layer = _layerForRequest(session);
    final normalized = nodeIds.where(_hasText).toSet();
    if (normalized.isEmpty) {
      return discardDraft(sessionId: session.sessionId);
    }
    this._revertExactPreview(session, layer: layer, nodeIds: normalized);
    layer.meaningfulNodeIds.removeAll(normalized);
    session.lastTouchedAt = DateTime.now().toUtc();
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'discarded': true,
      'draftChanges': const <Object?>[],
    };
  }

  Map<String, Object?> commitDraft({final String? sessionId}) {
    final session = this._requireSession(sessionId);
    final layer = _layerForRequest(session);
    layer.originalExactValues.clear();
    session.lastTouchedAt = DateTime.now().toUtc();
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'committed': true,
      'draftChanges': const <Object?>[],
    };
  }

  Map<String, Object?> commitDraftNodes({
    required final List<String> nodeIds,
    final String? sessionId,
  }) {
    final session = this._requireSession(sessionId);
    final layer = _layerForRequest(session);
    final normalized = nodeIds.where(_hasText).toSet();
    if (normalized.isEmpty) {
      return commitDraft(sessionId: session.sessionId);
    }
    layer.originalExactValues.removeWhere((final key, final _) {
      final separator = key.indexOf('::');
      final nodeId = separator < 0 ? key : key.substring(0, separator);
      return normalized.contains(nodeId);
    });
    layer.meaningfulNodeIds.removeAll(normalized);
    session.lastTouchedAt = DateTime.now().toUtc();
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'committed': true,
      'draftChanges': const <Object?>[],
    };
  }

  void showAppliedPreview({
    required final List<LiveEditDraftChange> changes,
    final String? sessionId,
  }) {
    final session = this._requireSession(sessionId);
    final layer = _layerForRequest(session);
    if (changes.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      final currentSession = _sessions[session.sessionId];
      if (currentSession == null) {
        return;
      }
      for (final change in changes) {
        final tracked = currentSession
            .layerFor(
              LiveEditTargetDomain.fromWire(change.meta['targetDomain']),
            )
            .trackedSelections[change.nodeId];
        if (tracked == null) {
          continue;
        }
        this._applyExactPreviewIfSupported(
          currentSession,
          change,
          layerOverride: layer,
          elementOverride: tracked.element,
          selectionOverride: tracked.selection,
        );
      }
    });
  }

  Map<String, Object?> endSession({final String? sessionId}) {
    final session = this._requireSession(sessionId);
    this._revertExactPreview(session, layer: session.appLayer);
    this._revertExactPreview(session, layer: session.toolLayer);
    final removed = _sessions.remove(session.sessionId);
    if (_activeSessionId == session.sessionId) {
      _activeSessionId = _sessions.keys.isEmpty ? null : _sessions.keys.first;
    }
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'ended': removed != null,
    };
  }

  Map<String, Object?> getDraft({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = this._requireSession(sessionId);
    final resolvedDomain = this._resolveTargetDomain(session, targetDomain);
    // final layer = _layerForRequest(session, requested: resolvedDomain);
    return <String, Object?>{
      'sessionId': session.sessionId,
      'targetDomain': resolvedDomain.wireName,
      'draftChanges': const <Object?>[],
    };
  }

  Map<String, Object?> getSelection({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = this._requireSession(sessionId);
    final resolvedDomain = this._resolveTargetDomain(session, targetDomain);
    final layer = _layerForRequest(session, requested: resolvedDomain);
    final selection = layer.selection;
    return <String, Object?>{
      'sessionId': session.sessionId,
      'targetDomain': resolvedDomain.wireName,
      'selection': selection?.toJson(),
      'hasSelection': selection != null,
      'hoverSelection': layer.hoverSelection?.toJson(),
      'selectedNodeIds': layer.multiSelections
          .map((final item) => item.nodeId)
          .toList(growable: false),
      'selectionCandidates': layer.selectionCandidates
          .map((final candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }

  Map<String, Object?> getTree({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = this._requireSession(sessionId);
    final resolvedDomain = this._resolveTargetDomain(session, targetDomain);
    if (resolvedDomain == LiveEditTargetDomain.toolScene) {
      session.lastTouchedAt = DateTime.now().toUtc();
      return <String, Object?>{
        'sessionId': session.sessionId,
        'targetDomain': resolvedDomain.wireName,
        'selectedNodeId': session.selection?.nodeId,
        'tree': LiveEditOverlayThemeModel.instance.buildTreeSnapshot(
          session.sessionId,
        ),
      };
    }
    final rawTree = _decodeObject(
      WidgetInspectorService.instance.getRootWidgetSummaryTree(
        session.objectGroup,
      ),
    );
    session.lastTouchedAt = DateTime.now().toUtc();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'targetDomain': resolvedDomain.wireName,
      'selectedNodeId': session.selection?.nodeId,
      'tree': rawTree,
    };
  }

  Map<String, Object?> selectAtGlobalOffset(final ui.Offset offset) =>
      selectAtPoint(
        sessionId: _activeSessionId,
        x: offset.dx.round(),
        y: offset.dy.round(),
      );

  Map<String, Object?> hoverAtPoint({
    required final int x,
    required final int y,
    final bool deeperMode = false,
    final String? sessionId,
    final int? viewId,
    final Element? contentRoot,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = this._requireSession(sessionId);
    final resolvedDomain = this._resolveTargetDomain(session, targetDomain);
    final root =
        (contentRoot != null && contentRoot.mounted ? contentRoot : null) ??
        WidgetsBinding.instance.rootElement;
    if (root == null) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'hovered': false,
        'reason': 'widget_tree_unavailable',
      };
    }
    final point = ui.Offset(x.toDouble(), y.toDouble());
    final reuseHover = _sameHoverRequest(
      session: session,
      point: point,
      root: root,
      viewId: viewId,
    );
    final hits = reuseHover
        ? session.hoverHitCandidates
        : resolvedDomain == LiveEditTargetDomain.toolScene
        ? _toolElementHitCandidates(root, point: point, requestedViewId: viewId)
        : _nativeElementHitCandidates(
            root,
            point: point,
            requestedViewId: viewId,
          );
    final nextPreviewIndex = _resolvedHoverIndex(
      session: session,
      hits: hits,
      deeperMode: deeperMode,
    );
    final previousHover = session.hoverSelection;
    final nextHoverSelection = hits.isEmpty
        ? null
        : reuseHover &&
              previousHover != null &&
              session.hoverPreviewIndex == nextPreviewIndex
        ? previousHover
        : _buildHoverSelection(
            session: session,
            element: hits[nextPreviewIndex].element,
            targetDomain: resolvedDomain,
          );
    final hoverUnchanged =
        previousHover?.nodeId == nextHoverSelection?.nodeId &&
        session.hoverPreviewIndex == nextPreviewIndex;
    session.hoverHitCandidates = hits;
    session.hoverPreviewIndex = nextPreviewIndex;
    session.hoverSelection = nextHoverSelection;
    session.hoverPoint = point;
    session.hoverRootElement = root;
    session.hoverViewId = viewId;
    session.lastTouchedAt = DateTime.now().toUtc();
    if (!hoverUnchanged || !reuseHover) {
      _lastUpdate = _buildLastUpdate();
    }
    return <String, Object?>{
      'sessionId': session.sessionId,
      'hovered': session.hoverSelection != null,
      if (session.hoverSelection != null)
        'selection': session.hoverSelection!.toJson(),
    };
  }

  Map<String, Object?> clearHover({final String? sessionId}) {
    final session = this._requireSession(sessionId);
    final hadHover =
        session.hoverSelection != null ||
        session.hoverHitCandidates.isNotEmpty ||
        session.hoverPoint != null;
    session.hoverSelection = null;
    session.hoverHitCandidates = const <_ElementHit>[];
    session.hoverPreviewIndex = 0;
    session.hoverPoint = null;
    session.hoverRootElement = null;
    session.hoverViewId = null;
    if (hadHover) {
      _lastUpdate = _buildLastUpdate();
    }
    return <String, Object?>{'sessionId': session.sessionId, 'cleared': true};
  }

  Map<String, Object?> selectAtPoint({
    required final int x,
    required final int y,
    final String? sessionId,
    final int? viewId,
    final Element? contentRoot,
    final bool preferHoverPreview = false,
    final LiveEditSelectionPolicy selectionPolicy =
        LiveEditSelectionPolicy.deepest,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = this._requireSession(sessionId);
    final resolvedDomain = this._resolveTargetDomain(session, targetDomain);
    final root =
        (contentRoot != null && contentRoot.mounted ? contentRoot : null) ??
        WidgetsBinding.instance.rootElement;
    if (root == null) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'hit': false,
        'reason': 'widget_tree_unavailable',
      };
    }

    final point = ui.Offset(x.toDouble(), y.toDouble());
    final canReuseHover =
        session.hoverHitCandidates.isNotEmpty &&
        _sameHoverRequest(
          session: session,
          point: point,
          root: root,
          viewId: viewId,
        );
    final hits = canReuseHover
        ? session.hoverHitCandidates
        : resolvedDomain == LiveEditTargetDomain.toolScene
        ? _toolElementHitCandidates(root, point: point, requestedViewId: viewId)
        : _nativeElementHitCandidates(
            root,
            point: point,
            requestedViewId: viewId,
          );
    if (hits.isEmpty) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'hit': false,
        'point': <String, Object?>{'x': x, 'y': y},
      };
    }

    session.selectionHitCandidates = hits;
    final selectedIndex = (preferHoverPreview && canReuseHover)
        ? session.hoverPreviewIndex.clamp(0, hits.length - 1)
        : _preferredSelectionIndex(
            session: session,
            hits: hits,
            selectionPolicy: selectionPolicy,
            targetDomain: resolvedDomain,
          );
    final selection = this._setSelection(
      session: session,
      element: hits[selectedIndex].element,
      ancestry: hits[selectedIndex].ancestry,
    );
    session.multiSelections = <LiveEditSelection>[selection];
    this._syncSelectionCandidates(session);
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'targetDomain': resolvedDomain.wireName,
      'hit': true,
      'point': <String, Object?>{'x': x, 'y': y},
      'selection': selection.toJson(),
      'selectionCandidates': session.selectionCandidates
          .map((final candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }
}
