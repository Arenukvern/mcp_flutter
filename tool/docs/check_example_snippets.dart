// Verifies docs fences tagged with <!-- example-snippet: id --> match
// tool/docs/example_snippets.yaml (and source sentinel comments).
//
//   dart run tool/docs/check_example_snippets.dart
import 'dart:io';

import 'example_snippets_verify.dart';

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('run from repository root');
    exit(1);
  }

  final result = verifyExampleSnippets(repoRoot: Directory.current);
  for (final error in result.errors) {
    stderr.writeln(error);
  }
  if (!result.ok) {
    stderr.writeln('check_example_snippets: ${result.errors.length} failure(s)');
    exit(1);
  }
  stdout.writeln(
    'check_example_snippets: OK (${result.snippetCount} snippets)',
  );
}
