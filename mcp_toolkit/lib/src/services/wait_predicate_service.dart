import 'dart:async';

import 'package:flutter/widgets.dart';

import '../mcp_toolkit_binding.dart';
import 'semantic_snapshot_service.dart';

/// Service that blocks until a UI predicate holds or a timeout elapses.
///
/// Predicate kinds:
///   - `time`:    {kind: 'time', ms: int} — pure delay, no UI inspection.
///   - `text`:    {kind: 'text', text: String} — substring appears in snapshot.
///   - `noText`:  {kind: 'noText', text: String} — substring absent.
///   - `node`:    {kind: 'node', identifier: String, selected/enabled/focused/
///                checked/toggled: bool, absent: bool} — a node carrying that
///                identifier holds the named flags. `absent: true` inverts it.
///   - `stable`:  {kind: 'stable', stableWindowMs: int} — no semantic change
///                for the stable window.
///   - `noError`: {kind: 'noError'} — Flutter error monitor has no entries.
///
/// Implemented incrementally — see plan tasks 2–5.
class WaitPredicateService {
  const WaitPredicateService._();

  /// Blocks until [predicate] matches or [timeoutMs] elapses.
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

    if (kind == 'noError') {
      final binding = WidgetsBinding.instance;
      final deadline = Duration(milliseconds: timeoutMs);
      while (stopwatch.elapsed < deadline) {
        if (_errorMonitorIsEmpty()) {
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
        await SemanticSnapshotService.peekSemanticSnapshot(),
      );
    }

    final binding = WidgetsBinding.instance;
    final deadline = Duration(milliseconds: timeoutMs);

    Map<String, Object?>? lastSnapshot;
    String? lastSerialised;
    var stableFrames = 0;
    final stableWindowMs =
        (predicate['stableWindowMs'] as num?)?.toInt() ?? 250;
    // Convert ms -> required consecutive stable frames at ~60fps.
    final requiredStableFrames = (stableWindowMs / 16).ceil().clamp(1, 9999);

    while (stopwatch.elapsed < deadline) {
      final snapshot = await SemanticSnapshotService.peekSemanticSnapshot();
      lastSnapshot = snapshot;

      if (kind == 'stable') {
        final serialised = _serialiseNodes(snapshot);
        if (lastSerialised != null && serialised == lastSerialised) {
          stableFrames++;
          if (stableFrames >= requiredStableFrames) {
            final finalSnapshot =
                await SemanticSnapshotService.buildSemanticSnapshot();
            return _successWithSnapshot(
              predicate,
              stopwatch.elapsedMilliseconds,
              finalSnapshot,
            );
          }
        } else {
          stableFrames = 0;
          lastSerialised = serialised;
        }
      } else if (_evaluate(predicate, snapshot)) {
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
      case 'noText':
        final needle = (predicate['text'] as String?) ?? '';
        return needle.isNotEmpty && !_snapshotContainsText(snapshot, needle);
      case 'node':
        return _nodeMatches(predicate, snapshot);
      default:
        return false;
    }
  }

  /// Semantic flags a `node` predicate can require, spelled as the snapshot
  /// spells them.
  static const _nodeFlags = <String>[
    'selected',
    'enabled',
    'focused',
    'checked',
    'toggled',
  ];

  /// Whether a node carrying `identifier` holds every flag the predicate
  /// names. `absent: true` inverts the result, so one shape covers "appeared",
  /// "became selected" and "went away".
  ///
  /// Unlike `text`, this reads the node's own state rather than any string in
  /// the tree: the label of an unselected tab is present the whole time, so it
  /// cannot say whether that tab is open.
  static bool _nodeMatches(
    final Map<String, Object?> predicate,
    final Map<String, Object?> snapshot,
  ) {
    final identifier = (predicate['identifier'] as String?) ?? '';
    if (identifier.isEmpty) return false;
    final nodes = snapshot['nodes'];
    if (nodes is! List) return false;

    final found = nodes.whereType<Map<Object?, Object?>>().any(
      (final node) =>
          node['identifier'] == identifier && _flagsHold(predicate, node),
    );
    return predicate['absent'] == true ? !found : found;
  }

  /// A flag the snapshot omits reads as `false` — it only emits the ones that
  /// are set.
  static bool _flagsHold(
    final Map<String, Object?> predicate,
    final Map<Object?, Object?> node,
  ) {
    for (final flag in _nodeFlags) {
      final expected = predicate[flag];
      if (expected == null) continue;
      if ((node[flag] ?? false) != expected) return false;
    }
    return true;
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
    if (lastSnapshot != null && lastSnapshot['snapshot_id'] is int)
      'lastSnapshotId': lastSnapshot['snapshot_id'],
  };

  /// Test-only surface for the timeout response shape.
  ///
  /// The integration path through [waitFor] is hard to drive deterministically
  /// in `testWidgets` (the deadline check uses a real-time [Stopwatch] which
  /// does not advance under fake-async pumps). Exposing the pure builder lets
  /// tests lock the wire field name (`lastSnapshotId`, not `lastSnapshot`)
  /// without flaky timing.
  static Map<String, Object?> buildTimeoutResponseForTesting({
    required final Map<String, Object?> predicate,
    required final int elapsedMs,
    final Map<String, Object?>? lastSnapshot,
  }) => _timeoutWithSnapshot(predicate, elapsedMs, lastSnapshot);

  /// Mutable per-call scratch space for predicates that need history.
  static bool _errorMonitorIsEmpty() {
    try {
      return MCPToolkitBinding.instance.errors.isEmpty;
    } on Object {
      return true;
    }
  }

  static String _serialiseNodes(final Map<String, Object?> snapshot) {
    final nodes = snapshot['nodes'];
    if (nodes is! List) return '';
    return nodes.map((final n) => n.toString()).join('|');
  }
}
