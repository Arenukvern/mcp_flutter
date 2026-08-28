import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('capturedErrorCount', () {
    final cases =
        <
          String,
          ({
            bool includeErrors,
            Object? appErrors,
            int? expected,
            String reason,
          })
        >{
          'counts the errors the bundle actually carries': (
            includeErrors: true,
            appErrors: <String, Object?>{
              'message': '2 errors found',
              'errors': <Object?>[
                <String, Object?>{'message': 'first'},
                <String, Object?>{'message': 'second'},
              ],
            },
            expected: 2,
            reason: 'the summary must count returned errors, not the request cap',
          ),
          'a clean app counts zero rather than the requested cap': (
            includeErrors: true,
            appErrors: <String, Object?>{
              'message': 'No errors found',
              'errors': <Object?>[],
            },
            expected: 0,
            reason: 'an empty returned list is an observed zero',
          ),
          'errors that were never asked for are not counted at all': (
            includeErrors: false,
            appErrors: null,
            expected: null,
            reason: 'the summary omits a count for data it did not request',
          ),
          'a payload without an errors list counts zero, not null': (
            includeErrors: true,
            appErrors: <String, Object?>{'message': 'No errors found'},
            expected: 0,
            reason: 'requested error data without a list carries zero entries',
          ),
        };

    cases.forEach((final name, final testCase) {
      test(name, () {
        expect(
          capturedErrorCount(
            includeErrors: testCase.includeErrors,
            appErrors: testCase.appErrors,
          ),
          testCase.expected,
          reason: testCase.reason,
        );
      });
    });
  });
}
