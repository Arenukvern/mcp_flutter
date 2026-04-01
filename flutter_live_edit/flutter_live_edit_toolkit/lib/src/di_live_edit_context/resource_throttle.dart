import 'dart:async';

import 'package:flutter/foundation.dart';

/// Wraps a [ValueNotifier] and debounces writes by [delay].
///
/// [writeImmediate] bypasses the debounce and synchronously updates the notifier.
/// [write] schedules an update that fires after [delay] unless superseded.
final class DebouncedResourceWriter<T> {
  DebouncedResourceWriter(this._notifier, {required this.delay});

  final ValueNotifier<T> _notifier;
  final Duration delay;

  T? _pending;
  Timer? _timer;

  void write(final T value) {
    _pending = value;
    _timer?.cancel();
    _timer = Timer(delay, _flush);
  }

  void writeImmediate(final T value) {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _notifier.value = value;
  }

  void _flush() {
    _timer = null;
    final value = _pending;
    _pending = null;
    if (value != null) {
      _notifier.value = value;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
