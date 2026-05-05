import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorCauseAnalyzer', () {
    test('detects RenderFlex overflow root cause', () {
      const analyzer = ErrorCauseAnalyzer();

      final causes = analyzer.analyze([
        {
          'message':
              'A RenderFlex overflowed by 6731 pixels on the right.\n'
              'The relevant error-causing widget was:\n'
              'Row:file:///tmp/flutter_test_app/lib/main.dart:262:13',
        },
      ]);

      expect(causes, isNotEmpty);
      expect(causes.first['code'], equals('render_flex_overflow'));
      expect(causes.first['confidence'], greaterThan(0.9));

      final evidence = (causes.first['evidence']! as List).cast<String>();
      expect(
        evidence.any((final line) => line.contains('RenderFlex overflowed')),
        isTrue,
      );
      expect(
        evidence.any((final line) => line.contains('main.dart:262:13')),
        isTrue,
      );
    });
  });
}
