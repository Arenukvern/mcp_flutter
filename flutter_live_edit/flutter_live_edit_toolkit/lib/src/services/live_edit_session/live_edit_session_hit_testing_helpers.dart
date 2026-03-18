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
