import 'dart:async';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

void main() {
  group('LogTap', () {
    test('waitFor returns an already-buffered matching line', () async {
      final tap = LogTap()..add('app INFO [input] pinch captured key g');
      final line = await tap.waitFor('pinch captured key');
      expect(line, contains('captured key g'));
    });

    test('waitFor resolves for a line added after subscribing', () async {
      final tap = LogTap();
      final future = tap.waitFor('connect finished');
      tap.add('noise');
      tap.add('app INFO [session] connect finished (connected)');
      expect(await future, contains('connected'));
    });

    test('waitFor times out when nothing matches', () async {
      final tap = LogTap();
      await expectLater(
        tap.waitFor('never appears', timeout: const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('waitFor fails fast when the tap closes while waiting', () async {
      final tap = LogTap();
      final future = tap.waitFor(
        'never appears',
        timeout: const Duration(seconds: 30),
      );
      await tap.close();
      await expectLater(
        future,
        throwsA(
          isA<StateError>().having(
            (final e) => e.message,
            'message',
            contains('never appears'),
          ),
        ),
      );
    });

    test('count and firstMatch scan retained lines', () {
      final tap = LogTap()
        ..add('pointer_move #1')
        ..add('pointer_move #2')
        ..add('pinch_start');
      expect(tap.count('pointer_move'), 2);
      expect(tap.firstMatch('pinch'), contains('pinch_start'));
      expect(tap.firstMatch('release_all'), isNull);
    });

    test('buffer is bounded by maxLines', () {
      final tap = LogTap(maxLines: 3);
      for (var i = 0; i < 5; i++) {
        tap.add('line $i');
      }
      expect(tap.lines, ['line 2', 'line 3', 'line 4']);
    });

    test('tail returns the last n retained lines', () {
      final tap = LogTap();
      for (var i = 0; i < 5; i++) {
        tap.add('line $i');
      }
      expect(tap.tail(2), ['line 3', 'line 4']);
      expect(tap.tail(10), hasLength(5));
    });
  });

  group('Scenario', () {
    test('records passes and returns true when all steps pass', () async {
      final scenario = Scenario('happy', steps: [
        (
          'step one',
          (final context) async {
            context.bag['value'] = 41;
            context.report.pass('step one');
          },
        ),
        (
          'step two',
          (final context) async {
            context.report.pass('answer ${context.take<int>('value') + 1}');
          },
        ),
      ]);
      expect(await scenario.run(), isTrue);
      expect(scenario.report.checks.map((final c) => c.name),
          ['step one', 'answer 42']);
    });

    test('a failed step aborts remaining steps and reports the error',
        () async {
      var secondRan = false;
      final scenario = Scenario('unhappy', steps: [
        (
          'boom',
          (final context) async {
            context.report.fail('boom', 'detail');
          },
        ),
        (
          'never',
          (final context) async {
            secondRan = true;
          },
        ),
      ]);
      expect(await scenario.run(), isFalse);
      expect(secondRan, isFalse);
      expect(scenario.report.checks.single.name, 'boom');
      expect(scenario.report.checks.single.detail, 'detail');
    });

    test('a thrown step is recorded as a failed check', () async {
      final scenario = Scenario('throws', steps: [
        (
          'explodes',
          (final context) async {
            throw StateError('kaboom');
          },
        ),
      ]);
      expect(await scenario.run(), isFalse);
      expect(scenario.report.checks.single.name, 'explodes');
      expect(scenario.report.checks.single.detail, contains('kaboom'));
    });
  });

  group('retry', () {
    test('returns the first non-null value', () async {
      var calls = 0;
      final value = await retry(() async {
        calls++;
        return calls == 2 ? 'found' : null;
      }, attempts: 5, delay: Duration.zero);
      expect(value, 'found');
      expect(calls, 2);
    });

    test('returns null after exhausting attempts', () async {
      var calls = 0;
      final value = await retry(() async {
        calls++;
        return null;
      }, attempts: 3, delay: Duration.zero);
      expect(value, isNull);
      expect(calls, 3);
    });
  });

  group('ToolkitExtensions', () {
    test('verbs are prefixed with the toolkit extension namespace', () {
      expect(ToolkitExtensions.snapshot, 'ext.mcp.toolkit.semantic_snapshot');
      expect(ToolkitExtensions.tap, 'ext.mcp.toolkit.tap_widget');
      expect(ToolkitExtensions.enterText, 'ext.mcp.toolkit.enter_text');
    });
  });
}
