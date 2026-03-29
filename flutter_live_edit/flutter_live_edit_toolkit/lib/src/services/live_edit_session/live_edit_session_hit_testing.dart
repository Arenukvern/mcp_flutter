// ignore_for_file: invalid_use_of_protected_member, unused_element

part of '../live_edit_session_service.dart';

_SelectionCandidateMetadata _selectionMetadataForElement(
  final _LiveEditSessionState session,
  final Element element, {
  final String? cachedNodeId,
  final Map<String, Object?>? cachedDetailsTree,
}) {
  final nodeId =
      cachedNodeId ??
      _selectionKeyForElement(session, element);
  final detailsTree =
      cachedDetailsTree ??
      _decodeObject(
        WidgetInspectorService.instance.getDetailsSubtree(
          nodeId,
          session.objectGroup,
        ),
      );
  final source = _extractSourceLocation(detailsTree, element);
  final createdByLocalProject = detailsTree['createdByLocalProject'] == true;
  final hasProjectPathSignal = _looksProjectOwnedPath(source?.file);
  final hasProjectHintSignal =
      !createdByLocalProject &&
      !hasProjectPathSignal &&
      _hasText(source?.sourceHint) &&
      !_looksFrameworkOwnedHint(source?.sourceHint);
  return _SelectionCandidateMetadata(
    nodeId: nodeId,
    source: source,
    createdByLocalProject: createdByLocalProject,
    hasProjectPathSignal: hasProjectPathSignal,
    hasProjectHintSignal: hasProjectHintSignal,
    hasEditableStringProperty: false,
    hasEditableProperty: false,
  );
}

String? _toolSurfaceIdForElement(final Element element) =>
    LiveEditOverlayThemeModel.instance.surfaceIdForElement(element);
// TODO: remove it
bool _isMeaningfulToolElement(final Element element) {
  final surfaceId = _toolSurfaceIdForElement(element);
  if (!_hasText(surfaceId)) {
    return false;
  }
  if (LiveEditOverlayThemeModel.instance.isSurfaceRootElement(element)) {
    return true;
  }
  return !<String>{
    'Align',
    'Builder',
    'Center',
    'ColoredBox',
    'Column',
    'ConstrainedBox',
    'Container',
    'DecoratedBox',
    'DefaultTextStyle',
    'Expanded',
    'Flex',
    'Flexible',
    'IconTheme',
    'KeyedSubtree',
    'MediaQuery',
    'Padding',
    'Positioned',
    'RepaintBoundary',
    'Semantics',
  }.contains(element.widget.runtimeType.toString());
}

List<_ElementHit> _toolElementHitCandidates(
  final Element root, {
  required final ui.Offset point,
  required final int? requestedViewId,
}) =>
    _nativeElementHitCandidates(
          root,
          point: point,
          requestedViewId: requestedViewId,
        )
        .where((final hit) => _isMeaningfulToolElement(hit.element))
        .toList(growable: false);

Map<String, Object?> _toolSelectionRawNode({
  required final Element element,
  required final Map<String, Object?> detailsTree,
  required final String surfaceId,
}) {
  final overlayTheme = LiveEditOverlayThemeModel.instance;
  final surfaceRoot = overlayTheme.isSurfaceRootElement(element);
  return <String, Object?>{
    ...detailsTree,
    'surfaceId': surfaceId,
    'componentKind': overlayTheme.componentKindForSurface(surfaceId),
    'toolSelectionKind': surfaceRoot ? 'surface_root' : 'surface_child',
    'toolWidgetType': element.widget.runtimeType.toString(),
  };
}

LiveEditSourceLocation? _selectionSourceForElement(
  final _LiveEditSessionState session,
  final Element element,
  final Map<String, Object?> detailsTree, {
  required final LiveEditTargetDomain targetDomain,
}) {
  if (targetDomain != LiveEditTargetDomain.toolScene) {
    return _extractSourceLocation(detailsTree, element);
  }
  final surfaceId = _toolSurfaceIdForElement(element);
  if (!_hasText(surfaceId)) {
    return _extractSourceLocation(detailsTree, element);
  }
  final surfaceSelection = LiveEditOverlayThemeModel.instance
      .selectionForSurface(surfaceId: surfaceId!, sessionId: session.sessionId);
  return surfaceSelection?.source ??
      LiveEditSourceLocation(
        file: kLiveEditOverlayThemeSourcePath,
        sourceHint: surfaceId,
      );
}

int _preferredSelectionIndex({
  required final _LiveEditSessionState session,
  required final List<_ElementHit> hits,
  required final LiveEditSelectionPolicy selectionPolicy,
  required final LiveEditTargetDomain targetDomain,
}) {
  if (hits.isEmpty || selectionPolicy == LiveEditSelectionPolicy.deepest) {
    return 0;
  }

  int? bestIndex;
  var bestRank = -1;
  for (var index = 0; index < hits.length; index += 1) {
    final hit = hits[index];
    final metadata = _selectionMetadataForElement(session, hit.element);
    final sourceFile = metadata.source?.file;
    final infrastructureHit =
        targetDomain == LiveEditTargetDomain.appScene &&
        _isLiveEditToolkitInfrastructurePath(sourceFile);
    final widgetType = hit.element.widget.runtimeType.toString();
    final weakStructuralCandidate = _structuralWidgetTypes.contains(widgetType);
    var rank = 0;
    if (infrastructureHit) {
      rank = -100;
    } else if (metadata.hasStrongProjectOwnership) {
      rank = 70;
    } else if (metadata.hasProjectHintSignal && !weakStructuralCandidate) {
      rank = 50;
    } else if (!weakStructuralCandidate) {
      rank = 40;
    }
    if (rank > bestRank) {
      bestRank = rank;
      bestIndex = index;
    }
  }
  return bestIndex ?? 0;
}

bool _isLiveEditToolkitInfrastructurePath(final String? file) {
  if (!_hasText(file)) {
    return false;
  }
  final normalized = file!.replaceAll(r'\', '/');
  return normalized.contains(
    '/flutter_live_edit/flutter_live_edit_toolkit/lib/src/',
  );
}

bool _isUserAuthoredElement(
  final _LiveEditSessionState session,
  final Element element,
  final String nodeId,
) {
  final tracked = session.trackedSelections[nodeId]?.selection;
  final trackedSource = tracked?.source;
  if (_looksProjectOwnedPath(trackedSource?.file)) {
    return true;
  }
  if (_hasText(trackedSource?.sourceHint) &&
      !_looksFrameworkOwnedHint(trackedSource?.sourceHint)) {
    return true;
  }
  String? sourceHint;
  assert(() {
    sourceHint = element.debugGetCreatorChain(8);
    return true;
  }(), 'sourceHint');
  return _hasText(sourceHint) && !_looksFrameworkOwnedHint(sourceHint);
}

bool _nativeHitTestHelper(
  final List<RenderObject> hits,
  final List<RenderObject> edgeHits,
  final ui.Offset position,
  final RenderObject object,
  final Matrix4 transform,
) {
  var hit = false;
  final inverse = Matrix4.tryInvert(transform);
  if (inverse == null) {
    return false;
  }
  final localPosition = MatrixUtils.transformPoint(inverse, position);

  final children = object.debugDescribeChildren();
  for (var index = children.length - 1; index >= 0; index -= 1) {
    final diagnostics = children[index];
    if (diagnostics.style == DiagnosticsTreeStyle.offstage ||
        diagnostics.value is! RenderObject) {
      continue;
    }
    final child = diagnostics.value! as RenderObject;
    final paintClip = object.describeApproximatePaintClip(child);
    if (paintClip != null && !paintClip.contains(localPosition)) {
      continue;
    }
    final childTransform = transform.clone();
    object.applyPaintTransform(child, childTransform);
    if (_nativeHitTestHelper(hits, edgeHits, position, child, childTransform)) {
      hit = true;
    }
  }

  final bounds = object.semanticBounds;
  if (bounds.contains(localPosition)) {
    hit = true;
    if (!bounds.deflate(_edgeHitMargin).contains(localPosition)) {
      edgeHits.add(object);
    }
  }
  if (hit) {
    hits.add(object);
  }
  return hit;
}

double _semanticArea(final RenderObject object) {
  final size = object.semanticBounds.size;
  return size.width * size.height;
}

List<_ElementHit> _nativeElementHitCandidates(
  final Element root, {
  required final ui.Offset point,
  required final int? requestedViewId,
}) {
  final rootRenderObject = _previewRenderObjectForElement(root);
  if (rootRenderObject == null) {
    return const <_ElementHit>[];
  }
  final rootViewId = _viewIdForRenderObject(rootRenderObject);
  if (requestedViewId != null &&
      rootViewId != null &&
      rootViewId != requestedViewId) {
    return const <_ElementHit>[];
  }

  final regularHits = <RenderObject>[];
  final edgeHits = <RenderObject>[];
  _nativeHitTestHelper(
    regularHits,
    edgeHits,
    point,
    rootRenderObject,
    rootRenderObject.getTransformTo(null),
  );
  regularHits.sort(
    (final left, final right) =>
        _semanticArea(left).compareTo(_semanticArea(right)),
  );
  final ordered = <RenderObject>{...edgeHits, ...regularHits}.toList();
  final results = <_ElementHit>[];
  for (final renderObject in ordered) {
    final debugCreator = renderObject.debugCreator;
    if (debugCreator is! DebugCreator) {
      continue;
    }
    final element = debugCreator.element;
    if (!element.mounted || !_isVisibleCandidate(element)) {
      continue;
    }
    results.add(
      _ElementHit(
        element: element,
        renderObject: renderObject,
        ancestry: _ancestryForElement(element),
        depth: _depthForElement(element),
        edgeHit: edgeHits.contains(renderObject),
      ),
    );
  }
  return results;
}

List<Map<String, Object?>> _ancestryForElement(final Element element) {
  final ancestry = <Map<String, Object?>>[];
  Element? current = element;
  while (true) {
    final parent = current?.findAncestorRenderObjectOfType<RenderObject>();
    final currentParent = current;
    if (currentParent == null) {
      break;
    }
    Element? directParent;
    currentParent.visitAncestorElements((final candidate) {
      directParent = candidate;
      return false;
    });
    if (directParent == null) {
      break;
    }
    ancestry.add(<String, Object?>{
      'widgetType': directParent!.widget.runtimeType.toString(),
      'renderObjectType': parent?.runtimeType.toString(),
    });
    current = directParent;
  }
  return ancestry.reversed.toList(growable: false);
}

int _depthForElement(final Element element) {
  var depth = 0;
  element.visitAncestorElements((final _) {
    depth += 1;
    return true;
  });
  return depth;
}

void _collectElementsIntersectingRect(
  final Element root, {
  required final Rect rect,
  required final List<_ElementHit> results,
  required final int? requestedViewId,
  final List<Map<String, Object?>> ancestry = const <Map<String, Object?>>[],
  final Element? parentElement,
}) {
  final renderObject = root.renderObject;
  final bounds = _boundsForRenderObject(renderObject);
  if (bounds == null || !_intersectsRect(bounds, rect)) {
    return;
  }
  final viewId = _viewIdForRenderObject(renderObject);
  if (requestedViewId != null && viewId != null && viewId != requestedViewId) {
    return;
  }
  if (_isVisibleCandidate(root)) {
    results.add(
      _ElementHit(
        element: root,
        renderObject: renderObject!,
        ancestry: ancestry,
        depth: ancestry.length,
        parentElement: parentElement,
      ),
    );
  }
  root.visitChildElements((final child) {
    _collectElementsIntersectingRect(
      child,
      rect: rect,
      results: results,
      requestedViewId: requestedViewId,
      ancestry: <Map<String, Object?>>[
        ...ancestry,
        <String, Object?>{
          'widgetType': root.widget.runtimeType.toString(),
          'renderObjectType': renderObject?.runtimeType.toString(),
        },
      ],
      parentElement: root,
    );
  });
}

Map<String, Object?> _layoutContextForElement(final Element element) {
  final renderObject = element.renderObject;
  final context = <String, Object?>{
    'widgetType': element.widget.runtimeType.toString(),
    if (renderObject != null)
      'renderObjectType': renderObject.runtimeType.toString(),
  };

  if (renderObject case final RenderBox box when box.hasSize) {
    context['size'] = <String, Object?>{
      'width': box.size.width,
      'height': box.size.height,
    };
  }

  try {
    if (renderObject != null && !renderObject.debugNeedsLayout) {
      final constraints = renderObject.constraints;
      context['constraints'] = constraints.toString();
    }
  } on Exception {
    // best effort
  }

  final parentData = renderObject?.parentData;
  if (parentData is FlexParentData) {
    context['flexFactor'] = parentData.flex;
    context['flexFit'] = parentData.fit?.name;
  } else if (parentData is BoxParentData) {
    context['offset'] = <String, Object?>{
      'dx': parentData.offset.dx,
      'dy': parentData.offset.dy,
    };
  }

  if (renderObject?.parent case final RenderFlex parentFlex) {
    context['parentFlex'] = <String, Object?>{
      'direction': parentFlex.direction.name,
      'mainAxisAlignment': parentFlex.mainAxisAlignment.name,
      'crossAxisAlignment': parentFlex.crossAxisAlignment.name,
    };
  }

  return context;
}

LiveEditSelection _buildHoverSelection({
  required final _LiveEditSessionState session,
  required final Element element,
  required final LiveEditTargetDomain targetDomain,
}) {
  final renderObject = _previewRenderObjectForElement(element);
  final nodeId = _selectionKeyForElement(session, element);
  final tracked = session.trackedSelections[nodeId]?.selection;
  final detailsTree = tracked?.detailsTree ?? const <String, Object?>{};
  final surfaceId = _toolSurfaceIdForElement(element);
  final rawNode =
      tracked?.rawNode ??
      (targetDomain == LiveEditTargetDomain.toolScene && _hasText(surfaceId)
          ? _toolSelectionRawNode(
              element: element,
              detailsTree: detailsTree,
              surfaceId: surfaceId!,
            )
          : const <String, Object?>{});
  return LiveEditSelection(
    sessionId: session.sessionId,
    selectionKey: nodeId,
    nodeId: nodeId,
    widgetType: element.widget.runtimeType.toString(),
    targetDomain: targetDomain,
    renderObjectType: renderObject?.runtimeType.toString(),
    bounds: _boundsForRenderObject(renderObject),
    source:
        tracked?.source ??
        _selectionSourceForElement(
          session,
          element,
          detailsTree,
          targetDomain: targetDomain,
        ),
    rawNode: rawNode,
  );
}

bool _isHydratedSelection(final LiveEditSelection selection) =>
    selection.detailsTree.isNotEmpty &&
    selection.propertiesTree.isNotEmpty &&
    selection.parentChain.isNotEmpty;

LiveEditSelection _buildLightweightSelection({
  required final _LiveEditSessionState session,
  required final _ElementHit hit,
}) {
  final element = hit.element;
  final renderObject = _previewRenderObjectForElement(element);
  final nodeId = _selectionKeyForElement(session, element);
  final tracked = session.trackedSelections[nodeId]?.selection;
  return LiveEditSelection(
    sessionId: session.sessionId,
    selectionKey: nodeId,
    nodeId: nodeId,
    widgetType: element.widget.runtimeType.toString(),
    targetDomain: session.targetDomain,
    renderObjectType: renderObject?.runtimeType.toString(),
    bounds: _boundsForRenderObject(renderObject),
    source:
        tracked?.source ??
        _selectionSourceForElement(
          session,
          element,
          tracked?.detailsTree ?? const <String, Object?>{},
          targetDomain: session.targetDomain,
        ),
    rawNode: tracked?.rawNode ?? const <String, Object?>{},
  );
}

LiveEditSelection _buildLightweightSelectionFromCache({
  required final _LiveEditSessionState session,
  required final _MarqueeCandidateCacheEntry entry,
}) {
  final tracked = session.trackedSelections[entry.nodeId]?.selection;
  return LiveEditSelection(
    sessionId: session.sessionId,
    selectionKey: entry.nodeId,
    nodeId: entry.nodeId,
    widgetType: entry.widgetType,
    targetDomain: session.targetDomain,
    renderObjectType: entry.renderObject.runtimeType.toString(),
    bounds: entry.bounds,
    source: tracked?.source,
    rawNode: tracked?.rawNode ?? const <String, Object?>{},
  );
}

bool _sameHoverRequest({
  required final _LiveEditSessionState session,
  required final ui.Offset point,
  required final Element root,
  required final int? viewId,
}) {
  final hoverPoint = session.hoverPoint;
  if (hoverPoint == null || session.hoverRootElement != root) {
    return false;
  }
  if (session.hoverViewId != viewId) {
    return false;
  }
  return (hoverPoint - point).distance <= _hoverReuseDistance;
}

int? _viewIdForRenderObject(final RenderObject? renderObject) {
  if (renderObject == null) {
    return null;
  }
  RenderObject current = renderObject;
  while (current.parent is RenderObject) {
    current = current.parent!;
  }
  if (current is RenderView) {
    return current.flutterView.viewId;
  }
  return null;
}
