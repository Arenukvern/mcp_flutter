import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:universal_automation_semantics/universal_automation_semantics.dart';

import '../mcp_toolkit_binding.dart';
import 'background_frame_pump.dart';
import 'semantic_delta_wire.dart';
import 'semantic_observation_history.dart';
import 'semantic_snapshot_service.dart';

/// Service that blocks until a UI predicate holds or a timeout elapses.
///
/// Predicate kinds:
///   - `time`:    {kind: 'time', ms: int, observe: bool?} — delay; observes
///                by default (`observe: true`).
///   - `text`:    {kind: 'text', text: String} — substring appears in snapshot.
///   - `noText`:  {kind: 'noText', text: String} — substring absent.
///   - `node`:    {kind: 'node', identifier: String, selected/enabled/focused/
///                checked/toggled: bool, absent: bool} — a node carrying that
///                identifier holds the named flags. `absent: true` inverts it.
///   - `stable`:  {kind: 'stable', stableWindowMs: int} — no semantic change
///                for the requested wall time, sampled once per frame.
///   - `noError`: {kind: 'noError'} — Flutter error monitor has no entries.
///   - `changed`: {kind: 'changed', since: int, settleMs?: int} — tree differs
///                from public snapshot [since] (ring buffer).
class WaitPredicateService {
  const WaitPredicateService._();

  /// Blocks until [predicate] matches or [timeoutMs] elapses.
  static Future<Map<String, Object?>> waitFor({
    required Map<String, Object?> predicate,
    int timeoutMs = 5000,
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
      final observe = predicate['observe'] as bool? ?? true;
      await Future<void>.delayed(Duration(milliseconds: ms));
      if (!observe) {
        return <String, Object?>{
          'matched': true,
          'observed': false,
          'predicate': predicate,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        };
      }
      final observed =
          await SemanticSnapshotService.peekSemanticSnapshot();
      return _successWithSnapshot(
        predicate,
        stopwatch.elapsedMilliseconds,
        observed,
      );
    }

    if (kind == 'changed') {
      return _waitForChanged(
        predicate: predicate,
        timeoutMs: timeoutMs,
        stopwatch: stopwatch,
      );
    }

    final waitStartSnapshotId = SemanticSnapshotService.currentSnapshotId;
    final waitRecord =
        SemanticSnapshotService.lookupPublicObservation(waitStartSnapshotId);
    final waitFilter = waitRecord != null
        ? SemanticSnapshotFilter.fromFilterKey(waitRecord.filterKey)
        : null;
    final waitStartBaseline = waitRecord?.observation;

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
        waitStartSnapshotId: waitStartSnapshotId,
        waitStartBaseline: waitStartBaseline,
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
      waitStartSnapshotId: waitStartSnapshotId,
      waitStartBaseline: waitStartBaseline,
    );
  }

  static Future<Map<String, Object?>> _waitForChanged({
    required Map<String, Object?> predicate,
    required int timeoutMs,
    required Stopwatch stopwatch,
  }) async {
    final since = (predicate['since'] as num?)?.toInt();
    if (since == null) {
      return <String, Object?>{
        'matched': false,
        'error': 'invalid_predicate',
        'reason': 'changed_since_required',
        'predicate': predicate,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'hint': 'Pass {"kind":"changed","since":<snapshotId from a public '
            'semantic_snapshot>}',
      };
    }

    final record = SemanticObservationHistory.instance.lookupSince(since);
    if (record == null) {
      final eviction =
          SemanticObservationHistory.instance.evictionInfoFor(since);
      final cap = SemanticObservationHistory.publicObservationRingCapacity;
      final hint = switch (eviction) {
        BaselineEvictionInfo(neverRecorded: true) =>
          'No public snapshot with id $since is in the observation ring '
              '(capacity $cap). Take semantic_snapshot and use its snapshot_id.',
        BaselineEvictionInfo(publicSnapshotsSince: final n?) =>
          'Snapshot $since was evicted from the observation ring (capacity '
              '$cap; $n public snapshot(s) recorded since). Take a fresh '
              'semantic_snapshot and wait again.',
        _ =>
          'Snapshot $since is not available. Take a fresh semantic_snapshot.',
      };
      return <String, Object?>{
        'matched': false,
        'error': 'baseline_evicted',
        'predicate': predicate,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'since': since,
        if (eviction?.publicSnapshotsSince != null)
          'publicSnapshotsSince': eviction!.publicSnapshotsSince,
        'ringCapacity': cap,
        'hint': hint,
      };
    }

    final baseline = record.observation;
    final filter = SemanticSnapshotFilter.fromFilterKey(record.filterKey);
    final optionalFilterKey = predicate['filterKey'];
    if (optionalFilterKey is String &&
        optionalFilterKey.isNotEmpty &&
        optionalFilterKey != record.filterKey) {
      return <String, Object?>{
        'matched': false,
        'error': 'baseline_filtered',
        'predicate': predicate,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'since': since,
        'hint':
            'The predicate filterKey does not match the filter recorded with '
            'snapshot $since. Use the same filter as that snapshot, or take a '
            'fresh baseline.',
      };
    }

    final settleMs = (predicate['settleMs'] as num?)?.toInt();
    final binding = WidgetsBinding.instance;
    final deadline = Duration(milliseconds: timeoutMs);
    Map<String, Object?>? lastPeek;

    while (stopwatch.elapsed < deadline) {
      lastPeek = await SemanticSnapshotService.peekSemanticSnapshot(
        filter: filter.isEmpty ? null : filter,
      );
      final current = SemanticSnapshotService.observationFromSnapshot(
        lastPeek,
        filter: filter.isEmpty ? null : filter,
      );
      final delta = current.diff(baseline);
      if (!delta.isEmpty) {
        var settled = true;
        if (settleMs != null && settleMs > 0) {
          final remainingMs =
              deadline.inMilliseconds - stopwatch.elapsedMilliseconds;
          if (remainingMs < settleMs) {
            final late = SemanticSnapshotService.observationFromSnapshot(
              lastPeek!,
              filter: filter.isEmpty ? null : filter,
            );
            return _successWithSnapshot(
              predicate,
              stopwatch.elapsedMilliseconds,
              lastPeek!,
              measured: <String, Object?>{
                'settled': false,
                'since': since,
                ...cappedDeltaRender(late.diff(baseline)),
              },
            );
          }
          final settle = await _settleForMs(
            binding: binding,
            settleMs: settleMs,
            stopwatch: stopwatch,
            deadline: deadline,
            filter: filter.isEmpty ? null : filter,
          );
          settled = settle.settled;
          lastPeek = settle.lastPeek ?? lastPeek;
          if (!settled) {
            final late = SemanticSnapshotService.observationFromSnapshot(
              lastPeek!,
              filter: filter.isEmpty ? null : filter,
            );
            return _successWithSnapshot(
              predicate,
              stopwatch.elapsedMilliseconds,
              lastPeek!,
              measured: <String, Object?>{
                'settled': false,
                'since': since,
                ...cappedDeltaRender(late.diff(baseline)),
              },
            );
          }
        }
        final finalSnapshot = await SemanticSnapshotService.buildSemanticSnapshot(
          filter: filter.isEmpty ? null : filter,
        );
        final finalObs = SemanticSnapshotService.observationFromSnapshot(
          finalSnapshot,
          filter: filter.isEmpty ? null : filter,
        );
        return _successWithSnapshot(
          predicate,
          stopwatch.elapsedMilliseconds,
          finalSnapshot,
          measured: <String, Object?>{
            ...cappedDeltaRender(finalObs.diff(baseline)),
            'since': since,
            if (settleMs != null && settleMs > 0) 'settled': settled,
          },
        );
      }
      await _awaitNextFrame(binding);
    }

    return _timeoutResponse(
      predicate,
      stopwatch.elapsedMilliseconds,
      lastPeek,
      waitStartSnapshotId: since,
      waitStartBaseline: baseline,
    );
  }

  static Future<({bool settled, Map<String, Object?>? lastPeek})>
      _settleForMs({
    required WidgetsBinding binding,
    required int settleMs,
    required Stopwatch stopwatch,
    required Duration deadline,
    SemanticSnapshotFilter? filter,
  }) async {
    var stableSamples = 0;
    String? lastSerialised;
    var unchangedSinceMs = 0;
    Map<String, Object?>? lastPeek;
    while (stopwatch.elapsed < deadline) {
      await _awaitNextFrame(binding);
      if (stopwatch.elapsed >= deadline) break;
      // Yield so widget tests can interleave pumps between settle samples.
      await Future<void>.delayed(Duration.zero);
      final snapshot = await SemanticSnapshotService.peekSemanticSnapshot(
        filter: filter?.isEmpty == false ? filter : null,
      );
      lastPeek = snapshot;
      final serialised = _serialiseNodes(snapshot);
      final sampledAtMs = stopwatch.elapsedMilliseconds;
      if (lastSerialised == null || serialised != lastSerialised) {
        stableSamples = 1;
        lastSerialised = serialised;
        unchangedSinceMs = sampledAtMs;
      } else {
        stableSamples++;
        if (sampledAtMs - unchangedSinceMs >= settleMs) {
          return (settled: true, lastPeek: lastPeek);
        }
      }
    }
    return (settled: false, lastPeek: lastPeek);
  }

  static Future<void> _awaitNextFrame(WidgetsBinding binding) async {
    binding.scheduleFrame();
    final endOfFrame = binding.endOfFrame;
    await pumpFramesIfSuspended();
    await endOfFrame;
  }

  static bool _evaluate(
    Map<String, Object?> predicate,
    Map<String, Object?> snapshot,
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
    Map<String, Object?> predicate,
    Map<String, Object?> snapshot,
  ) {
    final identifier = (predicate['identifier'] as String?) ?? '';
    if (identifier.isEmpty) return false;
    final nodes = snapshot['nodes'];
    if (nodes is! List) return false;

    final found = nodes.whereType<Map<Object?, Object?>>().any(
      (node) =>
          node['identifier'] == identifier && _flagsHold(predicate, node),
    );
    return predicate['absent'] == true ? !found : found;
  }

  /// A flag the snapshot omits reads as `false` — it only emits the ones that
  /// are set.
  static bool _flagsHold(
    Map<String, Object?> predicate,
    Map<Object?, Object?> node,
  ) {
    for (final flag in _nodeFlags) {
      final expected = predicate[flag];
      if (expected == null) continue;
      if ((node[flag] ?? false) != expected) return false;
    }
    return true;
  }

  static bool _snapshotContainsText(
    Map<String, Object?> snapshot,
    String needle,
  ) {
    final nodes = snapshot['nodes'];
    if (nodes is! List) return false;
    return _anyStringContains(nodes, needle);
  }

  /// Recursively walks any nested Map/List structure looking for a string
  /// value containing [needle]. Field-name agnostic so the predicate is
  /// robust to snapshot-shape changes (label/value/hint/name/whatever).
  static bool _anyStringContains(Object? value, String needle) {
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

  static Map<String, Object?> _successWithSnapshot(
    Map<String, Object?> predicate,
    int elapsedMs,
    Map<String, Object?> snapshot, {
    Map<String, Object?> measured = const <String, Object?>{},
  }) {
    final observed = predicate['observe'] as bool?;
    final nodes = snapshot['nodes'];
    final nodesAbsent = nodes is! List;
    if (nodesAbsent && observed != false) {
      return <String, Object?>{
        'matched': false,
        'error': 'invalid_observation',
        'predicate': predicate,
        'elapsedMs': elapsedMs,
        ...measured,
        'hint':
            'Success promised an observed tree but the snapshot carried no '
            'nodes. Use buildSemanticSnapshot or set observe:false on time.',
      };
    }
    return <String, Object?>{
      'matched': true,
      'predicate': predicate,
      'elapsedMs': elapsedMs,
      ...measured,
      ...snapshot,
    };
  }

  static Map<String, Object?> _invalidStableBudget({
    required Map<String, Object?> predicate,
    required int stableWindowMs,
    required int timeoutMs,
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
    Map<String, Object?> predicate,
    int elapsedMs,
    Map<String, Object?>? lastSnapshot, {
    int changeCount = 0,
    int? waitStartSnapshotId,
    Observation? waitStartBaseline,
  }) {
    final observedRevision =
        (lastSnapshot?['observedRevision'] as num?)?.toInt();
    Map<String, Object?>? deltaWire;
    if (waitStartBaseline != null && lastSnapshot != null) {
      final filter = waitStartSnapshotId != null
          ? SemanticSnapshotService.filterForPublicSnapshot(
              waitStartSnapshotId,
            )
          : null;
      final current = SemanticSnapshotService.observationFromSnapshot(
        lastSnapshot,
        filter: filter?.isEmpty == false ? filter : null,
      );
      deltaWire = cappedDeltaRender(current.diff(waitStartBaseline));
    }
    return <String, Object?>{
      'matched': false,
      'predicate': predicate,
      'elapsedMs': elapsedMs,
      if (waitStartSnapshotId != null) 'lastSnapshotId': waitStartSnapshotId,
      if (observedRevision != null) 'observedRevision': observedRevision,
      if (deltaWire != null) ...deltaWire,
      ..._timeoutDiagnosis(
        predicate: predicate,
        lastSnapshot: lastSnapshot,
        changeCount: changeCount,
      ),
    };
  }

  static Map<String, Object?> _timeoutDiagnosis({
    required Map<String, Object?> predicate,
    required Map<String, Object?>? lastSnapshot,
    required int changeCount,
  }) {
    final needle = (predicate['text'] as String?) ?? '';
    return switch (predicate['kind']) {
      'text' => _textTimeout(needle, lastSnapshot),
      'noText' => _noTextTimeout(needle, lastSnapshot),
      'node' => _nodeTimeout(predicate, lastSnapshot),
      'stable' => _stableTimeout(predicate, changeCount),
      'noError' => _noErrorTimeout(),
      'changed' => _changedTimeout(predicate, lastSnapshot),
      _ => const <String, Object?>{},
    };
  }

  static Map<String, Object?> _changedTimeout(
    Map<String, Object?> predicate,
    Map<String, Object?>? lastSnapshot,
  ) {
    final since = (predicate['since'] as num?)?.toInt();
    if (since == null) {
      return const <String, Object?>{
        'hint': 'changed requires since:<snapshotId>.',
      };
    }
    if (SemanticSnapshotService.observationForPublicSnapshot(since) == null) {
      final cap = SemanticObservationHistory.publicObservationRingCapacity;
      return <String, Object?>{
        'hint':
            'Baseline snapshot $since was evicted from the observation ring '
            '(capacity $cap).',
      };
    }
    return <String, Object?>{
      'hint':
          'Nothing changed versus snapshot $since before the timeout ended. '
          'The tree may already match the filtered baseline, or the change is '
          'slower than timeoutMs.',
      if (lastSnapshot != null)
        'observedRevision': lastSnapshot['observedRevision'],
    };
  }

  static Map<String, Object?> _textTimeout(
    String needle,
    Map<String, Object?>? snapshot,
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
    String needle,
    Map<String, Object?>? snapshot,
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
    Map<String, Object?> predicate,
    Map<String, Object?>? snapshot,
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
    Map<String, Object?> predicate,
    int changeCount,
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

  static (int, String?) _scanStrings(
    Object? value,
    String lowerNeedle,
  ) {
    var count = 0;
    String? match;
    void walk(Object? current) {
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
    Map<String, Object?>? snapshot,
    String needle,
  ) {
    final nodes = snapshot?['nodes'];
    if (nodes is! List) return null;
    for (final node in nodes.whereType<Map<Object?, Object?>>()) {
      if (_anyStringContains(node, needle)) return node;
    }
    return null;
  }

  static Map<Object?, Object?>? _nodeWithIdentifier(
    Map<String, Object?>? snapshot,
    String identifier,
  ) {
    final nodes = snapshot?['nodes'];
    if (nodes is! List) return null;
    for (final node in nodes.whereType<Map<Object?, Object?>>()) {
      if (node['identifier'] == identifier) return node;
    }
    return null;
  }

  static Map<String, Object?> _stateOf(Map<Object?, Object?> node) =>
      <String, Object?>{
        for (final flag in _nodeFlags)
          if (node.containsKey(flag)) flag: node[flag],
      };

  static String _nameOf(Map<Object?, Object?> node) {
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

  static Map<String, Object?> buildTimeoutResponseForTesting({
    required Map<String, Object?> predicate,
    required int elapsedMs,
    Map<String, Object?>? lastSnapshot,
    int changeCount = 0,
    int? waitStartSnapshotId,
    Observation? waitStartBaseline,
  }) => _timeoutResponse(
    predicate,
    elapsedMs,
    lastSnapshot,
    changeCount: changeCount,
    waitStartSnapshotId: waitStartSnapshotId,
    waitStartBaseline: waitStartBaseline,
  );

  static bool _errorMonitorIsEmpty() {
    try {
      return MCPToolkitBinding.instance.errors.isEmpty;
    } on Object {
      return true;
    }
  }

  static String _serialiseNodes(Map<String, Object?> snapshot) {
    final nodes = snapshot['nodes'];
    if (nodes is! List) return '';
    return nodes
        .map((n) {
          if (n is! Map) return n.toString();
          final copy = Map<String, Object?>.from(n.cast<String, Object?>());
          // Peeks omit ref/children; public builds include them. Stable/settle
          // compares semantic content, not bind generation.
          copy.remove('ref');
          copy.remove('children');
          return copy.toString();
        })
        .join('|');
  }
}