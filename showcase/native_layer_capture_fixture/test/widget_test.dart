import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_layer_capture_fixture/main.dart';

void main() {
  testWidgets('Increment updates counter and keeps marker stripe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NativeLayerCaptureFixtureApp());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
    expect(find.byType(Banner), findsNothing);

    expect(find.text('0'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Increment'), findsOneWidget);

    final stripeFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.color == kMarkerStripe &&
          (widget.constraints?.maxHeight == 8 ||
              widget.constraints == const BoxConstraints.tightFor(height: 8)),
    );
    expect(stripeFinder, findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Increment'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });
}
