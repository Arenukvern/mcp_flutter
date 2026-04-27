import 'dart:async';

import 'package:flutter/widgets.dart';

import 'semantic_snapshot_service.dart';

/// Service that blocks until a UI predicate holds or a timeout elapses.
///
/// Predicate kinds:
///   - `time`:    {kind: 'time', ms: int} — pure delay, no UI inspection.
///   - `text`:    {kind: 'text', text: String} — substring appears in snapshot.
///   - `noText`:  {kind: 'noText', text: String} — substring absent.
///   - `stable`:  {kind: 'stable', stableWindowMs: int} — no semantic change
///                for the stable window.
///
/// Implemented incrementally — see plan tasks 2–5.
class WaitPredicateService {
  const WaitPredicateService._();

  static Future<Map<String, Object?>> waitFor({
    required final Map<String, Object?> predicate,
    final int timeoutMs = 5000,
  }) async {
    final stopwatch = Stopwatch()..start();
    final kind = predicate['kind'];

    if (kind == 'time') {
      final ms = (predicate['ms'] as num?)?.toInt() ?? 0;
      await Future<void>.delayed(Duration(milliseconds: ms));
      return _successNoSnapshot(predicate, stopwatch.elapsedMilliseconds);
    }

    final binding = WidgetsBinding.instance;
    final deadline = Duration(milliseconds: timeoutMs);

    Map<String, Object?>? lastSnapshot;
    while (stopwatch.elapsed < deadline) {
      final snapshot = await SemanticSnapshotService.peekSemanticSnapshot();
      lastSnapshot = snapshot;
      if (_evaluate(predicate, snapshot)) {
        // Bump the public id once on success.
        final finalSnapshot =
            await SemanticSnapshotService.buildSemanticSnapshot();
        return _successWithSnapshot(
          predicate,
          stopwatch.elapsedMilliseconds,
          finalSnapshot,
        );
      }
      await binding.endOfFrame;
    }

    return _timeoutWithSnapshot(
      predicate,
      stopwatch.elapsedMilliseconds,
      lastSnapshot,
    );
  }

  static bool _evaluate(
    final Map<String, Object?> predicate,
    final Map<String, Object?> snapshot,
  ) {
    final kind = predicate['kind'];
    switch (kind) {
      case 'text':
        final needle = (predicate['text'] as String?) ?? '';
        return needle.isNotEmpty && _snapshotContainsText(snapshot, needle);
      default:
        return false;
    }
  }

  static bool _snapshotContainsText(
    final Map<String, Object?> snapshot,
    final String needle,
  ) {
    final nodes = snapshot['nodes'];
    if (nodes is! List) return false;
    return _anyStringContains(nodes, needle);
  }

  /// Recursively walks any nested Map/List structure looking for a string
  /// value containing [needle]. Field-name agnostic so the predicate is
  /// robust to snapshot-shape changes (label/value/hint/name/whatever).
  static bool _anyStringContains(final Object? value, final String needle) {
    if (value is String) return value.contains(needle);
    if (value is List) {
      for (final item in value) {
        if (_anyStringContains(item, needle)) return true;
      }
      return false;
    }
    if (value is Map) {
      for (final v in value.values) {
        if (_anyStringContains(v, needle)) return true;
      }
      return false;
    }
    return false;
  }

  static Map<String, Object?> _successNoSnapshot(
    final Map<String, Object?> predicate,
    final int elapsedMs,
  ) => <String, Object?>{
    'matched': true,
    'predicate': predicate,
    'elapsedMs': elapsedMs,
  };

  static Map<String, Object?> _successWithSnapshot(
    final Map<String, Object?> predicate,
    final int elapsedMs,
    final Map<String, Object?> snapshot,
  ) => <String, Object?>{
    'matched': true,
    'predicate': predicate,
    'elapsedMs': elapsedMs,
    ...snapshot,
  };

  static Map<String, Object?> _timeoutWithSnapshot(
    final Map<String, Object?> predicate,
    final int elapsedMs,
    final Map<String, Object?>? lastSnapshot,
  ) => <String, Object?>{
    'matched': false,
    'predicate': predicate,
    'elapsedMs': elapsedMs,
    if (lastSnapshot != null) 'lastSnapshot': lastSnapshot,
  };
}
