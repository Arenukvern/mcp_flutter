import 'package:flutter/material.dart';
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

  testWidgets(
    'wait_for text predicate matches when substring present in snapshot',
    (final tester) async {
      // Two-phase: start with "Loading", flip to "Done" after 200ms.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _DelayedText())),
      );
      // Initial frame shows "Loading".
      await tester.pump();

      // Run wait_for in parallel with the timer that flips text.
      final waitFuture = WaitPredicateService.waitFor(
        predicate: const {'kind': 'text', 'text': 'Done'},
        timeoutMs: 2000,
      );

      // Advance time + frames until the widget swaps and waitFor resolves.
      // pump() drives endOfFrame so the wait loop progresses.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final result = await waitFuture;
      expect(result['matched'], isTrue);
      expect(result['snapshot_id'], isA<int>());
      expect(result['nodes'], isA<List<Object?>>());
    },
  );

  testWidgets(
    'wait_for text predicate does not bump public snapshot_id more than once',
    (final tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('hello world'))),
      );
      await tester.pump();

      final before = SemanticSnapshotService.currentSnapshotId;

      final waitFuture = WaitPredicateService.waitFor(
        predicate: const {'kind': 'text', 'text': 'hello'},
        timeoutMs: 2000,
      );
      // Drive at least one frame so the loop runs and checks the predicate.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final result = await waitFuture;

      final after = SemanticSnapshotService.currentSnapshotId;
      expect(result['matched'], isTrue);
      // At most one increment for the final snapshot we returned.
      expect(after - before, lessThanOrEqualTo(1));
    },
  );
}

class _DelayedText extends StatefulWidget {
  const _DelayedText();

  @override
  State<_DelayedText> createState() => _DelayedTextState();
}

class _DelayedTextState extends State<_DelayedText> {
  String _label = 'Loading';

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _label = 'Done');
    });
  }

  @override
  Widget build(final BuildContext context) => Center(child: Text(_label));
}
