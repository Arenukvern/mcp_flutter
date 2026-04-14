// ignore_for_file: avoid_classes_with_only_static_members
// ignore_for_file: unnecessary_async, unused_element_parameter

// Stub implementation of [WebPointerDispatch] for non-web platforms.
//
// This file is picked up by the conditional import in
// `gesture_interaction_service.dart` whenever `dart.library.js_interop` is
// **not** available (i.e. on the Dart VM, Flutter mobile, and Flutter
// desktop). It must not import anything web-only — otherwise
// `dart compile exe` of `mcp_server_dart` (which depends on this package)
// would transitively fail to build.
//
// All methods throw [UnsupportedError] because callers must guard with
// `kIsWeb` and [available] before invoking any dispatch method.

import 'dart:ui' as ui;

/// Browser-native `PointerEvent` dispatcher.
///
/// Stub variant: [available] is `false`, every dispatch method throws.
class WebPointerDispatch {
  /// Whether this platform can dispatch real browser pointer events.
  ///
  /// Always `false` on VM / mobile / desktop — callers must fall through to
  /// the synthetic [GestureBinding] path there.
  static bool get available => false;

  /// Dispatch a browser-level tap (pointerdown → delay → pointerup).
  static Future<void> dispatchTap(final ui.Offset position) async {
    throw UnsupportedError(
      'WebPointerDispatch.dispatchTap is only available on Flutter Web.',
    );
  }

  /// Dispatch a browser-level long-press.
  static Future<void> dispatchLongPress(final ui.Offset position) async {
    throw UnsupportedError(
      'WebPointerDispatch.dispatchLongPress is only available on '
      'Flutter Web.',
    );
  }

  /// Dispatch a browser-level drag from [from] to [to] over [steps] moves.
  static Future<void> dispatchDrag(
    final ui.Offset from,
    final ui.Offset to, {
    final int steps = 10,
    final Duration perStep = const Duration(milliseconds: 16),
  }) async {
    throw UnsupportedError(
      'WebPointerDispatch.dispatchDrag is only available on Flutter Web.',
    );
  }

  /// Dispatch a browser-level swipe (short, fast drag).
  static Future<void> dispatchSwipe(
    final ui.Offset from,
    final ui.Offset to,
  ) async {
    throw UnsupportedError(
      'WebPointerDispatch.dispatchSwipe is only available on Flutter Web.',
    );
  }

  /// Dispatch a browser-level `WheelEvent` at [position] with [scrollDelta].
  static Future<void> dispatchScroll(
    final ui.Offset position,
    final ui.Offset scrollDelta,
  ) async {
    throw UnsupportedError(
      'WebPointerDispatch.dispatchScroll is only available on Flutter Web.',
    );
  }
}
