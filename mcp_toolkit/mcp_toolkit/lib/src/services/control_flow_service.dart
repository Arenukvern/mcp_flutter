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

  /// Synthesize a key-down + key-up via [HardwareKeyboard].
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
      };
    }

    // Dispatch in two passes so both modern and legacy paths see the event:
    //
    //  1. `HardwareKeyboard.handleKeyEvent` updates pressed-key state and
    //     notifies its listeners (Shortcuts, Actions, etc.).
    //  2. `KeyEventManager.keyMessageHandler` is the function `FocusManager`
    //     installs to walk the focus tree and call each `Focus.onKeyEvent`.
    //     Calling it directly bypasses `handleKeyData`'s pairing buffer
    //     (which waits for a matching legacy raw event that we don't send).
    //
    // KNOWN LIMITATION: `TextField.onSubmitted` goes through the
    // `flutter/textinput` channel (`TextInputAction.done`), not raw key
    // events. Pressing Enter via this tool will not submit a TextField —
    // use `tap_widget` on the submit button instead.
    final keyboard = HardwareKeyboard.instance;
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
          ? KeyDownEvent(
              physicalKey: physical,
              logicalKey: k,
              timeStamp: stamp,
            )
          : KeyUpEvent(
              physicalKey: physical,
              logicalKey: k,
              timeStamp: stamp,
            );
    }

    void send({required final bool isDown, required final LogicalKeyboardKey k}) {
      final event = makeEvent(isDown: isDown, k: k);
      keyboard.handleKeyEvent(event);
      // ignore: invalid_use_of_visible_for_testing_member
      keyManager.keyMessageHandler?.call(KeyMessage(<KeyEvent>[event], null));
    }

    // Press modifiers down in order, then main key down+up, then release
    // modifiers in reverse — mirrors a real keystroke sequence.
    for (final mod in modifiers) {
      send(isDown: true, k: mod);
    }
    send(isDown: true, k: logical);
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
    };
  }
}
