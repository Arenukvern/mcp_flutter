import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/agent_state.dart';
import 'package:test_app/showcase_screen.dart';

void main() {
  tearDown(() {
    AgentState.instance.resetForTest();
  });

  testWidgets('showcase reacts to external AgentState mutations', (
    final tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    AgentState.instance.resetForTest();
    await tester.pumpWidget(const MaterialApp(home: ShowcaseScreen()));

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 50);

    AgentState.instance
      ..increment()
      ..greeting = 'hello from vm'
      ..toggle = true
      ..slider = 73;
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('hello from vm'), findsNWidgets(2));
    expect(find.text('On'), findsOneWidget);
    expect(find.text('73'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 73);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'hello from vm',
    );
  });
}
