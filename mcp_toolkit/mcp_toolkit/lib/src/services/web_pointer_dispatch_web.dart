// ignore_for_file: avoid_classes_with_only_static_members

// Web (`dart.library.js_interop`) implementation of [WebPointerDispatch].
//
// On Flutter Web, the browser owns the gesture arena and scroll physics, so
// synthetic `PointerEvent`s fed through `GestureBinding.handlePointerEvent`
// don't reach the browser's native scroll / overscroll / drag pipelines
// reliably. Dispatching real browser `PointerEvent`s (and `WheelEvent`s)
// directly on the Flutter engine's own pointer targets lets the DOM run
// the native event path the same way it does for a real human gesture,
// which the engine then routes into the framework through its own
// listeners.
//
// Coordinate model: the [ui.Offset] values we receive come from
// `SemanticSnapshotService.resolveCenter`, which computes a node's global
// rect via `RenderView` transforms. **That transform includes the
// devicePixelRatio scale**, so the offsets are in *physical* pixels, not
// CSS pixels. The browser's PointerEvent `clientX` / `clientY` are in CSS
// pixels, so we must divide by `window.devicePixelRatio` before
// dispatching. On a 2x display a logical (600, 370) surface renders to
// physical (1200, 740); dispatching `clientX=1200` lands outside the
// viewport entirely, which is how this path originally appeared
// "successful" but never actually moved the app.
//
// Target element: dispatch *every* phase (`pointerdown` /
// `pointermove` / `pointerup` / `wheel`) on the Flutter view root element
// (`<flutter-view>` or legacy `<flt-glass-pane>`).
//
// Earlier iterations tried dispatching `pointermove` / `pointerup` on
// `window` (on the theory that the engine subscribes to "global" pointer
// targets there to follow gestures that drift off-element). In practice
// the engine's handler does `viewElement.contains(event.target)` to
// decide whether the event belongs to this view; `Node.contains()`
// throws `TypeError: Failed to execute 'contains' on 'Node': parameter 1
// is not of type 'Node'` when `event.target` is `Window` (which is not a
// Node). The error is caught silently by the engine's event-handler
// wrapper — the event appears dispatched to us and is never processed.
// Dispatching every phase on the view element keeps `event.target` a
// Node and lets `Node.contains(...)` succeed, so the engine ingests the
// events and routes them through its gesture arena.
//
// Pointer type: we use `'mouse'` (plus companion `mousedown` /
// `mousemove` / `mouseup` events). Flutter Web's gesture recognisers on
// desktop are wired up via `MouseTracker` + mouse-aware drag recognisers;
// synthetic `'touch'` events go into a different arena and don't drive
// desktop ListView scrolling.

import 'dart:ui' as ui;

import 'package:web/web.dart' as web;

/// Browser-native `PointerEvent` / `WheelEvent` dispatcher for Flutter Web.
class WebPointerDispatch {
  /// Monotonically increasing pointer id so consecutive gestures don't
  /// collide from the browser's perspective.
  static int _nextPointerId = 10001;

  /// Whether this platform can dispatch real browser pointer events.
  static bool get available => true;

  /// Convert a Flutter-physical-pixel offset to CSS pixels by dividing
  /// by `window.devicePixelRatio`. See file-header for why this is needed.
  static ui.Offset _toCssPixels(final ui.Offset physical) {
    final dpr = web.window.devicePixelRatio;
    if (dpr == 0) return physical;
    return ui.Offset(physical.dx / dpr, physical.dy / dpr);
  }

  /// The `<flutter-view>` root element — the engine's
  /// `_viewTarget`. Receives `pointerdown`, `pointercancel`,
  /// `pointerleave`, and `wheel` in the engine.
  ///
  /// Falls back to `<flt-glass-pane>` (older embeds) or the document
  /// body for non-standard embedders.
  static web.EventTarget _viewTarget() {
    final view = web.document.querySelector('flutter-view');
    if (view != null) return view;
    final glass = web.document.querySelector('flt-glass-pane');
    if (glass != null) return glass;
    return web.document.body ?? web.document;
  }

  // NOTE: we deliberately do *not* expose a separate "global" target.
  // Every phase dispatches on the view element — see file-header comment.

  static web.PointerEvent _makePointerEvent(
    final String type, {
    required final ui.Offset cssPosition,
    required final int pointerId,
  }) {
    final int button;
    final int buttons;
    final double pressure;
    switch (type) {
      case 'pointerdown':
        button = 0;
        buttons = 1;
        pressure = 0.5;
      case 'pointerup':
        button = 0;
        buttons = 0;
        pressure = 0.0;
      case 'pointermove':
      default:
        button = -1;
        buttons = 1;
        pressure = 0.5;
    }
    return web.PointerEvent(
      type,
      web.PointerEventInit(
        bubbles: true,
        cancelable: true,
        composed: true,
        view: web.window,
        clientX: cssPosition.dx.round(),
        clientY: cssPosition.dy.round(),
        screenX: cssPosition.dx.round(),
        screenY: cssPosition.dy.round(),
        pointerId: pointerId,
        pointerType: 'mouse',
        isPrimary: true,
        button: button,
        buttons: buttons,
        pressure: pressure,
        width: 1,
        height: 1,
      ),
    );
  }

  static web.MouseEvent _makeMouseEvent(
    final String type, {
    required final ui.Offset cssPosition,
  }) {
    final int button;
    final int buttons;
    switch (type) {
      case 'mousedown':
        button = 0;
        buttons = 1;
      case 'mouseup':
        button = 0;
        buttons = 0;
      case 'mousemove':
      default:
        button = 0;
        buttons = 1;
    }
    return web.MouseEvent(
      type,
      web.MouseEventInit(
        bubbles: true,
        cancelable: true,
        composed: true,
        view: web.window,
        clientX: cssPosition.dx.round(),
        clientY: cssPosition.dy.round(),
        screenX: cssPosition.dx.round(),
        screenY: cssPosition.dy.round(),
        button: button,
        buttons: buttons,
      ),
    );
  }

  static void _dispatch(
    final web.EventTarget target,
    final web.Event event,
  ) {
    target.dispatchEvent(event);
  }

  /// Dispatch a pointerdown + mousedown pair on the view root.
  static void _dispatchDown(
    final ui.Offset cssPosition,
    final int pointerId,
  ) {
    final view = _viewTarget();
    _dispatch(
      view,
      _makePointerEvent(
        'pointerdown',
        cssPosition: cssPosition,
        pointerId: pointerId,
      ),
    );
    _dispatch(
      view,
      _makeMouseEvent('mousedown', cssPosition: cssPosition),
    );
  }

  /// Dispatch a pointermove + mousemove pair on the view root.
  static void _dispatchMove(
    final ui.Offset cssPosition,
    final int pointerId,
  ) {
    final view = _viewTarget();
    _dispatch(
      view,
      _makePointerEvent(
        'pointermove',
        cssPosition: cssPosition,
        pointerId: pointerId,
      ),
    );
    _dispatch(
      view,
      _makeMouseEvent('mousemove', cssPosition: cssPosition),
    );
  }

  /// Dispatch a pointerup + mouseup pair on the view root.
  static void _dispatchUp(
    final ui.Offset cssPosition,
    final int pointerId,
  ) {
    final view = _viewTarget();
    _dispatch(
      view,
      _makePointerEvent(
        'pointerup',
        cssPosition: cssPosition,
        pointerId: pointerId,
      ),
    );
    _dispatch(
      view,
      _makeMouseEvent('mouseup', cssPosition: cssPosition),
    );
  }

  /// Dispatch a browser-level tap (pointerdown → 50 ms → pointerup).
  static Future<void> dispatchTap(final ui.Offset position) async {
    final css = _toCssPixels(position);
    final id = _nextPointerId++;
    _dispatchDown(css, id);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _dispatchUp(css, id);
  }

  /// Dispatch a browser-level long-press (pointerdown → 600 ms → pointerup).
  static Future<void> dispatchLongPress(final ui.Offset position) async {
    final css = _toCssPixels(position);
    final id = _nextPointerId++;
    _dispatchDown(css, id);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _dispatchUp(css, id);
  }

  /// Dispatch a browser-level drag from [from] to [to] over [steps] moves.
  static Future<void> dispatchDrag(
    final ui.Offset from,
    final ui.Offset to, {
    final int steps = 10,
    final Duration perStep = const Duration(milliseconds: 16),
  }) async {
    final cssFrom = _toCssPixels(from);
    final cssTo = _toCssPixels(to);
    final id = _nextPointerId++;
    _dispatchDown(cssFrom, id);

    final dx = (cssTo.dx - cssFrom.dx) / steps;
    final dy = (cssTo.dy - cssFrom.dy) / steps;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(perStep);
      final pos = ui.Offset(cssFrom.dx + dx * i, cssFrom.dy + dy * i);
      _dispatchMove(pos, id);
    }

    _dispatchUp(cssTo, id);
  }

  /// Dispatch a browser-level swipe (short, fast drag).
  static Future<void> dispatchSwipe(
    final ui.Offset from,
    final ui.Offset to,
  ) => dispatchDrag(
    from,
    to,
    steps: 8,
    perStep: const Duration(milliseconds: 8),
  );

  /// Dispatch a `WheelEvent` at [position] with the agent-convention
  /// [scrollDelta] (same delta semantics as
  /// `GestureInteractionService._scrollDelta`).
  ///
  /// The engine listens for `wheel` on the view root (`_viewTarget`),
  /// so we dispatch there.
  static Future<void> dispatchScroll(
    final ui.Offset position,
    final ui.Offset scrollDelta,
  ) async {
    final css = _toCssPixels(position);
    final event = web.WheelEvent(
      'wheel',
      web.WheelEventInit(
        bubbles: true,
        cancelable: true,
        composed: true,
        view: web.window,
        clientX: css.dx.round(),
        clientY: css.dy.round(),
        screenX: css.dx.round(),
        screenY: css.dy.round(),
        deltaX: scrollDelta.dx,
        deltaY: scrollDelta.dy,
        deltaMode: 0, // DOM_DELTA_PIXEL
      ),
    );
    _dispatch(_viewTarget(), event);
    // Give the browser a microtask to process scroll physics.
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}
