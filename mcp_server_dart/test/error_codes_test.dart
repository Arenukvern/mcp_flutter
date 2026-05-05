import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('CoreErrorDescriptor', () {
    test('maps vm_not_connected deterministically', () {
      final descriptor = descriptorForErrorCode(CoreErrorCode.vmNotConnected);
      expect(descriptor.category, equals('vm'));
      expect(descriptor.retryable, isTrue);
      expect(descriptor.exitCode, equals(68));
      expect(descriptor.httpLikeStatus, equals(503));
    });

    test('falls back for unknown code', () {
      final descriptor = descriptorForErrorCode('custom_unknown_error');
      expect(descriptor.category, equals('internal'));
      expect(descriptor.exitCode, equals(70));
      expect(descriptor.code, equals('custom_unknown_error'));
    });

    test('CoreResult.failure embeds descriptor envelope and recovery', () {
      final result = CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message: 'bad command',
      );

      expect(result.ok, isFalse);
      expect(result.exitCode, equals(64));

      final envelope = result.toEnvelopeJson();
      final error = envelope['error']! as Map<String, Object?>;
      expect(error['descriptor'], isA<Map<String, Object?>>());
      final descriptor = error['descriptor']! as Map<String, Object?>;
      expect(descriptor['retryable'], isFalse);
      expect(descriptor['category'], equals('validation'));
      expect(descriptor['exitCode'], equals(64));
      expect(error['recovery'], isA<Map<String, Object?>>());
    });
  });
}
