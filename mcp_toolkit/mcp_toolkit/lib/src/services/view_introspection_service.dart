import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'application_info.dart';

final class _TreeBuildState {
  _TreeBuildState({required this.maxNodes});

  final int maxNodes;
  int visited = 0;
  bool truncated = false;

  bool consume() {
    if (visited >= maxNodes) {
      truncated = true;
      return false;
    }
    visited++;
    return true;
  }
}

final class _HitResult {
  _HitResult({required this.node, required this.ancestry});

  final Map<String, Object?> node;
  final List<Map<String, Object?>> ancestry;
}

mixin ViewIntrospectionService {
  static const int _defaultMaxNodes = 2500;
  static const int _defaultMaxDepth = 40;

  static Map<String, Object?> buildViewDetailsPayload() {
    final viewMetrics = ApplicationInfo.getViewsInformation();
    final state = _TreeBuildState(maxNodes: _defaultMaxNodes);
    final tree = _buildWidgetTree(state: state, maxDepth: _defaultMaxDepth);

    return {
      'details': viewMetrics.map((final view) => view.toJson()).toList(),
      'widgetTree': tree,
      'summary': {
        'viewCount': viewMetrics.length,
        'nodeCount': state.visited,
        'truncated': state.truncated,
      },
    };
  }

  static Map<String, Object?> inspectWidgetAtPoint({
    required final int x,
    required final int y,
    final int? viewId,
  }) {
    final state = _TreeBuildState(maxNodes: _defaultMaxNodes);
    final tree = _buildWidgetTree(state: state, maxDepth: _defaultMaxDepth);
    final point = ui.Offset(x.toDouble(), y.toDouble());
    final hit = _findHit(
      tree,
      point: point,
      requestedViewId: viewId,
      ancestry: const <Map<String, Object?>>[],
    );

    if (hit == null) {
      return {
        'hit': false,
        'point': {'x': x, 'y': y},
        if (viewId != null) 'viewId': viewId,
        'summary': {'nodeCount': state.visited, 'truncated': state.truncated},
      };
    }

    return {
      'hit': true,
      'point': {'x': x, 'y': y},
      'node': hit.node,
      'ancestry': hit.ancestry,
      if (viewId != null) 'viewId': viewId,
      'summary': {'nodeCount': state.visited, 'truncated': state.truncated},
    };
  }

  static Map<String, Object?> _buildWidgetTree({
    required final _TreeBuildState state,
    required final int maxDepth,
  }) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return {
        'message': 'Widget tree unavailable (no root element attached).',
        'children': const <Object?>[],
      };
    }

    return _buildNode(root, state: state, depth: 0, maxDepth: maxDepth);
  }

  static Map<String, Object?> _buildNode(
    final Element element, {
    required final _TreeBuildState state,
    required final int depth,
    required final int maxDepth,
  }) {
    if (!state.consume()) {
      return {
        'widgetType': element.widget.runtimeType.toString(),
        'depth': depth,
        'truncated': true,
        'children': const <Object?>[],
      };
    }

    final renderObject = element.renderObject;
    final children = <Map<String, Object?>>[];
    if (depth < maxDepth) {
      element.visitChildElements((final child) {
        if (state.visited >= state.maxNodes) {
          state.truncated = true;
          return;
        }
        children.add(
          _buildNode(child, state: state, depth: depth + 1, maxDepth: maxDepth),
        );
      });
    } else {
      state.truncated = true;
    }

    final sourceLocationHint = _sourceLocationHintForElement(element);
    final route = _routeInfoForElement(element);

    return {
      'widgetType': element.widget.runtimeType.toString(),
      if (element.widget.key != null) 'key': element.widget.key.toString(),
      'depth': depth,
      'renderObjectType': renderObject?.runtimeType.toString(),
      if (renderObject != null) 'viewId': _viewIdForRenderObject(renderObject),
      'globalBounds': _globalBoundsForRenderObject(renderObject),
      'semanticBounds': _semanticBoundsForRenderObject(renderObject),
      if (sourceLocationHint != null) 'sourceLocationHint': sourceLocationHint,
      'overflowFlags': _overflowFlagsForRenderObject(renderObject),
      if (route != null) 'route': route,
      'children': children,
    };
  }

  static Map<String, Object?>? _routeInfoForElement(final Element element) {
    try {
      final route = ModalRoute.of(element);
      if (route == null) {
        return null;
      }
      return {
        'name': route.settings.name ?? route.runtimeType.toString(),
        'isCurrent': route.isCurrent,
        'isActive': route.isActive,
      };
    } on Exception {
      return null;
    }
  }

  static int? _viewIdForRenderObject(final RenderObject renderObject) {
    RenderObject current = renderObject;
    while (current.parent is RenderObject) {
      current = current.parent! as RenderObject;
    }

    if (current is RenderView) {
      return current.flutterView.viewId;
    }
    return null;
  }

  static Map<String, Object?> _overflowFlagsForRenderObject(
    final RenderObject? renderObject,
  ) {
    if (renderObject == null) {
      return const <String, Object?>{};
    }
    final diagnostic = renderObject
        .toDiagnosticsNode(style: DiagnosticsTreeStyle.singleLine)
        .toString()
        .toLowerCase();

    return {
      'mentionsOverflow': diagnostic.contains('overflow'),
      'debugNeedsLayout': renderObject.debugNeedsLayout,
      'debugNeedsPaint': renderObject.debugNeedsPaint,
      'attached': renderObject.attached,
    };
  }

  static String? _sourceLocationHintForElement(final Element element) {
    String? creatorChain;
    assert(() {
      try {
        creatorChain = element.debugGetCreatorChain(8);
      } on Exception {
        creatorChain = null;
      }
      return true;
    }());
    if (creatorChain != null && creatorChain!.trim().isNotEmpty) {
      return creatorChain!.trim();
    }

    final diagnostics = element.toDiagnosticsNode(
      style: DiagnosticsTreeStyle.singleLine,
    );
    final text = diagnostics.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, Object?>? _globalBoundsForRenderObject(
    final RenderObject? renderObject,
  ) {
    if (renderObject == null || !renderObject.attached) {
      return null;
    }

    if (renderObject is RenderBox) {
      if (!renderObject.hasSize) {
        return null;
      }
      final origin = renderObject.localToGlobal(ui.Offset.zero);
      final rect = origin & renderObject.size;
      return _rectToJson(rect);
    }

    try {
      final transformed = MatrixUtils.transformRect(
        renderObject.getTransformTo(null),
        renderObject.paintBounds,
      );
      return _rectToJson(transformed);
    } on Exception {
      return null;
    }
  }

  static Map<String, Object?>? _semanticBoundsForRenderObject(
    final RenderObject? renderObject,
  ) {
    if (renderObject == null || !renderObject.attached) {
      return null;
    }
    try {
      final transformed = MatrixUtils.transformRect(
        renderObject.getTransformTo(null),
        renderObject.semanticBounds,
      );
      return _rectToJson(transformed);
    } on Exception {
      return null;
    }
  }

  static Map<String, Object?> _rectToJson(final ui.Rect rect) => {
    'left': rect.left,
    'top': rect.top,
    'right': rect.right,
    'bottom': rect.bottom,
    'width': rect.width,
    'height': rect.height,
  };

  static _HitResult? _findHit(
    final Map<String, Object?> node, {
    required final ui.Offset point,
    required final int? requestedViewId,
    required final List<Map<String, Object?>> ancestry,
  }) {
    final viewId = _asInt(node['viewId']);
    if (requestedViewId != null &&
        viewId != null &&
        viewId != requestedViewId) {
      return null;
    }

    final containsPoint = _nodeContainsPoint(node, point);
    if (!containsPoint) {
      return null;
    }

    final children = switch (node['children']) {
      final List list => list,
      _ => const <Object?>[],
    };

    for (var i = children.length - 1; i >= 0; i--) {
      final child = children[i];
      if (child is! Map) {
        continue;
      }
      final childNode = child.cast<String, Object?>();
      final childHit = _findHit(
        childNode,
        point: point,
        requestedViewId: requestedViewId,
        ancestry: [...ancestry, _compactNodeSummary(node)],
      );
      if (childHit != null) {
        return childHit;
      }
    }

    return _HitResult(node: node, ancestry: ancestry);
  }

  static bool _nodeContainsPoint(
    final Map<String, Object?> node,
    final ui.Offset point,
  ) {
    final bounds = switch (node['globalBounds']) {
      final Map value => value.cast<String, Object?>(),
      _ => null,
    };
    if (bounds == null) {
      return false;
    }

    final left = _asDouble(bounds['left']);
    final top = _asDouble(bounds['top']);
    final right = _asDouble(bounds['right']);
    final bottom = _asDouble(bounds['bottom']);
    if (left == null || top == null || right == null || bottom == null) {
      return false;
    }

    return point.dx >= left &&
        point.dx <= right &&
        point.dy >= top &&
        point.dy <= bottom;
  }

  static Map<String, Object?> _compactNodeSummary(
    final Map<String, Object?> node,
  ) {
    return {
      'widgetType': node['widgetType'],
      if (node['key'] != null) 'key': node['key'],
      if (node['depth'] != null) 'depth': node['depth'],
      if (node['viewId'] != null) 'viewId': node['viewId'],
    };
  }

  static double? _asDouble(final Object? value) {
    return switch (value) {
      final double v => v,
      final int v => v.toDouble(),
      final num v => v.toDouble(),
      final String v => double.tryParse(v),
      _ => null,
    };
  }

  static int? _asInt(final Object? value) {
    return switch (value) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v),
      _ => null,
    };
  }
}
