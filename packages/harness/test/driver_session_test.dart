import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

/// Canned flat wire snapshot with a late-rendering label: the first two
/// snapshots miss 'Done'; the third carries it.
Map<String, dynamic> _envelope({required final bool done}) => {
  'snapshot_id': done ? 3 : 1,
  'nodes': [
    {
      'ref': 's_0',
      'type': 'widget',
      'children': done ? ['s_1', 's_2'] : ['s_1'],
    },
    {'ref': 's_1', 'type': 'text', 'label': 'Working…'},
    if (done)
      {'ref': 's_2', 'type': 'button', 'label': 'Done — saved'},
  ],
};

void main() {
  group('ToolkitDriverObserve (promoted from the showcase drives)', () {
    test('labelContaining retries until the label renders', () async {
      var polls = 0;
      final driver = ToolkitDriver.custom((
        name, {
        args = const <String, Object?>{},
      }) async {
        polls += 1;
        return _envelope(done: polls >= 3);
      });
      final label = await driver.labelContaining(
        'Done',
        attempts: 5,
        delay: Duration.zero,
      );
      expect(label, 'Done — saved');
      expect(polls, 3);
    });

    test('labelContaining reports the surface on the final miss', () async {
      final driver = ToolkitDriver.custom((
        name, {
        args = const <String, Object?>{},
      }) async {
        return _envelope(done: false);
      });
      String? dump;
      final label = await driver.labelContaining(
        'Done',
        attempts: 2,
        delay: Duration.zero,
        onMiss: (final surface) => dump = surface,
      );
      expect(label, isNull);
      expect(dump, contains('Working…'));
    });

    test('expectLabel throws with the surface in the error', () async {
      final driver = ToolkitDriver.custom((
        name, {
        args = const <String, Object?>{},
      }) async {
        return _envelope(done: false);
      });
      await expectLater(
        driver.expectLabel('Done', attempts: 2, delay: Duration.zero),
        throwsA(
          isA<StateError>()
              .having(
                (e) => e.message,
                'message',
                contains('label "Done" not on screen'),
              )
              .having(
                (e) => e.message,
                'message',
                contains('Working…'),
              ),
        ),
      );
    });
  });
}
