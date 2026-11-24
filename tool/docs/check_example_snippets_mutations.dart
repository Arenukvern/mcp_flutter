// Mutation harness for example snippet contract (CI-gated).
//
//   dart run tool/docs/check_example_snippets_mutations.dart
import 'dart:io';

import 'example_snippets_verify.dart';

void main() async {
  final repoRoot = Directory.current;
  if (!File('${repoRoot.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('run from repository root');
    exit(1);
  }

  final clean = verifyExampleSnippets(repoRoot: repoRoot);
  if (!clean.ok) {
    stderr.writeln('clean tree must pass before mutations:');
    for (final e in clean.errors) {
      stderr.writeln('  $e');
    }
    exit(1);
  }

  final cases = <_MutationCase>[
    _MutationCase(
      name: 'drifted doc fence',
      setup: (root) async {
        final path = '${root.path}/docs/use-cases/e2e-scenarios.mdx';
        final file = File(path);
        final backup = file.readAsStringSync();
        final bad = backup.replaceFirst(
          '<!-- example-snippet: e2e_drive_flutter_bash -->\n'
          '```bash\n'
          'dart run showcase/drivers/bin/drive_flutter.dart --device chrome',
          '<!-- example-snippet: e2e_drive_flutter_bash -->\n'
          '```bash\n'
          'dart run showcase/drivers/bin/drive_flutter.dart --device macos',
        );
        await file.writeAsString(bad);
        return _Restore(path, backup);
      },
      expectNeedle: 'e2e_drive_flutter_bash: doc fence drift',
    ),
    _MutationCase(
      name: 'drifted source sentinel',
      setup: (root) async {
        final path = '${root.path}/showcase/drivers/bin/drive_flutter.dart';
        final file = File(path);
        final backup = file.readAsStringSync();
        final bad = backup.replaceFirst(
          'dart run showcase/drivers/bin/drive_flutter.dart --device chrome',
          'dart run showcase/drivers/bin/drive_flutter.dart --device macos',
        );
        await file.writeAsString(bad);
        return _Restore(path, backup);
      },
      expectNeedle: 'e2e_drive_flutter_bash: source sentinel drift',
    ),
    _MutationCase(
      name: 'orphan doc tag',
      setup: (root) async {
        final path = '${root.path}/docs/use-cases/e2e-scenarios.mdx';
        final file = File(path);
        final backup = file.readAsStringSync();
        const tag = '\n<!-- example-snippet: orphan_mutation_probe -->\n';
        final bad = backup.replaceFirst('## Shape', '$tag## Shape');
        await file.writeAsString(bad);
        return _Restore(path, backup);
      },
      expectNeedle: 'orphan snippet tag orphan_mutation_probe',
    ),
    _MutationCase(
      name: 'manifest missing lines',
      setup: (root) async {
        final path = '${root.path}/tool/docs/example_snippets.yaml';
        final file = File(path);
        final backup = file.readAsStringSync();
        final bad = '$backup\n'
            '- id: incomplete_manifest_entry\n'
            '  doc: docs/use-cases/e2e-scenarios.mdx\n'
            '  language: bash\n';
        await file.writeAsString(bad);
        return _Restore(path, backup);
      },
      expectNeedle: 'snippet incomplete_manifest_entry: missing lines',
    ),
  ];

  var passed = 0;
  for (final mutation in cases) {
    final restore = await mutation.setup(repoRoot);
    try {
      final result = verifyExampleSnippets(repoRoot: repoRoot);
      if (result.ok) {
        stderr.writeln('mutation "${mutation.name}": checker must fail');
        exit(1);
      }
      final joined = result.errors.join('\n');
      if (!joined.contains(mutation.expectNeedle)) {
        stderr.writeln('mutation "${mutation.name}": missing expected error');
        stderr.writeln('expected needle: ${mutation.expectNeedle}');
        stderr.writeln('errors:\n$joined');
        exit(1);
      }
      stdout.writeln('mutation OK: ${mutation.name}');
      passed++;
    } finally {
      await restore.apply();
    }
  }

  final after = verifyExampleSnippets(repoRoot: repoRoot);
  if (!after.ok) {
    stderr.writeln('clean tree must pass after mutations');
    for (final e in after.errors) {
      stderr.writeln('  $e');
    }
    exit(1);
  }

  stdout.writeln(
    'check_example_snippets_mutations: OK ($passed/${cases.length} cases)',
  );
}

final class _MutationCase {
  _MutationCase({
    required this.name,
    required this.setup,
    required this.expectNeedle,
  });

  final String name;
  final Future<_Restore> Function(Directory root) setup;
  final String expectNeedle;
}

final class _Restore {
  _Restore(this.path, this.content);

  final String path;
  final String content;

  Future<void> apply() => File(path).writeAsString(content);
}
