// ignore_for_file: invalid_use_of_protected_member, unused_element

part of '../live_edit_session_service.dart';

class _LiveEditSessionServiceCore {
  _LiveEditSessionServiceCore();

  final Map<String, _LiveEditSessionState> _sessions =
      <String, _LiveEditSessionState>{};
  String? _activeSessionId;
  LiveEditSessionUpdate? _lastUpdate;

  LiveEditSessionUpdate? get lastUpdate => _lastUpdate;

  LiveEditSessionUpdate? _buildLastUpdate({
    final bool includeFlowGraph = true,
  }) {
    final session = _activeSessionOrNull();
    final sessionData = LiveEditSessionResourceData(
      activeSessionId: _activeSessionId,
      overlayVisible: session?.overlayEnabled ?? false,
      targetDomain: session?.targetDomain ?? LiveEditTargetDomain.appScene,
      sessionIds: _sessions.keys.toList(growable: false),
    );
    return LiveEditSessionUpdate(
      sessionData: sessionData,
      selectionStore: _buildSelectionStore(),
      draftStore: _buildDraftStore(),
      flowGraph: includeFlowGraph ? _buildFlowGraphUpdate(session) : null,
    );
  }

  FlowGraphSnapshot? _buildFlowGraphUpdate(
    final _LiveEditSessionState? session,
  ) {
    final snapshot = _buildFlowGraphSnapshot(session);
    final previous = _lastUpdate?.flowGraph;
    if (previous == null && _isEmptyFlowGraphSnapshot(snapshot)) {
      return null;
    }
    if (_flowGraphSnapshotsMatch(previous, snapshot)) {
      return null;
    }
    return snapshot;
  }

  FlowGraphSnapshot _buildFlowGraphSnapshot(
    final _LiveEditSessionState? session,
  ) {
    if (session == null) {
      return FlowGraphSnapshot.empty;
    }
    final screenSummaries = <String, Map<String, InteractionNodeSummary>>{};
    final screenRouteIds = <String, String>{};
    final screenSurfaceIds = <String, String>{};

    void collectSelectionSummary(final InteractionNodeSummary summary) {
      final screenId = summary.screenId?.trim();
      if (screenId == null || screenId.isEmpty) {
        return;
      }
      final entries = screenSummaries.putIfAbsent(
        screenId,
        () => <String, InteractionNodeSummary>{},
      );
      final selectionKey = summary.selectionKey.trim();
      final summaryKey = selectionKey.isNotEmpty
          ? selectionKey
          : summary.nodeId;
      if (summaryKey.isEmpty || entries.containsKey(summaryKey)) {
        return;
      }
      entries[summaryKey] = summary;
      final routeId = summary.routeId?.trim();
      if (routeId != null && routeId.isNotEmpty) {
        screenRouteIds.putIfAbsent(screenId, () => routeId);
      }
      final surfaceId = summary.surfaceId?.trim();
      if (surfaceId != null && surfaceId.isNotEmpty) {
        screenSurfaceIds.putIfAbsent(screenId, () => surfaceId);
      }
    }

    void collectLayer(final _LiveEditLayerState layer) {
      if (layer.selection != null) {
        collectSelectionSummary(_buildSelectionSummary(layer.selection!));
      }
      if (layer.hoverSelection != null) {
        collectSelectionSummary(_buildSelectionSummary(layer.hoverSelection!));
      }
      for (final selection in layer.multiSelections) {
        collectSelectionSummary(_buildSelectionSummary(selection));
      }
      for (final selection in layer.marqueeSelections) {
        collectSelectionSummary(_buildSelectionSummary(selection));
      }
    }

    collectLayer(session.appLayer);
    collectLayer(session.toolLayer);

    if (screenSummaries.isEmpty) {
      return FlowGraphSnapshot.empty;
    }

    final screenIds = screenSummaries.keys.toList(growable: false)..sort();
    final screens = screenIds
        .map(
          (final screenId) => ScreenSnapshot(
            screenId: screenId,
            routeId: screenRouteIds[screenId] ?? screenId,
            title: screenId,
            surfaceId: screenSurfaceIds[screenId],
            nodeSummaries: List<InteractionNodeSummary>.unmodifiable(
              (screenSummaries[screenId]!.values.toList(growable: false)..sort(
                (final a, final b) => a.selectionKey.compareTo(b.selectionKey),
              )),
            ),
          ),
        )
        .toList(growable: false);
    final routes =
        screenRouteIds.entries
            .map(
              (final entry) => RouteSnapshot(
                routeId: entry.value,
                name: entry.value,
                screenId: entry.key,
              ),
            )
            .toList(growable: false)
          ..sort((final a, final b) => a.routeId.compareTo(b.routeId));

    return FlowGraphSnapshot(
      screens: screens,
      routes: routes,
      focusedScreenId: _focusedFlowScreenId(session, screenIds),
    );
  }

  bool _isEmptyFlowGraphSnapshot(final FlowGraphSnapshot snapshot) =>
      snapshot.screens.isEmpty &&
      snapshot.routes.isEmpty &&
      snapshot.transitions.isEmpty &&
      !_hasText(snapshot.focusedScreenId);

  bool _flowGraphSnapshotsMatch(
    final FlowGraphSnapshot? previous,
    final FlowGraphSnapshot current,
  ) {
    if (previous == null) {
      return false;
    }
    if (previous.focusedScreenId != current.focusedScreenId ||
        previous.screens.length != current.screens.length ||
        previous.routes.length != current.routes.length ||
        previous.transitions.length != current.transitions.length) {
      return false;
    }
    for (var index = 0; index < previous.screens.length; index += 1) {
      if (!_screensMatch(previous.screens[index], current.screens[index])) {
        return false;
      }
    }
    for (var index = 0; index < previous.routes.length; index += 1) {
      if (!_routesMatch(previous.routes[index], current.routes[index])) {
        return false;
      }
    }
    for (var index = 0; index < previous.transitions.length; index += 1) {
      if (!_transitionsMatch(
        previous.transitions[index],
        current.transitions[index],
      )) {
        return false;
      }
    }
    return true;
  }

  bool _screensMatch(final ScreenSnapshot lhs, final ScreenSnapshot rhs) {
    if (lhs.screenId != rhs.screenId ||
        lhs.routeId != rhs.routeId ||
        lhs.title != rhs.title ||
        lhs.surfaceId != rhs.surfaceId ||
        lhs.nodeSummaries.length != rhs.nodeSummaries.length) {
      return false;
    }
    for (var index = 0; index < lhs.nodeSummaries.length; index += 1) {
      if (!_nodeSummariesMatch(
        lhs.nodeSummaries[index],
        rhs.nodeSummaries[index],
      )) {
        return false;
      }
    }
    return true;
  }

  bool _nodeSummariesMatch(
    final InteractionNodeSummary lhs,
    final InteractionNodeSummary rhs,
  ) {
    return lhs.selectionKey == rhs.selectionKey &&
        lhs.nodeId == rhs.nodeId &&
        lhs.widgetType == rhs.widgetType &&
        lhs.bounds == rhs.bounds &&
        lhs.routeId == rhs.routeId &&
        lhs.screenId == rhs.screenId &&
        lhs.surfaceId == rhs.surfaceId &&
        lhs.source == rhs.source &&
        lhs.ownedByLocalProject == rhs.ownedByLocalProject &&
        lhs.hasProjectSourceHint == rhs.hasProjectSourceHint &&
        lhs.actionable == rhs.actionable &&
        lhs.structural == rhs.structural;
  }

  bool _routesMatch(final RouteSnapshot lhs, final RouteSnapshot rhs) {
    return lhs.routeId == rhs.routeId &&
        lhs.name == rhs.name &&
        lhs.screenId == rhs.screenId &&
        lhs.presentationKind == rhs.presentationKind &&
        lhs.isActive == rhs.isActive;
  }

  bool _transitionsMatch(
    final ObservedTransition lhs,
    final ObservedTransition rhs,
  ) {
    return lhs.transitionId == rhs.transitionId &&
        lhs.kind == rhs.kind &&
        lhs.fromScreenId == rhs.fromScreenId &&
        lhs.toScreenId == rhs.toScreenId &&
        lhs.selectionKey == rhs.selectionKey &&
        lhs.routeId == rhs.routeId;
  }

  String? _focusedFlowScreenId(
    final _LiveEditSessionState session,
    final List<String> availableScreenIds,
  ) {
    String? firstScreenId(final _LiveEditLayerState layer) {
      if (layer.selection != null) {
        final screenId = _buildSelectionSummary(
          layer.selection!,
        ).screenId?.trim();
        if (_hasText(screenId)) {
          return screenId;
        }
      }
      if (layer.hoverSelection != null) {
        final screenId = _buildSelectionSummary(
          layer.hoverSelection!,
        ).screenId?.trim();
        if (_hasText(screenId)) {
          return screenId;
        }
      }
      for (final selection in layer.multiSelections) {
        final screenId = _buildSelectionSummary(selection).screenId?.trim();
        if (_hasText(screenId)) {
          return screenId;
        }
      }
      for (final selection in layer.marqueeSelections) {
        final screenId = _buildSelectionSummary(selection).screenId?.trim();
        if (_hasText(screenId)) {
          return screenId;
        }
      }
      return null;
    }

    return firstScreenId(session.currentLayer) ??
        firstScreenId(session.appLayer) ??
        firstScreenId(session.toolLayer) ??
        (availableScreenIds.isEmpty ? null : availableScreenIds.first);
  }

  LiveEditSelectionStore _buildSelectionStore() {
    final sessions = <String, LiveEditSelectionSessionState>{};
    for (final entry in _sessions.entries) {
      sessions[entry.key] = LiveEditSelectionSessionState(
        layers: <LiveEditTargetDomain, LiveEditSelectionLayerData>{
          LiveEditTargetDomain.appScene: _buildSelectionLayerData(
            entry.value.appLayer,
          ),
          LiveEditTargetDomain.toolScene: _buildSelectionLayerData(
            entry.value.toolLayer,
          ),
        },
      );
    }
    return LiveEditSelectionStore(sessions: sessions);
  }

  LiveEditDraftStore _buildDraftStore() {
    final sessions = <String, LiveEditDraftSessionState>{};
    for (final entry in _sessions.entries) {
      sessions[entry.key] = LiveEditDraftSessionState(
        layers: <LiveEditTargetDomain, LiveEditDraftLayerData>{
          LiveEditTargetDomain.appScene: LiveEditDraftLayerData(
            draftChanges: draftChangesForDomain(
              targetDomain: LiveEditTargetDomain.appScene,
              sessionId: entry.key,
            ),
            meaningfulNodeIds: Set<String>.from(
              entry.value.appLayer.meaningfulNodeIds,
            ),
          ),
          LiveEditTargetDomain.toolScene: LiveEditDraftLayerData(
            draftChanges: draftChangesForDomain(
              targetDomain: LiveEditTargetDomain.toolScene,
              sessionId: entry.key,
            ),
            meaningfulNodeIds: Set<String>.from(
              entry.value.toolLayer.meaningfulNodeIds,
            ),
          ),
        },
      );
    }
    return LiveEditDraftStore(sessions: sessions);
  }

  LiveEditSelectionLayerData _buildSelectionLayerData(
    final _LiveEditLayerState layer,
  ) {
    final primarySelections = layer.multiSelections.length > 1
        ? List<LiveEditSelection>.from(layer.multiSelections)
        : (layer.selection == null
              ? const <LiveEditSelection>[]
              : <LiveEditSelection>[layer.selection!]);
    final selectionSet = _buildInteractionSelectionSet(
      layer,
      primarySelections,
    );
    return LiveEditSelectionLayerData(
      selection: layer.selection,
      hoverSelection: layer.hoverSelection,
      marqueeRect: layer.marqueeRect,
      marqueeSelections: List<LiveEditSelection>.from(layer.marqueeSelections),
      multiSelections: List<LiveEditSelection>.from(layer.multiSelections),
      selectionCandidates: List<LiveEditSelectionCandidate>.from(
        layer.selectionCandidates,
      ),
      selectionSet: selectionSet,
      selectedNodeSummaries: primarySelections
          .map(_buildSelectionSummary)
          .toList(growable: false),
      marqueeNodeSummaries: layer.marqueeSelections
          .map(_buildSelectionSummary)
          .toList(growable: false),
      selectionCandidateSummaries: layer.selectionCandidates
          .map(_buildSelectionCandidateSummary)
          .toList(growable: false),
    );
  }

  InteractionSelectionSet _buildInteractionSelectionSet(
    final _LiveEditLayerState layer,
    final List<LiveEditSelection> selections,
  ) {
    if (layer.selectionSet.isEmpty && selections.isEmpty) {
      return InteractionSelectionSet.empty;
    }
    final memberKeys =
        (layer.selectionSet.memberKeys.isNotEmpty
                ? layer.selectionSet.memberKeys
                : selections.map(
                    (final item) =>
                        _selectionKey(item) ?? _selectionNodeId(item) ?? '',
                  ))
            .where(_hasText)
            .toList(growable: false);
    if (memberKeys.isEmpty) {
      return InteractionSelectionSet.empty;
    }
    final primaryKey =
        layer.selectionSet.primaryKey ??
        _selectionKey(layer.selection) ??
        _selectionNodeId(layer.selection) ??
        memberKeys.first;
    return InteractionSelectionSet(
      primaryKey: primaryKey,
      memberKeys: memberKeys,
      origin: layer.selectionSet.origin,
      focusKind: memberKeys.length > 1
          ? FlowFocusKind.selectionSet
          : FlowFocusKind.node,
    );
  }

  InteractionNodeSummary _buildSelectionSummary(
    final LiveEditSelection selection,
  ) {
    final selectionJson =
        _selectionJson(selection) ?? const <String, Object?>{};
    final rawNode = _jsonObject(selectionJson['rawNode']);
    final layoutContext = _jsonObject(selectionJson['layoutContext']);
    final source = _selectionSource(selection);
    final sourceFile = _sourceFile(source);
    final sourceHint = _sourceHint(source);
    return InteractionNodeSummary(
      selectionKey:
          _selectionKey(selection) ?? _selectionNodeId(selection) ?? '',
      nodeId: _selectionNodeId(selection) ?? '',
      widgetType:
          _selectionWidgetType(selection) ??
          _jsonString(selectionJson['widgetType']) ??
          '',
      bounds: _selectionBounds(selection),
      routeId:
          _jsonString(rawNode['routeId']) ??
          _jsonString(layoutContext['routeId']),
      screenId:
          _jsonString(rawNode['screenId']) ??
          _jsonString(layoutContext['screenId']),
      surfaceId:
          _jsonString(rawNode['surfaceId']) ??
          _jsonString(layoutContext['surfaceId']),
      source: source,
      ownedByLocalProject: _hasText(sourceFile),
      hasProjectSourceHint: _hasText(sourceHint) || _hasText(sourceFile),
      actionable: _selectionProperties(selection).isNotEmpty,
    );
  }

  InteractionNodeSummary _buildSelectionCandidateSummary(
    final LiveEditSelectionCandidate candidate,
  ) {
    final candidateJson = _selectionCandidateJson(candidate);
    final source = _selectionCandidateSource(candidate);
    final sourceFile = _sourceFile(source);
    final sourceHint = _sourceHint(source);
    return InteractionNodeSummary(
      selectionKey:
          _selectionCandidateKey(candidate) ??
          _selectionCandidateNodeId(candidate) ??
          '',
      nodeId: _selectionCandidateNodeId(candidate) ?? '',
      widgetType:
          _selectionCandidateWidgetType(candidate) ??
          _jsonString(candidateJson['widgetType']) ??
          '',
      bounds: _selectionCandidateBounds(candidate),
      routeId: _jsonString(candidateJson['routeId']),
      screenId: _jsonString(candidateJson['screenId']),
      surfaceId: _jsonString(candidateJson['surfaceId']),
      source: source,
      ownedByLocalProject:
          _selectionCandidateCreatedByLocalProject(candidate) ||
          candidateJson['createdByLocalProject'] == true,
      hasProjectSourceHint: _hasText(sourceHint) || _hasText(sourceFile),
      actionable: true,
    );
  }

  String? _selectionNodeId(final LiveEditSelection? selection) =>
      _jsonString(selection?.nodeId);

  String? _selectionKey(final LiveEditSelection? selection) {
    final key = _jsonString(selection?.selectionKey);
    return _hasText(key) ? key : _selectionNodeId(selection);
  }

  Map<String, Object?>? _selectionJson(final LiveEditSelection? selection) =>
      selection == null ? null : _jsonObject(selection.toJson());

  String? _selectionWidgetType(final LiveEditSelection? selection) =>
      _jsonString(selection?.widgetType);

  LiveEditBounds? _selectionBounds(final LiveEditSelection? selection) =>
      selection?.bounds;

  LiveEditSourceLocation? _selectionSource(
    final LiveEditSelection? selection,
  ) => selection?.source;

  List<Object?> _selectionProperties(final LiveEditSelection? selection) =>
      selection == null
      ? const <Object?>[]
      : _jsonList(selection.propertiesForWire);

  String? _selectionCandidateNodeId(
    final LiveEditSelectionCandidate? candidate,
  ) => _jsonString(candidate?.nodeId);

  String? _selectionCandidateKey(final LiveEditSelectionCandidate? candidate) {
    final key = _jsonString(candidate?.selectionKey);
    return _hasText(key) ? key : _selectionCandidateNodeId(candidate);
  }

  Map<String, Object?> _selectionCandidateJson(
    final LiveEditSelectionCandidate candidate,
  ) => _jsonObject(candidate.toJson());

  String? _selectionCandidateWidgetType(
    final LiveEditSelectionCandidate? candidate,
  ) => _jsonString(candidate?.widgetType);

  LiveEditBounds? _selectionCandidateBounds(
    final LiveEditSelectionCandidate? candidate,
  ) => candidate?.bounds;

  LiveEditSourceLocation? _selectionCandidateSource(
    final LiveEditSelectionCandidate? candidate,
  ) => candidate?.source;

  String? _sourceFile(final LiveEditSourceLocation? source) =>
      _jsonString(source?.file);

  String? _sourceHint(final LiveEditSourceLocation? source) =>
      _jsonString(source?.sourceHint);

  bool _selectionCandidateCreatedByLocalProject(
    final LiveEditSelectionCandidate? candidate,
  ) => candidate?.createdByLocalProject ?? false;

  String? _draftChangeNodeId(final LiveEditDraftChange change) =>
      _jsonString(change.nodeId);

  Map<String, Object?> _jsonObject(final Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (final key, final nestedValue) => MapEntry('$key', nestedValue),
      );
    }
    return const <String, Object?>{};
  }

  List<Object?> _jsonList(final Object? value) {
    if (value is List<Object?>) {
      return value;
    }
    if (value is List) {
      return List<Object?>.from(value);
    }
    return const <Object?>[];
  }

  String? _jsonString(final Object? value) {
    if (value == null) {
      return null;
    }
    final resolved = '$value'.trim();
    return resolved.isEmpty || resolved == 'null' ? null : resolved;
  }

  _LiveEditLayerState _activeLayerOrNull() {
    final session = _activeSessionOrNull();
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

  bool get overlayVisible => _activeSessionOrNull()?.overlayEnabled ?? false;

  LiveEditTargetDomain currentTargetDomain({final String? sessionId}) =>
      _requireSession(sessionId).targetDomain;

  bool isMeaningfulNode(final String nodeId, {final String? sessionId}) =>
      _layerForRequest(
        _requireSession(sessionId),
      ).meaningfulNodeIds.contains(nodeId);

  LiveEditSelection? selectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => _layerForRequest(
    _requireSession(sessionId),
    requested: targetDomain,
  ).selection;

  LiveEditSelection? hoverSelectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => _layerForRequest(
    _requireSession(sessionId),
    requested: targetDomain,
  ).hoverSelection;

  Rect? marqueeRectForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => _layerForRequest(
    _requireSession(sessionId),
    requested: targetDomain,
  ).marqueeRect;

  List<LiveEditSelection> marqueeSelectionsForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => List<LiveEditSelection>.unmodifiable(
    _layerForRequest(
      _requireSession(sessionId),
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
      _requireSession(sessionId),
      requested: targetDomain,
    ).multiSelections,
  );

  List<LiveEditSelectionCandidate> selectionCandidatesForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => List<LiveEditSelectionCandidate>.unmodifiable(
    _layerForRequest(
      _requireSession(sessionId),
      requested: targetDomain,
    ).selectionCandidates,
  );

  Map<String, Object?> discardDraft({final String? sessionId}) {
    final session = _requireSession(sessionId);
    final layer = _layerForRequest(session);
    _revertExactPreview(session, layer: layer);
    final selectedNodeId = _selectionNodeId(layer.selection);
    if (selectedNodeId != null) {
      layer.meaningfulNodeIds.remove(selectedNodeId);
    }
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
    final session = _requireSession(sessionId);
    final layer = _layerForRequest(session);
    final normalized = nodeIds.where(_hasText).toSet();
    if (normalized.isEmpty) {
      return discardDraft(sessionId: session.sessionId);
    }
    _revertExactPreview(session, layer: layer, nodeIds: normalized);
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
    final session = _requireSession(sessionId);
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
    final session = _requireSession(sessionId);
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
    final session = _requireSession(sessionId);
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
        final changeNodeId = _draftChangeNodeId(change);
        if (!_hasText(changeNodeId)) {
          continue;
        }
        final targetDomain = change.targetContext == null
            ? currentSession.targetDomain
            : LiveEditTargetDomain.fromWire(change.targetContext!.targetDomain);
        final tracked = currentSession
            .layerFor(targetDomain)
            .trackedSelections
            .get(changeNodeId!);
        if (tracked == null) {
          continue;
        }
        _applyExactPreviewIfSupported(
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
    final session = _requireSession(sessionId);
    _revertExactPreview(session, layer: session.appLayer);
    _revertExactPreview(session, layer: session.toolLayer);
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
    final session = _requireSession(sessionId);
    final resolvedDomain = _resolveTargetDomain(session, targetDomain);
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
    final session = _requireSession(sessionId);
    final resolvedDomain = _resolveTargetDomain(session, targetDomain);
    final layer = _layerForRequest(session, requested: resolvedDomain);
    final selection = layer.selection;
    return <String, Object?>{
      'sessionId': session.sessionId,
      'targetDomain': resolvedDomain.wireName,
      'selection': _selectionJson(selection),
      'hasSelection': selection != null,
      'hoverSelection': _selectionJson(layer.hoverSelection),
      'selectedNodeIds': layer.multiSelections
          .map(_selectionNodeId)
          .whereType<String>()
          .toList(growable: false),
      'selectionCandidates': layer.selectionCandidates
          .map(_selectionCandidateJson)
          .toList(growable: false),
    };
  }

  Map<String, Object?> getTree({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final session = _requireSession(sessionId);
    final resolvedDomain = _resolveTargetDomain(session, targetDomain);
    if (resolvedDomain == LiveEditTargetDomain.toolScene) {
      session.lastTouchedAt = DateTime.now().toUtc();
      return <String, Object?>{
        'sessionId': session.sessionId,
        'targetDomain': resolvedDomain.wireName,
        'selectedNodeId': _selectionNodeId(session.selection),
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
      'selectedNodeId': _selectionNodeId(session.selection),
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
    final session = _requireSession(sessionId);
    final resolvedDomain = _resolveTargetDomain(session, targetDomain);
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
    final dedupedHits = _dedupeHitsBySelectionKey(session, hits);
    final nextPreviewIndex = _resolvedHoverIndex(
      session: session,
      hits: dedupedHits,
      deeperMode: deeperMode,
    );
    final previousHover = session.hoverSelection;
    final nextHoverSelection = dedupedHits.isEmpty
        ? null
        : reuseHover &&
              previousHover != null &&
              session.hoverPreviewIndex == nextPreviewIndex
        ? previousHover
        : _buildHoverSelection(
            session: session,
            element: dedupedHits[nextPreviewIndex].element,
            targetDomain: resolvedDomain,
          );
    final hoverUnchanged =
        _selectionNodeId(previousHover) ==
            _selectionNodeId(nextHoverSelection) &&
        session.hoverPreviewIndex == nextPreviewIndex;
    session.hoverHitCandidates = dedupedHits;
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
        'selection': _selectionJson(session.hoverSelection),
    };
  }

  Map<String, Object?> clearHover({final String? sessionId}) {
    final session = _requireSession(sessionId);
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
    final session = _requireSession(sessionId);
    final resolvedDomain = _resolveTargetDomain(session, targetDomain);
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
    final dedupedHits = _dedupeHitsBySelectionKey(session, hits);
    if (dedupedHits.isEmpty) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'hit': false,
        'point': <String, Object?>{'x': x, 'y': y},
      };
    }

    session.selectionHitCandidates = dedupedHits;
    final selectedIndex = (preferHoverPreview && canReuseHover)
        ? session.hoverPreviewIndex.clamp(0, dedupedHits.length - 1)
        : _preferredSelectionIndex(
            session: session,
            hits: dedupedHits,
            selectionPolicy: selectionPolicy,
            targetDomain: resolvedDomain,
          );
    final hit = dedupedHits[selectedIndex];
    final hitSelectionKey = _selectionKeyForElement(session, hit.element);
    final layer = _layerForRequest(session, requested: resolvedDomain);
    if (layer.selectionSet.isSingle &&
        layer.selectionSet.primaryKey == hitSelectionKey &&
        layer.selection != null &&
        layer.multiSelections.length == 1) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'targetDomain': resolvedDomain.wireName,
        'hit': true,
        'point': <String, Object?>{'x': x, 'y': y},
        'selection': _selectionJson(layer.selection),
        'selectionCandidates': session.selectionCandidates
            .map(_selectionCandidateJson)
            .toList(growable: false),
      };
    }
    final selection = _setSelection(
      session: session,
      element: hit.element,
      ancestry: hit.ancestry,
    );
    _syncSelectionCandidates(session);
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'targetDomain': resolvedDomain.wireName,
      'hit': true,
      'point': <String, Object?>{'x': x, 'y': y},
      'selection': _selectionJson(selection),
      'selectionCandidates': session.selectionCandidates
          .map(_selectionCandidateJson)
          .toList(growable: false),
    };
  }
}
