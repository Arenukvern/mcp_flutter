// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: avoid_catches_without_on_clauses
// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'semantic_snapshot_service.dart';

/// A service that drives the running Flutter app using a two-tier strategy:
///
/// 1. **Tier 1 (primary)** — Semantic actions via
///    [SemanticsOwner.performAction]. This bypasses hit-testing entirely and
///    directly invokes the handler registered by the widget via
///    `SemanticsConfiguration.onTap` / etc.
/// 2. **Tier 2 (fallback)** — Synthetic pointer events for gestures that have
///    no semantic equivalent (drag, swipe) or when the target node does not
///    expose the desired semantic action.
mixin GestureInteractionService {
  /// Monotonic clock used to stamp dispatched pointer events.
  static final Stopwatch _clock = Stopwatch()..start();

  /// Last time value returned by [_now]; guarantees strictly monotonic
  /// [Duration] timestamps even if the underlying stopwatch stalls.
  static Duration _timeBase = Duration.zero;

  /// Monotonically increasing pointer id so every gesture sequence is unique.
  static int _nextPointerId = 1;

  // ---------------------------------------------------------------------------
  // Tier 1 / Tier 2 dispatch — public API
  // ---------------------------------------------------------------------------

  /// Tap the widget identified by [ref].
  ///
  /// Prefers a semantic `tap` action when available; otherwise falls back to
  /// synthesised pointer events at the widget's cached global center.
  static Future<Map<String, Object?>> tapAtRef(final String ref) async {
    final node = SemanticSnapshotService.resolveRef(ref);
    if (node == null) {
      return _refNotFound(ref);
    }

    if (node.getSemanticsData().hasAction(SemanticsAction.tap)) {
      final owner = SemanticSnapshotService.semanticsOwner;
      if (owner != null) {
        owner.performAction(node.id, SemanticsAction.tap);
        await _waitFrame();
        // Desktop: performAction alone often skips Material button callbacks.
        if (!kIsWeb) {
          final center = SemanticSnapshotService.resolveCenter(ref);
          if (center != null) {
            await _dispatchTap(center);
            await _waitFrame();
          }
        }
        return <String, Object?>{
          'success': true,
          'ref': ref,
          'via': 'semantic_action',
          'action': 'tap',
        };
      }
    }

    final center = SemanticSnapshotService.resolveCenter(ref);
    if (center == null) {
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'tap',
        'error': 'no_bounds_for_ref',
      };
    }
    if (kIsWeb) {
      // Tier 2 on web: pointer synthesis doesn't reach the browser gesture
      // arena. Tap that reached here had no SemanticsAction.tap — return a
      // structured failure so the agent knows to expose tap semantics.
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'tap',
        'error': 'web_gesture_not_supported',
        'hint':
            'tap on Flutter Web requires the target ref to expose '
            'SemanticsAction.tap. Check the node\'s "actions" in '
            'semantic_snapshot; if absent, add a Semantics(onTap: ...) '
            'wrapper. The Tier 2 pointer fallback does not drive the '
            'browser gesture arena.',
      };
    }
    await _dispatchTap(center);
    return <String, Object?>{
      'success': true,
      'ref': ref,
      'via': 'pointer_events',
      'action': 'tap',
      'point': _offsetToMap(center),
    };
  }

  /// Long-press the widget identified by [ref].
  static Future<Map<String, Object?>> longPressAtRef(final String ref) async {
    final node = SemanticSnapshotService.resolveRef(ref);
    if (node == null) {
      return _refNotFound(ref);
    }

    if (node.getSemanticsData().hasAction(SemanticsAction.longPress)) {
      final owner = SemanticSnapshotService.semanticsOwner;
      if (owner != null) {
        owner.performAction(node.id, SemanticsAction.longPress);
        await _waitFrame();
        return <String, Object?>{
          'success': true,
          'ref': ref,
          'via': 'semantic_action',
          'action': 'longPress',
        };
      }
    }

    final center = SemanticSnapshotService.resolveCenter(ref);
    if (center == null) {
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'long_press',
        'error': 'no_bounds_for_ref',
      };
    }
    if (kIsWeb) {
      // Pointer synthesis via GestureBinding doesn't reach the browser
      // gesture arena on web. Return a structured failure rather than
      // dispatch an event that has no observable effect.
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'long_press',
        'error': 'web_gesture_not_supported',
        'hint':
            'long_press on Flutter Web requires the target ref to expose '
            'SemanticsAction.longPress. Check the node\'s "actions" in '
            'semantic_snapshot; if absent, add a Semantics(onLongPress: ...) '
            'wrapper or handle the interaction a different way (for example '
            'call evaluate_dart_expression to mutate app state directly).',
      };
    }
    await _dispatchLongPress(center);
    return <String, Object?>{
      'success': true,
      'ref': ref,
      'via': 'pointer_events',
      'action': 'long_press',
      'point': _offsetToMap(center),
    };
  }

  /// Enter [text] into the text field identified by [ref].
  ///
  /// Prefers the `setText` semantic action. Falls back to tapping to focus
  /// the field and driving its [EditableTextState] directly via
  /// [EditableTextState.userUpdateTextEditingValue] (which runs
  /// [TextInputFormatter]s and fires `onChanged` correctly).
  static Future<Map<String, Object?>> enterTextAtRef(
    final String ref,
    final String text,
  ) async {
    final node = SemanticSnapshotService.resolveRef(ref);
    if (node == null) {
      return _refNotFound(ref);
    }

    if (node.getSemanticsData().hasAction(SemanticsAction.setText)) {
      final owner = SemanticSnapshotService.semanticsOwner;
      if (owner != null) {
        owner.performAction(node.id, SemanticsAction.setText, text);
        await _waitFrame();
        return <String, Object?>{
          'success': true,
          'ref': ref,
          'via': 'semantic_action',
          'action': 'setText',
          'text': text,
        };
      }
    }

    // Fallback: locate the EditableTextState whose render object overlaps
    // the ref's bounds and drive it directly. This avoids relying on focus,
    // which is not always set by synthetic taps (especially on desktop).
    final bounds = SemanticSnapshotService.resolveBounds(ref);
    EditableTextState? editable = bounds == null
        ? null
        : _findEditableInRect(bounds);

    // If the tree search didn't find one, tap to focus and try the focused
    // element as a last resort.
    if (editable == null) {
      final center = SemanticSnapshotService.resolveCenter(ref);
      if (center != null) {
        await _dispatchTap(center);
        await _waitFrame();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final focused = FocusManager.instance.primaryFocus;
      final context = focused?.context;
      editable = context?.findAncestorStateOfType<EditableTextState>();
    }

    if (editable == null) {
      final refType = _classifyForHint(node);
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'enter_text',
        'error': 'no_editable_state',
        'hint': refType == null
            ? 'The ref does not point to a text field. Call '
                  'semantic_snapshot and pick a node with '
                  'type: "textField" (check the node\'s "type" field).'
            : 'Ref "$ref" is a "$refType", not a text field. Call '
                  'semantic_snapshot and pick a node with '
                  'type: "textField".',
      };
    }

    final value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    editable.userUpdateTextEditingValue(value, SelectionChangedCause.keyboard);
    await _waitFrame();

    return <String, Object?>{
      'success': true,
      'ref': ref,
      'via': 'editable_state',
      'action': 'enter_text',
      'text': text,
    };
  }

  /// Scroll from [ref] (or screen centre) in [direction].
  ///
  /// [direction] is one of `up`, `down`, `left`, `right`. Describes which
  /// content should be revealed (matches Playwright / user language):
  ///
  /// * `down` — reveal content below (finger swipes up)
  /// * `up`   — reveal content above (finger swipes down)
  ///
  /// Dispatch order:
  /// 1. If [ref] is given and the node exposes the matching scroll action,
  ///    use `SemanticsOwner.performAction` (Tier 1).
  /// 2. If no [ref] is given, walk the semantics tree looking for the first
  ///    scrollable that exposes the matching action, and dispatch there.
  ///    This works on desktop where synthetic touch drags don't trigger
  ///    scroll physics.
  /// 3. Fallback: multi-step pointer drag from screen centre.
  static Future<Map<String, Object?>> scroll({
    required final String direction,
    final String? ref,
    final double distance = 300,
  }) async {
    final action = _scrollActionFor(direction);
    Map<String, Object?>? semanticAttempt;

    if (ref != null && action != null) {
      final node = SemanticSnapshotService.resolveRef(ref);
      if (node == null) {
        return _refNotFound(ref);
      }
      if (node.getSemanticsData().hasAction(action)) {
        final result = await _performSemanticScroll(
          node: node,
          action: action,
          direction: direction,
          distance: distance,
          ref: ref,
        );
        if (_scrollMoved(result)) {
          return result;
        }
        semanticAttempt = result;
      }
    }

    // No ref — try to auto-find a scrollable in the semantics tree.
    if (ref == null && action != null) {
      final owner = SemanticSnapshotService.semanticsOwner;
      final root = owner?.rootSemanticsNode;
      if (owner != null && root != null) {
        final target = _findScrollableFor(root, action);
        if (target != null) {
          final result = await _performSemanticScroll(
            node: target,
            action: action,
            direction: direction,
            distance: distance,
            targetNodeId: target.id,
          );
          if (_scrollMoved(result)) {
            return result;
          }
          semanticAttempt = result;
        }
      }
    }

    // Desktop-friendly fallback: PointerScrollEvent (mouse-wheel-style).
    // This is how Flutter on macOS/Linux/Windows actually scrolls; synthetic
    // touch drags don't always drive scroll physics on desktop.
    final start = ref != null
        ? SemanticSnapshotService.resolveCenter(ref)
        : _screenCenter();
    if (start == null && ref != null) {
      return _refNotFound(ref);
    }
    final origin = start ?? _screenCenter();
    final scrollDelta = _scrollDelta(direction, distance);
    final scrollable = _findAnyScrollable();
    final before = _scrollPosition(scrollable);
    if (kIsWeb) {
      // PointerScrollEvent routed through GestureBinding doesn't reach the
      // Flutter Web engine's wheel handler either. Return a structured
      // failure so the agent re-snapshots to find a scrollable ref.
      return <String, Object?>{
        'success': false,
        'ref': ?ref,
        'action': 'scroll_$direction',
        'error': 'web_gesture_not_supported',
        'hint':
            'scroll on Flutter Web requires a ref whose "actions" include '
            'the matching scroll action. Call semantic_snapshot, find a '
            'node with actions scrollUp / scrollDown, and pass its ref to '
            'scroll(ref, direction).',
      };
    }
    await _dispatchScrollSignal(origin, scrollDelta);
    final after = _scrollPosition(scrollable);
    if (before != null && after != null && before == after) {
      return <String, Object?>{
        'success': false,
        'via': 'pointer_scroll_event',
        'action': 'scroll',
        'direction': direction,
        'distance': distance,
        'at': _offsetToMap(origin),
        'scrollDelta': _offsetToMap(scrollDelta),
        'scrollBefore': before,
        'scrollAfter': after,
        'error': 'no_scroll_movement',
        'semanticAttempt': ?semanticAttempt,
        'hint':
            'Scroll input was dispatched, but the scroll position did not '
            'change. Re-snapshot and try a scrollable ref or a different '
            'direction.',
      };
    }
    return <String, Object?>{
      'success': true,
      'via': 'pointer_scroll_event',
      'action': 'scroll',
      'direction': direction,
      'distance': distance,
      'at': _offsetToMap(origin),
      'scrollDelta': _offsetToMap(scrollDelta),
      'scrollBefore': ?before,
      'scrollAfter': ?after,
      'semanticAttempt': ?semanticAttempt,
    };
  }

  static Future<Map<String, Object?>> _performSemanticScroll({
    required final SemanticsNode node,
    required final SemanticsAction action,
    required final String direction,
    required final double distance,
    final String? ref,
    final int? targetNodeId,
  }) async {
    final owner = SemanticSnapshotService.semanticsOwner;
    if (owner == null) {
      return <String, Object?>{
        'success': false,
        'ref': ?ref,
        'targetNodeId': ?targetNodeId,
        'action': 'scroll_$direction',
        'error': 'semantics_owner_unavailable',
      };
    }

    final before = _scrollPosition(node);
    owner.performAction(node.id, action);
    await _waitFrame();
    var after = _scrollPosition(node);
    if (before != null && after != null && before != after) {
      return <String, Object?>{
        'success': true,
        'ref': ?ref,
        'targetNodeId': ?targetNodeId,
        'via': 'semantic_action',
        'action': 'scroll_$direction',
        'scrollBefore': before,
        'scrollAfter': after,
      };
    }

    if (node.getSemanticsData().hasAction(SemanticsAction.scrollToOffset) &&
        before != null) {
      final target = _targetScrollOffset(
        direction: direction,
        distance: distance,
        data: node.getSemanticsData(),
      );
      final Float64List scrollToOffsetArgs;
      if (_isHorizontal(direction)) {
        scrollToOffsetArgs = Float64List.fromList(<double>[target, 0]);
      } else {
        scrollToOffsetArgs = Float64List.fromList(<double>[0, target]);
      }
      owner.performAction(
        node.id,
        SemanticsAction.scrollToOffset,
        scrollToOffsetArgs,
      );
      await _waitFrame();
      after = _scrollPosition(node);
      if (after != null && before != after) {
        return <String, Object?>{
          'success': true,
          'ref': ?ref,
          'targetNodeId': ?targetNodeId,
          'via': 'semantic_scroll_to_offset',
          'action': 'scroll_$direction',
          'distance': distance,
          'scrollBefore': before,
          'scrollAfter': after,
        };
      }
    }

    return <String, Object?>{
      'success': false,
      'ref': ?ref,
      'targetNodeId': ?targetNodeId,
      'via': 'semantic_action',
      'action': 'scroll_$direction',
      'scrollBefore': ?before,
      'scrollAfter': ?after,
      'scrollExtentMin': _finiteOrNull(node.getSemanticsData().scrollExtentMin),
      'scrollExtentMax': _finiteOrNull(node.getSemanticsData().scrollExtentMax),
      'error': 'no_scroll_movement',
    };
  }

  static bool _scrollMoved(final Map<String, Object?> result) =>
      result['success'] == true &&
      result['scrollBefore'] != null &&
      result['scrollAfter'] != null &&
      result['scrollBefore'] != result['scrollAfter'];

  /// Best-effort classification of [node]'s widget type, used only to produce
  /// a helpful hint when `enter_text` can't find an editable state. Returns
  /// null when the node's flags don't suggest a specific type.
  static String? _classifyForHint(final SemanticsNode node) {
    final data = node.getSemanticsData();
    final f = data.flagsCollection;
    if (f.isTextField) return 'textField';
    if (f.isButton) return 'button';
    if (f.isSlider) return 'slider';
    if (f.isToggled != ui.Tristate.none) return 'switch';
    if (f.isChecked != ui.CheckedState.none) return 'checkbox';
    if (f.isHeader) return 'header';
    if (f.isImage) return 'image';
    if (f.isLink) return 'link';
    return null;
  }

  /// Return the [EditableTextState] whose render box overlaps [rect] — or,
  /// if only one editable is on screen, just return that one.
  ///
  /// Lets enter_text find the right field without depending on focus,
  /// which synthetic taps don't reliably transfer on desktop.
  static EditableTextState? _findEditableInRect(final ui.Rect rect) {
    final centre = rect.center;
    final editables = <EditableTextState>[];
    EditableTextState? spatialMatch;

    void visit(final Element element) {
      final state = element is StatefulElement ? element.state : null;
      if (state is EditableTextState) {
        editables.add(state);
        if (spatialMatch == null) {
          final renderObject = element.renderObject;
          if (renderObject is RenderBox && renderObject.hasSize) {
            final origin = renderObject.localToGlobal(ui.Offset.zero);
            final bounds = origin & renderObject.size;
            if (bounds.contains(centre) || bounds.overlaps(rect)) {
              spatialMatch = state;
            }
          }
        }
      }
      element.visitChildElements(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);

    if (spatialMatch != null) return spatialMatch;
    if (editables.length == 1) return editables.first;
    return null;
  }

  /// Walk the semantics tree depth-first and return the first node that
  /// advertises [action]. Returns `null` if none is found.
  static SemanticsNode? _findScrollableFor(
    final SemanticsNode root,
    final SemanticsAction action,
  ) {
    SemanticsNode? result;
    void visit(final SemanticsNode node) {
      if (result != null) return;
      if (node.getSemanticsData().hasAction(action)) {
        result = node;
        return;
      }
      node.visitChildren((final child) {
        visit(child);
        return result == null;
      });
    }

    visit(root);
    return result;
  }

  static SemanticsNode? _findAnyScrollable() {
    final root = SemanticSnapshotService.semanticsOwner?.rootSemanticsNode;
    if (root == null) return null;
    SemanticsNode? result;
    void visit(final SemanticsNode node) {
      if (result != null) return;
      final data = node.getSemanticsData();
      if (data.hasAction(SemanticsAction.scrollUp) ||
          data.hasAction(SemanticsAction.scrollDown) ||
          data.hasAction(SemanticsAction.scrollLeft) ||
          data.hasAction(SemanticsAction.scrollRight) ||
          data.hasAction(SemanticsAction.scrollToOffset)) {
        result = node;
        return;
      }
      node.visitChildren((final child) {
        visit(child);
        return result == null;
      });
    }

    visit(root);
    return result;
  }

  /// Swipe from [ref] (or screen centre) in [direction].
  ///
  /// Always uses pointer events (higher pointer velocity than [scroll]).
  static Future<Map<String, Object?>> swipe({
    required final String direction,
    final String? ref,
    final double distance = 300,
  }) async {
    ui.Offset start;
    if (ref != null) {
      final center = SemanticSnapshotService.resolveCenter(ref);
      if (center == null) {
        return _refNotFound(ref);
      }
      start = center;
    } else {
      start = _screenCenter();
    }

    // On Flutter Web, synthetic pointer events fed to
    // GestureBinding.handlePointerEvent don't drive real scroll physics —
    // the browser owns that pipeline. If [ref] is a scrollable that
    // exposes the matching scroll action, redirect to the Tier 1 semantic
    // action path. Otherwise return a structured failure so the agent can
    // pick a different strategy (typically `scroll(ref, direction)`).
    if (kIsWeb) {
      if (ref != null) {
        final scrollAction = _scrollActionFor(direction);
        if (scrollAction != null) {
          final node = SemanticSnapshotService.resolveRef(ref);
          final owner = SemanticSnapshotService.semanticsOwner;
          if (node != null &&
              owner != null &&
              node.getSemanticsData().hasAction(scrollAction)) {
            owner.performAction(node.id, scrollAction);
            await _waitFrame();
            return <String, Object?>{
              'success': true,
              'ref': ref,
              'via': 'semantic_action_fallback',
              'action': 'swipe_$direction',
              'note':
                  'On web, swipe redirected to SemanticsAction.scroll because '
                  'pointer synthesis does not drive browser scroll physics.',
            };
          }
        }
      }
      return <String, Object?>{
        'success': false,
        'ref': ?ref,
        'action': 'swipe',
        'error': 'web_gesture_not_supported',
        'hint':
            'swipe on Flutter Web requires a scrollable ref whose "actions" '
            'include the matching scroll action (scrollUp / scrollDown / '
            'scrollLeft / scrollRight). Use semantic_snapshot to locate one, '
            'then prefer scroll(ref, direction) directly. Pointer-event '
            'synthesis cannot drive Flutter Web scroll physics.',
      };
    }
    final end = start + _directionDelta(direction, distance);
    await _dispatchSwipe(start, end);
    return <String, Object?>{
      'success': true,
      'via': 'pointer_events',
      'action': 'swipe',
      'direction': direction,
      'distance': distance,
      'from': _offsetToMap(start),
      'to': _offsetToMap(end),
    };
  }

  /// Drag from the centre of [fromRef] to the centre of [toRef].
  static Future<Map<String, Object?>> drag({
    required final String fromRef,
    required final String toRef,
  }) async {
    final from = SemanticSnapshotService.resolveCenter(fromRef);
    if (from == null) {
      return _refNotFound(fromRef);
    }
    final to = SemanticSnapshotService.resolveCenter(toRef);
    if (to == null) {
      return _refNotFound(toRef);
    }
    if (kIsWeb) {
      // Drag has no Tier 1 semantic equivalent. Pointer synthesis via
      // GestureBinding doesn't reach Flutter Web's gesture arena, so we
      // return a structured failure rather than fake success.
      return <String, Object?>{
        'success': false,
        'fromRef': fromRef,
        'toRef': toRef,
        'action': 'drag',
        'error': 'web_gesture_not_supported',
        'hint':
            'drag is not supported on Flutter Web. There is no semantic-action '
            'equivalent, and pointer-event synthesis does not drive the '
            'browser gesture arena. If the intent is scrolling, use '
            'scroll(ref, direction). If the intent is a picker / reorder, '
            'mutate state directly via evaluate_dart_expression.',
      };
    }
    await _dispatchDrag(from, to, steps: 12);
    return <String, Object?>{
      'success': true,
      'via': 'pointer_events',
      'action': 'drag',
      'fromRef': fromRef,
      'toRef': toRef,
      'from': _offsetToMap(from),
      'to': _offsetToMap(to),
    };
  }

  /// Synthesize a mouse hover at the centre of the widget identified by
  /// [ref]. Drives `MouseRegion.onEnter`/`onExit` via the framework's
  /// mouse tracker (which computes enter/exit transitions from position
  /// changes).
  ///
  /// Primes the tracker with an off-screen hover first so the target hover
  /// is unambiguously a position change — without priming, a single hover
  /// at the target may not produce an enter transition if the tracker's
  /// last-known position is unset or already over the target.
  static Future<Map<String, Object?>> hoverAtRef(final String ref) async {
    final node = SemanticSnapshotService.resolveRef(ref);
    if (node == null) {
      return _refNotFound(ref);
    }
    final centre = SemanticSnapshotService.resolveCenter(ref);
    if (centre == null) {
      return _refNotFound(ref);
    }

    // Register the device first — MouseTracker only tracks hover events from
    // pointers that announced themselves via PointerAddedEvent; otherwise the
    // hover may be filtered out and MouseRegion.onEnter never fires.
    const pointer = 1;
    GestureBinding.instance
      ..handlePointerEvent(
        PointerAddedEvent(
          pointer: pointer,
          position: const ui.Offset(-100, -100),
          kind: PointerDeviceKind.mouse,
          timeStamp: _now(),
        ),
      )
      // Prime: hover off-screen first so the target hover is a clean
      // position change. Reuses pointer id so the mouse tracker treats
      // them as the same logical mouse.
      ..handlePointerEvent(
        PointerHoverEvent(
          pointer: pointer,
          position: const ui.Offset(-100, -100),
          kind: PointerDeviceKind.mouse,
          timeStamp: _now(),
        ),
      )
      ..handlePointerEvent(
        PointerHoverEvent(
          pointer: pointer,
          position: centre,
          kind: PointerDeviceKind.mouse,
          timeStamp: _now(),
        ),
      );
    await _waitFrame();

    return <String, Object?>{
      'success': true,
      'ref': ref,
      'position': <String, Object?>{'dx': centre.dx, 'dy': centre.dy},
    };
  }

  // ---------------------------------------------------------------------------
  // Pointer dispatch helpers (tier 2)
  // ---------------------------------------------------------------------------

  static Future<void> _dispatchTap(final ui.Offset position) async {
    final binding = GestureBinding.instance;
    final pointer = _nextPointerId++;
    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.mouse,
        timeStamp: _now(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.mouse,
        timeStamp: _now(),
      ),
    );
    await _waitFrame();
  }

  static Future<void> _dispatchLongPress(final ui.Offset position) async {
    final binding = GestureBinding.instance;
    final pointer = _nextPointerId++;
    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.mouse,
        timeStamp: _now(),
      ),
    );
    // Hold well past kLongPressTimeout (500 ms).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.mouse,
        timeStamp: _now(),
      ),
    );
    await _waitFrame();
  }

  static Future<void> _dispatchDrag(
    final ui.Offset from,
    final ui.Offset to, {
    final int steps = 10,
    final Duration perStep = const Duration(milliseconds: 16),
  }) async {
    final binding = GestureBinding.instance;
    final pointer = _nextPointerId++;
    binding.handlePointerEvent(
      PointerDownEvent(pointer: pointer, position: from, timeStamp: _now()),
    );

    final dx = (to.dx - from.dx) / steps;
    final dy = (to.dy - from.dy) / steps;
    var last = from;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(perStep);
      final pos = ui.Offset(from.dx + dx * i, from.dy + dy * i);
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: pos,
          delta: pos - last,
          timeStamp: _now(),
        ),
      );
      last = pos;
    }

    binding.handlePointerEvent(
      PointerUpEvent(pointer: pointer, position: to, timeStamp: _now()),
    );
    await _waitFrame();
  }

  /// Faster drag for swipe / fling — tighter per-step interval feeds higher
  /// velocity into Flutter's velocity tracker.
  static Future<void> _dispatchSwipe(
    final ui.Offset from,
    final ui.Offset to,
  ) => _dispatchDrag(
    from,
    to,
    steps: 8,
    perStep: const Duration(milliseconds: 8),
  );

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  /// Map a user-facing direction (Playwright convention: direction = which
  /// content the agent wants to reveal) to Flutter's [SemanticsAction].
  ///
  /// Flutter's `SemanticsAction.scrollUp` corresponds to a finger moving up —
  /// i.e. the content scrolls up and content below is revealed. So to reveal
  /// content *below*, the agent's `direction: "down"` maps to `scrollUp`.
  static SemanticsAction? _scrollActionFor(final String direction) =>
      switch (direction.toLowerCase()) {
        'down' => SemanticsAction.scrollUp,
        'up' => SemanticsAction.scrollDown,
        'right' => SemanticsAction.scrollLeft,
        'left' => SemanticsAction.scrollRight,
        _ => null,
      };

  /// Dispatch a single [PointerScrollEvent] (signal event) at [position].
  ///
  /// This is the desktop-native scroll path — equivalent to a trackpad swipe
  /// or mouse-wheel tick. Flutter routes this through `PointerSignalResolver`
  /// and scroll physics pick it up the same way real wheel input does.
  static Future<void> _dispatchScrollSignal(
    final ui.Offset position,
    final ui.Offset scrollDelta,
  ) async {
    GestureBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        position: position,
        scrollDelta: scrollDelta,
        timeStamp: _now(),
      ),
    );
    await _waitFrame();
  }

  /// Convert a user-facing direction to a scroll delta for
  /// [PointerScrollEvent]. Unlike pointer-drag deltas, scroll-event deltas
  /// already follow the "direction content moves" convention directly —
  /// `scrollDelta.dy > 0` scrolls content *up* and reveals content below.
  static ui.Offset _scrollDelta(
    final String direction,
    final double distance,
  ) => switch (direction.toLowerCase()) {
    'up' => ui.Offset(0, -distance),
    'down' => ui.Offset(0, distance),
    'left' => ui.Offset(-distance, 0),
    'right' => ui.Offset(distance, 0),
    _ => ui.Offset(0, distance),
  };

  /// Map a direction string to a pointer-delta.
  ///
  /// `direction` describes which way the *content* should move — i.e. which
  /// content the user wants to reveal. This matches Playwright's convention
  /// and how users talk about scrolling ("scroll down to see the footer").
  ///
  /// To reveal content below (direction=down), the finger swipes *up*
  /// (negative y). Hence the inversion from the name to the delta.
  static ui.Offset _directionDelta(
    final String direction,
    final double distance,
  ) => switch (direction.toLowerCase()) {
    'up' => ui.Offset(0, distance), // reveal content above → finger down
    'down' => ui.Offset(0, -distance), // reveal content below → finger up
    'left' => ui.Offset(distance, 0), // reveal content left → finger right
    'right' => ui.Offset(-distance, 0), // reveal content right → finger left
    _ => ui.Offset(0, -distance),
  };

  static double? _scrollPosition(final SemanticsNode? node) {
    if (node == null) return null;
    return _finiteOrNull(node.getSemanticsData().scrollPosition);
  }

  static double _targetScrollOffset({
    required final String direction,
    required final double distance,
    required final SemanticsData data,
  }) {
    final before = _finiteOrNull(data.scrollPosition) ?? 0;
    final requested = switch (direction.toLowerCase()) {
      'down' || 'right' => before + distance,
      'up' || 'left' => before - distance,
      _ => before + distance,
    };
    final min = _finiteOrNull(data.scrollExtentMin) ?? 0;
    final max = _finiteOrNull(data.scrollExtentMax) ?? requested;
    return requested.clamp(min, max);
  }

  static double? _finiteOrNull(final double? value) =>
      value != null && value.isFinite ? value : null;

  static bool _isHorizontal(final String direction) =>
      direction.toLowerCase() == 'left' || direction.toLowerCase() == 'right';

  /// Return the centre of the first render view.
  static ui.Offset _screenCenter() {
    try {
      final view = WidgetsBinding.instance.renderViews.first;
      final size = view.size;
      return ui.Offset(size.width / 2, size.height / 2);
    } catch (_) {
      return const ui.Offset(200, 400);
    }
  }

  static Map<String, Object?> _offsetToMap(final ui.Offset o) =>
      <String, Object?>{'x': o.dx.roundToDouble(), 'y': o.dy.roundToDouble()};

  static Map<String, Object?> _refNotFound(final String ref) =>
      <String, Object?>{
        'success': false,
        'ref': ref,
        'error':
            'Ref "$ref" not found. '
            'Call semantic_snapshot first to populate refs.',
      };

  /// Produce a strictly monotonically increasing [Duration] since app start.
  ///
  /// Pointer event dispatch asserts monotonic timestamps per pointer; this
  /// guarantees the property even if [Stopwatch] stalls at a single tick.
  static Duration _now() {
    final elapsed = _clock.elapsed;
    if (elapsed <= _timeBase) {
      return _timeBase = _timeBase + const Duration(microseconds: 1);
    }
    _timeBase = elapsed;
    return elapsed;
  }

  /// Wait one vsync frame (~16 ms) so the framework can flush pointer / focus
  /// work triggered by a preceding dispatch.
  static Future<void> _waitFrame() =>
      Future<void>.delayed(const Duration(milliseconds: 16));
}
