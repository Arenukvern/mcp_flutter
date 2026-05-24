// packages/core/test/results_test.dart
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

void main() {
  group('CoreResult.toErrorEnvelopeJson', () {
    test('failure case round-trips with all 5 keys present', () {
      final result = CoreResult.failure(
        code: CoreErrorCode.interactionFailed,
        message: 'Widget not found',
        details: {'ref': 's_0'},
      );
      final json = result.toErrorEnvelopeJson();
      expect(json.containsKey('code'), isTrue);
      expect(json.containsKey('message'), isTrue);
      expect(json.containsKey('details'), isTrue);
      expect(json.containsKey('descriptor'), isTrue);
      expect(json.containsKey('recovery'), isTrue);
      expect(json['code'], equals(CoreErrorCode.interactionFailed));
      expect(json['message'], equals('Widget not found'));
      expect(json['details'], equals({'ref': 's_0'}));
    });

    test(
      'success case (defensive fallback) returns code: unknown and all 5 keys',
      () {
        final result = CoreResult.success(data: {'foo': 'bar'});
        final json = result.toErrorEnvelopeJson();
        expect(json.containsKey('code'), isTrue);
        expect(json.containsKey('message'), isTrue);
        expect(json.containsKey('details'), isTrue);
        expect(json.containsKey('descriptor'), isTrue);
        expect(json.containsKey('recovery'), isTrue);
        expect(json['code'], equals(CoreErrorCode.unknown));
        expect(json['message'], equals('Unknown error'));
      },
    );
  });
}
