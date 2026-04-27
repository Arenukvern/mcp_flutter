import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  // The `time` predicate is a pure delay with no widget interaction. Use
  // plain `test` (real time) rather than `testWidgets` (FakeAsync) — under
  // FakeAsync, `await Future.delayed(...)` inside `waitFor` blocks the very
  // `tester.pump(duration)` that would advance fake time, deadlocking.
  // Snapshot-derived predicates (Tasks 3+) will use `testWidgets` with the
  // parallel-pump pattern instead.
  test(
    'wait_for time predicate resolves after the requested delay',
    () async {
      final stopwatch = Stopwatch()..start();
      final result = await WaitPredicateService.waitFor(
        predicate: const {'kind': 'time', 'ms': 100},
        timeoutMs: 1000,
      );
      stopwatch.stop();

      expect(result['matched'], isTrue);
      expect(result['elapsedMs'], isA<int>());
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
      expect((result['predicate']! as Map)['kind'], 'time');
    },
  );

  test('wait_for time predicate echoes ms in the predicate field', () async {
    final result = await WaitPredicateService.waitFor(
      predicate: const {'kind': 'time', 'ms': 50},
      timeoutMs: 500,
    );
    expect((result['predicate']! as Map)['ms'], 50);
  });
}
