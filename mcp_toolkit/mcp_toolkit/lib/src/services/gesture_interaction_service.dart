// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: avoid_catches_without_on_clauses
// ignore_for_file: use_build_context_synchronously

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'semantic_snapshot_service.dart';

/// A service that drives the running Flutter app using a two-tier strategy:
///
/// 1. **Tier 1 (primary)** — Semantic actions via [SemanticsOwner.performAction].
///    This bypasses hit-testing entirely and directly invokes the handler
///    registered by the widget via `SemanticsConfiguration.onTap` / etc.
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
  static Future<Map<String, Object?>> longPressAtRef(
    final String ref,
  ) async {
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

    // Fallback: focus by tapping, then drive the EditableTextState directly.
    final center = SemanticSnapshotService.resolveCenter(ref);
    if (center != null) {
      await _dispatchTap(center);
      await _waitFrame();
      // Extra settle so the focus/keyboard machinery attaches.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final focused = FocusManager.instance.primaryFocus;
    final context = focused?.context;
    if (context == null) {
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'enter_text',
        'error': 'no_focused_element',
      };
    }

    final editable = context.findAncestorStateOfType<EditableTextState>();
    if (editable == null) {
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'enter_text',
        'error': 'no_editable_state',
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
  /// [direction] is one of `up`, `down`, `left`, `right`. Tries the matching
  /// semantic scroll action first when a [ref] is supplied, otherwise falls
  /// back to a multi-step pointer drag.
  static Future<Map<String, Object?>> scroll({
    required final String direction,
    final String? ref,
    final double distance = 300,
  }) async {
    final action = _scrollActionFor(direction);

    if (ref != null && action != null) {
      final node = SemanticSnapshotService.resolveRef(ref);
      if (node == null) {
        return _refNotFound(ref);
      }
      if (node.getSemanticsData().hasAction(action)) {
        final owner = SemanticSnapshotService.semanticsOwner;
        if (owner != null) {
          owner.performAction(node.id, action);
          await _waitFrame();
          return <String, Object?>{
            'success': true,
            'ref': ref,
            'via': 'semantic_action',
            'action': 'scroll_$direction',
          };
        }
      }
    }

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

    final end = start + _directionDelta(direction, distance);
    await _dispatchDrag(start, end);
    return <String, Object?>{
      'success': true,
      'via': 'pointer_events',
      'action': 'scroll',
      'direction': direction,
      'distance': distance,
      'from': _offsetToMap(start),
      'to': _offsetToMap(end),
    };
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

  // ---------------------------------------------------------------------------
  // Pointer dispatch helpers (tier 2)
  // ---------------------------------------------------------------------------

  static Future<void> _dispatchTap(final ui.Offset position) async {
    final binding = GestureBinding.instance;
    final pointer = _nextPointerId++;
    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        kind: PointerDeviceKind.touch,
        position: position,
        timeStamp: _now(),
        buttons: kPrimaryButton,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        kind: PointerDeviceKind.touch,
        position: position,
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
        kind: PointerDeviceKind.touch,
        position: position,
        timeStamp: _now(),
        buttons: kPrimaryButton,
      ),
    );
    // Hold well past kLongPressTimeout (500 ms).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        kind: PointerDeviceKind.touch,
        position: position,
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
      PointerDownEvent(
        pointer: pointer,
        kind: PointerDeviceKind.touch,
        position: from,
        timeStamp: _now(),
        buttons: kPrimaryButton,
      ),
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
          kind: PointerDeviceKind.touch,
          position: pos,
          delta: pos - last,
          timeStamp: _now(),
          buttons: kPrimaryButton,
        ),
      );
      last = pos;
    }

    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        kind: PointerDeviceKind.touch,
        position: to,
        timeStamp: _now(),
      ),
    );
    await _waitFrame();
  }

  /// Faster drag for swipe / fling — tighter per-step interval feeds higher
  /// velocity into Flutter's velocity tracker.
  static Future<void> _dispatchSwipe(
    final ui.Offset from,
    final ui.Offset to,
  ) =>
      _dispatchDrag(
        from,
        to,
        steps: 8,
        perStep: const Duration(milliseconds: 8),
      );

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  /// Map a cardinal direction to a matching scroll semantic action.
  static SemanticsAction? _scrollActionFor(final String direction) =>
      switch (direction.toLowerCase()) {
        'up' => SemanticsAction.scrollUp,
        'down' => SemanticsAction.scrollDown,
        'left' => SemanticsAction.scrollLeft,
        'right' => SemanticsAction.scrollRight,
        _ => null,
      };

  /// Map a direction string to an [Offset] delta.
  static ui.Offset _directionDelta(
    final String direction,
    final double distance,
  ) => switch (direction.toLowerCase()) {
    'up' => ui.Offset(0, -distance),
    'down' => ui.Offset(0, distance),
    'left' => ui.Offset(-distance, 0),
    'right' => ui.Offset(distance, 0),
    _ => ui.Offset(0, -distance),
  };

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
      <String, Object?>{
        'x': o.dx.roundToDouble(),
        'y': o.dy.roundToDouble(),
      };

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
      _timeBase = _timeBase + const Duration(microseconds: 1);
      return _timeBase;
    }
    _timeBase = elapsed;
    return elapsed;
  }

  /// Wait one vsync frame (~16 ms) so the framework can flush pointer / focus
  /// work triggered by a preceding dispatch.
  static Future<void> _waitFrame() =>
      Future<void>.delayed(const Duration(milliseconds: 16));
}
