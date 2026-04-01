import 'dart:async';

import 'package:flutter/foundation.dart';

/// Aggregates N [Listenable] sources into a single [ChangeNotifier].
/// Rapid back-to-back source changes are coalesced into one notification
/// via [scheduleMicrotask], avoiding redundant rebuilds.
final class LiveEditBatchNotifier extends ChangeNotifier {
  LiveEditBatchNotifier(final Iterable<Listenable> sources) {
    _sources = List<Listenable>.unmodifiable(sources);
    for (final source in _sources) {
      source.addListener(_onSourceChanged);
    }
  }

  late final List<Listenable> _sources;
  bool _scheduled = false;

  void _onSourceChanged() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (hasListeners) notifyListeners();
    });
  }

  @override
  void dispose() {
    for (final source in _sources) {
      source.removeListener(_onSourceChanged);
    }
    super.dispose();
  }
}
