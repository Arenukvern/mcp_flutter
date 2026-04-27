import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  // -----------------------------------------------------------------------
  // press_key
  // -----------------------------------------------------------------------

  testWidgets(
    'press_key Enter is observed by the focused Focus widget',
    (final tester) async {
      // NOTE: We assert against `Focus.onKeyEvent`, not `TextField.onSubmitted`.
      // TextField submission travels via the `flutter/textinput` channel
      // (`TextInputAction.done`), not raw key events — synthesized hardware
      // keys are by design unreachable to onSubmitted. press_key is for the
      // focus-tree path: Focus/Shortcuts/Actions/Tab traversal.
      var gotEnter = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Focus(
              autofocus: true,
              onKeyEvent: (final node, final event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  gotEnter = true;
                }
                return KeyEventResult.ignored;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = await ControlFlowService.pressKey(key: 'Enter');
      await tester.pump();

      expect(result['success'], isTrue);
      expect(result['key'], 'Enter');
      expect(gotEnter, isTrue);
    },
  );

  test('press_key rejects unknown key with structured failure', () async {
    final result = await ControlFlowService.pressKey(key: 'BogusKey');
    expect(result['success'], isFalse);
    expect(result['error'], 'unknown_key');
    expect(result['key'], 'BogusKey');
  });

  test('press_key rejects empty key', () async {
    final result = await ControlFlowService.pressKey(key: '');
    expect(result['success'], isFalse);
    expect(result['error'], 'unknown_key');
  });
}
