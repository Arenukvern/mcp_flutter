// ignore_for_file: invalid_use_of_protected_member, unused_element

part of '../live_edit_session_service.dart';

extension _LiveEditSessionServicePreview on _LiveEditSessionServiceCore {
  Map<String, Object?> updateDraft({
    required final LiveEditDraftChange change,
    final String? sessionId,
  }) {
    final session = _requireSession(sessionId);
    final targetDomain = change.meta['targetDomain'] == null
        ? session.targetDomain
        : LiveEditTargetDomain.fromWire(change.meta['targetDomain']);
    final layer = _layerForRequest(session, requested: targetDomain);
    if (targetDomain == LiveEditTargetDomain.toolScene) {
      final selectionNodeId =
          '${change.meta['selectionNodeId'] ?? change.nodeId}'.trim();
      final surfaceId = '${change.meta['surfaceId'] ?? change.nodeId}'.trim();
      final appliedChange = surfaceId == change.nodeId
          ? change
          : LiveEditDraftChange(
              nodeId: surfaceId,
              propertyId: change.propertyId,
              targetValue: change.targetValue,
              previewMode: change.previewMode,
              confidence: change.confidence,
              intentText: change.intentText,
              meta: change.meta,
            );
      final updated = LiveEditOverlayThemeModel.instance.applyDraft(
        appliedChange,
      );
      if (!updated) {
        return <String, Object?>{
          'sessionId': session.sessionId,
          'updated': false,
          'reason': 'selection_mismatch',
        };
      }
      final tracked = layer.trackedSelections[selectionNodeId];
      final selection =
          tracked != null &&
              tracked.element.mounted &&
              tracked.element.renderObject != null
          ? _hydrateTrackedSelection(
              session: session,
              tracked: tracked,
              updateInspectorSelection: false,
              targetDomain: targetDomain,
            )
          : LiveEditOverlayThemeModel.instance.selectionForSurface(
              surfaceId: surfaceId,
              sessionId: session.sessionId,
            );
      layer.selection = selection;
      layer.multiSelections = selection == null
          ? const <LiveEditSelection>[]
          : <LiveEditSelection>[selection];
      session.lastTouchedAt = DateTime.now().toUtc();
      _lastUpdate = _buildLastUpdate();
      return <String, Object?>{
        'sessionId': session.sessionId,
        'targetDomain': targetDomain.wireName,
        'updated': true,
        'selection': selection?.toJson(),
        'draftChanges': const <Object?>[],
        'appliedPreviewMode': LiveEditPreviewMode.exact.wireName,
      };
    }
    final trackedSelection = session.selection?.nodeId == change.nodeId
        ? session.selection
        : session.trackedSelections[change.nodeId]?.selection;
    if (trackedSelection == null) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'updated': false,
        'reason': 'selection_mismatch',
      };
    }

    final appliedExact = _applyExactPreviewIfSupported(
      session,
      change,
      elementOverride: session.trackedSelections[change.nodeId]?.element,
      selectionOverride: trackedSelection,
    );
    if (_isMeaningfulChange(session, change, trackedSelection)) {
      session.meaningfulNodeIds.add(change.nodeId);
    }
    session.lastTouchedAt = DateTime.now().toUtc();
    _lastUpdate = _buildLastUpdate();
    if (appliedExact) {
      WidgetsBinding.instance.addPostFrameCallback((final _) {
        final currentSession = _sessions[session.sessionId];
        final trackedElement = currentSession?.trackedSelections[change.nodeId];
        if (currentSession == null || trackedElement == null) {
          return;
        }
        _applyExactPreviewIfSupported(
          currentSession,
          change,
          elementOverride: trackedElement.element,
          selectionOverride: trackedElement.selection,
        );
      });
    }
    return <String, Object?>{
      'sessionId': session.sessionId,
      'targetDomain': targetDomain.wireName,
      'updated': true,
      'selection': trackedSelection.toJson(),
      'draftChanges': const <Object?>[],
      'appliedPreviewMode': appliedExact
          ? LiveEditPreviewMode.exact.wireName
          : LiveEditPreviewMode.ghost.wireName,
    };
  }

  Map<String, Object?> updateDraftBatch({
    required final List<String> nodeIds,
    required final String propertyId,
    required final Object? targetValue,
    required final LiveEditPreviewMode previewMode,
    required final String intentText,
    required final Map<String, Object?> meta,
    final String? sessionId,
  }) {
    final session = _requireSession(sessionId);
    final updated = <Map<String, Object?>>[];
    for (final nodeId in nodeIds) {
      final result = updateDraft(
        sessionId: session.sessionId,
        change: LiveEditDraftChange(
          nodeId: nodeId,
          propertyId: propertyId,
          targetValue: targetValue,
          previewMode: previewMode,
          confidence: 0.9,
          intentText: intentText,
          meta: meta,
        ),
      );
      if (result['updated'] == true) {
        updated.add(result);
      }
    }
    return <String, Object?>{
      'sessionId': session.sessionId,
      'updated': updated.isNotEmpty,
      'count': updated.length,
    };
  }

  _LiveEditSessionState? _activeSessionOrNull() {
    final activeSessionId = _activeSessionId;
    if (activeSessionId == null) {
      return null;
    }
    return _sessions[activeSessionId];
  }

  bool _applyExactPreviewIfSupported(
    final _LiveEditSessionState session,
    final LiveEditDraftChange change, {
    final _LiveEditLayerState? layerOverride,
    final Element? elementOverride,
    final LiveEditSelection? selectionOverride,
  }) {
    final layer = layerOverride ?? session.currentLayer;
    final selection = selectionOverride ?? layer.selection;
    final element = elementOverride ?? layer.selectedElement;
    if (selection == null || element == null || !element.mounted) {
      return false;
    }

    void captureOriginal(final String propertyId, final Object? currentValue) {
      layer.originalExactValues.putIfAbsent(
        '${selection.nodeId}::$propertyId',
        () => currentValue,
      );
    }

    final renderObject = _previewRenderObjectForElement(element);
    switch (change.propertyId) {
      case 'text':
        if (renderObject is RenderParagraph) {
          captureOriginal(change.propertyId, renderObject.text);
          renderObject.text = TextSpan(
            style: renderObject.text.style,
            text: '${change.targetValue ?? ''}',
          );
          renderObject.markNeedsLayout();
          renderObject.markNeedsPaint();
          return true;
        }
      case 'flexFactor':
        final parentData = renderObject?.parentData;
        if (parentData is FlexParentData) {
          captureOriginal(change.propertyId, parentData.flex);
          parentData.flex = jsonDecodeNullableInt(change.targetValue);
          renderObject?.markNeedsLayout();
          return true;
        }
      case 'flexFit':
        final parentData = renderObject?.parentData;
        if (parentData is FlexParentData) {
          captureOriginal(change.propertyId, parentData.fit?.name ?? 'tight');
          parentData.fit = '$change.targetValue'.trim() == 'loose'
              ? FlexFit.loose
              : FlexFit.tight;
          renderObject?.markNeedsLayout();
          return true;
        }
      case 'mainAxisAlignment':
        if (renderObject is RenderFlex) {
          captureOriginal(
            change.propertyId,
            renderObject.mainAxisAlignment.name,
          );
          renderObject.mainAxisAlignment = MainAxisAlignment.values.firstWhere(
            (final candidate) => candidate.name == '$change.targetValue',
            orElse: () => renderObject.mainAxisAlignment,
          );
          renderObject.markNeedsLayout();
          renderObject.markNeedsPaint();
          return true;
        }
      case 'crossAxisAlignment':
        if (renderObject is RenderFlex) {
          captureOriginal(
            change.propertyId,
            renderObject.crossAxisAlignment.name,
          );
          renderObject.crossAxisAlignment = CrossAxisAlignment.values
              .firstWhere(
                (final candidate) => candidate.name == '$change.targetValue',
                orElse: () => renderObject.crossAxisAlignment,
              );
          renderObject.markNeedsLayout();
          renderObject.markNeedsPaint();
          return true;
        }
    }
    return false;
  }

  _LiveEditSessionState _requireSession(final String? sessionId) {
    final resolvedId = sessionId?.trim().isNotEmpty == true
        ? sessionId!.trim()
        : _activeSessionId;
    if (resolvedId == null) {
      final started = startSession();
      return _sessions[started['sessionId']! as String]!;
    }
    return _sessions.putIfAbsent(
      resolvedId,
      () => _LiveEditSessionState(
        sessionId: resolvedId,
        objectGroup: 'live_edit_group_$resolvedId',
      ),
    );
  }

  LiveEditTargetDomain _resolveTargetDomain(
    final _LiveEditSessionState session,
    final LiveEditTargetDomain? requested,
  ) {
    if (requested != null) {
      session.targetDomain = requested;
    }
    return session.targetDomain;
  }

  List<LiveEditSelection> _normalizeSelectionsForSet(
    final Iterable<LiveEditSelection> selections,
    final _SelectionSetState selectionSet,
  ) {
    final keyedSelections = <String, LiveEditSelection>{
      for (final selection in selections)
        (selection.selectionKey.isNotEmpty
                ? selection.selectionKey
                : selection.nodeId): selection,
    };
    final normalized = <LiveEditSelection>[];
    final selectionMode = selectionSet.isSingle
        ? LiveEditSelectionMode.single
        : LiveEditSelectionMode.multi;
    for (final key in selectionSet.memberKeys) {
      final selection = keyedSelections[key];
      if (selection == null) {
        continue;
      }
      normalized.add(
        selection.copyWith(
          selectionMode: selectionMode,
          selectedNodeIds: selectionSet.memberKeys,
        ),
      );
    }
    return normalized;
  }

  void _applySelectionSetState(
    final _LiveEditLayerState layer,
    final _SelectionSetState selectionSet, {
    required final Iterable<LiveEditSelection> selections,
    final LiveEditSelection? activeSelection,
  }) {
    layer.selectionSet = selectionSet.normalized();
    layer.multiSelections = _normalizeSelectionsForSet(
      selections,
      layer.selectionSet,
    );
    layer.selection = activeSelection == null
        ? null
        : activeSelection.copyWith(
            selectionMode: layer.selectionSet.isSingle
                ? LiveEditSelectionMode.single
                : LiveEditSelectionMode.multi,
            selectedNodeIds: layer.selectionSet.memberKeys,
          );
    _assertSelectionSetInvariants(layer);
  }

  LiveEditSelection _setSingleSelection({
    required final _LiveEditSessionState session,
    required final Element element,
    required final List<Map<String, Object?>> ancestry,
    required final _SelectionSetOrigin origin,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final layer = _layerForRequest(session, requested: targetDomain);
    if (layer.selectedElement != null && layer.selectedElement != element) {
      _revertExactPreview(session, layer: layer);
    }
    final selectionKey = _selectionKeyForElement(session, element);
    final selectionSet = _selectionSetForKeys(
      memberKeys: <String>[selectionKey],
      primaryKey: selectionKey,
      origin: origin,
    );
    final selection = _buildSelection(
      session: session,
      element: element,
      ancestry: ancestry,
      selectedNodeIds: selectionSet.memberKeys,
      selectionMode: LiveEditSelectionMode.single,
      updateInspectorSelection: true,
      targetDomain: targetDomain,
    );
    layer.selectedElement = element;
    layer.ancestry = ancestry;
    _applySelectionSetState(
      layer,
      selectionSet,
      selections: <LiveEditSelection>[selection],
      activeSelection: selection,
    );
    session.lastTouchedAt = DateTime.now().toUtc();
    return layer.selection!;
  }

  void _setSelectionSet({
    required final _LiveEditSessionState session,
    required final Iterable<LiveEditSelection> selections,
    required final String primaryKey,
    required final _SelectionSetOrigin origin,
    final LiveEditTargetDomain? targetDomain,
    final LiveEditSelection? activeSelection,
  }) {
    final layer = _layerForRequest(session, requested: targetDomain);
    final selectionSet = _selectionSetForKeys(
      memberKeys: selections.map(
        (final selection) => selection.selectionKey.isNotEmpty
            ? selection.selectionKey
            : selection.nodeId,
      ),
      primaryKey: primaryKey,
      origin: origin,
      focusKind: _SelectionFocusKind.multi,
    );
    _applySelectionSetState(
      layer,
      selectionSet,
      selections: selections,
      activeSelection: activeSelection,
    );
  }

  LiveEditSelection _activateMemberWithinSelectionSet({
    required final _LiveEditSessionState session,
    required final LiveEditSelection selection,
    required final Element element,
    required final List<Map<String, Object?>> ancestry,
    required final _SelectionSetOrigin origin,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final layer = _layerForRequest(session, requested: targetDomain);
    final nextSelectionSet = layer.selectionSet.normalized(
      primaryKey: selection.selectionKey.isNotEmpty
          ? selection.selectionKey
          : selection.nodeId,
      origin: origin,
    );
    layer.selectedElement = element;
    layer.ancestry = ancestry;
    _applySelectionSetState(
      layer,
      nextSelectionSet,
      selections: <LiveEditSelection>[...layer.multiSelections, selection],
      activeSelection: selection,
    );
    session.lastTouchedAt = DateTime.now().toUtc();
    return layer.selection!;
  }

  void _revertExactPreview(
    final _LiveEditSessionState session, {
    required final _LiveEditLayerState layer,
    final Set<String>? nodeIds,
  }) {
    for (final entry in layer.originalExactValues.entries) {
      final parts = entry.key.split('::');
      if (parts.length != 2) {
        continue;
      }
      if (nodeIds != null && !nodeIds.contains(parts.first)) {
        continue;
      }
      final tracked = layer.trackedSelections[parts.first];
      final element = tracked?.element;
      if (element == null || !element.mounted) {
        continue;
      }
      final renderObject = element.renderObject;
      if (renderObject == null) {
        continue;
      }
      switch (entry.key) {
        case final key when key.endsWith('::text'):
          if (renderObject is RenderParagraph && entry.value is InlineSpan) {
            renderObject.text = entry.value! as InlineSpan;
            renderObject.markNeedsLayout();
            renderObject.markNeedsPaint();
          }
        case final key when key.endsWith('::flexFactor'):
          final parentData = renderObject.parentData;
          if (parentData is FlexParentData) {
            parentData.flex = jsonDecodeNullableInt(entry.value);
            renderObject.markNeedsLayout();
          }
        case final key when key.endsWith('::flexFit'):
          final parentData = renderObject.parentData;
          if (parentData is FlexParentData) {
            parentData.fit = '${entry.value ?? 'tight'}' == 'loose'
                ? FlexFit.loose
                : FlexFit.tight;
            renderObject.markNeedsLayout();
          }
        case final key when key.endsWith('::mainAxisAlignment'):
          if (renderObject is RenderFlex) {
            renderObject.mainAxisAlignment = MainAxisAlignment.values
                .firstWhere(
                  (final candidate) => candidate.name == '${entry.value}',
                  orElse: () => renderObject.mainAxisAlignment,
                );
            renderObject.markNeedsLayout();
            renderObject.markNeedsPaint();
          }
        case final key when key.endsWith('::crossAxisAlignment'):
          if (renderObject is RenderFlex) {
            renderObject.crossAxisAlignment = CrossAxisAlignment.values
                .firstWhere(
                  (final candidate) => candidate.name == '${entry.value}',
                  orElse: () => renderObject.crossAxisAlignment,
                );
            renderObject.markNeedsLayout();
            renderObject.markNeedsPaint();
          }
      }
    }
    if (nodeIds == null) {
      layer.originalExactValues.clear();
    } else {
      layer.originalExactValues.removeWhere((final key, final _) {
        final separator = key.indexOf('::');
        final nodeId = separator < 0 ? key : key.substring(0, separator);
        return nodeIds.contains(nodeId);
      });
    }
  }

  bool _isMeaningfulChange(
    final _LiveEditSessionState session,
    final LiveEditDraftChange change,
    final LiveEditSelection selection,
  ) => false;

  int _resolvedHoverIndex({
    required final _LiveEditSessionState session,
    required final List<_ElementHit> hits,
    required final bool deeperMode,
  }) {
    if (hits.isEmpty || !deeperMode) {
      return 0;
    }
    final activeNodeId = session.selection?.nodeId;
    if (activeNodeId != null) {
      final activeIndex = hits.indexWhere((final hit) {
        final nodeId = WidgetInspectorService.instance.toId(
          hit.element,
          session.objectGroup,
        );
        return nodeId == activeNodeId;
      });
      if (activeIndex >= 0 && activeIndex + 1 < hits.length) {
        return activeIndex + 1;
      }
    }
    return hits.length > 1 ? 1 : 0;
  }

  LiveEditSelection _buildSelection({
    required final _LiveEditSessionState session,
    required final Element element,
    required final List<Map<String, Object?>> ancestry,
    required final List<String> selectedNodeIds,
    required final LiveEditSelectionMode selectionMode,
    final bool updateInspectorSelection = false,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final nodeId = _selectionKeyForElement(session, element);
    final resolvedDomain = _resolveTargetDomain(session, targetDomain);
    if (updateInspectorSelection) {
      WidgetInspectorService.instance.setSelection(
        element,
        session.objectGroup,
      );
    }
    final detailsTree = _decodeObject(
      WidgetInspectorService.instance.getDetailsSubtree(
        nodeId,
        session.objectGroup,
      ),
    );
    final propertiesList = _decodeList(
      WidgetInspectorService.instance.getProperties(
        nodeId,
        session.objectGroup,
      ),
    );
    final parentChain = _decodeList(
      WidgetInspectorService.instance.getParentChain(
        nodeId,
        session.objectGroup,
      ),
    );
    final renderObject = _previewRenderObjectForElement(element);
    final layer = _layerForRequest(session, requested: targetDomain);
    final surfaceId = resolvedDomain == LiveEditTargetDomain.toolScene
        ? _toolSurfaceIdForElement(element)
        : null;
    final source = _selectionSourceForElement(
      session,
      element,
      detailsTree,
      targetDomain: resolvedDomain,
    );
    final selection = LiveEditSelection(
      sessionId: session.sessionId,
      selectionKey: nodeId,
      nodeId: nodeId,
      widgetType: element.widget.runtimeType.toString(),
      targetDomain: resolvedDomain,
      renderObjectType: renderObject?.runtimeType.toString(),
      bounds: _boundsForRenderObject(renderObject),
      source: source,
      layoutContext: _layoutContextForElement(element),
      parentChain: parentChain
          .whereType<Map>()
          .map(Map<String, Object?>.from)
          .toList(growable: false),
      detailsTree: detailsTree,
      propertiesTree: <String, Object?>{'items': propertiesList},
      rawNode:
          resolvedDomain == LiveEditTargetDomain.toolScene &&
              _hasText(surfaceId)
          ? _toolSelectionRawNode(
              element: element,
              detailsTree: detailsTree,
              surfaceId: surfaceId!,
            )
          : detailsTree,
      selectionMode: selectionMode,
      selectedNodeIds: selectedNodeIds,
    );
    layer.trackedSelections[nodeId] = _TrackedSelectionTarget(
      element: element,
      ancestry: ancestry,
      selection: selection,
    );
    return selection;
  }

  LiveEditSelection _setSelection({
    required final _LiveEditSessionState session,
    required final Element element,
    required final List<Map<String, Object?>> ancestry,
    final _SelectionSetOrigin origin = _SelectionSetOrigin.hitTest,
    final LiveEditTargetDomain? targetDomain,
  }) => _setSingleSelection(
    session: session,
    element: element,
    ancestry: ancestry,
    origin: origin,
    targetDomain: targetDomain,
  );

  void _replaceSelectionInMulti(
    final _LiveEditSessionState session,
    final LiveEditSelection selection, {
    final LiveEditTargetDomain? targetDomain,
  }) {
    final layer = _layerForRequest(session, requested: targetDomain);
    final existingSelections = <LiveEditSelection>[
      ...layer.multiSelections.where(
        (final candidate) => candidate.nodeId != selection.nodeId,
      ),
      selection,
    ];
    _applySelectionSetState(
      layer,
      layer.selectionSet,
      selections: existingSelections,
      activeSelection: layer.selection?.nodeId == selection.nodeId
          ? selection
          : layer.selection,
    );
  }

  LiveEditSelection _hydrateTrackedSelection({
    required final _LiveEditSessionState session,
    required final _TrackedSelectionTarget tracked,
    required final bool updateInspectorSelection,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final layer = _layerForRequest(session, requested: targetDomain);
    final selectedNodeIds = layer.selectionSet.memberKeys.isEmpty
        ? layer.multiSelections
              .map((final selection) => selection.nodeId)
              .toList(growable: false)
        : layer.selectionSet.memberKeys;
    final hydrated = _buildSelection(
      session: session,
      element: tracked.element,
      ancestry: tracked.ancestry,
      selectedNodeIds: selectedNodeIds,
      selectionMode: selectedNodeIds.length > 1
          ? LiveEditSelectionMode.multi
          : LiveEditSelectionMode.single,
      updateInspectorSelection: updateInspectorSelection,
      targetDomain: targetDomain,
    );
    return _activateMemberWithinSelectionSet(
      session: session,
      selection: hydrated,
      element: tracked.element,
      ancestry: tracked.ancestry,
      origin: _SelectionSetOrigin.hydrate,
      targetDomain: targetDomain,
    );
  }

  void _syncSelectionCandidates(
    final _LiveEditSessionState session, {
    final LiveEditTargetDomain? requested,
  }) {
    final layer = _layerForRequest(session, requested: requested);
    final targetDomain = _resolveTargetDomain(session, requested);
    final activeSelectionKey = layer.selectionSet.primaryKey;
    final dedupedHits = _dedupeHitsBySelectionKey(
      session,
      layer.selectionHitCandidates,
    );
    layer.selectionHitCandidates = dedupedHits;
    layer.selectionCandidates = dedupedHits.indexed
        .take(12)
        .map((final entry) {
          final index = entry.$1;
          final hit = entry.$2;
          final renderObject = _previewRenderObjectForElement(hit.element);
          final nodeId = _selectionKeyForElement(session, hit.element);
          final detailsTree = _decodeObject(
            WidgetInspectorService.instance.getDetailsSubtree(
              nodeId,
              session.objectGroup,
            ),
          );
          final metadata = _selectionMetadataForElement(
            session,
            hit.element,
            cachedNodeId: nodeId,
            cachedDetailsTree: detailsTree,
          );
          final source = _selectionSourceForElement(
            session,
            hit.element,
            detailsTree,
            targetDomain: targetDomain,
          );
          return LiveEditSelectionCandidate(
            selectionKey: nodeId,
            nodeId: nodeId,
            widgetType: hit.element.widget.runtimeType.toString(),
            bounds: _boundsForRenderObject(renderObject),
            depth: index,
            source: source,
            createdByLocalProject:
                targetDomain == LiveEditTargetDomain.toolScene ||
                metadata.createdByLocalProject,
            active: nodeId == activeSelectionKey,
          );
        })
        .toList(growable: false);
    _assertSelectionSetInvariants(layer);
  }
}
