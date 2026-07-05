// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A service that walks the Flutter semantics tree and produces a compact,
/// AI-friendly snapshot of interactive / meaningful elements.
///
/// Each element receives a sequential stable `ref` (e.g. `"s_0"`) that can be
/// passed to `GestureInteractionService` to interact with the widget.
mixin SemanticSnapshotService {
  /// Ref-to-node mapping populated on the most recent [buildSemanticSnapshot]
  /// call.
  static Map<String, SemanticsNode> _lastRefMap = <String, SemanticsNode>{};

  /// Ref-to-global-bounds mapping populated alongside [_lastRefMap].
  static Map<String, ui.Rect> _lastBoundsMap = <String, ui.Rect>{};

  /// Ref-to-global-center mapping populated alongside [_lastRefMap].
  static Map<String, ui.Offset> _lastCenterMap = <String, ui.Offset>{};

  /// Handle that keeps the semantics tree built for the lifetime of the app.
  /// Created lazily on first snapshot / semantic action call.
  static SemanticsHandle? _semanticsHandle;

  /// Monotonically increasing snapshot counter. Exposed on each snapshot so
  /// clients can detect staleness.
  static int _snapshotCounter = 0;

  /// The snapshot id of the most recently produced snapshot.
  static int get currentSnapshotId => _snapshotCounter;

  /// Look up a [SemanticsNode] captured during the last snapshot.
  static SemanticsNode? resolveRef(final String ref) => _lastRefMap[ref];

  /// Look up the cached global bounds for a ref from the last snapshot.
  static ui.Rect? resolveBounds(final String ref) => _lastBoundsMap[ref];

  /// Look up the cached global center for a ref from the last snapshot.
  static ui.Offset? resolveCenter(final String ref) => _lastCenterMap[ref];

  /// Current logical viewport for pointer-driven interactions.
  static ui.Rect? get viewportRect {
    final renderView = _activeRenderView;
    if (renderView == null) return null;
    final view = renderView.flutterView;
    final dpr = view.devicePixelRatio;
    if (dpr <= 0) return null;
    final physicalSize = view.physicalSize;
    return ui.Rect.fromLTWH(
      0,
      0,
      physicalSize.width / dpr,
      physicalSize.height / dpr,
    );
  }

  /// Visibility metadata for a cached ref from the last snapshot.
  static Map<String, Object?> visibilityForRef(final String ref) {
    final bounds = resolveBounds(ref);
    final center = resolveCenter(ref);
    final viewport = viewportRect;
    return visibilityForBounds(
      bounds: bounds,
      center: center,
      viewport: viewport,
    );
  }

  /// Visibility metadata for logical bounds in the current Flutter viewport.
  static Map<String, Object?> visibilityForBounds({
    required final ui.Rect? bounds,
    required final ui.Offset? center,
    required final ui.Rect? viewport,
  }) {
    final visible =
        bounds != null &&
        viewport != null &&
        bounds.overlaps(viewport) &&
        bounds.width > 0 &&
        bounds.height > 0;
    final centerVisible =
        center != null && viewport != null && viewport.contains(center);
    return <String, Object?>{
      'visibleInViewport': visible,
      'centerInViewport': centerVisible,
      if (bounds != null) 'bounds': _rectToMap(bounds),
      if (viewport != null) 'viewport': _rectToMap(viewport),
      if (center != null)
        'center': <String, Object?>{'x': center.dx, 'y': center.dy},
    };
  }

  /// Ensure the semantics tree is built and return the active
  /// [SemanticsOwner].
  ///
  /// The returned [SemanticsHandle] is retained in a static field so the
  /// tree stays live for the rest of the app's lifetime. Safe to call
  /// multiple times.
  static SemanticsOwner? get semanticsOwner {
    final binding = WidgetsBinding.instance;
    if (_isInFlutterTest()) {
      return binding.pipelineOwner.semanticsOwner;
    }
    _semanticsHandle ??= binding.ensureSemantics();
    return binding.pipelineOwner.semanticsOwner;
  }

  /// Enable the semantics tree at app startup so the first
  /// [buildSemanticSnapshot] call returns a populated tree without having to
  /// wait for a frame. Called from [MCPToolkitBinding.initialize].
  ///
  /// No-op under [TestWidgetsFlutterBinding]: the test harness asserts that
  /// every [SemanticsHandle] is disposed before a test ends, and priming at
  /// bootstrap retains one for the whole process.
  static void primeSemanticsTree() {
    if (_isInFlutterTest()) return;
    _semanticsHandle ??= WidgetsBinding.instance.ensureSemantics();
  }

  static bool _isInFlutterTest() {
    try {
      final binding = WidgetsBinding.instance;
      return binding.runtimeType.toString().contains('Test');
    } on Object {
      return false;
    }
  }

  /// Build a compact semantic snapshot of the current UI.
  ///
  /// Returns a map suitable for JSON serialisation with keys `snapshot_id`,
  /// `nodes`, `nodeCount`, and `truncated`.
  ///
  /// Async so we can await a frame on the (rare) cold path where the
  /// semantics tree hasn't been primed yet — e.g. if
  /// [MCPToolkitBinding.initialize] didn't run for some reason.
  static Future<Map<String, Object?>> buildSemanticSnapshot() =>
      _buildSnapshot(incrementId: true);

  /// Internal: read the snapshot without bumping the public id stream.
  /// Used by `WaitPredicateService` while polling so callers' outstanding
  /// snapshotIds remain valid.
  static Future<Map<String, Object?>> peekSemanticSnapshot() =>
      _buildSnapshot(incrementId: false);

  /// Non-mutating signature of visible descendants under [node].
  ///
  /// This intentionally does not allocate refs, update cached ref/bounds maps,
  /// or bump [currentSnapshotId]. It is for internal movement checks where the
  /// caller already owns a live semantics node and must not invalidate or
  /// silently rebind refs from the last public snapshot.
  static Map<String, Object?> visibleSubtreeSignature(
    final SemanticsNode node,
  ) {
    final viewport = viewportRect;
    if (viewport == null) {
      return <String, Object?>{
        'available': false,
        'targetNodeId': node.id,
        'reason': 'viewport_unavailable',
      };
    }

    final entries = <String>[];
    void walk(final SemanticsNode current) {
      final rect = _globalRect(current);
      final visible =
          current != node &&
          rect.overlaps(viewport) &&
          rect.width > 0 &&
          rect.height > 0;
      if (visible) {
        final data = current.getSemanticsData();
        entries.add(
          [
            current.id,
            _classifyNode(data),
            rect.left.round(),
            rect.top.round(),
            rect.right.round(),
            rect.bottom.round(),
          ].join(':'),
        );
      }
      current.visitChildren((final child) {
        walk(child);
        return true;
      });
    }

    walk(node);
    if (entries.isEmpty) {
      return <String, Object?>{
        'available': false,
        'targetNodeId': node.id,
        'reason': 'no_visible_descendants',
      };
    }

    return <String, Object?>{
      'available': true,
      'targetNodeId': node.id,
      'visibleDescendantCount': entries.length,
      'signatureHash': _stableHash(entries),
    };
  }

  static Future<Map<String, Object?>> _buildSnapshot({
    required final bool incrementId,
  }) async {
    final binding = WidgetsBinding.instance;
    final isTestBinding = _isInFlutterTest();

    // Acquire a SemanticsHandle. In production we cache it for the app
    // lifetime so subsequent snapshots are cheap and avoid the cold-frame
    // wait. Under TestWidgetsFlutterBinding we acquire+dispose per call so
    // the binding's end-of-test handle audit passes (and stale ref/bounds/
    // center caches don't leak between tests).
    final SemanticsHandle handle;
    final bool isCold;
    if (isTestBinding) {
      handle = binding.ensureSemantics();
      isCold = true;
    } else {
      final wasEnabled = _semanticsHandle != null;
      _semanticsHandle ??= binding.ensureSemantics();
      handle = _semanticsHandle!;
      isCold = !wasEnabled;
    }

    try {
      if (isCold) {
        // Cold path only: give Flutter a frame to actually populate the tree.
        binding.scheduleFrame();
        await binding.endOfFrame;
      }

      return await _buildSnapshotBody(incrementId: incrementId);
    } finally {
      if (isTestBinding) {
        handle.dispose();
        // Note: do NOT clear _lastRefMap/_lastBoundsMap/_lastCenterMap here.
        // _buildSnapshotBody's success paths already overwrite them with the
        // fresh snapshot's contents, and clearing in this finally happens
        // synchronously before the awaiter sees the result — which would make
        // any within-test "build snapshot then resolveRef" flow (every
        // gesture-after-snapshot test) fail. The next snapshot call overwrites
        // stale entries on its own, so cross-test isolation is preserved.
      }
    }
  }

  static Future<Map<String, Object?>> _buildSnapshotBody({
    required final bool incrementId,
  }) async {
    final refMap = <String, SemanticsNode>{};
    final boundsMap = <String, ui.Rect>{};
    final centerMap = <String, ui.Offset>{};

    final snapshotId = incrementId ? ++_snapshotCounter : _snapshotCounter;

    SemanticsNode? root;
    try {
      final renderViews = WidgetsBinding.instance.renderViews;
      if (renderViews.isEmpty) {
        _lastRefMap = refMap;
        _lastBoundsMap = boundsMap;
        _lastCenterMap = centerMap;
        return <String, Object?>{
          'snapshot_id': snapshotId,
          'nodes': const <Object?>[],
          'nodeCount': 0,
          'truncated': false,
          'interactionSurface': 'empty',
          'message': 'No render views available.',
        };
      }
      final owner = (_activeRenderView ?? renderViews.first).owner;
      if (owner == null) {
        _lastRefMap = refMap;
        _lastBoundsMap = boundsMap;
        _lastCenterMap = centerMap;
        return <String, Object?>{
          'snapshot_id': snapshotId,
          'nodes': const <Object?>[],
          'nodeCount': 0,
          'truncated': false,
          'interactionSurface': 'empty',
          'message': 'No pipeline owner available.',
        };
      }
      root = owner.semanticsOwner?.rootSemanticsNode;
    } on Exception {
      // Best-effort; fall through to null check below.
    }

    if (root == null) {
      _lastRefMap = refMap;
      _lastBoundsMap = boundsMap;
      _lastCenterMap = centerMap;
      return <String, Object?>{
        'snapshot_id': snapshotId,
        'nodes': const <Object?>[],
        'nodeCount': 0,
        'truncated': false,
        'interactionSurface': 'game_canvas',
        'message':
            'Semantics tree unavailable (common for raw canvas/game UIs). '
            'Use evaluate_dart_expression and screenshots instead of tap-by-ref.',
      };
    }

    var counter = 0;
    const maxNodes = 500;
    var truncated = false;

    final nodes = <Map<String, Object?>>[];

    void walk(final SemanticsNode node, final List<String>? parentChildRefs) {
      if (counter >= maxNodes) {
        truncated = true;
        return;
      }

      final data = node.getSemanticsData();
      final isInteractive = _isInteractiveOrMeaningful(data);

      final childRefs = <String>[];

      // Always walk children even if this node is not interesting.
      if (node.hasChildren) {
        node.visitChildren((final child) {
          walk(child, isInteractive ? childRefs : parentChildRefs);
          return true;
        });
      }

      if (!isInteractive) return;
      if (counter >= maxNodes) {
        truncated = true;
        return;
      }

      final ref = 's_$counter';
      counter++;

      refMap[ref] = node;
      final globalRect = _globalRect(node);
      boundsMap[ref] = globalRect;
      centerMap[ref] = globalRect.center;

      final type = _classifyNode(data);
      final actions = _actionNames(data);

      final nodeMap = <String, Object?>{
        'ref': ref,
        'id': node.id,
        'type': type,
        if (data.identifier.isNotEmpty) 'identifier': data.identifier,
        if (data.label.isNotEmpty) 'label': data.label,
        if (data.value.isNotEmpty) 'value': data.value,
        if (data.hint.isNotEmpty) 'hint': data.hint,
        if (data.hasFlag(SemanticsFlag.hasEnabledState))
          'enabled': data.hasFlag(SemanticsFlag.isEnabled),
        if (data.hasFlag(SemanticsFlag.isFocused)) 'focused': true,
        if (data.hasFlag(SemanticsFlag.isChecked)) 'checked': true,
        if (data.hasFlag(SemanticsFlag.isToggled)) 'toggled': true,
        'bounds': <String, Object?>{
          'left': globalRect.left.roundToDouble(),
          'top': globalRect.top.roundToDouble(),
          'right': globalRect.right.roundToDouble(),
          'bottom': globalRect.bottom.roundToDouble(),
        },
        if (actions.isNotEmpty) 'actions': actions,
        if (childRefs.isNotEmpty) 'children': childRefs,
      };

      nodes.add(nodeMap);
      parentChildRefs?.add(ref);
    }

    walk(root, null);

    _lastRefMap = refMap;
    _lastBoundsMap = boundsMap;
    _lastCenterMap = centerMap;

    final viewport = viewportRect;
    for (final node in nodes) {
      final ref = node['ref'];
      if (ref is! String) continue;
      node.addAll(
        visibilityForBounds(
          bounds: boundsMap[ref],
          center: centerMap[ref],
          viewport: viewport,
        ),
      );
    }

    return <String, Object?>{
      'snapshot_id': snapshotId,
      'nodes': nodes,
      'nodeCount': nodes.length,
      'truncated': truncated,
      'interactionSurface': _classifyInteractionSurface(nodes.length),
      if (viewport != null) 'viewport': _rectToMap(viewport),
    };
  }

  /// How agents should interact with this app's visible surface.
  ///
  /// - [flutter_widgets]: semantics expose tappable refs (normal Material/Cupertino).
  /// - [hybrid]: semantics exist but no interactive refs (custom painters + chrome).
  /// - [game_canvas]: no semantics tree (raw canvas / game loop).
  /// - [empty]: no render surface.
  static String _classifyInteractionSurface(final int interactiveNodeCount) {
    if (interactiveNodeCount > 0) return 'flutter_widgets';
    return 'hybrid';
  }

  static Map<String, Object?> _rectToMap(final ui.Rect rect) =>
      <String, Object?>{
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
        'width': rect.width,
        'height': rect.height,
      };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Compute the global rect of a [SemanticsNode] in **logical
  /// (Flutter-space) pixels**.
  ///
  /// The accumulated transform up the parent chain produces physical-pixel
  /// coordinates because one of the ancestor `SemanticsNode`s carries the
  /// engine's device-pixel-ratio scaling. We divide by the snapshot view's
  /// DPR so synthesized pointer events (taps, hovers, drags) land on the
  /// widget instead of missing it by a factor of DPR on Retina / mobile.
  ///
  /// Longer write-up (symptom, root cause, regression test): repository root
  /// `todo/dpr_resolve_center_bounds.md`.
  static ui.Rect _globalRect(final SemanticsNode node) {
    var rect = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      if (current.transform != null) {
        rect = MatrixUtils.transformRect(current.transform!, rect);
      }
      current = current.parent;
    }
    final renderViews = WidgetsBinding.instance.renderViews;
    if (renderViews.isEmpty) return rect;
    final activeRenderView = _activeRenderView;
    if (activeRenderView == null) return rect;
    final dpr = activeRenderView.flutterView.devicePixelRatio;
    if (dpr == 1.0) return rect;
    return ui.Rect.fromLTRB(
      rect.left / dpr,
      rect.top / dpr,
      rect.right / dpr,
      rect.bottom / dpr,
    );
  }

  static RenderView? get _activeRenderView {
    final renderViews = WidgetsBinding.instance.renderViews;
    if (renderViews.isEmpty) {
      return null;
    }

    final implicitView =
        WidgetsBinding.instance.platformDispatcher.implicitView;
    if (implicitView == null) {
      return renderViews.last;
    }

    for (final renderView in renderViews) {
      if (renderView.flutterView == implicitView ||
          renderView.flutterView.viewId == implicitView.viewId) {
        return renderView;
      }
    }

    return renderViews.last;
  }

  /// Returns `true` when a semantics node is interactive or carries a
  /// meaningful label/value that an AI agent should see.
  static bool _isInteractiveOrMeaningful(final SemanticsData data) {
    // Has a semantic label or value worth surfacing.
    if (data.label.isNotEmpty || data.value.isNotEmpty) return true;

    // Interactive flags.
    if (data.hasFlag(SemanticsFlag.isButton)) return true;
    if (data.hasFlag(SemanticsFlag.isTextField)) return true;
    if (data.hasFlag(SemanticsFlag.isSlider)) return true;
    if (data.hasFlag(SemanticsFlag.isLink)) return true;
    if (data.hasFlag(SemanticsFlag.hasCheckedState)) return true;
    if (data.hasFlag(SemanticsFlag.hasToggledState)) return true;
    if (data.hasFlag(SemanticsFlag.isHeader)) return true;
    if (data.hasFlag(SemanticsFlag.isImage)) return true;
    if (data.hasFlag(SemanticsFlag.isFocusable)) return true;

    // Has interactive actions beyond basic ones.
    if (data.hasAction(SemanticsAction.tap)) return true;
    if (data.hasAction(SemanticsAction.longPress)) return true;
    if (data.hasAction(SemanticsAction.increase)) return true;
    if (data.hasAction(SemanticsAction.decrease)) return true;
    if (data.hasAction(SemanticsAction.setText)) return true;
    if (data.hasAction(SemanticsAction.scrollUp)) return true;
    if (data.hasAction(SemanticsAction.scrollDown)) return true;
    if (data.hasAction(SemanticsAction.scrollLeft)) return true;
    if (data.hasAction(SemanticsAction.scrollRight)) return true;

    return false;
  }

  /// Classify the node into a human-readable type string.
  static String _classifyNode(final SemanticsData data) {
    if (data.hasFlag(SemanticsFlag.isTextField)) return 'textField';
    if (data.hasFlag(SemanticsFlag.isButton)) return 'button';
    if (data.hasFlag(SemanticsFlag.isSlider)) return 'slider';
    if (data.hasFlag(SemanticsFlag.isLink)) return 'link';
    if (data.hasFlag(SemanticsFlag.hasCheckedState)) return 'checkbox';
    if (data.hasFlag(SemanticsFlag.hasToggledState)) return 'switch';
    if (data.hasFlag(SemanticsFlag.isHeader)) return 'header';
    if (data.hasFlag(SemanticsFlag.isImage)) return 'image';
    if (data.hasAction(SemanticsAction.tap)) return 'tappable';
    if (data.hasAction(SemanticsAction.longPress)) return 'longPressable';
    if (data.hasAction(SemanticsAction.scrollUp) ||
        data.hasAction(SemanticsAction.scrollDown) ||
        data.hasAction(SemanticsAction.scrollLeft) ||
        data.hasAction(SemanticsAction.scrollRight)) {
      return 'scrollable';
    }
    if (data.label.isNotEmpty) return 'text';
    return 'widget';
  }

  /// Return the list of available [SemanticsAction] names.
  static List<String> _actionNames(final SemanticsData data) {
    final names = <String>[];
    for (final action in SemanticsAction.values) {
      if (data.hasAction(action)) {
        names.add(_semanticsActionName(action));
      }
    }
    return names;
  }

  static String _semanticsActionName(final SemanticsAction action) {
    if (action == SemanticsAction.tap) return 'tap';
    if (action == SemanticsAction.longPress) return 'longPress';
    if (action == SemanticsAction.scrollLeft) return 'scrollLeft';
    if (action == SemanticsAction.scrollRight) return 'scrollRight';
    if (action == SemanticsAction.scrollUp) return 'scrollUp';
    if (action == SemanticsAction.scrollDown) return 'scrollDown';
    if (action == SemanticsAction.increase) return 'increase';
    if (action == SemanticsAction.decrease) return 'decrease';
    if (action == SemanticsAction.copy) return 'copy';
    if (action == SemanticsAction.cut) return 'cut';
    if (action == SemanticsAction.paste) return 'paste';
    if (action == SemanticsAction.setText) return 'setText';
    if (action == SemanticsAction.dismiss) return 'dismiss';
    if (action == SemanticsAction.moveCursorForwardByCharacter) {
      return 'moveCursorForwardByCharacter';
    }
    if (action == SemanticsAction.moveCursorBackwardByCharacter) {
      return 'moveCursorBackwardByCharacter';
    }
    if (action == SemanticsAction.moveCursorForwardByWord) {
      return 'moveCursorForwardByWord';
    }
    if (action == SemanticsAction.moveCursorBackwardByWord) {
      return 'moveCursorBackwardByWord';
    }
    if (action == SemanticsAction.setSelection) return 'setSelection';
    if (action == SemanticsAction.didGainAccessibilityFocus) {
      return 'didGainAccessibilityFocus';
    }
    if (action == SemanticsAction.didLoseAccessibilityFocus) {
      return 'didLoseAccessibilityFocus';
    }
    if (action == SemanticsAction.focus) return 'focus';
    return action.toString();
  }

  static int _stableHash(final List<String> values) {
    var hash = 0x811c9dc5;
    for (final value in values) {
      for (final unit in value.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0xffffffff;
      }
      hash ^= 0x0a;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
