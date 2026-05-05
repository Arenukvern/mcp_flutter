import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  testWidgets(
    'inspectWidgetAtPoint returns selected summary and render hit targets',
    (final tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                label: 'inspect target',
                child: const Text('Inspect Me'),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('Inspect Me'));
      final payload = ViewIntrospectionService.inspectWidgetAtPoint(
        x: center.dx.round(),
        y: center.dy.round(),
      );

      expect(payload['hit'], isTrue);
      expect(payload['viewId'], isA<int>());

      final summary = payload['summary']! as Map<String, Object?>;
      expect(summary, isNotEmpty);

      final targets = payload['renderHitTargets']! as List<Object?>;
      expect(targets, isNotEmpty);

      final renderObject = payload['renderObject']! as Map<String, Object?>;
      expect(renderObject['renderObjectType'], isNotNull);

      final element = payload['element']! as Map<String, Object?>;
      expect(element['widgetType'], isNotNull);
    },
  );
}
