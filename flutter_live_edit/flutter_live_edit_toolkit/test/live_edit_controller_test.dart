import 'package:flutter/material.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('controller starts and ends session', (final tester) async {
    final controller = LiveEditController.instance;

    final started = controller.startSession();
    final sessionId = started['sessionId']! as String;

    expect(sessionId, isNotEmpty);
    expect(controller.activeSessionId, sessionId);

    final ended = controller.endSession(sessionId: sessionId);
    expect(ended['ended'], isTrue);
  });

  testWidgets('host builds without overlay by default', (final tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterLiveEditHost(child: Scaffold(body: Text('Hello'))),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
  });
}
