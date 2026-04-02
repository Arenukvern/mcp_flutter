// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment('FLOW_MATCH_MODE', defaultValue: 'both');
  final runLegacy = mode == 'legacy' || mode == 'both';
  final runOptimized = mode == 'optimized' || mode == 'both';

  if (!runLegacy && !runOptimized) {
    stderr.writeln(
      'Invalid FLOW_MATCH_MODE="$mode". Use "legacy", "optimized", or "both".',
    );
    exit(2);
  }

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

  final legacySamples = runLegacy
      ? _measureComparator(
          iterations: iterations,
          compare: () => legacyFlowGraphSnapshotsMatch(previous, current),
        )
      : null;
  final optimizedSamples = runOptimized
      ? _measureComparator(
          iterations: iterations,
          compare: () => flowGraphSnapshotsMatch(previous, current),
        )
      : null;

  if (legacySamples != null) {
    final legacyP95Us = _p95Micros(legacySamples.samples);
    final legacyJankFrames = _jankFrames(
      legacySamples.samples,
      frameBudgetUs: frameBudgetUs,
    );
    print(
      'live_edit_flow_graph_profile '
      'mode=legacy '
      'legacy_p95_us=$legacyP95Us '
      'legacy_jank_frames=$legacyJankFrames '
      'iterations=$iterations',
    );
  }
  if (optimizedSamples != null) {
    final optimizedP95Us = _p95Micros(optimizedSamples.samples);
    final optimizedJankFrames = _jankFrames(
      optimizedSamples.samples,
      frameBudgetUs: frameBudgetUs,
    );
    print(
      'live_edit_flow_graph_profile '
      'mode=optimized '
      'optimized_p95_us=$optimizedP95Us '
      'optimized_jank_frames=$optimizedJankFrames '
      'iterations=$iterations',
    );
  }

  if ((legacySamples != null && !legacySamples.allMatched) ||
      (optimizedSamples != null && !optimizedSamples.allMatched)) {
    stderr.writeln(
      'flow graph profile probe failed: snapshot comparators did not match.',
    );
    exitCode = 1;
  }

  await Future<void>.delayed(const Duration(milliseconds: 50));
  exit(exitCode);
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
