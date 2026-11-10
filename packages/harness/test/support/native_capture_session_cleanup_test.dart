@TestOn('vm')
library;

import 'package:test/test.dart';

import 'native_capture_session_cleanup.dart';

void main() {
  test('retains primary exception when cleanup also fails', () async {
    NativeCaptureRunOutcome? captured;
    await expectLater(
      () => runWithPreservedPrimaryFailure<void>(
        body: () async => throw StateError('launch failed'),
        cleanupSteps: [
          (
            'logcat.stop',
            () async => throw TypeError(),
          ),
        ],
        onOutcome: (result) async => captured = result,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => '$error',
          'message',
          contains('launch failed'),
        ),
      ),
    );
    final outcome = captured;
    expect(outcome, isNotNull);
    expect(outcome!.hasPrimary, isTrue);
    expect(outcome.cleanupFailures, hasLength(1));
    expect(outcome.cleanupFailures.single.label, 'logcat.stop');
  });

  test('throws cleanup aggregate when body succeeded', () async {
    await expectLater(
      () => runWithPreservedPrimaryFailure<int>(
        body: () async => 42,
        cleanupSteps: [
          ('driver.close', () async => throw StateError('close boom')),
        ],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => '$error',
          'message',
          contains('cleanup failed'),
        ),
      ),
    );
  });

  test('returns result when body and cleanup succeed', () async {
    final seen = <String>[];
    final value = await runWithPreservedPrimaryFailure<int>(
      body: () async => 7,
      cleanupSteps: [
        ('a', () async => seen.add('a')),
        ('b', () async => seen.add('b')),
      ],
    );
    expect(value, 7);
    expect(seen, ['a', 'b']);
  });
}
