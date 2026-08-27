// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: avoid_catches_without_on_clauses
// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'background_frame_pump.dart';
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

  /// The pointer device every synthesised event is attributed to.
  ///
  /// Must stay clear of the platform's own device ids — the embedder numbers
  /// its mouse `0` on desktop. [MouseTracker] keys its per-device state
  /// machine on `device` (never on `pointer`) and asserts that a device's
  /// event stream is bracketed by add/remove: sharing the id parks a
  /// synthetic hover in the real mouse's slot, and the `PointerAddedEvent`
  /// the embedder sends when the cursor next enters the window trips that
  /// assert inside the gesture binding.
  static const int _syntheticDevice = 1 << 20;

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
    if (!node.attached) {
      return _staleRef(ref, 'tap');
    }
    final disabled = _disabledRef(node, ref, 'tap');
    if (disabled != null) return disabled;
    final visibility = SemanticSnapshotService.liveVisibilityForRef(ref);
    if (visibility['centerInViewport'] != true) {
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'tap',
        'error': 'target_outside_viewport',
        'message':
            'Target center is outside the visible viewport. Reveal or scroll '
            'the target before tapping.',
        'hint':
            'The node exists but sits off screen, so a pointer event at its '
            'centre would land outside the window. Call reveal_search with '
            'its identifier or text to scroll it into view and get a fresh '
            'ref.',
        ...visibility,
      };
    }

    if (node.getSemanticsData().hasAction(SemanticsAction.tap)) {
      final owner = SemanticSnapshotService.semanticsOwner;
      if (owner != null) {
        owner.performAction(node.id, SemanticsAction.tap);
        _releaseSyntheticDevice();
        await _waitFrame();
        return <String, Object?>{
          'success': true,
          'ref': ref,
          'via': 'semantic_action',
          'action': 'tap',
        };
      }
    }

    final center = _liveCenter(ref);
    if (center == null) {
      return _noBoundsForRef(ref, 'tap');
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
    final occupant = _occupantAtPoint(node, center);
    await _dispatchTap(center);
    return <String, Object?>{
      'success': true,
      'ref': ref,
      'via': 'pointer_events',
      'action': 'tap',
      'point': _offsetToMap(center),
      'pointBelongsTo': ?occupant,
      if (occupant != null)
        'hint':
            'The node exposed no tap action, so the tap was aimed at the '
            'centre of its box — which "$occupant" occupies. Whatever '
            'reacted, reacted there.',
    };
  }

  /// Long-press the widget identified by [ref].
  static Future<Map<String, Object?>> longPressAtRef(final String ref) async {
    final node = SemanticSnapshotService.resolveRef(ref);
    if (node == null) {
      return _refNotFound(ref);
    }
    if (!node.attached) {
      return _staleRef(ref, 'long_press');
    }
    final disabled = _disabledRef(node, ref, 'long_press');
    if (disabled != null) return disabled;

    if (node.getSemanticsData().hasAction(SemanticsAction.longPress)) {
      final owner = SemanticSnapshotService.semanticsOwner;
      if (owner != null) {
        owner.performAction(node.id, SemanticsAction.longPress);
        _releaseSyntheticDevice();
        await _waitFrame();
        return <String, Object?>{
          'success': true,
          'ref': ref,
          'via': 'semantic_action',
          'action': 'longPress',
        };
      }
    }

    final center = _liveCenter(ref);
    if (center == null) {
      return _noBoundsForRef(ref, 'long_press');
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
    final occupant = _occupantAtPoint(node, center);
    await _dispatchLongPress(center);
    return <String, Object?>{
      'success': true,
      'ref': ref,
      'via': 'pointer_events',
      'action': 'long_press',
      'point': _offsetToMap(center),
      'pointBelongsTo': ?occupant,
      if (occupant != null)
        'hint':
            'The node exposed no long-press action, so the press was aimed at '
            'the centre of its box — which "$occupant" occupies. Whatever '
            'reacted, reacted there.',
    };
  }

  /// Enter [text] into the text field identified by [ref].
  ///
  /// Prefers the `setText` semantic action, which the field exposes only while
  /// it holds focus. Otherwise drives the [EditableTextState] that lives inside
  /// the ref's own bounds via [EditableTextState.userUpdateTextEditingValue]
  /// (which runs [TextInputFormatter]s and fires `onChanged` correctly).
  ///
  /// Both paths report what the field holds afterwards in `verified`: the
  /// second one reads the controller back, so a value the field refused —
  /// or a hit on the wrong field — fails instead of reporting success.
  static Future<Map<String, Object?>> enterTextAtRef(
    final String ref,
    final String text,
  ) async {
    final node = SemanticSnapshotService.resolveRef(ref);
    if (node == null) {
      return _refNotFound(ref);
    }
    if (!node.attached) {
      return _staleRef(ref, 'enter_text');
    }
    final disabled = _disabledRef(node, ref, 'enter_text');
    if (disabled != null) return disabled;

    if (node.getSemanticsData().hasAction(SemanticsAction.setText)) {
      final owner = SemanticSnapshotService.semanticsOwner;
      if (owner != null) {
        owner.performAction(node.id, SemanticsAction.setText, text);
        _releaseSyntheticDevice();
        await _waitFrame();
        // The field's semantics value is the only read-back this path has.
        // A masking or formatting field legitimately reports something else,
        // so a mismatch is surfaced rather than treated as a failure.
        final applied = node.attached ? node.getSemanticsData().value : null;
        return <String, Object?>{
          'success': true,
          'ref': ref,
          'via': 'semantic_action',
          'action': 'setText',
          'text': text,
          'verified': applied == text,
          'appliedText': applied,
          'verifiedBy': 'semantics_value',
          if (applied != text)
            'hint':
                'The field now reports "$applied". Fields that mask, format, '
                'or publish no semantics value do this legitimately; otherwise '
                're-snapshot and read the node value to see where the text '
                'went.',
        };
      }
    }

    // Fallback: locate the EditableTextState that sits inside the ref's own
    // bounds and drive it directly. This avoids relying on focus, which is not
    // always set by synthetic taps (especially on desktop).
    final bounds = _liveBounds(ref);
    final isTextField = node.getSemanticsData().flagsCollection.isTextField;
    EditableTextState? editable = bounds == null
        ? null
        : _findEditableForNode(node, bounds);

    // A ref that is not a text field has no business reaching the focus-based
    // last resort: it would drive whichever field happens to hold focus and
    // report success for a write the caller never asked for.
    if (editable == null && !isTextField) {
      final refType = _classifyForHint(node);
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'enter_text',
        'error': 'not_a_text_field',
        'hint': refType == null
            ? 'The ref does not point to a text field. Call '
                  'semantic_snapshot and pick a node with '
                  'type: "textField" (check the node\'s "type" field).'
            : 'Ref "$ref" is a "$refType", not a text field. Call '
                  'semantic_snapshot and pick a node with '
                  'type: "textField".',
      };
    }

    // If the tree search didn't find one, tap to focus and try the focused
    // element as a last resort.
    if (editable == null) {
      final center = _liveCenter(ref);
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
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'action': 'enter_text',
        'error': 'no_editable_state',
        'hint':
            'Ref "$ref" is a text field, but no EditableTextState was found '
            'inside its bounds or on the focused element. Re-snapshot and try '
            'again, or set the value through evaluate_dart_expression.',
      };
    }

    final previous = editable.textEditingValue;
    final value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    editable.userUpdateTextEditingValue(value, SelectionChangedCause.keyboard);
    await _waitFrame();

    final applied = editable.textEditingValue.text;
    // Nothing landed at all: the field refused the write outright (read-only,
    // or a formatter that rejects every character of it). Anything the field
    // did keep is a value the caller now has to reckon with, not a failure —
    // a formatter trimming "3 days" to "3" is the same thing a person typing
    // there would get.
    if (applied.isEmpty && text.isNotEmpty) {
      // The rejected write still wiped whatever the field held. A refusal that
      // leaves the field emptied is a change the caller never asked for, so
      // put the old value back before reporting.
      if (previous.text.isNotEmpty) {
        editable.userUpdateTextEditingValue(
          previous,
          SelectionChangedCause.keyboard,
        );
        await _waitFrame();
      }
      return <String, Object?>{
        'success': false,
        'ref': ref,
        'via': 'editable_state',
        'action': 'enter_text',
        'error': 'text_not_applied',
        'text': text,
        'appliedText': editable.textEditingValue.text,
        'hint':
            'The field kept none of "$text" — an input formatter rejected it '
            'outright, or the field is read-only. It was left holding '
            '"${previous.text}", as it was before the call.',
      };
    }

    return <String, Object?>{
      'success': true,
      'ref': ref,
      'via': 'editable_state',
      'action': 'enter_text',
      'text': text,
      'verified': applied == text,
      'appliedText': applied,
      'verifiedBy': 'controller',
      if (applied != text)
        'hint':
            'The field holds "$applied" — an input formatter reshaped the '
            'value on the way in. Read appliedText as what the field now '
            'contains.',
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
      if (!node.attached) {
        return _staleRef(ref, 'scroll_$direction');
      }
      // A ref that scrolls itself is the target; otherwise the caller means
      // the list the ref sits in. A row carries no scroll action of its own,
      // and its centre is usually off screen — which is the very reason the
      // caller is scrolling — so neither tier can act on the row itself.
      final scrollTarget = node.getSemanticsData().hasAction(action)
          ? node
          : _scrollableAncestorOf(node, action);
      if (scrollTarget != null) {
        final result = await _performSemanticScroll(
          node: scrollTarget,
          action: action,
          direction: direction,
          distance: distance,
          ref: ref,
          targetNodeId: scrollTarget.id == node.id ? null : scrollTarget.id,
        );
        if (_scrollMoved(result)) {
          return result;
        }
        semanticAttempt = result;
      }
    }

    // No ref — scroll what sits in the middle of the screen, which is what
    // "scroll the page" means to the caller. When that scrollable cannot take
    // the action it is already at that edge, and the pointer tier below
    // reports about it. Widening to the whole tree only makes sense when
    // nothing scrollable is under the pointer at all: its first match is as
    // likely to be a header strip as the content, and a boundary report about
    // that strip describes a widget the caller never meant.
    if (ref == null && action != null) {
      final owner = SemanticSnapshotService.semanticsOwner;
      final root = owner?.rootSemanticsNode;
      if (owner != null && root != null) {
        final underPointer = _findScrollableAt(_screenCenter());
        final target = underPointer == null
            ? _findScrollableFor(root, action)
            : (underPointer.getSemanticsData().hasAction(action)
                  ? underPointer
                  : null);
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

    if (kIsWeb) {
      if (semanticAttempt != null) {
        return semanticAttempt;
      }
      return <String, Object?>{
        'success': false,
        'ref': ?ref,
        'action': 'scroll_$direction',
        'error': 'unsupported_scroll_action',
        'hint':
            'No Flutter Web semantics node exposed the matching scroll '
            'action for this direction. Call semantic_snapshot and choose a '
            'scrollable ref with scrollUp / scrollDown / scrollLeft / '
            'scrollRight.',
      };
    }

    // Desktop-friendly fallback: PointerScrollEvent (mouse-wheel-style).
    // This is how Flutter on macOS/Linux/Windows actually scrolls; synthetic
    // touch drags don't always drive scroll physics on desktop.
    final start = ref != null ? _liveCenter(ref) : _screenCenter();
    if (start == null && ref != null) {
      return _refNotFound(ref);
    }
    final origin = start ?? _screenCenter();
    final scrollDelta = _scrollDelta(direction, distance);
    final scrollable = _findScrollableAt(origin);
    if (scrollable == null) {
      // A scrollable that answered the semantic tier already said what it
      // could do — its boundary report beats "there is nothing under the
      // pointer", which is about a fallback the caller never asked for.
      if (semanticAttempt != null) {
        return semanticAttempt;
      }
      return <String, Object?>{
        'success': false,
        'ref': ?ref,
        'via': 'pointer_scroll_event',
        'action': 'scroll_$direction',
        'at': _offsetToMap(origin),
        'error': 'no_scrollable_at_point',
        'semanticAttempt': ?semanticAttempt,
        'hint':
            'Nothing under that point advertises a scroll action, so a wheel '
            'event there would have had nothing to drive. Call '
            'semantic_snapshot and pass the ref of a node with scrollUp / '
            'scrollDown / scrollLeft / scrollRight in its "actions".',
      };
    }
    final before = await _restingScrollPosition(scrollable);
    await _dispatchScrollSignal(origin, scrollDelta);
    final settle = await _settledScrollPosition(scrollable, before);
    final after = settle.position;
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
      if (!settle.settled) 'settled': false,
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
        'hint':
            'The app is publishing no semantics tree, so no node can be asked '
            'to scroll. Semantics are built on demand: call semantic_snapshot '
            'first — it turns them on — and retry.',
      };
    }

    final before = await _restingScrollPosition(node);
    final beforeSignature = kIsWeb
        ? SemanticSnapshotService.visibleSubtreeSignature(node)
        : null;

    // An exact offset beats a page whenever the scrollable offers one: the
    // page action moves by whatever the viewport calls a page and ignores
    // `distance` entirely, so asking for 400 px and travelling 642 is the
    // normal outcome rather than an edge case.
    final exact = await _scrollToOffsetAttempt(
      owner: owner,
      node: node,
      direction: direction,
      distance: distance,
      before: before,
      beforeSignature: beforeSignature,
      ref: ref,
      targetNodeId: targetNodeId,
    );
    if (exact != null) return exact;

    owner.performAction(node.id, action);
    _releaseSyntheticDevice();
    await _waitSemanticScrollFrame();
    final settle = await _settledScrollPosition(node, before);
    final after = settle.position;
    if (before != null && after != null && before != after) {
      final travelled = (after - before).abs();
      return <String, Object?>{
        'success': true,
        'ref': ?ref,
        'targetNodeId': ?targetNodeId,
        'via': 'semantic_action',
        'action': 'scroll_$direction',
        'scrollBefore': before,
        'scrollAfter': after,
        if (!settle.settled) 'settled': false,
        // Reached only where an exact offset was unavailable or refused, so
        // the page the scrollable chose is all `distance` could ever have got.
        if ((travelled - distance).abs() > distance * 0.25)
          'hint':
              'This scrollable takes no exact offset, so it moved by a '
              'viewport page — ${travelled.round()} px rather than the '
              '$distance requested. Read scrollAfter for where it stopped.',
      };
    }
    final actionProgress = kIsWeb
        ? _webScrollSubtreeProgress(
            beforeSignature: beforeSignature,
            node: node,
          )
        : null;
    if (actionProgress != null) {
      return <String, Object?>{
        'success': true,
        'ref': ?ref,
        'targetNodeId': ?targetNodeId,
        'via': 'semantic_action_web',
        'action': 'scroll_$direction',
        'platform': 'web',
        'distance': distance,
        'scrollBefore': ?before,
        'scrollAfter': ?after,
        ...actionProgress,
      };
    }

    final offsetResult = await _scrollToOffsetAttempt(
      owner: owner,
      node: node,
      direction: direction,
      distance: distance,
      before: before,
      beforeSignature: beforeSignature,
      ref: ref,
      targetNodeId: targetNodeId,
    );
    if (offsetResult != null) return offsetResult;

    final extentMin = _finiteOrNull(node.getSemanticsData().scrollExtentMin);
    final extentMax = _finiteOrNull(node.getSemanticsData().scrollExtentMax);
    // A scrollable whose extents coincide has no range to travel, so its
    // offset sits at both ends at once — that is content fitting the viewport,
    // not the end of a list, and saying "already at its end" would send the
    // caller scrolling the other way for nothing.
    final edge = extentMin == extentMax
        ? null
        : switch (before) {
            final double at when at == extentMin => 'start',
            final double at when at == extentMax => 'end',
            _ => null,
          };
    return <String, Object?>{
      'success': false,
      'ref': ?ref,
      'targetNodeId': ?targetNodeId,
      'via': 'semantic_action',
      'action': 'scroll_$direction',
      'scrollBefore': ?before,
      'scrollAfter': ?after,
      'scrollExtentMin': extentMin,
      'scrollExtentMax': extentMax,
      'error': 'no_scroll_movement',
      'platform': kIsWeb ? 'web' : 'flutter',
      'movementVerified': false,
      'dispatched': true,
      'hint': edge != null
          ? 'The scrollable took the action but is already at its $edge, so '
                'there was nowhere left to go in that direction. Scroll the '
                'other way, or read this as the $edge of the list.'
          : 'The scrollable took the action and its offset never changed. Its '
                'content fits the viewport, or an inner list owns the rows — '
                'call semantic_snapshot and pass the ref of the node whose '
                'scrollExtentMax exceeds its own height.',
    };
  }

  /// Ask [node] to land on an exact offset [distance] away, if it can.
  ///
  /// Returns the success payload, or `null` when the node takes no offset
  /// action or the offset moved nothing — the caller then falls back to the
  /// page action.
  static Future<Map<String, Object?>?> _scrollToOffsetAttempt({
    required final SemanticsOwner owner,
    required final SemanticsNode node,
    required final String direction,
    required final double distance,
    required final double? before,
    required final Map<String, Object?>? beforeSignature,
    required final String? ref,
    required final int? targetNodeId,
  }) async {
    if (!node.getSemanticsData().hasAction(SemanticsAction.scrollToOffset)) {
      return null;
    }
    final target = _targetScrollOffset(
      direction: direction,
      distance: distance,
      data: node.getSemanticsData(),
    );
    final scrollToOffsetArgs = _isHorizontal(direction)
        ? Float64List.fromList(<double>[target, 0])
        : Float64List.fromList(<double>[0, target]);
    owner.performAction(
      node.id,
      SemanticsAction.scrollToOffset,
      scrollToOffsetArgs,
    );
    // This tier can now answer before the page action runs, so releasing the
    // synthetic pointer is its job too: a device left connected parks a
    // synthetic hover in the real mouse's slot.
    _releaseSyntheticDevice();
    await _waitSemanticScrollFrame();
    final settle = await _settledScrollPosition(node, before);
    final after = settle.position;
    if (before != null && after != null && before != after) {
      return <String, Object?>{
        'success': true,
        'ref': ?ref,
        'targetNodeId': ?targetNodeId,
        'via': 'semantic_scroll_to_offset',
        'action': 'scroll_$direction',
        'distance': distance,
        'scrollBefore': before,
        'scrollAfter': after,
        if (!settle.settled) 'settled': false,
      };
    }
    final offsetProgress = kIsWeb
        ? _webScrollSubtreeProgress(
            beforeSignature: beforeSignature,
            node: node,
          )
        : null;
    if (offsetProgress != null) {
      return <String, Object?>{
        'success': true,
        'ref': ?ref,
        'targetNodeId': ?targetNodeId,
        'via': 'semantic_scroll_to_offset_web',
        'action': 'scroll_$direction',
        'platform': 'web',
        'distance': distance,
        'scrollBefore': ?before,
        'scrollAfter': ?after,
        'scrollToOffset': target,
        ...offsetProgress,
      };
    }
    return null;
  }

  /// [node]'s scroll position once it stops changing.
  ///
  /// A list relaxing out of an overscroll reports a different offset every
  /// frame. Taking the "before" reading off that motion makes the next
  /// comparison measure the settling instead of the scroll, and the springback
  /// to the edge then counts as movement — a scroll that did nothing reported
  /// as one that did.
  static Future<double?> _restingScrollPosition(
    final SemanticsNode? node,
  ) async {
    var previous = _scrollPosition(node);
    for (var attempt = 0; attempt < 25; attempt++) {
      await _waitFrame();
      final current = _scrollPosition(node);
      if (current == previous) return current;
      previous = current;
    }
    return previous;
  }

  static bool _scrollMoved(final Map<String, Object?> result) =>
      result['success'] == true &&
      ((result['scrollBefore'] != null &&
              result['scrollAfter'] != null &&
              result['scrollBefore'] != result['scrollAfter']) ||
          result['movementVerified'] == true);

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
  /// Whether [start] sits in a subtree that the semantics tree cannot see.
  ///
  /// A cross-fade keeps both branches mounted at the same coordinates and hides
  /// one from semantics; an offstage branch is laid out and equally invisible.
  /// Their fields answer geometry questions exactly like the visible ones, so
  /// a search by position alone happily writes into the branch nobody is
  /// looking at — and then reads its own write back as confirmation.
  static bool _hiddenFromSemantics(final RenderObject start) {
    RenderObject? current = start;
    while (current != null) {
      if (current is RenderExcludeSemantics && current.excluding) return true;
      if (current is RenderOffstage && current.offstage) return true;
      current = current.parent;
    }
    return false;
  }

  /// The [EditableTextState] that belongs to [node].
  ///
  /// A candidate that owns the target's own semantics node is the answer.
  /// Failing that, containment either way — the field sits inside the ref's
  /// bounds, or the ref's centre sits inside the field — makes the match the
  /// caller's target. A plain overlap test would also claim a field the ref
  /// merely touches at the edge, and writing into a neighbour is
  /// indistinguishable from writing nowhere.
  static EditableTextState? _findEditableForNode(
    final SemanticsNode node,
    final ui.Rect rect,
  ) {
    final centre = rect.center;
    EditableTextState? semanticMatch;
    EditableTextState? spatialMatch;

    void visit(final Element element) {
      if (semanticMatch != null) return;
      final state = element is StatefulElement ? element.state : null;
      if (state is EditableTextState) {
        final renderObject = element.renderObject;
        if (renderObject is RenderBox &&
            renderObject.hasSize &&
            !_hiddenFromSemantics(renderObject)) {
          if (renderObject.debugSemantics?.id == node.id) {
            semanticMatch = state;
            return;
          }
          if (spatialMatch == null) {
            final origin = renderObject.localToGlobal(ui.Offset.zero);
            final bounds = origin & renderObject.size;
            if (bounds.contains(centre) || rect.contains(bounds.center)) {
              spatialMatch = state;
            }
          }
        }
      }
      element.visitChildElements(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);

    return semanticMatch ?? spatialMatch;
  }

  /// The nearest ancestor of [node] that advertises [action].
  ///
  /// Climbing beats searching by position here: the row whose ref was passed
  /// is off screen more often than not, so its coordinates point outside every
  /// scrollable on screen. Its parent chain says which list owns it no matter
  /// where it currently sits.
  static SemanticsNode? _scrollableAncestorOf(
    final SemanticsNode node,
    final SemanticsAction action,
  ) {
    SemanticsNode? anyScrollable;
    var current = node.parent;
    while (current != null) {
      final data = current.getSemanticsData();
      if (data.hasAction(action)) return current;
      anyScrollable ??= _isScrollable(data) ? current : null;
      current = current.parent;
    }
    // No ancestor can move that way — a list already at the edge the caller is
    // asking for drops the direction from its actions. The nearest scrollable
    // is still the answer: it reports which edge it is sitting at, whereas
    // falling through to a wheel event aims at the ref's own centre, which is
    // off screen exactly when the caller needs the scroll.
    return anyScrollable;
  }

  /// Whether [data] belongs to a node that scrolls at all, in any direction.
  static bool _isScrollable(final SemanticsData data) =>
      data.hasAction(SemanticsAction.scrollUp) ||
      data.hasAction(SemanticsAction.scrollDown) ||
      data.hasAction(SemanticsAction.scrollLeft) ||
      data.hasAction(SemanticsAction.scrollRight) ||
      data.hasAction(SemanticsAction.scrollToOffset);

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

  /// The innermost scrollable whose bounds contain [point].
  ///
  /// The pointer-scroll fallback proves it moved something by reading a scroll
  /// position before and after. Reading it off the first scrollable in the tree
  /// would measure a list nowhere near the pointer — in a shell with a scrolling
  /// header that is always the header — and report movement, or the lack of it,
  /// for the wrong widget. Descending keeps the innermost match, which is the
  /// one a wheel event at [point] actually drives.
  static SemanticsNode? _findScrollableAt(final ui.Offset point) {
    final root = SemanticSnapshotService.semanticsOwner?.rootSemanticsNode;
    if (root == null) return null;
    SemanticsNode? result;
    var smallest = double.infinity;
    // The whole tree is walked rather than descended into: a node's rect does
    // not have to cover its children, so pruning on the parent would hide the
    // scrollable that actually sits under the point.
    void visit(final SemanticsNode node) {
      final data = node.getSemanticsData();
      if (_isScrollable(data)) {
        final rect = SemanticSnapshotService.liveRect(node);
        if (rect != null && rect.contains(point)) {
          // Nested scrollables all contain the point; the tightest one is what
          // a wheel event there drives.
          final area = rect.width * rect.height;
          if (area <= smallest) {
            smallest = area;
            result = node;
          }
        }
      }
      node.visitChildren((final child) {
        visit(child);
        return true;
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
      final node = SemanticSnapshotService.resolveRef(ref);
      if (node == null) {
        return _refNotFound(ref);
      }
      if (!node.attached) {
        return _staleRef(ref, 'swipe_$direction');
      }
      final center = _liveCenter(ref);
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
          if (node != null && node.getSemanticsData().hasAction(scrollAction)) {
            final result = await scroll(
              ref: ref,
              direction: direction,
              distance: distance,
            );
            if (result['success'] == true) {
              result
                ..['action'] = 'swipe_$direction'
                ..['note'] =
                    'On web, swipe redirected to the verified semantic '
                    'scroll path because pointer synthesis does not drive '
                    'browser scroll physics.';
              return result;
            }
            return <String, Object?>{
              ...result,
              'ref': ref,
              'action': 'swipe_$direction',
              'note':
                  'On web, swipe redirected to SemanticsAction.scroll because '
                  'pointer synthesis does not drive browser scroll physics, '
                  'but no movement was verified.',
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
    // A fling carries past the finger, so `distance` describes the gesture and
    // not the travel. Where something scrollable sits under the start point,
    // its own offset before and after is the only honest measure of what the
    // swipe did.
    final scrollable = _findScrollableAt(start);
    final before = await _restingScrollPosition(scrollable);
    await _dispatchSwipe(start, end);
    final settle = await _settledScrollPosition(scrollable, before);
    final after = settle.position;
    if (before != null && after != null && before == after) {
      return <String, Object?>{
        'success': false,
        'ref': ?ref,
        'via': 'pointer_events',
        'action': 'swipe_$direction',
        'direction': direction,
        'distance': distance,
        'from': _offsetToMap(start),
        'to': _offsetToMap(end),
        'scrollBefore': before,
        'scrollAfter': after,
        'error': 'no_scroll_movement',
        'hint':
            'The swipe was dispatched, but the scrollable under the start '
            'point did not move. It may already be at that edge; check '
            'scrollBefore against the list extents, or swipe the other way.',
      };
    }
    return <String, Object?>{
      'success': true,
      'ref': ?ref,
      'via': 'pointer_events',
      'action': 'swipe',
      'direction': direction,
      'distance': distance,
      'from': _offsetToMap(start),
      'to': _offsetToMap(end),
      'scrollBefore': ?before,
      'scrollAfter': ?after,
      if (!settle.settled) 'settled': false,
    };
  }

  /// Drag from the centre of [fromRef] to the centre of [toRef].
  ///
  /// [kind] selects the synthesized pointer device; when null, defaults to
  /// [PointerDeviceKind.mouse] on desktop platforms and
  /// [PointerDeviceKind.touch] elsewhere — the device a real user would
  /// drag with there. See [_dispatchDrag] for how the kind decides the
  /// gesture-arena outcome.
  static Future<Map<String, Object?>> drag({
    required final String fromRef,
    required final String toRef,
    final PointerDeviceKind? kind,
  }) async {
    for (final ref in <String>[fromRef, toRef]) {
      final node = SemanticSnapshotService.resolveRef(ref);
      if (node == null) {
        return _refNotFound(ref);
      }
      if (!node.attached) {
        return _staleRef(ref, 'drag');
      }
    }
    final from = _liveCenter(fromRef);
    if (from == null) {
      return _refNotFound(fromRef);
    }
    final to = _liveCenter(toRef);
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
    final effectiveKind = kind ?? _defaultDragKind();
    await _dispatchDrag(from, to, steps: 12, kind: effectiveKind);
    return <String, Object?>{
      'success': true,
      'via': 'pointer_events',
      'action': 'drag',
      'kind': effectiveKind.name,
      'fromRef': fromRef,
      'toRef': toRef,
      'from': _offsetToMap(from),
      'to': _offsetToMap(to),
    };
  }

  /// The pointer device a real user drags with on the running platform.
  static PointerDeviceKind _defaultDragKind() =>
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => PointerDeviceKind.mouse,
        _ => PointerDeviceKind.touch,
      };

  /// Synthesize a mouse hover at the centre of the widget identified by
  /// [ref]. Drives `MouseRegion.onEnter`/`onExit` via the framework's
  /// mouse tracker (which computes enter/exit transitions from position
  /// changes).
  ///
  /// Primes the tracker with an off-screen hover first so the target hover
  /// is unambiguously a position change — without priming, a single hover
  /// at the target may not produce an enter transition if the tracker's
  /// last-known position is unset or already over the target.
  ///
  /// The hover is left parked on the target so a revealed affordance stays on
  /// screen for the interaction that follows; every other entry point ends
  /// with [_releaseSyntheticDevice] — whichever tier served it — which fires
  /// the matching `onExit`.
  static Future<Map<String, Object?>> hoverAtRef(final String ref) async {
    final node = SemanticSnapshotService.resolveRef(ref);
    if (node == null) {
      return _refNotFound(ref);
    }
    if (!node.attached) {
      return _staleRef(ref, 'hover');
    }
    final centre = _liveCenter(ref);
    if (centre == null) {
      return _refNotFound(ref);
    }

    // Drive hover as position changes only: hover events are enough to update
    // the tracked position and fire MouseRegion transitions, so the device
    // never needs an add/remove pair to become live.
    final pointer = _nextPointerId++;
    final binding = GestureBinding.instance;
    const prime = ui.Offset(-100, -100);
    binding
      // Prime: hover off-screen first so the target hover is a clean position
      // change.
      ..handlePointerEvent(
        PointerHoverEvent(
          pointer: pointer,
          position: prime,
          kind: PointerDeviceKind.mouse,
          device: _syntheticDevice,
          timeStamp: _now(),
        ),
      )
      ..handlePointerEvent(
        PointerHoverEvent(
          pointer: pointer,
          position: centre,
          kind: PointerDeviceKind.mouse,
          device: _syntheticDevice,
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

  /// Detach [_syntheticDevice] from [MouseTracker] once a gesture is done, so
  /// its hover state does not outlive the gesture: the removal fires
  /// `MouseRegion.onExit` for whatever the synthetic pointer was over. Moving
  /// the real mouse cannot clear it — that is a different device.
  ///
  /// Called from every gesture entry point, semantic and pointer alike, so the
  /// lifetime of a parked hover does not depend on which tier served the
  /// gesture. A no-op when the device holds no mouse state, and the removal
  /// carries no position because [MouseTracker] clears the annotations of a
  /// removed device without hit-testing.
  static void _releaseSyntheticDevice() {
    GestureBinding.instance.handlePointerEvent(
      PointerRemovedEvent(
        pointer: _nextPointerId++,
        kind: PointerDeviceKind.mouse,
        device: _syntheticDevice,
        timeStamp: _now(),
      ),
    );
  }

  static Future<void> _dispatchTap(final ui.Offset position) async {
    final binding = GestureBinding.instance;
    final pointer = _nextPointerId++;
    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.mouse,
        device: _syntheticDevice,
        timeStamp: _now(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.mouse,
        device: _syntheticDevice,
        timeStamp: _now(),
      ),
    );
    _releaseSyntheticDevice();
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
        device: _syntheticDevice,
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
        device: _syntheticDevice,
        timeStamp: _now(),
      ),
    );
    _releaseSyntheticDevice();
    await _waitFrame();
  }

  /// Dispatches a press-move-release sequence as [kind] pointer events.
  ///
  /// [kind] decides which recognizers compete for the gesture. Mouse wins a
  /// drag-and-drop cleanly on desktop: scrollables don't track mouse drags
  /// (default [ScrollBehavior.dragDevices] excludes the mouse), so the
  /// target's pan recognizer takes the gesture uncontested — matching a
  /// real user drag. Touch keeps scrollables in the arena, which a
  /// swipe/fling relies on.
  static Future<void> _dispatchDrag(
    final ui.Offset from,
    final ui.Offset to, {
    final int steps = 10,
    final Duration perStep = const Duration(milliseconds: 16),
    final PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final binding = GestureBinding.instance;
    final pointer = _nextPointerId++;
    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: from,
        kind: kind,
        device: _syntheticDevice,
        timeStamp: _now(),
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
          position: pos,
          delta: pos - last,
          kind: kind,
          device: _syntheticDevice,
          timeStamp: _now(),
        ),
      );
      last = pos;
    }

    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: to,
        kind: kind,
        device: _syntheticDevice,
        timeStamp: _now(),
      ),
    );
    _releaseSyntheticDevice();
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
        device: _syntheticDevice,
        timeStamp: _now(),
      ),
    );
    _releaseSyntheticDevice();
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

  /// [node]'s scroll position once the tree has had a chance to publish it.
  ///
  /// A scroll applied to the render object reaches semantics only on the next
  /// flush, so reading straight after the dispatch can still see [before].
  /// Calling that "nothing moved" is worse than a slow answer: the caller then
  /// retries through another tier and the content scrolls twice.
  static Future<({double? position, bool settled})> _settledScrollPosition(
    final SemanticsNode? node,
    final double? before,
  ) async {
    var after = _scrollPosition(node);
    for (var attempt = 0; attempt < 3 && after == before; attempt++) {
      await _waitFrame();
      after = _scrollPosition(node);
    }
    if (after == before) return (position: after, settled: true);
    // The move showed up; now let it come to rest. A fling passes through
    // mid-flight offsets and springs back past the edge on the way, so a
    // reading taken mid-flight both reports a place the list never stopped at
    // and, at the edge, differs from `before` enough to pass for movement.
    var previous = after;
    for (var attempt = 0; attempt < 25; attempt++) {
      await _waitFrame();
      final current = _scrollPosition(node);
      if (current == previous) return (position: current, settled: true);
      previous = current;
    }
    return (position: previous, settled: false);
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

  static Map<String, Object?>? _webScrollSubtreeProgress({
    required final Map<String, Object?>? beforeSignature,
    required final SemanticsNode node,
  }) {
    if (beforeSignature == null || beforeSignature['available'] != true) {
      return null;
    }
    final afterSignature = SemanticSnapshotService.visibleSubtreeSignature(
      node,
    );
    if (afterSignature['available'] != true ||
        afterSignature['signatureHash'] == beforeSignature['signatureHash']) {
      return null;
    }

    return <String, Object?>{
      'movementVerified': true,
      'movementSource': 'scrollable_subtree_signature',
      'targetNodeId': node.id,
      'visibleDescendantCountBefore': beforeSignature['visibleDescendantCount'],
      'visibleDescendantCountAfter': afterSignature['visibleDescendantCount'],
      'signatureHashBefore': beforeSignature['signatureHash'],
      'signatureHashAfter': afterSignature['signatureHash'],
    };
  }

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
        'error': 'ref_not_found',
        'hint':
            'Ref "$ref" is not in the current snapshot. Call '
            'semantic_snapshot (or reveal_search for an off-screen target) '
            'and use a ref from its result.',
      };

  /// Structured refusal for a ref whose node has left the semantics tree.
  ///
  /// Without it the node answers no actions, so every gesture silently falls
  /// through to Tier 2 and fires at coordinates that now belong to whatever
  /// took the node's place.
  static Map<String, Object?> _staleRef(
    final String ref,
    final String action,
  ) => <String, Object?>{
    'success': false,
    'ref': ref,
    'action': action,
    'error': 'stale_ref',
    'hint':
        'The node behind "$ref" left the semantics tree (a route closed, a row '
        'collapsed, a list rebuilt). Call semantic_snapshot again and use the '
        'fresh ref.',
  };

  /// Structured refusal for a node that is in the tree but has no box.
  ///
  /// A node with no geometry gives the pointer tier nowhere to aim, and the
  /// fallback would otherwise fire at the screen centre — a gesture on a
  /// widget the caller never named.
  static Map<String, Object?> _noBoundsForRef(
    final String ref,
    final String action,
  ) => <String, Object?>{
    'success': false,
    'ref': ref,
    'action': action,
    'error': 'no_bounds_for_ref',
    'hint':
        'The node behind "$ref" reports no rectangle, so there is no point to '
        'aim at. A merged or zero-sized node does this; call '
        'semantic_snapshot and take the ref of the node that carries the '
        'bounds — usually the parent that owns the label.',
  };

  /// The tightest semantics node covering [point], if it is not [node] itself.
  ///
  /// A pointer gesture aims at the centre of the target's box, and in a
  /// composite row that centre often belongs to a child — the long-press lands
  /// on the date chip inside the card rather than on the card. The answer has
  /// to name that, or the caller reads the wrong widget's reaction as its own.
  static String? _occupantAtPoint(
    final SemanticsNode node,
    final ui.Offset point,
  ) {
    final root = SemanticSnapshotService.semanticsOwner?.rootSemanticsNode;
    if (root == null) return null;
    SemanticsNode? tightest;
    var smallest = double.infinity;
    void visit(final SemanticsNode current) {
      final rect = SemanticSnapshotService.liveRect(current);
      if (rect != null && rect.contains(point)) {
        final area = rect.width * rect.height;
        if (area <= smallest) {
          smallest = area;
          tightest = current;
        }
      }
      current.visitChildren((final child) {
        visit(child);
        return true;
      });
    }

    visit(root);
    final occupant = tightest;
    if (occupant == null || occupant.id == node.id) return null;
    final data = occupant.getSemanticsData();
    final name = data.identifier.isNotEmpty
        ? data.identifier
        : (data.label.isNotEmpty ? data.label : 'node ${occupant.id}');
    return name;
  }

  /// Structured refusal for a node that says it cannot be operated.
  ///
  /// A disabled control ignores every tier: the semantic action is not
  /// registered and the pointer event hits a widget with no live callback.
  /// Both look exactly like a delivered gesture from the outside.
  static Map<String, Object?>? _disabledRef(
    final SemanticsNode node,
    final String ref,
    final String action,
  ) {
    // `isEnabled` is a tristate: `none` means the widget never declared an
    // enabled state at all, which is not the same as being disabled.
    if (node.getSemanticsData().flagsCollection.isEnabled !=
        ui.Tristate.isFalse) {
      return null;
    }
    return <String, Object?>{
      'success': false,
      'ref': ref,
      'action': action,
      'error': 'target_disabled',
      'hint':
          'The node behind "$ref" reports enabled: false, so nothing would '
          'act on the gesture — a control disabled by validation, or one that '
          'is read-only by design. Its own screen decides which.',
    };
  }

  /// Current global centre of [ref], falling back to the snapshot capture when
  /// the node cannot report live geometry.
  static ui.Offset? _liveCenter(final String ref) =>
      SemanticSnapshotService.liveCenter(
        SemanticSnapshotService.resolveRef(ref),
      ) ??
      SemanticSnapshotService.resolveCenter(ref);

  /// Current global bounds of [ref], falling back to the snapshot capture when
  /// the node cannot report live geometry.
  static ui.Rect? _liveBounds(final String ref) =>
      SemanticSnapshotService.liveRect(
        SemanticSnapshotService.resolveRef(ref),
      ) ??
      SemanticSnapshotService.resolveBounds(ref);

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
  /// work triggered by a preceding dispatch. When the window is backgrounded
  /// the engine delivers no vsync — the pipeline is then driven manually so
  /// the dispatch still lands in layout/paint/semantics.
  static Future<void> _waitFrame() async {
    await pumpFramesIfSuspended();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  static Future<void> _waitSemanticScrollFrame() async {
    await _waitFrame();
    if (!kIsWeb) return;
    for (var i = 0; i < 3; i++) {
      WidgetsBinding.instance.scheduleFrame();
      await Future<void>.delayed(const Duration(milliseconds: 32));
    }
  }
}
