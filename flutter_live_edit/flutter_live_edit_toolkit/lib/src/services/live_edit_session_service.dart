// ignore_for_file: invalid_use_of_protected_member, unused_element

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:from_json_to_json/from_json_to_json.dart';

import '../live_edit_overlay_theme.dart';
import '../resources/live_edit_draft.src.data.dart';
import '../resources/live_edit_selection.src.data.dart';
import '../resources/live_edit_session.src.data.dart';
import 'live_edit_session_update.dart';

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

LiveEditBounds? _boundsForRenderObject(final RenderObject? renderObject) {
  if (renderObject == null || !renderObject.attached) {
    return null;
  }
  if (renderObject is RenderBox) {
    if (!renderObject.hasSize) {
      return null;
    }
    final origin = renderObject.localToGlobal(ui.Offset.zero);
    final rect = origin & renderObject.size;
    return LiveEditBounds(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      width: rect.width,
      height: rect.height,
    );
  }

  try {
    final rect = MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      renderObject.paintBounds,
    );
    return LiveEditBounds(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      width: rect.width,
      height: rect.height,
    );
  } on Exception {
    return null;
  }
}

RenderObject? _previewRenderObjectForElement(final Element element) {
  final direct = element.renderObject;
  if (direct != null) {
    return direct;
  }
  RenderObject? resolved;

  void visit(final Element candidate) {
    if (resolved != null) {
      return;
    }
    final renderObject = candidate.renderObject;
    if (renderObject != null) {
      resolved = renderObject;
      return;
    }
    candidate.visitChildElements(visit);
  }

  element.visitChildElements(visit);
  return resolved;
}

bool _containsPoint(final LiveEditBounds bounds, final ui.Offset point) =>
    point.dx >= bounds.left &&
    point.dx <= bounds.right &&
    point.dy >= bounds.top &&
    point.dy <= bounds.bottom;

const double _hoverReuseDistance = 8;

Rect _rectFromBounds(final LiveEditBounds bounds) =>
    Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.bottom);

bool _intersectsRect(final LiveEditBounds bounds, final Rect rect) =>
    _rectFromBounds(bounds).overlaps(rect);

bool _sameNodeIdSet(
  final List<LiveEditSelection> left,
  final List<LiveEditSelection> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].nodeId != right[index].nodeId) {
      return false;
    }
  }
  return true;
}

bool _isVisibleCandidate(final Element element) {
  final renderObject = element.renderObject;
  final bounds = _boundsForRenderObject(renderObject);
  if (renderObject == null || bounds == null) {
    return false;
  }
  if (bounds.width <= 0 || bounds.height <= 0) {
    return false;
  }
  if (renderObject is RenderOpacity && renderObject.opacity <= 0) {
    return false;
  }
  return true;
}

const double _edgeHitMargin = 2;

const Set<String> _structuralWidgetTypes = <String>{
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
  'RichText',
  'Row',
  'Semantics',
};

List<Object?> _decodeList(final String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return const <Object?>[];
  }
  return decoded.cast<Object?>();
}

Map<String, Object?> _decodeObject(final String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    return const <String, Object?>{};
  }
  return decoded.map((final key, final value) => MapEntry('$key', value));
}

LiveEditSourceLocation? _extractSourceLocation(
  final Map<String, Object?> detailsTree,
  final Element element,
) {
  final creationLocation = detailsTree['creationLocation'];
  if (creationLocation is Map) {
    final normalized = creationLocation.map(
      (final key, final value) => MapEntry('$key', value),
    );
    final file = '${normalized['file'] ?? normalized['fileUri'] ?? ''}'.trim();
    if (file.isNotEmpty) {
      return LiveEditSourceLocation(
        file: file,
        line: jsonDecodeNullableInt(normalized['line']),
        column: jsonDecodeNullableInt(normalized['column']),
      );
    }
  }

  String? sourceHint;
  assert(() {
    sourceHint = element.debugGetCreatorChain(8);
    return true;
  }());
  if (sourceHint == null || sourceHint!.trim().isEmpty) {
    return null;
  }
  return LiveEditSourceLocation(file: '', sourceHint: sourceHint!.trim());
}

String? _normalizeSourceFilePath(final String? rawPath) {
  if (!_hasText(rawPath)) {
    return null;
  }
  final trimmed = rawPath!.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.scheme == 'file') {
    return uri.toFilePath();
  }
  return trimmed;
}

bool _containsPathSegment(final String path, final String segment) {
  final normalizedPath = path.replaceAll(r'\', '/').toLowerCase();
  final normalizedSegment = segment.toLowerCase();
  return normalizedPath.contains(normalizedSegment);
}

bool _isFrameworkOwnedPath(final String path) =>
    _containsPathSegment(path, '/packages/flutter/') ||
    _containsPathSegment(path, '/bin/cache/pkg/sky_engine/') ||
    _containsPathSegment(path, '/flutter/packages/flutter/');

bool _isThirdPartyPackagePath(final String path) =>
    _containsPathSegment(path, '/.pub-cache/') ||
    _containsPathSegment(path, '/pub.dev/');

bool _looksProjectOwnedPath(final String? path) {
  if (!_hasText(path)) {
    return false;
  }
  final normalizedPath = _normalizeSourceFilePath(path);
  if (!_hasText(normalizedPath)) {
    return false;
  }
  return !_isFrameworkOwnedPath(normalizedPath!) &&
      !_isThirdPartyPackagePath(normalizedPath);
}

bool _looksFrameworkOwnedHint(final String? hint) {
  if (!_hasText(hint)) {
    return false;
  }
  final normalized = hint!.toLowerCase();
  return normalized.contains('package:flutter/') ||
      normalized.contains('/packages/flutter/') ||
      normalized.contains('/flutter/packages/flutter/') ||
      normalized.contains('widgets/text.dart');
}

final class _SelectionCandidateMetadata {
  const _SelectionCandidateMetadata({
    required this.nodeId,
    required this.source,
    required this.createdByLocalProject,
    required this.hasProjectPathSignal,
    required this.hasProjectHintSignal,
    required this.hasEditableStringProperty,
    required this.hasEditableProperty,
  });

  final String nodeId;
  final LiveEditSourceLocation? source;
  final bool createdByLocalProject;
  final bool hasProjectPathSignal;
  final bool hasProjectHintSignal;
  final bool hasEditableStringProperty;
  final bool hasEditableProperty;

  bool get hasStrongProjectOwnership =>
      createdByLocalProject || hasProjectPathSignal;
}

final class _MarqueeCandidateCacheEntry {
  const _MarqueeCandidateCacheEntry({
    required this.element,
    required this.renderObject,
    required this.parentElement,
    required this.ancestry,
    required this.nodeId,
    required this.widgetType,
    required this.depth,
    required this.isStructural,
    required this.isUserAuthored,
    required this.bounds,
  });

  final Element element;
  final RenderObject renderObject;
  final Element? parentElement;
  final List<Map<String, Object?>> ancestry;
  final String nodeId;
  final String widgetType;
  final int depth;
  final bool isStructural;
  final bool isUserAuthored;
  final LiveEditBounds? bounds;

  bool get isVisualCandidate =>
      isUserAuthored && !isStructural && bounds != null;
}

_SelectionCandidateMetadata _selectionMetadataForElement(
  final _LiveEditSessionState session,
  final Element element, {
  final String? cachedNodeId,
  final Map<String, Object?>? cachedDetailsTree,
  final List<LiveEditPropertyDescriptor> Function(
    Element element,
    LiveEditTargetDomain targetDomain,
  )? propertyDescriptorProvider,
}) {
  final nodeId =
      cachedNodeId ??
      WidgetInspectorService.instance.toId(element, session.objectGroup) ??
      'live_edit_candidate_${session.sessionId}_${element.hashCode}';
  final detailsTree =
      cachedDetailsTree ??
      _decodeObject(
        WidgetInspectorService.instance.getDetailsSubtree(
          nodeId,
          session.objectGroup,
        ),
      );
  final source = _extractSourceLocation(detailsTree, element);
  final properties = _selectionPropertyGroupsForElement(
    session,
    element,
    targetDomain: session.targetDomain,
    propertyDescriptorProvider: propertyDescriptorProvider,
  );
  final createdByLocalProject = detailsTree['createdByLocalProject'] == true;
  final hasProjectPathSignal = _looksProjectOwnedPath(source?.file);
  final hasProjectHintSignal =
      !createdByLocalProject &&
      !hasProjectPathSignal &&
      _hasText(source?.sourceHint) &&
      !_looksFrameworkOwnedHint(source?.sourceHint);
  final hasEditableStringProperty = properties.any(
    (final property) =>
        property.editable && property.kind == LiveEditPropertyKind.string,
  );
  final hasEditableProperty =
      hasEditableStringProperty ||
      properties.any((final property) => property.editable);
  return _SelectionCandidateMetadata(
    nodeId: nodeId,
    source: source,
    createdByLocalProject: createdByLocalProject,
    hasProjectPathSignal: hasProjectPathSignal,
    hasProjectHintSignal: hasProjectHintSignal,
    hasEditableStringProperty: hasEditableStringProperty,
    hasEditableProperty: hasEditableProperty,
  );
}

LiveEditPropertyDescriptor _copyPropertyDescriptor(
  final LiveEditPropertyDescriptor descriptor, {
  final Object? value,
  final bool preserveValue = true,
  final Map<String, Object?>? meta,
}) => LiveEditPropertyDescriptor(
  id: descriptor.id,
  label: descriptor.label,
  group: descriptor.group,
  kind: descriptor.kind,
  value: preserveValue ? descriptor.value : value,
  options: descriptor.options,
  editable: descriptor.editable,
  previewMode: descriptor.previewMode,
  persistable: descriptor.persistable,
  canPreviewExactly: descriptor.canPreviewExactly,
  requiresAgentForPersistence: descriptor.requiresAgentForPersistence,
  safeToAutoGroupInApply: descriptor.safeToAutoGroupInApply,
  meta: meta ?? descriptor.meta,
);

String? _toolSurfaceIdForElement(final Element element) =>
    LiveEditOverlayThemeModel.instance.surfaceIdForElement(element);

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

List<LiveEditPropertyDescriptor> _selectionPropertyGroupsForElement(
  final _LiveEditSessionState session,
  final Element element, {
  required final LiveEditTargetDomain targetDomain,
  final List<LiveEditPropertyDescriptor> Function(
    Element element,
    LiveEditTargetDomain targetDomain,
  )? propertyDescriptorProvider,
}) {
  if (targetDomain != LiveEditTargetDomain.toolScene) {
    final provider = propertyDescriptorProvider;
    if (provider != null) {
      return provider(element, targetDomain);
    }
    return const <LiveEditPropertyDescriptor>[];
  }
  final surfaceId = _toolSurfaceIdForElement(element);
  if (!_hasText(surfaceId)) {
    final provider = propertyDescriptorProvider;
    if (provider != null) {
      return provider(element, targetDomain);
    }
    return const <LiveEditPropertyDescriptor>[];
  }
  final overlayTheme = LiveEditOverlayThemeModel.instance;
  final surfaceSelection = overlayTheme.selectionForSurface(
    surfaceId: surfaceId!,
    sessionId: session.sessionId,
  );
  if (surfaceSelection == null) {
    final provider = propertyDescriptorProvider;
    if (provider != null) {
      return provider(element, targetDomain);
    }
    return const <LiveEditPropertyDescriptor>[];
  }
  final toolSelectionKind = overlayTheme.isSurfaceRootElement(element)
      ? 'surface_root'
      : 'surface_child';
  return surfaceSelection.propertyGroups
      .map(
        (final property) => _copyPropertyDescriptor(
          property,
          meta: <String, Object?>{
            ...property.meta,
            'surfaceId': surfaceId,
            'componentKind': overlayTheme.componentKindForSurface(surfaceId),
            'toolSelectionKind': toolSelectionKind,
            'toolWidgetType': element.widget.runtimeType.toString(),
          },
        ),
      )
      .toList(growable: false);
}

int _preferredSelectionIndex({
  required final _LiveEditSessionState session,
  required final List<_ElementHit> hits,
  required final LiveEditSelectionPolicy selectionPolicy,
  final List<LiveEditPropertyDescriptor> Function(
    Element element,
    LiveEditTargetDomain targetDomain,
  )? propertyDescriptorProvider,
}) {
  if (hits.isEmpty || selectionPolicy == LiveEditSelectionPolicy.deepest) {
    return 0;
  }

  int? bestIndex;
  var bestRank = -1;
  for (var index = 0; index < hits.length; index += 1) {
    final hit = hits[index];
    final metadata = _selectionMetadataForElement(
      session,
      hit.element,
      propertyDescriptorProvider: propertyDescriptorProvider,
    );
    final widgetType = hit.element.widget.runtimeType.toString();
    final weakStructuralCandidate = _structuralWidgetTypes.contains(widgetType);
    var rank = 0;
    if (metadata.hasStrongProjectOwnership &&
        metadata.hasEditableStringProperty) {
      rank = 90;
    } else if (metadata.hasProjectHintSignal &&
        metadata.hasEditableStringProperty) {
      rank = 80;
    } else if (metadata.hasStrongProjectOwnership) {
      rank = 70;
    } else if (metadata.hasEditableStringProperty && !weakStructuralCandidate) {
      rank = 60;
    } else if (metadata.hasProjectHintSignal &&
        metadata.hasEditableProperty &&
        !weakStructuralCandidate) {
      rank = 50;
    } else if (metadata.hasProjectHintSignal && !weakStructuralCandidate) {
      rank = 40;
    }
    if (rank > bestRank) {
      bestRank = rank;
      bestIndex = index;
    }
  }
  return bestIndex ?? 0;
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
  }());
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
  final nodeId =
      WidgetInspectorService.instance.toId(element, session.objectGroup) ??
      'live_edit_hover_${DateTime.now().microsecondsSinceEpoch}';
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
    propertyGroups:
        tracked?.propertyGroups ?? const <LiveEditPropertyDescriptor>[],
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
  final bool includePropertyGroups = false,
}) {
  final element = hit.element;
  final renderObject = _previewRenderObjectForElement(element);
  final nodeId =
      WidgetInspectorService.instance.toId(element, session.objectGroup) ??
      'live_edit_preview_${DateTime.now().microsecondsSinceEpoch}';
  final tracked = session.trackedSelections[nodeId]?.selection;
  final propertyGroups =
      tracked?.propertyGroups ??
      (includePropertyGroups
          ? _selectionPropertyGroupsForElement(
              session,
              element,
              targetDomain: session.targetDomain,
            )
          : const <LiveEditPropertyDescriptor>[]);
  return LiveEditSelection(
    sessionId: session.sessionId,
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
    propertyGroups: propertyGroups,
    rawNode: tracked?.rawNode ?? const <String, Object?>{},
  );
}

LiveEditSelection _buildLightweightSelectionFromCache({
  required final _LiveEditSessionState session,
  required final _MarqueeCandidateCacheEntry entry,
  final bool includePropertyGroups = false,
  final List<LiveEditPropertyDescriptor> Function(
    Element element,
    LiveEditTargetDomain targetDomain,
  )? propertyDescriptorProvider,
}) {
  final tracked = session.trackedSelections[entry.nodeId]?.selection;
  final propertyGroups =
      tracked?.propertyGroups ??
      (includePropertyGroups
          ? _selectionPropertyGroupsForElement(
              session,
              entry.element,
              targetDomain: session.targetDomain,
              propertyDescriptorProvider: propertyDescriptorProvider,
            )
          : const <LiveEditPropertyDescriptor>[]);
  return LiveEditSelection(
    sessionId: session.sessionId,
    nodeId: entry.nodeId,
    widgetType: entry.widgetType,
    targetDomain: session.targetDomain,
    renderObjectType: entry.renderObject.runtimeType.toString(),
    bounds: entry.bounds,
    source: tracked?.source,
    propertyGroups: propertyGroups,
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

final class LiveEditSessionService {
  LiveEditSessionService({
    List<LiveEditPropertyDescriptor> Function(
      Element element,
      LiveEditTargetDomain targetDomain,
    )? propertyDescriptorProvider,
  }) : _propertyDescriptorProvider = propertyDescriptorProvider;

  final Map<String, _LiveEditSessionState> _sessions =
      <String, _LiveEditSessionState>{};
  String? _activeSessionId;
  LiveEditSessionUpdate? _lastUpdate;

  List<LiveEditPropertyDescriptor> Function(
    Element element,
    LiveEditTargetDomain targetDomain,
  )? _propertyDescriptorProvider;

  List<LiveEditPropertyDescriptor> Function(
    Element element,
    LiveEditTargetDomain targetDomain,
  )?
  get propertyDescriptorProvider => _propertyDescriptorProvider;
  set propertyDescriptorProvider(
    final List<LiveEditPropertyDescriptor> Function(
      Element element,
      LiveEditTargetDomain targetDomain,
    )?
    value,
  ) {
    _propertyDescriptorProvider = value;
  }

  LiveEditSessionUpdate? get lastUpdate => _lastUpdate;

  LiveEditSessionUpdate? _buildLastUpdate() {
    final session = _activeSessionOrNull();
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
        marqueeSelections: List<LiveEditSelection>.from(layer.marqueeSelections),
        multiSelections: List<LiveEditSelection>.from(layer.multiSelections),
        selectionCandidates:
            List<LiveEditSelectionCandidate>.from(layer.selectionCandidates),
      ),
    );
    final draftLayer = (
      session.sessionId,
      session.targetDomain,
      LiveEditDraftLayerData(
        draftChanges: List<LiveEditDraftChange>.from(layer.draftChanges),
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
      List<LiveEditDraftChange>.unmodifiable(_activeLayerOrNull().draftChanges);

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
  }) => List<LiveEditDraftChange>.unmodifiable(
    _layerForRequest(
      _requireSession(sessionId),
      requested: targetDomain,
    ).draftChanges,
  );

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
    layer.draftChanges.clear();
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
    final session = _requireSession(sessionId);
    final layer = _layerForRequest(session);
    final normalized = nodeIds.where(_hasText).toSet();
    if (normalized.isEmpty) {
      return discardDraft(sessionId: session.sessionId);
    }
    _revertExactPreview(session, layer: layer, nodeIds: normalized);
    layer.draftChanges.removeWhere(
      (final draft) => normalized.contains(draft.nodeId),
    );
    layer.meaningfulNodeIds.removeAll(normalized);
    session.lastTouchedAt = DateTime.now().toUtc();
    _lastUpdate = _buildLastUpdate();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'discarded': true,
      'draftChanges': layer.draftChanges
          .map((final draft) => draft.toJson())
          .toList(growable: false),
    };
  }

  Map<String, Object?> commitDraft({final String? sessionId}) {
    final session = _requireSession(sessionId);
    final layer = _layerForRequest(session);
    layer.draftChanges.clear();
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
    layer.draftChanges.removeWhere(
      (final draft) => normalized.contains(draft.nodeId),
    );
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
      'draftChanges': layer.draftChanges
          .map((final draft) => draft.toJson())
          .toList(growable: false),
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
        final tracked = currentSession
            .layerFor(
              LiveEditTargetDomain.fromWire(change.meta['targetDomain']),
            )
            .trackedSelections[change.nodeId];
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
    final layer = _layerForRequest(session, requested: resolvedDomain);
    return <String, Object?>{
      'sessionId': session.sessionId,
      'targetDomain': resolvedDomain.wireName,
      'draftChanges': layer.draftChanges
          .map((final draft) => draft.toJson())
          .toList(),
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
    final session = _requireSession(sessionId);
    final resolvedDomain = _resolveTargetDomain(session, targetDomain);
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
            propertyDescriptorProvider: _propertyDescriptorProvider,
          );
    final selection = _setSelection(
      session: session,
      element: hits[selectedIndex].element,
      ancestry: hits[selectedIndex].ancestry,
    );
    session.multiSelections = <LiveEditSelection>[selection];
    _syncSelectionCandidates(session);
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

  Map<String, Object?> startMarquee({
    required final int x,
    required final int y,
    final String? sessionId,
  }) {
    final session = _requireSession(sessionId);
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
    final session = _requireSession(sessionId);
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
    final session = _requireSession(sessionId);
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
        final committed = _setSelection(
          session: session,
          element: hit.element,
          ancestry: hit.ancestry,
        );
        session.multiSelections = <LiveEditSelection>[committed];
        _syncSelectionCandidates(session);
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
            propertyGroups: selection.propertyGroups,
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
      _hydrateTrackedSelection(
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
    _syncSelectionCandidates(session);
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
    final session = _requireSession(sessionId);
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
    final session = _requireSession(sessionId);
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
        ? _hydrateTrackedSelection(
            session: session,
            tracked: tracked,
            updateInspectorSelection: true,
            targetDomain: targetDomain,
          )
        : _setSelection(
            session: session,
            element: hit.element,
            ancestry: hit.ancestry,
            targetDomain: targetDomain,
          );
    if (layer.multiSelections.length <= 1) {
      layer.multiSelections = <LiveEditSelection>[selection];
    }
    _syncSelectionCandidates(session, requested: targetDomain);
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
    final session = _requireSession(sessionId);
    final resolvedDomain = _resolveTargetDomain(session, targetDomain);
    final layer = _layerForRequest(session, requested: targetDomain);
    if (resolvedDomain == LiveEditTargetDomain.toolScene) {
      final tracked = layer.trackedSelections[nodeId];
      if (tracked != null &&
          tracked.element.mounted &&
          tracked.element.renderObject != null) {
        final selection = _hydrateTrackedSelection(
          session: session,
          tracked: tracked,
          updateInspectorSelection: true,
          targetDomain: targetDomain,
        );
        if (layer.multiSelections.length <= 1) {
          layer.multiSelections = <LiveEditSelection>[selection];
        }
        _syncSelectionCandidates(session, requested: targetDomain);
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
          depth: 0,
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
        ? _setSelection(
            session: session,
            element: tracked.element,
            ancestry: tracked.ancestry,
            targetDomain: targetDomain,
          )
        : _hydrateTrackedSelection(
            session: session,
            tracked: tracked,
            updateInspectorSelection: true,
            targetDomain: targetDomain,
          );
    if (layer.multiSelections.length <= 1) {
      layer.multiSelections = <LiveEditSelection>[selection];
    }
    _syncSelectionCandidates(session, requested: targetDomain);
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
    final session = _requireSession(sessionId);
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
    final session = _requireSession(sessionId);
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
    final session = _requireSession(sessionId);
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
    final session = _requireSession(sessionId);
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
    final List<_ElementHit> hits, {
    final bool includePropertyGroups = false,
  }) => hits
      .map((final hit) => _resolveMarqueeCandidate(session, hit))
      .whereType<_MarqueeCandidateCacheEntry>()
      .map(
        (final entry) => _buildLightweightSelectionFromCache(
          session: session,
          entry: entry,
          includePropertyGroups: includePropertyGroups,
          propertyDescriptorProvider: _propertyDescriptorProvider,
        ),
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
      final existingIndex = layer.draftChanges.indexWhere(
        (final candidate) =>
            candidate.nodeId == selectionNodeId &&
            candidate.propertyId == change.propertyId,
      );
      if (existingIndex >= 0) {
        layer.draftChanges[existingIndex] = change;
      } else {
        layer.draftChanges.add(change);
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
        'draftChanges': layer.draftChanges
            .map((final draft) => draft.toJson())
            .toList(),
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

    final existingIndex = session.draftChanges.indexWhere(
      (final candidate) =>
          candidate.nodeId == change.nodeId &&
          candidate.propertyId == change.propertyId,
    );
    if (existingIndex >= 0) {
      session.draftChanges[existingIndex] = change;
    } else {
      session.draftChanges.add(change);
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
      'draftChanges': session.draftChanges
          .map((final draft) => draft.toJson())
          .toList(),
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
  ) {
    final property = selection.propertyGroups.firstWhere(
      (final item) => item.id == change.propertyId,
      orElse: () => LiveEditPropertyDescriptor(
        id: change.propertyId,
        label: change.propertyId,
        group: LiveEditPropertyGroup.diagnostics,
        kind: LiveEditPropertyKind.object,
      ),
    );
    return '${property.value}' != '${change.targetValue}';
  }

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
    final nodeId =
        WidgetInspectorService.instance.toId(element, session.objectGroup) ??
        'live_edit_node_${DateTime.now().microsecondsSinceEpoch}';
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
    final propertyGroups = _selectionPropertyGroupsForElement(
      session,
      element,
      targetDomain: resolvedDomain,
      propertyDescriptorProvider: _propertyDescriptorProvider,
    );
    final selection = LiveEditSelection(
      sessionId: session.sessionId,
      nodeId: nodeId,
      widgetType: element.widget.runtimeType.toString(),
      targetDomain: resolvedDomain,
      renderObjectType: renderObject?.runtimeType.toString(),
      bounds: _boundsForRenderObject(renderObject),
      source: source,
      propertyGroups: propertyGroups,
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
    final LiveEditTargetDomain? targetDomain,
  }) {
    final layer = _layerForRequest(session, requested: targetDomain);
    if (layer.selectedElement != null && layer.selectedElement != element) {
      _revertExactPreview(session, layer: layer);
    }

    final selection = _buildSelection(
      session: session,
      element: element,
      ancestry: ancestry,
      selectedNodeIds: layer.multiSelections
          .map((final item) => item.nodeId)
          .toList(growable: false),
      selectionMode: layer.multiSelections.length > 1
          ? LiveEditSelectionMode.multi
          : LiveEditSelectionMode.single,
      updateInspectorSelection: true,
      targetDomain: targetDomain,
    );

    layer.selectedElement = element;
    layer.selection = selection;
    layer.ancestry = ancestry;
    layer.multiSelections = <LiveEditSelection>[selection];
    session.lastTouchedAt = DateTime.now().toUtc();
    return selection;
  }

  void _replaceSelectionInMulti(
    final _LiveEditSessionState session,
    final LiveEditSelection selection, {
    final LiveEditTargetDomain? targetDomain,
  }) {
    final layer = _layerForRequest(session, requested: targetDomain);
    final hasExisting = layer.multiSelections.any(
      (final candidate) => candidate.nodeId == selection.nodeId,
    );
    final nextSelections = layer.multiSelections
        .map(
          (final candidate) =>
              candidate.nodeId == selection.nodeId ? selection : candidate,
        )
        .toList(growable: false);
    layer.multiSelections = hasExisting
        ? nextSelections
        : <LiveEditSelection>[...nextSelections, selection];
  }

  LiveEditSelection _hydrateTrackedSelection({
    required final _LiveEditSessionState session,
    required final _TrackedSelectionTarget tracked,
    required final bool updateInspectorSelection,
    final LiveEditTargetDomain? targetDomain,
  }) {
    final layer = _layerForRequest(session, requested: targetDomain);
    final selectedNodeIds = layer.multiSelections
        .map((final selection) => selection.nodeId)
        .toList(growable: false);
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
    layer.selectedElement = tracked.element;
    layer.selection = hydrated;
    layer.ancestry = tracked.ancestry;
    _replaceSelectionInMulti(session, hydrated, targetDomain: targetDomain);
    session.lastTouchedAt = DateTime.now().toUtc();
    return hydrated;
  }

  void _syncSelectionCandidates(
    final _LiveEditSessionState session, {
    final LiveEditTargetDomain? requested,
  }) {
    final layer = _layerForRequest(session, requested: requested);
    final targetDomain = _resolveTargetDomain(session, requested);
    final activeElement = layer.selectedElement;
    layer.selectionCandidates = layer.selectionHitCandidates.indexed
        .map((final entry) {
          final index = entry.$1;
          final hit = entry.$2;
          final renderObject = _previewRenderObjectForElement(hit.element);
          final nodeId =
              WidgetInspectorService.instance.toId(
                hit.element,
                session.objectGroup,
              ) ??
              'live_edit_candidate_${session.sessionId}_$index';
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
            propertyDescriptorProvider: _propertyDescriptorProvider,
          );
          final source = _selectionSourceForElement(
            session,
            hit.element,
            detailsTree,
            targetDomain: targetDomain,
          );
          return LiveEditSelectionCandidate(
            nodeId: nodeId,
            widgetType: hit.element.widget.runtimeType.toString(),
            bounds: _boundsForRenderObject(renderObject),
            depth: index,
            source: source,
            createdByLocalProject:
                targetDomain == LiveEditTargetDomain.toolScene ||
                metadata.createdByLocalProject,
            active: identical(hit.element, activeElement),
          );
        })
        .toList(growable: false);
  }
}

final class _ElementHit {
  const _ElementHit({
    required this.element,
    required this.renderObject,
    required this.ancestry,
    required this.depth,
    this.parentElement,
    this.edgeHit = false,
  });

  final Element element;
  final RenderObject renderObject;
  final List<Map<String, Object?>> ancestry;
  final int depth;
  final Element? parentElement;
  final bool edgeHit;
}

final class _LiveEditSessionState {
  _LiveEditSessionState({required this.sessionId, required this.objectGroup});

  final String sessionId;
  final String objectGroup;
  LiveEditTargetDomain targetDomain = LiveEditTargetDomain.appScene;
  bool overlayEnabled = false;
  final _LiveEditLayerState appLayer = _LiveEditLayerState();
  final _LiveEditLayerState toolLayer = _LiveEditLayerState();
  DateTime lastTouchedAt = DateTime.now().toUtc();

  _LiveEditLayerState layerFor(final LiveEditTargetDomain domain) =>
      switch (domain) {
        LiveEditTargetDomain.appScene => appLayer,
        LiveEditTargetDomain.toolScene => toolLayer,
      };

  _LiveEditLayerState get currentLayer => layerFor(targetDomain);

  Element? get selectedElement => currentLayer.selectedElement;
  set selectedElement(final Element? value) =>
      currentLayer.selectedElement = value;

  LiveEditSelection? get selection => currentLayer.selection;
  set selection(final LiveEditSelection? value) =>
      currentLayer.selection = value;

  LiveEditSelection? get hoverSelection => currentLayer.hoverSelection;
  set hoverSelection(final LiveEditSelection? value) =>
      currentLayer.hoverSelection = value;

  ui.Offset? get hoverPoint => currentLayer.hoverPoint;
  set hoverPoint(final ui.Offset? value) => currentLayer.hoverPoint = value;

  Element? get hoverRootElement => currentLayer.hoverRootElement;
  set hoverRootElement(final Element? value) =>
      currentLayer.hoverRootElement = value;

  int? get hoverViewId => currentLayer.hoverViewId;
  set hoverViewId(final int? value) => currentLayer.hoverViewId = value;

  List<Map<String, Object?>> get ancestry => currentLayer.ancestry;
  set ancestry(final List<Map<String, Object?>> value) =>
      currentLayer.ancestry = value;

  List<_ElementHit> get selectionHitCandidates =>
      currentLayer.selectionHitCandidates;
  set selectionHitCandidates(final List<_ElementHit> value) =>
      currentLayer.selectionHitCandidates = value;

  List<_ElementHit> get hoverHitCandidates => currentLayer.hoverHitCandidates;
  set hoverHitCandidates(final List<_ElementHit> value) =>
      currentLayer.hoverHitCandidates = value;

  List<LiveEditSelectionCandidate> get selectionCandidates =>
      currentLayer.selectionCandidates;
  set selectionCandidates(final List<LiveEditSelectionCandidate> value) =>
      currentLayer.selectionCandidates = value;

  int get hoverPreviewIndex => currentLayer.hoverPreviewIndex;
  set hoverPreviewIndex(final int value) =>
      currentLayer.hoverPreviewIndex = value;

  ui.Offset? get marqueeStart => currentLayer.marqueeStart;
  set marqueeStart(final ui.Offset? value) => currentLayer.marqueeStart = value;

  Rect? get marqueeRect => currentLayer.marqueeRect;
  set marqueeRect(final Rect? value) => currentLayer.marqueeRect = value;

  List<_ElementHit> get marqueeHits => currentLayer.marqueeHits;
  set marqueeHits(final List<_ElementHit> value) =>
      currentLayer.marqueeHits = value;

  List<LiveEditSelection> get marqueeSelections =>
      currentLayer.marqueeSelections;
  set marqueeSelections(final List<LiveEditSelection> value) =>
      currentLayer.marqueeSelections = value;

  List<LiveEditSelection> get multiSelections => currentLayer.multiSelections;
  set multiSelections(final List<LiveEditSelection> value) =>
      currentLayer.multiSelections = value;

  Map<Element, _MarqueeCandidateCacheEntry> get marqueeCache =>
      currentLayer.marqueeCache;

  List<LiveEditDraftChange> get draftChanges => currentLayer.draftChanges;

  Map<String, Object?> get originalExactValues =>
      currentLayer.originalExactValues;

  Set<String> get meaningfulNodeIds => currentLayer.meaningfulNodeIds;

  Map<String, _TrackedSelectionTarget> get trackedSelections =>
      currentLayer.trackedSelections;
}

final class _LiveEditLayerState {
  Element? selectedElement;
  LiveEditSelection? selection;
  LiveEditSelection? hoverSelection;
  ui.Offset? hoverPoint;
  Element? hoverRootElement;
  int? hoverViewId;
  List<Map<String, Object?>> ancestry = const <Map<String, Object?>>[];
  List<_ElementHit> selectionHitCandidates = const <_ElementHit>[];
  List<_ElementHit> hoverHitCandidates = const <_ElementHit>[];
  List<LiveEditSelectionCandidate> selectionCandidates =
      const <LiveEditSelectionCandidate>[];
  int hoverPreviewIndex = 0;
  ui.Offset? marqueeStart;
  Rect? marqueeRect;
  List<_ElementHit> marqueeHits = const <_ElementHit>[];
  List<LiveEditSelection> marqueeSelections = const <LiveEditSelection>[];
  List<LiveEditSelection> multiSelections = const <LiveEditSelection>[];
  final Map<Element, _MarqueeCandidateCacheEntry> marqueeCache =
      <Element, _MarqueeCandidateCacheEntry>{};
  final List<LiveEditDraftChange> draftChanges = <LiveEditDraftChange>[];
  final Map<String, Object?> originalExactValues = <String, Object?>{};
  final Set<String> meaningfulNodeIds = <String>{};
  final Map<String, _TrackedSelectionTarget> trackedSelections =
      <String, _TrackedSelectionTarget>{};
}

final class _TrackedSelectionTarget {
  const _TrackedSelectionTarget({
    required this.element,
    required this.ancestry,
    required this.selection,
  });

  final Element element;
  final List<Map<String, Object?>> ancestry;
  final LiveEditSelection selection;
}
