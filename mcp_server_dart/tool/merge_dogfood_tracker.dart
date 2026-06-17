// Appends a dogfood iteration block to docs/evidence/dogfood/dogfood_web_eval.yaml (preserves comments).
// Usage: dart run tool/merge_dogfood_tracker.dart <tracker.yaml> <iteration.yaml> <verdict>
import 'dart:io';

void main(final List<String> args) {
  if (args.length < 3) {
    stderr.writeln(
      'Usage: dart run tool/merge_dogfood_tracker.dart <tracker.yaml> '
      '<iteration.yaml> <verdict>',
    );
    exit(64);
  }

  final trackerPath = args[0];
  final iterationPath = args[1];
  final verdict = args[2];

  final trackerFile = File(trackerPath);
  if (!trackerFile.existsSync()) {
    stderr.writeln('Tracker not found: $trackerPath');
    exit(1);
  }

  final lines = trackerFile.readAsLinesSync();
  final summaryIdx = lines.indexWhere((final line) => line == 'summary:');
  if (summaryIdx < 0) {
    stderr.writeln('Tracker missing summary: section');
    exit(1);
  }

  final iterationLines = File(iterationPath).readAsLinesSync();
  if (iterationLines.isEmpty) {
    stderr.writeln('Empty iteration file');
    exit(1);
  }

  final scorePattern = RegExp(r'^\s*score:\s*(\d+)\s*$');
  final scores = <num>[
    for (final line in lines)
      if (scorePattern.firstMatch(line) case final m?) num.parse(m.group(1)!),
    for (final line in iterationLines)
      if (scorePattern.firstMatch(line) case final m?) num.parse(m.group(1)!),
  ];

  final block = <String>[
    '  - ${iterationLines.first.trim()}',
    for (var i = 1; i < iterationLines.length; i++)
      if (iterationLines[i].trim().isNotEmpty)
        '    ${iterationLines[i].trimRight()}',
  ];

  final nextIteration =
      RegExp(
        r'^iteration:\s*(\d+)',
      ).firstMatch(iterationLines.first)?.group(1) ??
      '${scores.length}';

  final out = <String>[
    ...lines.sublist(0, summaryIdx),
    ...block,
    '',
    ...lines.sublist(summaryIdx),
  ];

  num? best;
  num? worst;
  if (scores.isNotEmpty) {
    best = scores.reduce((final a, final b) => a > b ? a : b);
    worst = scores.reduce((final a, final b) => a < b ? a : b);
  }
  final mean = scores.isEmpty
      ? 0
      : scores.fold<num>(0, (final a, final b) => a + b) / scores.length;

  for (var i = 0; i < out.length; i++) {
    final line = out[i];
    if (line.startsWith('  iterations_count:')) {
      out[i] = '  iterations_count: $nextIteration';
    } else if (line.startsWith('  best_score:') && best != null) {
      out[i] = '  best_score: $best';
    } else if (line.startsWith('  worst_score:') && worst != null) {
      out[i] = '  worst_score: $worst';
    } else if (line.startsWith('  mean_score:') && scores.isNotEmpty) {
      out[i] =
          '  mean_score: ${mean == mean.roundToDouble() ? mean.toInt() : mean.toStringAsFixed(1)}';
    } else if (line.startsWith('  verdict:')) {
      out[i] = '  verdict: $verdict';
    }
  }

  trackerFile.writeAsStringSync('${out.join('\n')}\n');
  stdout.writeln('merged iteration $nextIteration into $trackerPath');
}
