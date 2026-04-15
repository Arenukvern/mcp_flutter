// Pure hit-testing surface extracted from the live-edit session service.
//
// Phase 0 of the selection-state-machine migration (see
// `todo/selection_state_machine.md`) splits raw hit-testing out of the
// session service into this interface. The interface is intentionally
// minimal and stateless: inputs in, results out.
//
// The session service keeps its legacy `part of` helpers and delegates to
// [DefaultHitTestService] so behaviour is identical today; later phases
// will move call sites onto the interface directly.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Pure result of a hit test against the element tree.
///
/// Intentionally public and minimal so it can be produced/consumed without
/// any reference to the session service's private types.
final class HitTestCandidate {
  const HitTestCandidate({
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

  /// True when the point landed inside the inflated edge margin but not
  /// the deflated inner rect. Used by downstream ranking.
  final bool edgeHit;
}

/// Pure interface for element hit-testing at a point or rect.
///
/// Implementations must not retain mutable state between calls — every
/// method is a pure function of its inputs and the live element tree.
abstract interface class HitTestService {
  /// Native-style hit test: gather all elements whose render object bounds
  /// contain [point]. Results are ordered smallest-first with edge hits
  /// prioritised. Elements from foreign views (when [requestedViewId] is
  /// non-null) are filtered out.
  List<HitTestCandidate> hitTestAtPoint({
    required final Element root,
    required final ui.Offset point,
    required final int? requestedViewId,
  });

  /// Rect hit test: gather all visible elements whose render object bounds
  /// intersect [rect]. Used by marquee selection.
  List<HitTestCandidate> hitTestInRect({
    required final Element root,
    required final Rect rect,
    required final int? requestedViewId,
  });
}

/// Margin (logical px) by which a render object's outer rect must be
/// exceeded before a hit is demoted to a non-edge hit. Mirrors the
/// legacy `_edgeHitMargin` constant.
const double kHitTestEdgeMargin = 2;

/// Default implementation of [HitTestService].
///
/// Stateless. Every call walks the live element tree fresh. Behaviour
/// matches the legacy `_nativeElementHitCandidates` and
/// `_collectElementsIntersectingRect` helpers 1:1.
final class DefaultHitTestService implements HitTestService {
  const DefaultHitTestService();

  @override
  List<HitTestCandidate> hitTestAtPoint({
    required final Element root,
    required final ui.Offset point,
    required final int? requestedViewId,
  }) {
    final rootRenderObject = _resolveRenderObject(root);
    if (rootRenderObject == null) {
      return const <HitTestCandidate>[];
    }
    final rootViewId = _viewIdFor(rootRenderObject);
    if (requestedViewId != null &&
        rootViewId != null &&
        rootViewId != requestedViewId) {
      return const <HitTestCandidate>[];
    }

    final regularHits = <RenderObject>[];
    final edgeHits = <RenderObject>[];
    _nativeHitTest(
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
    final results = <HitTestCandidate>[];
    for (final renderObject in ordered) {
      final debugCreator = renderObject.debugCreator;
      if (debugCreator is! DebugCreator) {
        continue;
      }
      final element = debugCreator.element;
      if (!element.mounted || !_isVisibleElement(element)) {
        continue;
      }
      results.add(
        HitTestCandidate(
          element: element,
          renderObject: renderObject,
          ancestry: _ancestryOf(element),
          depth: _depthOf(element),
          edgeHit: edgeHits.contains(renderObject),
        ),
      );
    }
    return results;
  }

  @override
  List<HitTestCandidate> hitTestInRect({
    required final Element root,
    required final Rect rect,
    required final int? requestedViewId,
  }) {
    final results = <HitTestCandidate>[];
    _collectIntersecting(
      root,
      rect: rect,
      results: results,
      requestedViewId: requestedViewId,
    );
    return results;
  }

  void _collectIntersecting(
    final Element root, {
    required final Rect rect,
    required final List<HitTestCandidate> results,
    required final int? requestedViewId,
    final List<Map<String, Object?>> ancestry = const <Map<String, Object?>>[],
    final Element? parentElement,
  }) {
    final renderObject = root.renderObject;
    final bounds = _rectForRenderObject(renderObject);
    if (bounds == null || !bounds.overlaps(rect)) {
      return;
    }
    final viewId = _viewIdFor(renderObject);
    if (requestedViewId != null && viewId != null && viewId != requestedViewId) {
      return;
    }
    if (_isVisibleElement(root)) {
      results.add(
        HitTestCandidate(
          element: root,
          renderObject: renderObject!,
          ancestry: ancestry,
          depth: ancestry.length,
          parentElement: parentElement,
        ),
      );
    }
    root.visitChildElements((final child) {
      _collectIntersecting(
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

  bool _nativeHitTest(
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
      if (_nativeHitTest(hits, edgeHits, position, child, childTransform)) {
        hit = true;
      }
    }

    final bounds = object.semanticBounds;
    if (bounds.contains(localPosition)) {
      hit = true;
      if (!bounds.deflate(kHitTestEdgeMargin).contains(localPosition)) {
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

  RenderObject? _resolveRenderObject(final Element element) {
    final direct = element.renderObject;
    if (direct != null) {
      return direct;
    }
    RenderObject? resolved;
    void visit(final Element candidate) {
      if (resolved != null) {
        return;
      }
      final ro = candidate.renderObject;
      if (ro != null) {
        resolved = ro;
        return;
      }
      candidate.visitChildElements(visit);
    }

    element.visitChildElements(visit);
    return resolved;
  }

  Rect? _rectForRenderObject(final RenderObject? renderObject) {
    if (renderObject == null || !renderObject.attached) {
      return null;
    }
    if (renderObject is RenderBox) {
      if (!renderObject.hasSize) {
        return null;
      }
      final origin = renderObject.localToGlobal(ui.Offset.zero);
      return origin & renderObject.size;
    }
    try {
      return MatrixUtils.transformRect(
        renderObject.getTransformTo(null),
        renderObject.paintBounds,
      );
    } on Exception {
      return null;
    }
  }

  bool _isVisibleElement(final Element element) {
    final renderObject = element.renderObject;
    final bounds = _rectForRenderObject(renderObject);
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

  int? _viewIdFor(final RenderObject? renderObject) {
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

  List<Map<String, Object?>> _ancestryOf(final Element element) {
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

  int _depthOf(final Element element) {
    var depth = 0;
    element.visitAncestorElements((final _) {
      depth += 1;
      return true;
    });
    return depth;
  }
}

