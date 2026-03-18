// ignore_for_file: invalid_use_of_protected_member, unused_element

part of '../live_edit_session_service.dart';

extension _LiveEditSessionServiceSelectionCommands
    on _LiveEditSessionServiceCore {

  Map<String, Object?> startMarquee({
    required final int x,
    required final int y,
    final String? sessionId,
  }) {
    final session = this._requireSession(sessionId);
    session.marqueeStart = ui.Offset(x.toDouble(), y.toDouble());
    session.marqueeRect = Rect.fromLTWH(x.toDouble(), y.toDouble(), 0, 0);
    session.marqueeHits = const <_ElementHit>[];
    session.marqueeSelections = const <LiveEditSelection>[];
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{'sessionId': session.sessionId, 'started': true};
  }

  Map<String, Object?> updateMarquee({
    required final int x,
    required final int y,
    final String? sessionId,
    final int? viewId,
    final Element? contentRoot,
  }) {
    final session = this._requireSession(sessionId);
    final start = session.marqueeStart;
    final root =
        (contentRoot != null && contentRoot.mounted ? contentRoot : null) ??
        WidgetsBinding.instance.rootElement;
    if (start == null || root == null) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'updated': false,
      };
    }
    final rect = Rect.fromPoints(start, ui.Offset(x.toDouble(), y.toDouble()));
    final hits = <_ElementHit>[];
    _collectElementsIntersectingRect(
      root,
      rect: rect,
      results: hits,
      requestedViewId: viewId,
    );
    final ranked = _sortMarqueeHits(session, hits);
    final previewSelections = _buildMarqueeSelections(session, ranked);
    final shouldNotify =
        session.marqueeRect != rect ||
        !_sameNodeIdSet(session.marqueeSelections, previewSelections);
    session.marqueeRect = rect;
    session.marqueeHits = ranked;
    session.marqueeSelections = previewSelections;
    if (shouldNotify) {
      _lastUpdate = _buildLastUpdate();
    }
    return <String, Object?>{
      'sessionId': session.sessionId,
      'updated': true,
      'selectedNodeIds': session.marqueeSelections
          .map((final item) => item.nodeId)
          .toList(growable: false),
    };
  }

  Map<String, Object?> commitMarquee({final String? sessionId}) {
    final session = this._requireSession(sessionId);
    final previewSelections = session.marqueeSelections;
    final hits = session.marqueeHits;
    session.marqueeRect = null;
    session.marqueeStart = null;
    session.marqueeHits = const <_ElementHit>[];
    if (previewSelections.isEmpty || hits.isEmpty) {
      _lastUpdate = _buildLastUpdate();
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': false,
      };
    }
    if (previewSelections.length == 1) {
      final selection = previewSelections.first;
      final tracked = session.trackedSelections[selection.nodeId];
      if (tracked == null) {
        final hit = hits.firstWhere(
          (final candidate) =>
              (WidgetInspectorService.instance.toId(
                    candidate.element,
                    session.objectGroup,
                  ) ??
                  '') ==
              selection.nodeId,
          orElse: () => hits.first,
        );
        final committed = this._setSelection(
          session: session,
          element: hit.element,
          ancestry: hit.ancestry,
        );
        session.multiSelections = <LiveEditSelection>[committed];
        this._syncSelectionCandidates(session);
        _lastUpdate = _buildLastUpdate();
        return <String, Object?>{
          'sessionId': session.sessionId,
          'selected': true,
          'selection': committed.toJson(),
        };
      }
      return selectTrackedNode(nodeId: selection.nodeId, sessionId: sessionId);
    }
    final lightweightSelections = _buildMarqueeSelections(session, hits);
    final selectedNodeIds = lightweightSelections
        .map((final selection) => selection.nodeId)
        .toList(growable: false);
    final selections = lightweightSelections
        .map(
          (final selection) => LiveEditSelection(
            sessionId: selection.sessionId,
            nodeId: selection.nodeId,
            widgetType: selection.widgetType,
            renderObjectType: selection.renderObjectType,
            bounds: selection.bounds,
            source: selection.source,
            propertiesForWire: selection.propertiesForWire,
            layoutContext: selection.layoutContext,
            parentChain: selection.parentChain,
            detailsTree: selection.detailsTree,
            propertiesTree: selection.propertiesTree,
            rawNode: selection.rawNode,
            selectionMode: LiveEditSelectionMode.multi,
            selectedNodeIds: selectedNodeIds,
          ),
        )
        .toList(growable: false);
    final activeHit = hits.first;
    final activeNodeId =
        WidgetInspectorService.instance.toId(
          activeHit.element,
          session.objectGroup,
        ) ??
        selections.first.nodeId;
    session.selectionHitCandidates = hits;
    session.multiSelections = selections;
    session.selectedElement = activeHit.element;
    session.ancestry = activeHit.ancestry;
    session.selection = selections.firstWhere(
      (final selection) => selection.nodeId == activeNodeId,
      orElse: () => selections.first,
    );
    final tracked = session.trackedSelections[activeNodeId];
    if (tracked != null) {
      this._hydrateTrackedSelection(
        session: session,
        tracked: tracked,
        updateInspectorSelection: true,
      );
    } else {
      final hydrated = _buildSelection(
        session: session,
        element: activeHit.element,
        ancestry: activeHit.ancestry,
        selectedNodeIds: selectedNodeIds,
        selectionMode: LiveEditSelectionMode.multi,
        updateInspectorSelection: true,
      );
      session.selection = hydrated;
      _replaceSelectionInMulti(session, hydrated);
      session.selectedElement = activeHit.element;
      session.ancestry = activeHit.ancestry;
      session.lastTouchedAt = DateTime.now().toUtc();
    }
    this._syncSelectionCandidates(session);
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'selected': true,
      'selectedNodeIds': session.multiSelections
          .map((final item) => item.nodeId)
          .toList(growable: false),
    };
  }

  Map<String, Object?> cancelMarquee({final String? sessionId}) {
    final session = this._requireSession(sessionId);
    session.marqueeRect = null;
    session.marqueeStart = null;
    session.marqueeHits = const <_ElementHit>[];
    session.marqueeSelections = const <LiveEditSelection>[];
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{'sessionId': session.sessionId, 'cancelled': true};
  }

  Map<String, Object?> selectCandidate({
    final String? sessionId,
    final int? index,
    final String? nodeId,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = this._requireSession(sessionId);
    final layer = _layerForRequest(session, requested: targetDomain);
    final hits = layer.selectionHitCandidates;
    if (hits.isEmpty) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': false,
        'reason': 'no_candidates',
      };
    }
    final resolvedIndex =
        index ??
        hits.indexWhere(
          (final candidate) =>
              (WidgetInspectorService.instance.toId(
                    candidate.element,
                    session.objectGroup,
                  ) ??
                  '') ==
              '$nodeId',
        );
    if (resolvedIndex < 0 || resolvedIndex >= hits.length) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': false,
        'reason': 'candidate_not_found',
      };
    }
    final hit = hits[resolvedIndex];
    final hitNodeId =
        WidgetInspectorService.instance.toId(
          hit.element,
          session.objectGroup,
        ) ??
        '';
    final tracked = layer.trackedSelections[hitNodeId];
    final selection = layer.multiSelections.length > 1 && tracked != null
        ? this._hydrateTrackedSelection(
            session: session,
            tracked: tracked,
            updateInspectorSelection: true,
            targetDomain: targetDomain,
          )
        : this._setSelection(
            session: session,
            element: hit.element,
            ancestry: hit.ancestry,
            targetDomain: targetDomain,
          );
    if (layer.multiSelections.length <= 1) {
      layer.multiSelections = <LiveEditSelection>[selection];
    }
    this._syncSelectionCandidates(session, requested: targetDomain);
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'selected': true,
      'selection': selection.toJson(),
      'selectionCandidates': layer.selectionCandidates
          .map((final candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }

  Map<String, Object?> selectTrackedNode({
    required final String nodeId,
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = this._requireSession(sessionId);
    final resolvedDomain = this._resolveTargetDomain(session, targetDomain);
    final layer = _layerForRequest(session, requested: targetDomain);
    if (resolvedDomain == LiveEditTargetDomain.toolScene) {
      final tracked = layer.trackedSelections[nodeId];
      if (tracked != null &&
          tracked.element.mounted &&
          tracked.element.renderObject != null) {
        final selection = this._hydrateTrackedSelection(
          session: session,
          tracked: tracked,
          updateInspectorSelection: true,
          targetDomain: targetDomain,
        );
        if (layer.multiSelections.length <= 1) {
          layer.multiSelections = <LiveEditSelection>[selection];
        }
        this._syncSelectionCandidates(session, requested: targetDomain);
        _lastUpdate = _buildLastUpdate();
        return <String, Object?>{
          'sessionId': session.sessionId,
          'selected': true,
          'selection': selection.toJson(),
        };
      }
      final surfaceSelection = LiveEditOverlayThemeModel.instance
          .selectionForSurface(surfaceId: nodeId, sessionId: session.sessionId);
      if (surfaceSelection == null) {
        return <String, Object?>{
          'sessionId': session.sessionId,
          'selected': false,
          'reason': 'tracked_node_unavailable',
        };
      }
      layer.selection = surfaceSelection;
      layer.multiSelections = <LiveEditSelection>[surfaceSelection];
      layer.selectionCandidates = <LiveEditSelectionCandidate>[
        LiveEditSelectionCandidate(
          nodeId: surfaceSelection.nodeId,
          widgetType: surfaceSelection.widgetType,
          bounds: surfaceSelection.bounds,
          source: surfaceSelection.source,
          createdByLocalProject: true,
          active: true,
        ),
      ];
      _lastUpdate = _buildLastUpdate();
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': true,
        'selection': surfaceSelection.toJson(),
      };
    }
    final tracked = layer.trackedSelections[nodeId];
    if (tracked == null ||
        !tracked.element.mounted ||
        tracked.element.renderObject == null) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': false,
        'reason': 'tracked_node_unavailable',
      };
    }
    final trackedSelection = tracked.selection;
    final selection = _isHydratedSelection(trackedSelection)
        ? this._setSelection(
            session: session,
            element: tracked.element,
            ancestry: tracked.ancestry,
            targetDomain: targetDomain,
          )
        : this._hydrateTrackedSelection(
            session: session,
            tracked: tracked,
            updateInspectorSelection: true,
            targetDomain: targetDomain,
          );
    if (layer.multiSelections.length <= 1) {
      layer.multiSelections = <LiveEditSelection>[selection];
    }
    this._syncSelectionCandidates(session, requested: targetDomain);
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'selected': true,
      'selection': selection.toJson(),
    };
  }

  Map<String, Object?> selectParent({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = this._requireSession(sessionId);
    final layer = _layerForRequest(session, requested: targetDomain);
    final activeIndex = layer.selectionCandidates.indexWhere(
      (final candidate) => candidate.active,
    );
    if (activeIndex < 0 ||
        activeIndex + 1 >= layer.selectionHitCandidates.length) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': false,
        'reason': 'parent_unavailable',
      };
    }
    return selectCandidate(
      sessionId: session.sessionId,
      index: activeIndex + 1,
      targetDomain: targetDomain,
    );
  }

  Map<String, Object?> selectChild({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = this._requireSession(sessionId);
    final layer = _layerForRequest(session, requested: targetDomain);
    final activeIndex = layer.selectionCandidates.indexWhere(
      (final candidate) => candidate.active,
    );
    if (activeIndex <= 0) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': false,
        'reason': 'child_unavailable',
      };
    }
    return selectCandidate(
      sessionId: session.sessionId,
      index: activeIndex - 1,
      targetDomain: targetDomain,
    );
  }

  Map<String, Object?> setOverlay({
    required final bool enabled,
    final String? sessionId,
  }) {
    final session = this._requireSession(sessionId);
    session.overlayEnabled = enabled;
    session.lastTouchedAt = DateTime.now().toUtc();
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'overlayEnabled': session.overlayEnabled,
      'selectionMode': session.overlayEnabled,
    };
  }

  Map<String, Object?> startSession({
    final String? requestedSessionId,
    final LiveEditTargetDomain targetDomain = LiveEditTargetDomain.appScene,
  }) {
    final sessionId = requestedSessionId?.trim().isNotEmpty == true
        ? requestedSessionId!.trim()
        : 'live_edit_${DateTime.now().millisecondsSinceEpoch}';

    _activeSessionId = sessionId;
    final session = _sessions.putIfAbsent(
      sessionId,
      () => _LiveEditSessionState(
        sessionId: sessionId,
        objectGroup: 'live_edit_group_$sessionId',
      ),
    );
    session.targetDomain = targetDomain;
    session.lastTouchedAt = DateTime.now().toUtc();
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': sessionId,
      'active': true,
      'targetDomain': targetDomain.wireName,
      'overlayEnabled': session.overlayEnabled,
      'selectionCandidates': session.selectionCandidates
          .map((final candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }

  Map<String, Object?> setTargetDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final session = this._requireSession(sessionId);
    session.targetDomain = targetDomain;
    if (targetDomain == LiveEditTargetDomain.toolScene) {
      session.selectedElement = null;
      session.hoverSelection = null;
      session.hoverHitCandidates = const <_ElementHit>[];
    }
    session.lastTouchedAt = DateTime.now().toUtc();
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'targetDomain': targetDomain.wireName,
    };
  }

  List<_ElementHit> _rankSelectionHits(final List<_ElementHit> hits) =>
      List<_ElementHit>.from(hits);

  _MarqueeCandidateCacheEntry? _resolveMarqueeCandidate(
    final _LiveEditSessionState session,
    final _ElementHit hit,
  ) {
    if (!hit.element.mounted) {
      session.marqueeCache.remove(hit.element);
      return null;
    }
    final renderObject = hit.renderObject;
    if (!renderObject.attached) {
      session.marqueeCache.remove(hit.element);
      return null;
    }
    final bounds = _boundsForRenderObject(renderObject);
    if (bounds == null) {
      session.marqueeCache.remove(hit.element);
      return null;
    }
    final cached = session.marqueeCache[hit.element];
    final nodeId =
        cached?.nodeId ??
        WidgetInspectorService.instance.toId(
          hit.element,
          session.objectGroup,
        ) ??
        'live_edit_marquee_${session.sessionId}_${hit.element.hashCode}';
    final widgetType = hit.element.widget.runtimeType.toString();
    final entry = _MarqueeCandidateCacheEntry(
      element: hit.element,
      renderObject: renderObject,
      parentElement: hit.parentElement,
      ancestry: hit.ancestry,
      nodeId: nodeId,
      widgetType: widgetType,
      depth: hit.depth,
      isStructural: _structuralWidgetTypes.contains(widgetType),
      isUserAuthored:
          cached?.isUserAuthored ??
          _isUserAuthoredElement(session, hit.element, nodeId),
      bounds: bounds,
    );
    session.marqueeCache[hit.element] = entry;
    return entry;
  }

  int _compareMarqueeEntries(
    final _MarqueeCandidateCacheEntry left,
    final _MarqueeCandidateCacheEntry right,
  ) {
    final leftBounds = left.bounds;
    final rightBounds = right.bounds;
    if (leftBounds != null && rightBounds != null) {
      if (leftBounds.top != rightBounds.top) {
        return leftBounds.top.compareTo(rightBounds.top);
      }
      if (leftBounds.left != rightBounds.left) {
        return leftBounds.left.compareTo(rightBounds.left);
      }
      final leftArea = leftBounds.width * leftBounds.height;
      final rightArea = rightBounds.width * rightBounds.height;
      if (leftArea != rightArea) {
        return leftArea.compareTo(rightArea);
      }
    }
    if (left.depth != right.depth) {
      return right.depth.compareTo(left.depth);
    }
    return left.widgetType.compareTo(right.widgetType);
  }

  List<LiveEditSelection> _buildMarqueeSelections(
    final _LiveEditSessionState session,
    final List<_ElementHit> hits,
  ) => hits
      .map((final hit) => _resolveMarqueeCandidate(session, hit))
      .whereType<_MarqueeCandidateCacheEntry>()
      .map(
        (final entry) =>
            _buildLightweightSelectionFromCache(session: session, entry: entry),
      )
      .fold(<String, LiveEditSelection>{}, (final map, final selection) {
        map.putIfAbsent(selection.nodeId, () => selection);
        return map;
      })
      .values
      .toList(growable: false);

  List<_ElementHit> _sortMarqueeHits(
    final _LiveEditSessionState session,
    final List<_ElementHit> hits,
  ) {
    session.marqueeCache.removeWhere(
      (final element, final _) => !element.mounted,
    );
    final candidatesByNodeId = <String, _MarqueeCandidateCacheEntry>{};
    final candidatesByElement = <Element, _MarqueeCandidateCacheEntry>{};
    for (final hit in hits) {
      final entry = _resolveMarqueeCandidate(session, hit);
      if (entry == null || !entry.isUserAuthored) {
        continue;
      }
      candidatesByNodeId.putIfAbsent(entry.nodeId, () => entry);
      candidatesByElement.putIfAbsent(entry.element, () => entry);
    }
    if (candidatesByNodeId.isEmpty) {
      return const <_ElementHit>[];
    }

    final covered = candidatesByNodeId.values.toList(growable: false);
    final depthRanked = List<_MarqueeCandidateCacheEntry>.from(covered)
      ..sort((final left, final right) {
        if (left.depth != right.depth) {
          return right.depth.compareTo(left.depth);
        }
        return _compareMarqueeEntries(left, right);
      });
    final blockedStructuralAncestors = <Element>{};
    final kept = <_MarqueeCandidateCacheEntry>[];
    for (final candidate in depthRanked) {
      if (!candidate.isVisualCandidate ||
          blockedStructuralAncestors.contains(candidate.element)) {
        continue;
      }
      kept.add(candidate);
      var ancestor = candidate.parentElement;
      while (ancestor != null) {
        final coveredAncestor = candidatesByElement[ancestor];
        if (coveredAncestor != null) {
          if (coveredAncestor.isStructural) {
            blockedStructuralAncestors.add(ancestor);
          }
          ancestor = coveredAncestor.parentElement;
          continue;
        }
        Element? nextAncestor;
        ancestor.visitAncestorElements((final parent) {
          if (candidatesByElement.containsKey(parent)) {
            nextAncestor = parent;
            return false;
          }
          return true;
        });
        ancestor = nextAncestor;
      }
    }
    kept.sort(_compareMarqueeEntries);
    return kept
        .map(
          (final candidate) => _ElementHit(
            element: candidate.element,
            renderObject: candidate.renderObject,
            ancestry: candidate.ancestry,
            depth: candidate.depth,
            parentElement: candidate.parentElement,
          ),
        )
        .toList(growable: false);
  }

}
