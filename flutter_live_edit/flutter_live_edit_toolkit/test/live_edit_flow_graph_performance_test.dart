// ignore_for_file: avoid_print

import 'package:flutter_live_edit_toolkit/src/models/live_edit_flow_graph_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flow graph matcher removes JSON-encode bottleneck', () {
    final previous = buildFlowGraphBenchmarkSnapshot(
      screenCount: 18,
      nodesPerScreen: 44,
    );
    final current = buildFlowGraphBenchmarkSnapshot(
      screenCount: 18,
      nodesPerScreen: 44,
    );

    const iterations = 260;
    const frameBudgetUs = 16667;

    final legacySamples = _measureComparator(
      iterations: iterations,
      compare: () => legacyFlowGraphSnapshotsMatch(previous, current),
    );
    final optimizedSamples = _measureComparator(
      iterations: iterations,
      compare: () => flowGraphSnapshotsMatch(previous, current),
    );

    final legacyP95Us = _p95Micros(legacySamples.samples);
    final optimizedP95Us = _p95Micros(optimizedSamples.samples);
    final legacyJankFrames = _jankFrames(
      legacySamples.samples,
      frameBudgetUs: frameBudgetUs,
    );
    final optimizedJankFrames = _jankFrames(
      optimizedSamples.samples,
      frameBudgetUs: frameBudgetUs,
    );

    print(
      'live_edit_flow_graph_perf '
      'legacy_p95_us=$legacyP95Us '
      'optimized_p95_us=$optimizedP95Us '
      'legacy_jank_frames=$legacyJankFrames '
      'optimized_jank_frames=$optimizedJankFrames '
      'iterations=$iterations',
    );

    expect(legacySamples.allMatched, isTrue);
    expect(optimizedSamples.allMatched, isTrue);
    expect(
      optimizedP95Us,
      lessThan(legacyP95Us),
      reason: 'Optimized matcher should beat legacy JSON encoding matcher.',
    );
    expect(
      optimizedJankFrames,
      lessThanOrEqualTo(legacyJankFrames),
      reason: 'Optimized matcher should not increase frame-budget overruns.',
    );
  });
}

({List<int> samples, bool allMatched}) _measureComparator({
  required final int iterations,
  required final bool Function() compare,
}) {
  final samples = <int>[];
  var allMatched = true;
  for (var i = 0; i < iterations; i += 1) {
    final watch = Stopwatch()..start();
    final matched = compare();
    watch.stop();
    allMatched = allMatched && matched;
    samples.add(watch.elapsedMicroseconds);
  }
  return (samples: samples, allMatched: allMatched);
}

int _p95Micros(final List<int> samples) {
  if (samples.isEmpty) {
    return 0;
  }
  final sorted = List<int>.from(samples)..sort();
  final index = ((sorted.length - 1) * 0.95).round();
  return sorted[index];
}

int _jankFrames(final List<int> samples, {required final int frameBudgetUs}) =>
    samples.where((final elapsed) => elapsed > frameBudgetUs).length;
