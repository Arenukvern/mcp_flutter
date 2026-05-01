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

  /// Ensure the semantics tree is built and return the active
  /// [SemanticsOwner].
  ///
  /// The returned [SemanticsHandle] is retained in a static field so the
  /// tree stays live for the rest of the app's lifetime. Safe to call
  /// multiple times.
  static SemanticsOwner? get semanticsOwner {
    final binding = WidgetsBinding.instance;
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
          'message': 'No render views available.',
        };
      }
      final owner = renderViews.first.owner;
      if (owner == null) {
        _lastRefMap = refMap;
        _lastBoundsMap = boundsMap;
        _lastCenterMap = centerMap;
        return <String, Object?>{
          'snapshot_id': snapshotId,
          'nodes': const <Object?>[],
          'nodeCount': 0,
          'truncated': false,
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
        'message':
            'Semantics tree unavailable. '
            'Ensure SemanticsBinding is enabled '
            '(e.g. wrap with Semantics).',
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

    return <String, Object?>{
      'snapshot_id': snapshotId,
      'nodes': nodes,
      'nodeCount': nodes.length,
      'truncated': truncated,
    };
  }

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
    final dpr = renderViews.first.flutterView.devicePixelRatio;
    if (dpr == 1.0) return rect;
    return ui.Rect.fromLTRB(
      rect.left / dpr,
      rect.top / dpr,
      rect.right / dpr,
      rect.bottom / dpr,
    );
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
}
