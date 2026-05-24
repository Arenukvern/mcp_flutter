// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:from_json_to_json/from_json_to_json.dart';

import 'application_info.dart';
import 'platform_view_hints.dart';

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

/// Builds structured widget-tree payloads for MCP view introspection tools.
mixin ViewIntrospectionService {
  static const int _defaultMaxNodes = 2500;
  /// MaterialApp / router scaffolding can exceed 40 levels before route content.
  static const int _defaultMaxDepth = 96;

  /// Widget tree plus multi-view metrics for the `view_details` MCP tool.
  static Map<String, Object?> buildViewDetailsPayload() {
    final viewMetrics = ApplicationInfo.getViewsInformation();
    final state = _TreeBuildState(maxNodes: _defaultMaxNodes);
    final tree = _buildWidgetTree(state: state, maxDepth: _defaultMaxDepth);

    final captureHints = _captureHintsFromLiveElements();

    return {
      'details': viewMetrics.map((final view) => view.toJson()).toList(),
      'widgetTree': tree,
      'captureHints': captureHints.toCaptureHintsJson(),
      'summary': {
        'viewCount': viewMetrics.length,
        'nodeCount': state.visited,
        'truncated': state.truncated,
        'platformViewsDetected': captureHints.platformViewsDetected,
      },
    };
  }

  /// Hit-tests [RenderView]s at logical ([x], [y]) and summarizes selection.
  static Map<String, Object?> inspectWidgetAtPoint({
    required final int x,
    required final int y,
    final int? viewId,
  }) {
    final point = ui.Offset(x.toDouble(), y.toDouble());
    final renderView = _selectRenderView(
      requestedViewId: viewId,
      position: point,
    );
    if (renderView == null) {
      return {
        'hit': false,
        'point': {'x': x, 'y': y},
        'viewId': ?viewId,
        'summary': const <String, Object?>{},
        'message': 'No Flutter render view is available for inspection.',
      };
    }

    final hitTestResult = HitTestResult();
    renderView.hitTest(hitTestResult, position: point);
    final targets = hitTestResult.path
        .map((final entry) => entry.target)
        .whereType<RenderObject>()
        .toList(growable: false);
    final target = targets.isEmpty ? null : targets.first;
    final element = (target?.debugCreator as DebugCreator?)?.element;
    final summary = _selectedSummary(target);

    return {
      'hit': target != null,
      'point': {'x': x, 'y': y},
      'requestedViewId': viewId,
      'viewId': renderView.flutterView.viewId,
      'view': _viewSummary(renderView),
      'summary': summary,
      'selectedNode': summary,
      'renderHitTargets': targets.take(8).map(_renderObjectSummary).toList(),
      if (target != null) 'renderObject': _renderObjectSummary(target),
      if (element != null) 'element': _elementSummary(element),
      if (target != null) 'semantic': _semanticSummary(target),
      'message': target == null
          ? 'No widget matched ($x, $y).'
          : 'Inspected widget at ($x, $y).',
    };
  }

  /// Full element walk for [captureHints] (no depth cap; tree JSON stays bounded).
  static PlatformViewHints _captureHintsFromLiveElements() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return PlatformViewHints.none;
    }
    final matches = <PlatformViewMatch>[];
    var visited = 0;
    const maxVisit = 8000;

    void visit(final Element element, final int depth) {
      if (visited >= maxVisit) {
        return;
      }
      visited++;
      accumulatePlatformViewSignals(
        widgetType: element.widget.runtimeType.toString(),
        renderObjectType: element.renderObject?.runtimeType.toString(),
        depth: depth,
        globalBounds: _globalBoundsForRenderObject(element.renderObject),
        matches: matches,
      );
      element.visitChildElements((final child) => visit(child, depth + 1));
    }

    visit(root, 0);
    return platformViewHintsFromMatches(matches);
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
      'sourceLocationHint': ?sourceLocationHint,
      'overflowFlags': _overflowFlagsForRenderObject(renderObject),
      'route': ?route,
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
      current = current.parent!;
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
    }(), 'creator chain is optional; failures fall back to diagnostics');
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

  static RenderView? _selectRenderView({
    required final int? requestedViewId,
    required final ui.Offset position,
  }) {
    final binding = WidgetsBinding.instance;
    final renderViews = binding.renderViews.toList(growable: false);
    if (renderViews.isEmpty) {
      return null;
    }

    if (requestedViewId != null) {
      for (final renderView in renderViews) {
        if (renderView.flutterView.viewId == requestedViewId) {
          return renderView;
        }
      }
      return null;
    }

    for (final renderView in renderViews.reversed) {
      final bounds = _globalBoundsForRenderObject(renderView);
      if (_rectContainsPoint(bounds, position)) {
        return renderView;
      }
    }

    return renderViews.last;
  }

  static bool _rectContainsPoint(
    final Map<String, Object?>? rect,
    final ui.Offset point,
  ) {
    if (rect == null) {
      return false;
    }
    final left = jsonDecodeDouble(rect['left']);
    final top = jsonDecodeDouble(rect['top']);
    final right = jsonDecodeDouble(rect['right']);
    final bottom = jsonDecodeDouble(rect['bottom']);
    if (left == 0 || top == 0 || right == 0 || bottom == 0) {
      return false;
    }
    return point.dx >= left &&
        point.dx <= right &&
        point.dy >= top &&
        point.dy <= bottom;
  }

  static Map<String, Object?> _viewSummary(final RenderView renderView) => {
    'viewId': renderView.flutterView.viewId,
    'renderObjectType': renderView.runtimeType.toString(),
    'globalBounds': _globalBoundsForRenderObject(renderView),
    'semanticBounds': _semanticBoundsForRenderObject(renderView),
  };

  static Map<String, Object?> _renderObjectSummary(final RenderObject object) {
    final element = (object.debugCreator as DebugCreator?)?.element;
    return {
      'renderObjectType': object.runtimeType.toString(),
      'widgetType': element?.widget.runtimeType.toString(),
      if (element?.widget.key != null) 'key': '${element?.widget.key}',
      'viewId': _viewIdForRenderObject(object),
      'globalBounds': _globalBoundsForRenderObject(object),
      'semanticBounds': _semanticBoundsForRenderObject(object),
      'sourceLocationHint': element == null
          ? null
          : _sourceLocationHintForElement(element),
      'overflowFlags': _overflowFlagsForRenderObject(object),
    };
  }

  static Map<String, Object?> _elementSummary(final Element element) => {
    'widgetType': element.widget.runtimeType.toString(),
    if (element.widget.key != null) 'key': '${element.widget.key}',
    'renderObjectType': element.renderObject?.runtimeType.toString(),
    'sourceLocationHint': _sourceLocationHintForElement(element),
    'route': ?_routeInfoForElement(element),
  };

  static Map<String, Object?> _semanticSummary(final RenderObject object) {
    final semantics = <String, Object?>{};
    assert(() {
      try {
        final configuration = object.debugSemantics;
        if (configuration == null) {
          return true;
        }
        if (configuration.label.isNotEmpty) {
          semantics['label'] = configuration.label;
        }
        if (configuration.value.isNotEmpty) {
          semantics['value'] = configuration.value;
        }
        if (configuration.hint.isNotEmpty) {
          semantics['hint'] = configuration.hint;
        }
      } on Exception {
        // Best effort only in debug introspection.
      }
      return true;
    }(), 'semantic summary is best-effort in debug mode');
    return semantics;
  }

  static Map<String, Object?> _selectedSummary(final RenderObject? target) {
    if (target == null) {
      return const <String, Object?>{};
    }

    const groupName = 'mcp_toolkit.inspect_widget_at_point';
    final inspector = WidgetInspectorService.instance..disposeGroup(groupName);
    try {
      inspector.setSelection(target, groupName);
      final selection = inspector.getSelectedSummaryWidget(null, groupName);
      return _decodeSummaryJson(selection);
    } finally {
      inspector.disposeGroup(groupName);
    }
  }

  static Map<String, Object?> _decodeSummaryJson(final Object? raw) {
    if (raw is Map<String, Object?>) {
      return raw;
    }
    if (raw is Map) {
      return raw.cast<String, Object?>();
    }
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    }
    return const <String, Object?>{};
  }
}
