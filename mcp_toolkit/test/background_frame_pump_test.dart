import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/src/services/background_frame_pump.dart';

void main() {
  testWidgets('drives build manually while frames are suspended',
      (tester) async {
    var counter = 0;
    late StateSetter setCounter;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setCounter = setState;
            return Text('count: $counter');
          },
        ),
      ),
    );
    expect(find.text('count: 0'), findsOneWidget);

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    expect(binding.framesEnabled, isFalse);

    setCounter(() => counter = 1);
    // No tester.pump: with frames suspended the engine would never deliver
    // this frame — the pump has to drive the pipeline itself.
    pumpFramesIfSuspended();

    expect(find.text('count: 1'), findsOneWidget);
  });

  testWidgets('is a no-op when frames are enabled', (tester) async {
    await tester.pumpWidget(const Text('idle', textDirection: TextDirection.ltr));
    expect(tester.binding.framesEnabled, isTrue);

    pumpFramesIfSuspended();

    await tester.pump();
    expect(find.text('idle'), findsOneWidget);
  });
}
