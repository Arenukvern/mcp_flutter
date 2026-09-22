import 'dart:async';

import 'package:flutter/widgets.dart';

import '../mcp_toolkit_binding.dart';
import 'background_frame_pump.dart';
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
///                for the requested wall time, sampled once per frame.
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
    final kind = predicate['kind'];
    final stableWindowMs =
        (predicate['stableWindowMs'] as num?)?.toInt() ?? 250;
    if (kind == 'stable' && stableWindowMs >= timeoutMs) {
      return _invalidStableBudget(
        predicate: predicate,
        stableWindowMs: stableWindowMs,
        timeoutMs: timeoutMs,
      );
    }
    final stopwatch = Stopwatch()..start();

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
        await _awaitNextFrame(binding);
      }
      return _timeoutResponse(
        predicate,
        stopwatch.elapsedMilliseconds,
        await SemanticSnapshotService.peekSemanticSnapshot(),
      );
    }

    final binding = WidgetsBinding.instance;
    final deadline = Duration(milliseconds: timeoutMs);

    Map<String, Object?>? lastSnapshot;
    String? lastSerialised;
    var stableSamples = 0;
    var unchangedSinceMs = 0;
    // How often the tree changed under the wait. Only `stable` acts on it, but
    // it is the one number that explains why that predicate never settled.
    var changeCount = 0;

    while (stopwatch.elapsed < deadline) {
      final snapshot = await SemanticSnapshotService.peekSemanticSnapshot();
      lastSnapshot = snapshot;

      if (kind == 'stable') {
        final serialised = _serialiseNodes(snapshot);
        final sampledAtMs = stopwatch.elapsedMilliseconds;
        if (lastSerialised == null || serialised != lastSerialised) {
          if (lastSerialised != null) changeCount++;
          stableSamples = 1;
          lastSerialised = serialised;
          unchangedSinceMs = sampledAtMs;
        } else {
          stableSamples++;
          if (sampledAtMs - unchangedSinceMs >= stableWindowMs) {
            final finalSnapshot =
                await SemanticSnapshotService.buildSemanticSnapshot();
            final finalSerialised = _serialiseNodes(finalSnapshot);
            if (finalSerialised == lastSerialised) {
              return _successWithSnapshot(
                predicate,
                stopwatch.elapsedMilliseconds,
                finalSnapshot,
                measured: <String, Object?>{
                  'stableFor': <String, Object?>{
                    'requestedWindowMs': stableWindowMs,
                    'sampledFrames': stableSamples,
                    'elapsedMs':
                        stopwatch.elapsedMilliseconds - unchangedSinceMs,
                  },
                },
              );
            }
            changeCount++;
            lastSnapshot = finalSnapshot;
            lastSerialised = finalSerialised;
            stableSamples = 1;
            unchangedSinceMs = stopwatch.elapsedMilliseconds;
          }
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

      await _awaitNextFrame(binding);
    }

    return _timeoutResponse(
      predicate,
      stopwatch.elapsedMilliseconds,
      lastSnapshot,
      changeCount: changeCount,
    );
  }

  static Future<void> _awaitNextFrame(final WidgetsBinding binding) async {
    binding.scheduleFrame();
    final endOfFrame = binding.endOfFrame;
    await pumpFramesIfSuspended();
    await endOfFrame;
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
    final Map<String, Object?> snapshot, {
    final Map<String, Object?> measured = const <String, Object?>{},
  }) => <String, Object?>{
    'matched': true,
    'predicate': predicate,
    'elapsedMs': elapsedMs,
    ...measured,
    ...snapshot,
  };

  static Map<String, Object?> _invalidStableBudget({
    required final Map<String, Object?> predicate,
    required final int stableWindowMs,
    required final int timeoutMs,
  }) => <String, Object?>{
    'matched': false,
    'error': 'invalid_predicate',
    'reason': 'stable_window_not_less_than_timeout',
    'predicate': predicate,
    'elapsedMs': 0,
    'timeoutMs': timeoutMs,
    'hint':
        'stableWindowMs ($stableWindowMs) must be less than timeoutMs '
        '($timeoutMs). Set timeoutMs above stableWindowMs; when timeoutMs is '
        'omitted, its default is 5000 ms.',
  };

  static Map<String, Object?> _timeoutResponse(
    final Map<String, Object?> predicate,
    final int elapsedMs,
    final Map<String, Object?>? lastSnapshot, {
    final int changeCount = 0,
  }) => <String, Object?>{
    'matched': false,
    'predicate': predicate,
    'elapsedMs': elapsedMs,
    if (lastSnapshot != null && lastSnapshot['snapshot_id'] is int)
      'lastSnapshotId': lastSnapshot['snapshot_id'],
    ..._timeoutDiagnosis(
      predicate: predicate,
      lastSnapshot: lastSnapshot,
      changeCount: changeCount,
    ),
  };

  /// Why the predicate never held, in a sentence the caller can act on.
  ///
  /// A timeout used to report only how long it waited, which is the one thing
  /// the caller already knew. The tree it waited on is too big to inline — a
  /// real screen runs to thousands of tokens — but the reason is small: the
  /// identifier is absent, one flag disagrees, or the text differs only by
  /// case. Named `hint` so it reaches the caller as the failure's recovery
  /// summary, like every other refusal.
  static Map<String, Object?> _timeoutDiagnosis({
    required final Map<String, Object?> predicate,
    required final Map<String, Object?>? lastSnapshot,
    required final int changeCount,
  }) {
    final needle = (predicate['text'] as String?) ?? '';
    return switch (predicate['kind']) {
      'text' => _textTimeout(needle, lastSnapshot),
      'noText' => _noTextTimeout(needle, lastSnapshot),
      'node' => _nodeTimeout(predicate, lastSnapshot),
      'stable' => _stableTimeout(predicate, changeCount),
      'noError' => _noErrorTimeout(),
      _ => const <String, Object?>{},
    };
  }

  static Map<String, Object?> _textTimeout(
    final String needle,
    final Map<String, Object?>? snapshot,
  ) {
    if (needle.isEmpty) {
      return const <String, Object?>{
        'hint':
            'The predicate carried no text to look for, so it could never '
            'match. Pass {"kind":"text","text":"…"}.',
      };
    }
    final (count, loose) = _scanStrings(
      snapshot?['nodes'],
      needle.toLowerCase(),
    );
    if (loose != null) {
      return <String, Object?>{
        'hint':
            'Nothing on screen contains "$needle" — this match is '
            'case-sensitive, and the screen shows "$loose".',
        'caseInsensitiveMatch': loose,
      };
    }
    return <String, Object?>{
      'hint':
          'Nothing on screen contains "$needle"; $count strings were visible. '
          'A node that is built but scrolled away is still listed, so this '
          'means the text is not in the tree at all.',
    };
  }

  static Map<String, Object?> _noTextTimeout(
    final String needle,
    final Map<String, Object?>? snapshot,
  ) {
    if (needle.isEmpty) {
      return const <String, Object?>{
        'hint':
            'The predicate carried no text to wait on, so it could never '
            'match. Pass {"kind":"noText","text":"…"}.',
      };
    }
    final holder = _nodeHolding(snapshot, needle);
    if (holder == null) {
      return <String, Object?>{
        'hint': '"$needle" is still somewhere in the tree.',
      };
    }
    return <String, Object?>{
      'hint':
          '"$needle" is still on screen, carried by ${_nameOf(holder)}. It '
          'has to leave the tree, not merely scroll out of view.',
      'stillCarriedBy': ?holder['ref'],
    };
  }

  static Map<String, Object?> _nodeTimeout(
    final Map<String, Object?> predicate,
    final Map<String, Object?>? snapshot,
  ) {
    final identifier = (predicate['identifier'] as String?) ?? '';
    if (identifier.isEmpty) {
      return const <String, Object?>{
        'hint':
            'The predicate named no identifier, so it could never match. Pass '
            '{"kind":"node","identifier":"…"}.',
      };
    }
    final node = _nodeWithIdentifier(snapshot, identifier);
    final wantAbsent = predicate['absent'] == true;

    if (node == null) {
      return <String, Object?>{
        'hint': wantAbsent
            ? 'No node carries "$identifier" any more.'
            : 'No node on screen carries the identifier "$identifier". Check '
                  'it against semantic_snapshot — a snapshot lists only what '
                  'the app has built, so a screen that was never opened has '
                  'no such node to wait for.',
      };
    }
    if (wantAbsent) {
      return <String, Object?>{
        'hint': 'The node "$identifier" is still in the tree.',
        'nodeState': _stateOf(node),
      };
    }

    final disagreeing = <String>[];
    for (final flag in _nodeFlags) {
      final expected = predicate[flag];
      if (expected == null) continue;
      final actual = node[flag] ?? false;
      if (actual != expected) {
        disagreeing.add('$flag is $actual, not $expected');
      }
    }
    if (disagreeing.isEmpty) {
      return <String, Object?>{
        'hint': 'The node "$identifier" is on screen and its flags hold.',
        'nodeState': _stateOf(node),
      };
    }
    return <String, Object?>{
      'hint':
          'The node "$identifier" is on screen, but ${disagreeing.join('; ')}.',
      'nodeState': _stateOf(node),
    };
  }

  static Map<String, Object?> _stableTimeout(
    final Map<String, Object?> predicate,
    final int changeCount,
  ) {
    final window = (predicate['stableWindowMs'] as num?)?.toInt() ?? 250;
    if (changeCount == 0) {
      return <String, Object?>{
        'hint':
            'No semantic change was observed, but the wait ended before the '
            'tree had remained unchanged for the requested $window ms. '
            'Increase timeoutMs beyond stableWindowMs so the full window can '
            'be observed.',
        'changeCount': 0,
      };
    }
    return <String, Object?>{
      'hint':
          'The semantics tree never remained unchanged for $window ms across '
          'consecutive frame samples — it changed $changeCount times while '
          'waiting. Something on screen is animating or polling; wait on what '
          'you actually need instead.',
      'changeCount': changeCount,
    };
  }

  static Map<String, Object?> _noErrorTimeout() {
    final count = _errorMonitorCount();
    return <String, Object?>{
      'hint':
          'The error monitor still holds $count '
          '${count == 1 ? 'entry' : 'entries'}; they never cleared. Call '
          'get_app_errors to read them — the monitor keeps what it has '
          'captured, so an old error keeps this predicate failing.',
      'errorCount': count,
    };
  }

  /// Number of strings under [value], and the first one containing
  /// [lowerNeedle] once case is set aside.
  static (int, String?) _scanStrings(
    final Object? value,
    final String lowerNeedle,
  ) {
    var count = 0;
    String? match;
    void walk(final Object? current) {
      if (current is String) {
        count++;
        if (match == null && current.toLowerCase().contains(lowerNeedle)) {
          match = current;
        }
        return;
      }
      if (current is List) {
        current.forEach(walk);
        return;
      }
      if (current is Map) {
        current.values.forEach(walk);
      }
    }

    walk(value);
    return (count, match);
  }

  static Map<Object?, Object?>? _nodeHolding(
    final Map<String, Object?>? snapshot,
    final String needle,
  ) {
    final nodes = snapshot?['nodes'];
    if (nodes is! List) return null;
    for (final node in nodes.whereType<Map<Object?, Object?>>()) {
      if (_anyStringContains(node, needle)) return node;
    }
    return null;
  }

  static Map<Object?, Object?>? _nodeWithIdentifier(
    final Map<String, Object?>? snapshot,
    final String identifier,
  ) {
    final nodes = snapshot?['nodes'];
    if (nodes is! List) return null;
    for (final node in nodes.whereType<Map<Object?, Object?>>()) {
      if (node['identifier'] == identifier) return node;
    }
    return null;
  }

  /// The flags the snapshot actually published for [node].
  ///
  /// Only those: a snapshot emits a flag when the widget declares that state
  /// at all, so filling the rest in as `false` would report a plain label as
  /// a disabled, unchecked control. Matching still reads an absent flag as
  /// `false` — see [_flagsHold] — but that is a rule about the predicate, not
  /// a description of the widget.
  static Map<String, Object?> _stateOf(final Map<Object?, Object?> node) =>
      <String, Object?>{
        for (final flag in _nodeFlags)
          if (node.containsKey(flag)) flag: node[flag],
      };

  static String _nameOf(final Map<Object?, Object?> node) {
    final identifier = node['identifier'];
    if (identifier is String && identifier.isNotEmpty) return '"$identifier"';
    final label = node['label'];
    if (label is String && label.isNotEmpty) return '"$label"';
    return 'ref ${node['ref']}';
  }

  static int _errorMonitorCount() {
    try {
      return MCPToolkitBinding.instance.errors.length;
    } on Object {
      return 0;
    }
  }

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
    final int changeCount = 0,
  }) => _timeoutResponse(
    predicate,
    elapsedMs,
    lastSnapshot,
    changeCount: changeCount,
  );

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
