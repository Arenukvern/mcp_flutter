import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../mcp_toolkit_binding.dart';

/// Toolkit-side implementation of P1 control-flow MCP tools:
/// `press_key`, `handle_dialog`, `navigate`.
class ControlFlowService {
  const ControlFlowService._();

  // -------------------------------------------------------------------------
  // press_key
  // -------------------------------------------------------------------------

  /// Map of accepted key names to LogicalKeyboardKey constants.
  static final Map<String, LogicalKeyboardKey> _namedKeys = {
    'Enter': LogicalKeyboardKey.enter,
    'Escape': LogicalKeyboardKey.escape,
    'Tab': LogicalKeyboardKey.tab,
    'Backspace': LogicalKeyboardKey.backspace,
    'Delete': LogicalKeyboardKey.delete,
    'Space': LogicalKeyboardKey.space,
    'ArrowUp': LogicalKeyboardKey.arrowUp,
    'ArrowDown': LogicalKeyboardKey.arrowDown,
    'ArrowLeft': LogicalKeyboardKey.arrowLeft,
    'ArrowRight': LogicalKeyboardKey.arrowRight,
  };

  static LogicalKeyboardKey? _resolveKey(final String name) {
    if (name.isEmpty) return null;
    final named = _namedKeys[name];
    if (named != null) return named;
    if (name.length != 1) return null;
    final code = name.codeUnitAt(0);
    // Lowercase letters
    if (code >= 0x61 && code <= 0x7A) {
      return LogicalKeyboardKey(code);
    }
    // Digits
    if (code >= 0x30 && code <= 0x39) {
      return LogicalKeyboardKey(code);
    }
    return null;
  }

  /// Synthesizes key-down and key-up sequences for the MCP `press_key` tool.
  ///
  /// ## Two-phase dispatch
  ///
  /// Each logical key transition calls:
  ///
  /// 1. [HardwareKeyboard.handleKeyEvent] — updates pressed-key state and runs
  ///    [HardwareKeyboard] handlers (e.g. pieces of the shortcut system that
  ///    listen here).
  /// 2. The global `KeyEventManager.keyMessageHandler`, which under a normal
  ///    [WidgetsBinding] is the callback registered by [FocusManager] so the
  ///    focus chain receives [Focus.onKeyEvent] / [Shortcuts] routing. We
  ///    invoke whatever handler is installed (not hard-coded to
  ///    [FocusManager]) so apps that legitimately patch the handler still work.
  ///
  /// `KeyMessage` is built with `rawEvent: null` so only the [KeyEvent] path
  /// runs inside `FocusManager.handleKeyMessage`; that matches solitary
  /// synthesized events in the framework's own dispatch path.
  ///
  /// ## Deprecation (no public replacement yet)
  ///
  /// `KeyMessage`, `KeyEventManager`, and
  /// `ServicesBinding.instance.keyEventManager` are deprecated with no
  /// substitute until the legacy RawKeyEvent pipeline is removed. Official
  /// context:
  ///
  /// * Migration guide (app code Raw → KeyEvent):
  ///   https://docs.flutter.dev/release/breaking-changes/key-event-migration
  /// * Phase-2 dispatch (why [HardwareKeyboard] handlers and
  ///   `KeyEventManager.keyMessageHandler` are parallel):
  ///   https://api.flutter.dev/flutter/services/KeyEventManager/keyMessageHandler.html
  /// * Removal tracking: https://github.com/flutter/flutter/issues/136419
  /// * Deprecation PR: https://github.com/flutter/flutter/pull/136677
  ///
  /// Framework registration still uses
  /// `ServicesBinding.instance.keyEventManager` until RawKeyEvent goes away;
  /// see `FocusManager.registerGlobalHandlers` TODO in the Flutter SDK
  /// (`hardware_keyboard.dart` / `focus_manager.dart`).
  ///
  /// ## Limitation
  ///
  /// [TextField.onSubmitted] is driven by the text-input channel
  /// ([TextInputAction.done]), not this path. Use `tap_widget` on the submit
  /// control when you need submission semantics.
  static Future<Map<String, Object?>> pressKey({
    required final String key,
    final bool ctrl = false,
    final bool shift = false,
    final bool alt = false,
    final bool meta = false,
  }) async {
    final logical = _resolveKey(key);
    if (logical == null) {
      return <String, Object?>{
        'success': false,
        'error': 'unknown_key',
        'key': key,
        'acceptedNames': _namedKeys.keys.toList(),
        'hint':
            'No key is named "$key". Pass one of acceptedNames, or a single '
            'character (a letter or a digit) — the names are case-sensitive '
            'and a whole word like "esc" or "return" resolves to nothing.',
      };
    }

    final keyboard = HardwareKeyboard.instance;
    // ignore: deprecated_member_use
    final keyManager = ServicesBinding.instance.keyEventManager;
    final modifiers = <LogicalKeyboardKey>[
      if (ctrl) LogicalKeyboardKey.controlLeft,
      if (shift) LogicalKeyboardKey.shiftLeft,
      if (alt) LogicalKeyboardKey.altLeft,
      if (meta) LogicalKeyboardKey.metaLeft,
    ];

    final stamp = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);

    KeyEvent makeEvent({
      required final bool isDown,
      required final LogicalKeyboardKey k,
    }) {
      final physical = PhysicalKeyboardKey(k.keyId);
      return isDown
          ? KeyDownEvent(physicalKey: physical, logicalKey: k, timeStamp: stamp)
          : KeyUpEvent(physicalKey: physical, logicalKey: k, timeStamp: stamp);
    }

    // Whether either dispatch phase claimed the keystroke. A key nothing
    // listens for is dispatched just as successfully as one that triggers a
    // shortcut, so the caller needs this to tell the two apart.
    bool send({
      required final bool isDown,
      required final LogicalKeyboardKey k,
    }) {
      final event = makeEvent(isDown: isDown, k: k);
      final byKeyboard = keyboard.handleKeyEvent(event);
      final byFocusChain =
          // ignore: deprecated_member_use
          keyManager.keyMessageHandler?.call(
            // ignore: deprecated_member_use
            KeyMessage(<KeyEvent>[event], null),
          ) ??
          false;
      return byKeyboard || byFocusChain;
    }

    // Press modifiers down in order, then main key down+up, then release
    // modifiers in reverse — mirrors a real keystroke sequence.
    for (final mod in modifiers) {
      send(isDown: true, k: mod);
    }
    final handled = send(isDown: true, k: logical);
    send(isDown: false, k: logical);
    for (final mod in modifiers.reversed) {
      send(isDown: false, k: mod);
    }

    return <String, Object?>{
      'success': true,
      'key': key,
      'ctrl': ctrl,
      'shift': shift,
      'alt': alt,
      'meta': meta,
      'handled': handled,
      if (!handled)
        'hint':
            'The main key-down event reached both dispatch phases — the '
            'hardware keyboard handlers and the focus chain — and neither '
            'claimed it. Text input is one such case: desktop typing goes '
            'through the TextInput channel, so use enter_text for fields.',
    };
  }

  // -------------------------------------------------------------------------
  // handle_dialog
  // -------------------------------------------------------------------------

  /// Structured refusal for an app whose root navigator the toolkit cannot
  /// reach, either because the key was never handed over or because no
  /// navigator is mounted behind it yet.
  static Map<String, Object?> _navigatorNotRegistered() => <String, Object?>{
    'success': false,
    'error': 'navigator_not_registered',
    'hint':
        'The toolkit has no root NavigatorState to act on. Assign the same '
        'GlobalKey<NavigatorState> to MCPToolkitBinding.instance.navigatorKey '
        'and to MaterialApp.navigatorKey, and call again once the first frame '
        'is up. Until then, drive the UI through tap_widget.',
  };

  /// The topmost route, read without touching the stack.
  ///
  /// [NavigatorState.popUntil] visits routes from the top down, and a
  /// predicate that answers `true` on the first one aborts the loop before
  /// anything is popped.
  static Route<Object?>? _topRoute(final NavigatorState navState) {
    Route<Object?>? top;
    navState.popUntil((final r) {
      top ??= r;
      return true;
    });
    return top;
  }

  /// Dismisses the topmost [PopupRoute] via [Navigator.maybePop].
  ///
  /// Returns the dismissal verdict and the route name/type. Refuses when no
  /// navigator is registered, the top route is not a popup, or the popup
  /// declines the pop. Tools should use this instead of a blind navigator pop
  /// so a plain page is never mistaken for a dialog.
  ///
  /// @ai Call this only for dialog-like popup routes; use `navigate` for pages.
  static Future<Map<String, Object?>> dismissDialog() async {
    final navState = MCPToolkitBinding.instance.navigatorKey?.currentState;
    if (navState == null) {
      return _navigatorNotRegistered();
    }

    final route = _topRoute(navState);
    if (route is! PopupRoute) {
      return <String, Object?>{
        'success': false,
        'error': 'no_popup_route',
        'topRouteName': route?.settings.name,
        'topRouteType': route?.runtimeType.toString(),
        'hint':
            'Nothing dialog-like is on top of the stack, so there was nothing '
            'to dismiss. A sheet or overlay shown without a PopupRoute — an '
            'OverlayEntry, an inline panel — is not reachable this way; close '
            'it through its own control, or use navigate with action "pop" '
            'for a plain page.',
      };
    }

    final popped = await navState.maybePop();
    return <String, Object?>{
      'success': popped,
      // A dialog route is usually anonymous, so the type is what identifies
      // what was actually dismissed.
      'routeName': route.settings.name,
      'routeType': route.runtimeType.toString(),
      if (!popped) ...<String, Object?>{
        'error': 'dialog_declined_pop',
        'hint':
            'The popup is still open: it declined the pop, which a dialog '
            'built with barrierDismissible false or guarded by a PopScope '
            'does deliberately. Dismiss it through its own control instead.',
      },
    };
  }

  // -------------------------------------------------------------------------
  // navigate
  // -------------------------------------------------------------------------

  /// Performs [Navigator] actions: `push`, `pop`, or `popUntil` [route].
  static Future<Map<String, Object?>> navigate({
    required final String action,
    final String? route,
    final Map<String, Object?>? arguments,
  }) async {
    // Precheck only: the navigator key must be registered. We resolve
    // `currentState` lazily inside the arms that need it so the `default`
    // arm (unknown_action) reports the correct error even when no widget
    // tree is mounted yet (e.g. unit tests that don't pump a MaterialApp).
    final key = MCPToolkitBinding.instance.navigatorKey;
    if (key == null) {
      return _navigatorNotRegistered();
    }
    final navState = key.currentState;

    switch (action) {
      case 'push':
        if (route == null || route.isEmpty) {
          return <String, Object?>{
            'success': false,
            'error': 'missing_route',
            'action': action,
            'hint':
                'navigate "$action" acts on a named route, so it needs a '
                '"route" argument — the name the app registered in its routes '
                'table, such as "/settings".',
          };
        }
        if (navState == null) {
          return _navigatorNotRegistered();
        }
        // Don't await: `pushNamed` resolves only when the route is popped,
        // so awaiting deadlocks until the next pop. Fire-and-forget the
        // push; the caller's pump/pumpAndSettle drives the navigation.
        // Attach a catchError so an unknown-route exception (or any
        // navigation error) surfaces as a debug log instead of an
        // unhandled future, which would otherwise be swallowed silently.
        // An app without `onGenerateRoute` (anything on a declarative router,
        // for instance) throws out of `pushNamed` before the future exists, so
        // the catchError below never sees it. Without this the exception
        // escapes the extension and reaches the caller as a transport error
        // with no cause in it.
        final previousTopRoute = _topRoute(navState);
        try {
          unawaited(
            navState.pushNamed<Object?>(route, arguments: arguments).catchError((
              final Object error,
              final StackTrace stack,
            ) {
              debugPrint(
                '[MCPToolkit] navigate push failed for route "$route": $error',
              );
              return null;
            }),
          );
        } on Object catch (error, stack) {
          debugPrint(
            '[MCPToolkit] navigate push threw for route "$route": $error\n'
            '$stack',
          );
          return <String, Object?>{
            'success': false,
            'action': 'push',
            'route': route,
            'error': 'push_rejected',
            'reason': '$error',
            'hint':
                'The navigator refused the name outright. Apps built on a '
                'declarative router (go_router, auto_route) have no named '
                'route table for this call to use — drive their navigation '
                'through the UI, or through evaluate_dart_expression.',
          };
        }
        // The push cannot be awaited — it completes only when the route is
        // popped — but [NavigatorState.push] adds the entry synchronously, so
        // the stack already says whether it happened. A generated route may
        // omit settings.name; a changed route object still proves the push,
        // but cannot verify that the app preserved the requested name.
        final currentTopRoute = _topRoute(navState);
        final topRouteName = currentTopRoute?.settings.name;
        if (topRouteName == route) {
          return <String, Object?>{
            'success': true,
            'action': 'push',
            'route': route,
          };
        }
        if (!identical(currentTopRoute, previousTopRoute) &&
            topRouteName == null) {
          return <String, Object?>{
            'success': true,
            'action': 'push',
            'route': route,
            'verified': false,
            'via': 'stack_changed_unnamed_route',
            'topRouteType': currentTopRoute?.runtimeType.toString(),
            'hint':
                'The navigator stack changed, but the generated route has no '
                'settings.name. The push took effect; use semantic_snapshot '
                'to verify the destination screen.',
          };
        }
        return <String, Object?>{
          'success': false,
          'action': 'push',
          'route': route,
          'error': 'route_not_pushed',
          'topRouteName': topRouteName,
          'hint':
              'The navigator is showing "$topRouteName" instead. Check the '
              "name against the app's route table; an unknown name is either "
              "dropped or replaced by the app's unknown-route fallback.",
        };
      case 'pop':
        if (navState == null) {
          return _navigatorNotRegistered();
        }
        final popped = await navState.maybePop();
        return <String, Object?>{
          'success': popped,
          'action': 'pop',
          if (!popped) ...<String, Object?>{
            'error': 'nothing_popped',
            'topRouteName': _topRoute(navState)?.settings.name,
            'hint':
                'The navigator stayed where it was: this is the last route on '
                'its stack, or the current route declined the pop (a '
                'PopScope guarding unsaved input, for instance).',
          },
        };
      case 'popUntil':
        if (route == null || route.isEmpty) {
          return <String, Object?>{
            'success': false,
            'error': 'missing_route',
            'action': action,
            'hint':
                'navigate "$action" acts on a named route, so it needs a '
                '"route" argument — the name the app registered in its routes '
                'table, such as "/settings".',
          };
        }
        if (navState == null) {
          return _navigatorNotRegistered();
        }
        // Walk the stack non-destructively first using the `popUntil`
        // sentinel pattern (predicate returns `true` so nothing is popped).
        // Without this guard, calling `popUntil` with a route name that
        // is not in the stack would pop every route until the navigator
        // is empty — catastrophic for the host app.
        final routeNames = <String?>[];
        navState.popUntil((final r) {
          routeNames.add(r.settings.name);
          return true;
        });
        if (!routeNames.contains(route)) {
          return <String, Object?>{
            'success': false,
            'error': 'route_not_in_stack',
            'action': 'popUntil',
            'route': route,
            'currentRoutes': routeNames,
            'hint':
                'Nothing was popped: "$route" is not on the stack, and '
                'popUntil with a name it cannot find would pop every route '
                'and leave the navigator empty. Pick a name from '
                'currentRoutes — an anonymous route shows there as null and '
                'cannot be targeted by name.',
          };
        }
        navState.popUntil(ModalRoute.withName(route));
        return <String, Object?>{
          'success': true,
          'action': 'popUntil',
          'route': route,
        };
      default:
        return <String, Object?>{
          'success': false,
          'error': 'unknown_action',
          'action': action,
          'acceptedActions': const <String>['push', 'pop', 'popUntil'],
          'hint':
              'navigate does not know the action "$action". Pass one of '
              'acceptedActions; to close a dialog rather than a page, call '
              'handle_dialog instead.',
        };
    }
  }
}
