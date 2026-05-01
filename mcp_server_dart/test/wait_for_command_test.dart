import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('WaitForCommand', () {
    final catalog = CommandCatalog.instance;

    test('round-trips arbitrary timeoutMs', () {
      final cmd =
          catalog.buildCommand('wait_for', {
                'predicate': {'kind': 'text', 'text': 'foo'},
                'timeoutMs': 12345,
              })
              as WaitForCommand;
      expect(cmd.timeoutMs, 12345);
      expect(cmd.predicate['kind'], 'text');
      expect(cmd.predicate['text'], 'foo');
    });

    test('default timeoutMs is 5000 when omitted', () {
      final cmd =
          catalog.buildCommand('wait_for', {
                'predicate': {'kind': 'time', 'ms': 10},
              })
              as WaitForCommand;
      expect(cmd.timeoutMs, 5000);
    });
  });

  group('routeWaitForResponse', () {
    test('matched == true routes to success', () {
      final result = routeWaitForResponse({
        'matched': true,
        'elapsedMs': 42,
        'snapshot_id': 7,
      });
      expect(result.ok, isTrue);
      expect((result.data! as Map<String, Object?>)['snapshot_id'], 7);
    });

    test('matched == false routes to wait_timeout', () {
      final result = routeWaitForResponse({
        'matched': false,
        'elapsedMs': 5000,
        'lastSnapshotId': 3,
      });
      expect(result.ok, isFalse);
      expect(result.error!.code, CoreErrorCode.waitTimeout);
      expect(result.error!.message, contains('5000'));
      expect((result.error!.details! as Map)['lastSnapshotId'], 3);
    });

    test('matched missing routes to wait_for_failed (malformed)', () {
      final result = routeWaitForResponse({'elapsedMs': 100});
      expect(result.ok, isFalse);
      expect(result.error!.code, CoreErrorCode.waitForFailed);
      expect(result.error!.message, contains('malformed'));
    });

    test('matched as a non-bool string routes to wait_for_failed', () {
      // Coerced wire values must NOT slip through to the success path —
      // commit 0df147e tightened `matched != true` instead of
      // `matched == false` for exactly this case.
      final result = routeWaitForResponse({
        'matched': 'true',
        'elapsedMs': 100,
      });
      expect(result.ok, isFalse);
      expect(result.error!.code, CoreErrorCode.waitForFailed);
    });

    test('matched as null routes to wait_for_failed', () {
      final result = routeWaitForResponse({'matched': null, 'elapsedMs': 100});
      expect(result.ok, isFalse);
      expect(result.error!.code, CoreErrorCode.waitForFailed);
    });
  });
}
