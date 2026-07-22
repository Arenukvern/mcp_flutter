import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/src/services/background_frame_pump.dart';

void main() {
  testWidgets('drives build manually while frames are suspended',
      (final tester) async {
    var counter = 0;
    late StateSetter setCounter;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (final context, final setState) {
            setCounter = setState;
            return Text('count: $counter');
          },
        ),
      ),
    );
    expect(find.text('count: 0'), findsOneWidget);

    final binding = tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    expect(binding.framesEnabled, isFalse);

    setCounter(() => counter = 1);
    // No tester.pump: with frames suspended the engine would never deliver
    // this frame — the pump has to drive the pipeline itself.
    await pumpFramesIfSuspended();

    expect(find.text('count: 1'), findsOneWidget);
    // The pump is a web no-op, so this expectation cannot hold there.
  }, skip: kIsWeb);

  testWidgets('is a no-op when frames are enabled',
      (final tester) async {
    await tester.pumpWidget(const Text('idle', textDirection: TextDirection.ltr));
    expect(tester.binding.framesEnabled, isTrue);

    await pumpFramesIfSuspended();

    await tester.pump();
    expect(find.text('idle'), findsOneWidget);
  });
}
