import 'dart:async';

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

    switch (kind) {
      case 'time':
        final ms = (predicate['ms'] as num?)?.toInt() ?? 0;
        await Future<void>.delayed(Duration(milliseconds: ms));
        return _success(predicate, stopwatch.elapsedMilliseconds);
      default:
        return _timeout(
          predicate,
          stopwatch.elapsedMilliseconds,
          'unsupported predicate kind: $kind',
        );
    }
  }

  static Map<String, Object?> _success(
    final Map<String, Object?> predicate,
    final int elapsedMs,
  ) => <String, Object?>{
    'matched': true,
    'predicate': predicate,
    'elapsedMs': elapsedMs,
  };

  static Map<String, Object?> _timeout(
    final Map<String, Object?> predicate,
    final int elapsedMs,
    final String reason,
  ) => <String, Object?>{
    'matched': false,
    'predicate': predicate,
    'elapsedMs': elapsedMs,
    'reason': reason,
  };
}
