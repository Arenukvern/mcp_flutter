import 'package:flutter/foundation.dart';
import 'package:flutter_live_edit_toolkit/src/di_live_edit_context/live_edit_batch_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveEditBatchNotifier', () {
    test('notifies once for a single source change', () async {
      final source = ValueNotifier<int>(0);
      final batch = LiveEditBatchNotifier([source]);
      addTearDown(batch.dispose);

      var count = 0;
      batch.addListener(() => count++);

      source.value = 1;
      // Notification is scheduled via scheduleMicrotask — pump the event queue.
      await Future<void>.microtask(() {});

      expect(count, 1);
    });

    test('coalesces rapid changes into one notification', () async {
      final source = ValueNotifier<int>(0);
      final batch = LiveEditBatchNotifier([source]);
      addTearDown(batch.dispose);

      var count = 0;
      batch.addListener(() => count++);

      source.value = 1;
      source.value = 2;
      source.value = 3;
      await Future<void>.microtask(() {});

      expect(count, 1);
    });

    test('listens to multiple sources', () async {
      final s1 = ValueNotifier<int>(0);
      final s2 = ValueNotifier<int>(0);
      final batch = LiveEditBatchNotifier([s1, s2]);
      addTearDown(batch.dispose);

      var count = 0;
      batch.addListener(() => count++);

      s1.value = 1;
      await Future<void>.microtask(() {});
      s2.value = 1;
      await Future<void>.microtask(() {});

      expect(count, 2);
    });

    test('dispose removes source listeners', () async {
      final source = ValueNotifier<int>(0);
      final batch = LiveEditBatchNotifier([source]);

      var count = 0;
      batch.addListener(() => count++);
      batch.dispose();

      source.value = 1;
      await Future<void>.microtask(() {});

      expect(count, 0);
    });

    test('does not notify after dispose', () async {
      final source = ValueNotifier<int>(0);
      final batch = LiveEditBatchNotifier([source]);

      var count = 0;
      batch.addListener(() => count++);
      source.value = 1;
      batch.dispose(); // dispose before microtask fires
      await Future<void>.microtask(() {});

      expect(count, 0);
    });
  });
}
