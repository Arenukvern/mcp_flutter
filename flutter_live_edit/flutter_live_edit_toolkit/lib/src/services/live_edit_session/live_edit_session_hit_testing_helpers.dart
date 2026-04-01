// ignore_for_file: invalid_use_of_protected_member, unused_element

part of '../live_edit_session_service.dart';

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
  return _sameSelectionKeySet(
    left.map((final selection) => selection.nodeId),
    right.map((final selection) => selection.nodeId),
  );
}

List<String> _canonicalSelectionKeys(final Iterable<String> keys) {
  final normalized = keys
      .map((final key) => key.trim())
      .where((final key) => key.isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
  return normalized;
}

bool _sameSelectionKeySet(
  final Iterable<String> left,
  final Iterable<String> right,
) {
  final leftKeys = _canonicalSelectionKeys(left);
  final rightKeys = _canonicalSelectionKeys(right);
  if (leftKeys.length != rightKeys.length) {
    return false;
  }
  for (var index = 0; index < leftKeys.length; index += 1) {
    if (leftKeys[index] != rightKeys[index]) {
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
  }(), 'sourceHint');
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

String _selectionKeyForElement(
  final _LiveEditSessionState session,
  final Element element,
) {
  final inspectorKey = WidgetInspectorService.instance.toId(
    element,
    session.objectGroup,
  );
  if (_hasText(inspectorKey)) {
    return inspectorKey!;
  }
  session.fallbackSelectionKeys.removeWhere(
    (final candidate, final _) => !candidate.mounted,
  );
  return session.fallbackSelectionKeys.putIfAbsent(element, () {
    session.fallbackSelectionKeyCounter += 1;
    final sequence = session.fallbackSelectionKeyCounter.toString().padLeft(
      6,
      '0',
    );
    return 'live_edit_node_${session.sessionId}_$sequence';
  });
}

List<_ElementHit> _dedupeHitsBySelectionKey(
  final _LiveEditSessionState session,
  final List<_ElementHit> hits,
) {
  if (hits.length < 2) {
    return hits;
  }
  final deduped = <String, _ElementHit>{};
  for (final hit in hits) {
    deduped.putIfAbsent(
      _selectionKeyForElement(session, hit.element),
      () => hit,
    );
  }
  return deduped.values.toList(growable: false);
}

InteractionSelectionSet _selectionSetForKeys({
  required final Iterable<String> memberKeys,
  final String? primaryKey,
  required final InteractionSelectionOrigin origin,
  final InteractionFocusKind? focusKind,
}) {
  final normalizedKeys = _canonicalSelectionKeys(memberKeys);
  return InteractionSelectionSet(
    primaryKey: primaryKey,
    memberKeys: normalizedKeys,
    origin: origin,
    focusKind:
        focusKind ??
        (normalizedKeys.length > 1
            ? InteractionFocusKind.selectionSet
            : InteractionFocusKind.node),
  ).normalized(primaryKey: primaryKey);
}

void _assertSelectionSetInvariants(final _LiveEditLayerState layer) {
  assert(() {
    final selectionSet = layer.selectionSet.normalized();
    if (selectionSet.isEmpty) {
      if (layer.selection != null || layer.multiSelections.isNotEmpty) {
        throw StateError('empty selection set must not keep active members');
      }
      return true;
    }
    final primaryKey = selectionSet.primaryKey;
    if (primaryKey == null || !selectionSet.memberKeys.contains(primaryKey)) {
      throw StateError('active selection key must belong to selection set');
    }
    if (selectionSet.isSingle && selectionSet.memberKeys.length != 1) {
      throw StateError('single selection set must have exactly one member');
    }
    final activeSelection = layer.selection;
    if (activeSelection != null) {
      final activeSelectionKey = activeSelection.selectionKey.isNotEmpty
          ? activeSelection.selectionKey
          : activeSelection.nodeId;
      if (activeSelectionKey != primaryKey) {
        throw StateError('active selection must match primary selection key');
      }
      if (!_sameSelectionKeySet(
        activeSelection.selectedNodeIds,
        selectionSet.memberKeys,
      )) {
        throw StateError('selection ids must derive from selection set');
      }
    }
    final candidateKeys = <String>{};
    for (final candidate in layer.selectionCandidates) {
      final candidateKey = candidate.selectionKey.isNotEmpty
          ? candidate.selectionKey
          : candidate.nodeId;
      if (!candidateKeys.add(candidateKey)) {
        throw StateError('candidate list keys must be unique within a frame');
      }
    }
    return true;
  }());
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
