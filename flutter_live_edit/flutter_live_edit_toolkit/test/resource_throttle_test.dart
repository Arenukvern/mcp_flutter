import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_live_edit_toolkit/src/di_live_edit_context/resource_throttle.dart';

void main() {
  group('DebouncedResourceWriter', () {
    test('write debounces and applies final value', () async {
      final notifier = ValueNotifier<int>(0);
      final writer = DebouncedResourceWriter<int>(
        notifier,
        delay: const Duration(milliseconds: 20),
      );
      addTearDown(writer.dispose);

      writer.write(1);
      writer.write(2);
      writer.write(3);

      // Not applied yet (debounce in progress).
      expect(notifier.value, 0);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(notifier.value, 3);
    });

    test('writeImmediate bypasses debounce', () {
      final notifier = ValueNotifier<int>(0);
      final writer = DebouncedResourceWriter<int>(
        notifier,
        delay: const Duration(milliseconds: 200),
      );
      addTearDown(writer.dispose);

      writer.write(99); // pending debounce
      writer.writeImmediate(42);

      expect(notifier.value, 42);
    });

    test('writeImmediate cancels pending debounced write', () async {
      final notifier = ValueNotifier<int>(0);
      final writer = DebouncedResourceWriter<int>(
        notifier,
        delay: const Duration(milliseconds: 20),
      );
      addTearDown(writer.dispose);

      writer.write(99);
      writer.writeImmediate(42);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      // The debounced value (99) should NOT overwrite the immediate (42).
      expect(notifier.value, 42);
    });

    test('dispose cancels pending write', () async {
      final notifier = ValueNotifier<int>(0);
      final writer = DebouncedResourceWriter<int>(
        notifier,
        delay: const Duration(milliseconds: 20),
      );

      writer.write(5);
      writer.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(notifier.value, 0);
    });
  });
}
