import 'package:flutter/foundation.dart' show kIsWeb;
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
  test('wait_for time predicate resolves after the requested delay', () async {
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
  });

  test('wait_for time predicate echoes ms in the predicate field', () async {
    final result = await WaitPredicateService.waitFor(
      predicate: const {'kind': 'time', 'ms': 50},
      timeoutMs: 500,
    );
    expect((result['predicate']! as Map)['ms'], 50);
  });

  test('wait_for rejects an impossible stable timeout budget', () async {
    final result = await WaitPredicateService.waitFor(
      predicate: const {'kind': 'stable', 'stableWindowMs': 1000},
      timeoutMs: 100,
    );

    expect(result['matched'], isFalse);
    expect(result['error'], 'invalid_predicate');
    expect(result['reason'], 'stable_window_not_less_than_timeout');
    expect(result['elapsedMs'], 0);
    expect(result['timeoutMs'], 100);
    expect(result['hint'], contains('must be less than timeoutMs'));
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

  testWidgets('wait_for noText predicate matches once substring disappears', (
    final tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: _DelayedClear())),
    );
    await tester.pump();

    final waitFuture = WaitPredicateService.waitFor(
      predicate: const {'kind': 'noText', 'text': 'Loading'},
      timeoutMs: 2000,
    );

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final result = await waitFuture;
    expect(result['matched'], isTrue);
  });

  test('wait_for timeout payload emits lastSnapshotId, not lastSnapshot', () {
    // Plan decision #5: on timeout the response carries the integer
    // `lastSnapshotId` (a pointer to the most recent peeked snapshot)
    // rather than the entire snapshot payload, so the wire response
    // stays small. This test is a direct shape check on the pure
    // builder — driving the full waitFor loop deterministically under
    // testWidgets is impractical because the deadline check uses a
    // real-time Stopwatch that does not advance under fake-async pumps.
    final result = WaitPredicateService.buildTimeoutResponseForTesting(
      predicate: const {'kind': 'text', 'text': 'never_appears'},
      elapsedMs: 50,
      lastSnapshot: const <String, Object?>{
        'snapshot_id': 7,
        'nodes': <Object?>[],
      },
    );
    expect(result['matched'], isFalse);
    expect(result['elapsedMs'], 50);
    expect(result['lastSnapshotId'], 7);
    expect(
      result.containsKey('lastSnapshot'),
      isFalse,
      reason: 'timeout payload must not include the full snapshot',
    );
    expect((result['predicate']! as Map)['kind'], 'text');
  });

  test(
    'wait_for timeout payload omits lastSnapshotId when no snapshot peeked',
    () {
      final result = WaitPredicateService.buildTimeoutResponseForTesting(
        predicate: const {'kind': 'stable', 'stableWindowMs': 100},
        elapsedMs: 5000,
      );
      expect(result['matched'], isFalse);
      expect(result.containsKey('lastSnapshotId'), isFalse);
    },
  );

  group('wait_for timeout says why it never matched', () {
    Map<String, Object?> snapshotOf(final List<Object?> nodes) =>
        <String, Object?>{'snapshot_id': 3, 'nodes': nodes};

    test('text that differs only by case names the string on screen', () {
      final result = WaitPredicateService.buildTimeoutResponseForTesting(
        predicate: const {'kind': 'text', 'text': 'закупки'},
        elapsedMs: 5000,
        lastSnapshot: snapshotOf(<Object?>[
          <String, Object?>{'ref': 's_0', 'label': 'Закупки'},
        ]),
      );

      expect(result['hint'], contains('case-sensitive'));
      expect(result['caseInsensitiveMatch'], 'Закупки');
    });

    test('text absent altogether reports how much was on screen', () {
      final result = WaitPredicateService.buildTimeoutResponseForTesting(
        predicate: const {'kind': 'text', 'text': 'nowhere'},
        elapsedMs: 5000,
        lastSnapshot: snapshotOf(<Object?>[
          <String, Object?>{'ref': 's_0', 'label': 'Заказы'},
        ]),
      );

      expect(result['hint'], contains('Nothing on screen contains "nowhere"'));
      expect(result.containsKey('caseInsensitiveMatch'), isFalse);
    });

    test('a node whose flag disagrees names the flag and its value', () {
      final result = WaitPredicateService.buildTimeoutResponseForTesting(
        predicate: const {
          'kind': 'node',
          'identifier': 'panel.tab.journal',
          'selected': true,
        },
        elapsedMs: 5000,
        lastSnapshot: snapshotOf(<Object?>[
          <String, Object?>{
            'ref': 's_4',
            'identifier': 'panel.tab.journal',
            'selected': false,
          },
        ]),
      );

      expect(result['hint'], contains('selected is false, not true'));
      expect((result['nodeState']! as Map)['selected'], isFalse);
    });

    test('nodeState reports only the flags the snapshot published', () {
      final result = WaitPredicateService.buildTimeoutResponseForTesting(
        predicate: const {
          'kind': 'node',
          'identifier': 'nav.settings',
          'checked': true,
        },
        elapsedMs: 5000,
        lastSnapshot: snapshotOf(<Object?>[
          <String, Object?>{'ref': 's_9', 'identifier': 'nav.settings'},
        ]),
      );

      // A snapshot emits a flag only where the widget declares that state, so
      // filling the rest in reported a plain nav row as a disabled, unchecked
      // control.
      expect(result['nodeState'], isEmpty);
      expect(result['hint'], contains('checked is false, not true'));
    });

    test('a node that is not in the tree is told apart from a wrong flag', () {
      final result = WaitPredicateService.buildTimeoutResponseForTesting(
        predicate: const {'kind': 'node', 'identifier': 'panel.tab.absent'},
        elapsedMs: 5000,
        lastSnapshot: snapshotOf(<Object?>[
          <String, Object?>{'ref': 's_4', 'identifier': 'panel.tab.journal'},
        ]),
      );

      expect(result['hint'], contains('No node on screen carries'));
      expect(result.containsKey('nodeState'), isFalse);
    });

    test('noText names the node still carrying the string', () {
      final result = WaitPredicateService.buildTimeoutResponseForTesting(
        predicate: const {'kind': 'noText', 'text': 'Загрузка'},
        elapsedMs: 5000,
        lastSnapshot: snapshotOf(<Object?>[
          <String, Object?>{
            'ref': 's_2',
            'identifier': 'screen.loader',
            'label': 'Загрузка',
          },
        ]),
      );

      expect(result['hint'], contains('screen.loader'));
      expect(result['stillCarriedBy'], 's_2');
    });

    test('stable reports how often the tree moved under it', () {
      final result = WaitPredicateService.buildTimeoutResponseForTesting(
        predicate: const {'kind': 'stable', 'stableWindowMs': 250},
        elapsedMs: 5000,
        changeCount: 17,
      );

      expect(result['changeCount'], 17);
      expect(result['hint'], contains('changed 17 times'));
    });

    test('stable with no changes points at the timeout budget', () {
      final result = WaitPredicateService.buildTimeoutResponseForTesting(
        predicate: const {'kind': 'stable', 'stableWindowMs': 1000},
        elapsedMs: 100,
      );

      expect(result['changeCount'], 0);
      expect(result['hint'], contains('Increase timeoutMs'));
      expect(result['hint'], isNot(contains('animating')));
    });
  });

  testWidgets(
    'wait_for noError predicate matches when error monitor is empty',
    (final tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('ok'))),
      );
      await tester.pump();

      final waitFuture = WaitPredicateService.waitFor(
        predicate: const {'kind': 'noError'},
        timeoutMs: 2000,
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final result = await waitFuture;
      expect(result['matched'], isTrue);
      expect(result['snapshot_id'], isA<int>());
    },
  );

  testWidgets('wait_for stable predicate matches once UI stops changing', (
    final tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('static'))),
    );
    await tester.pump();

    // Kick off the wait without awaiting — the loop awaits endOfFrame.
    final waitFuture = WaitPredicateService.waitFor(
      predicate: const {'kind': 'stable', 'stableWindowMs': 100},
      timeoutMs: 2000,
    );

    // Each sample needs two pumped frames under the test binding. Ten slow
    // frames provide about five samples over 250 ms: enough wall time, but
    // fewer than the seven samples the old 60 fps conversion required.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }

    final result = await waitFuture;
    expect(result['matched'], isTrue);
    expect(result['snapshot_id'], isA<int>());

    final stableFor = result['stableFor']! as Map<String, Object?>;
    expect(stableFor['requestedWindowMs'], 100);
    expect(stableFor['sampledFrames'], greaterThanOrEqualTo(2));
    expect(
      stableFor['sampledFrames'],
      lessThan(7),
      reason: 'a millisecond window must not become a fixed 60 fps frame count',
    );
    expect(stableFor['elapsedMs'], greaterThanOrEqualTo(100));
  });

  testWidgets(
    'wait_for stable resolves while frames are suspended',
    (final tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('static'))),
      );
      await tester.pump();

      final binding = tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      addTearDown(
        () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      expect(binding.framesEnabled, isFalse);

      final result = await WaitPredicateService.waitFor(
        predicate: const {'kind': 'stable', 'stableWindowMs': 0},
        timeoutMs: 500,
      );

      expect(result['matched'], isTrue);
      expect(
        (result['stableFor']! as Map<String, Object?>)['sampledFrames'],
        greaterThanOrEqualTo(2),
      );
    },
    skip: kIsWeb,
  );

  group('wait_for node predicate', () {
    testWidgets('reads state, not the label', (final tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _StaticTabs())),
      );
      await tester.pump();

      // The label of the closed tab is in the tree the whole time, so a text
      // predicate reports it as open — while the node predicate reads the flag
      // and reports it closed.
      final textFuture = WaitPredicateService.waitFor(
        predicate: const {'kind': 'text', 'text': 'Second'},
        timeoutMs: 2000,
      );
      final closedFuture = WaitPredicateService.waitFor(
        predicate: const {
          'kind': 'node',
          'identifier': 'tab_second',
          'selected': true,
          'absent': true,
        },
        timeoutMs: 2000,
      );
      final openFuture = WaitPredicateService.waitFor(
        predicate: const {
          'kind': 'node',
          'identifier': 'tab_first',
          'selected': true,
        },
        timeoutMs: 2000,
      );

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect((await textFuture)['matched'], isTrue);
      expect((await closedFuture)['matched'], isTrue);
      expect((await openFuture)['matched'], isTrue);
    });

    testWidgets('matches once the flag flips', (final tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _DelayedSelection())),
      );
      await tester.pump();

      final waitFuture = WaitPredicateService.waitFor(
        predicate: const {
          'kind': 'node',
          'identifier': 'tab_second',
          'selected': true,
        },
        timeoutMs: 2000,
      );

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final result = await waitFuture;
      expect(result['matched'], isTrue);
      expect(result['snapshot_id'], isA<int>());
    });

    testWidgets('absent matches once the node is gone', (final tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _DelayedIdentifiedClear())),
      );
      await tester.pump();

      final waitFuture = WaitPredicateService.waitFor(
        predicate: const {
          'kind': 'node',
          'identifier': 'transient_row',
          'absent': true,
        },
        timeoutMs: 2000,
      );

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect((await waitFuture)['matched'], isTrue);
    });
  });
}

class _StaticTabs extends StatelessWidget {
  const _StaticTabs();

  @override
  Widget build(final BuildContext context) => Row(
    children: <Widget>[
      Semantics(
        identifier: 'tab_first',
        label: 'First',
        selected: true,
        child: const SizedBox(width: 40, height: 40),
      ),
      Semantics(
        identifier: 'tab_second',
        label: 'Second',
        selected: false,
        child: const SizedBox(width: 40, height: 40),
      ),
    ],
  );
}

class _DelayedIdentifiedClear extends StatefulWidget {
  const _DelayedIdentifiedClear();

  @override
  State<_DelayedIdentifiedClear> createState() =>
      _DelayedIdentifiedClearState();
}

class _DelayedIdentifiedClearState extends State<_DelayedIdentifiedClear> {
  bool _present = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _present = false);
    });
  }

  @override
  Widget build(final BuildContext context) => Center(
    child: _present
        ? Semantics(
            identifier: 'transient_row',
            label: 'Row',
            child: const SizedBox(width: 40, height: 40),
          )
        : const SizedBox.shrink(),
  );
}

class _DelayedSelection extends StatefulWidget {
  const _DelayedSelection();

  @override
  State<_DelayedSelection> createState() => _DelayedSelectionState();
}

class _DelayedSelectionState extends State<_DelayedSelection> {
  bool _secondSelected = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _secondSelected = true);
    });
  }

  @override
  Widget build(final BuildContext context) => Row(
    children: <Widget>[
      Semantics(
        identifier: 'tab_first',
        label: 'First',
        selected: !_secondSelected,
        child: const SizedBox(width: 40, height: 40),
      ),
      Semantics(
        identifier: 'tab_second',
        label: 'Second',
        selected: _secondSelected,
        child: const SizedBox(width: 40, height: 40),
      ),
    ],
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

class _DelayedClear extends StatefulWidget {
  const _DelayedClear();
  @override
  State<_DelayedClear> createState() => _DelayedClearState();
}

class _DelayedClearState extends State<_DelayedClear> {
  bool _showLoading = true;
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showLoading = false);
    });
  }

  @override
  Widget build(final BuildContext context) => Center(
    child: _showLoading ? const Text('Loading') : const SizedBox.shrink(),
  );
}
