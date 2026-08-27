import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('capturedErrorCount', () {
    test('counts the errors the bundle actually carries', () {
      final count = capturedErrorCount(
        includeErrors: true,
        appErrors: <String, Object?>{
          'message': '2 errors found',
          'errors': <Object?>[
            <String, Object?>{'message': 'first'},
            <String, Object?>{'message': 'second'},
          ],
        },
      );

      expect(count, 2);
    });

    test('a clean app counts zero rather than the requested cap', () {
      final count = capturedErrorCount(
        includeErrors: true,
        appErrors: <String, Object?>{
          'message': 'No errors found',
          'errors': <Object?>[],
        },
      );

      expect(count, 0);
    });

    test('errors that were never asked for are not counted at all', () {
      // The summary omits the key entirely: printing the request's cap there
      // announced errors the bundle never fetched.
      expect(capturedErrorCount(includeErrors: false, appErrors: null), isNull);
    });

    test('a payload without an errors list counts zero, not null', () {
      expect(
        capturedErrorCount(
          includeErrors: true,
          appErrors: <String, Object?>{'message': 'No errors found'},
        ),
        0,
      );
    });
  });
}
