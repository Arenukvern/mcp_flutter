import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Resolves `packages/harness` whether tests run from repo root or package dir.
Directory resolveHarnessPackageRoot() {
  final seen = <String>{};
  for (final start in [
    Directory.current.absolute,
    Directory(p.dirname(Platform.script.toFilePath())).absolute,
  ]) {
    var dir = start;
    while (seen.add(dir.path)) {
      for (final rel in ['.', p.join('packages', 'harness')]) {
        final candidate = Directory(p.normalize(p.join(dir.path, rel)));
        final pubspec = File(p.join(candidate.path, 'pubspec.yaml'));
        if (pubspec.existsSync() &&
            pubspec.readAsStringSync().contains('name: flutter_mcp_harness')) {
          return candidate;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
  throw StateError(
    'Could not resolve flutter_mcp_harness root '
    '(cwd=${Directory.current.path})',
  );
}

/// LA automations visual acceptance is an on-device probe, not a headless test.
/// Run: `dart run tool/visual_supervisor_probe.dart <out-dir>` with `LA_VM_URI`.
void main() {
  final harnessRoot = resolveHarnessPackageRoot();

  test('visual_supervisor_probe.dart exists as dart run entry (not dart test)', () {
    final probe = File(
      p.join(harnessRoot.path, 'tool', 'visual_supervisor_probe.dart'),
    );
    expect(probe.existsSync(), isTrue, reason: 'ADR-0041 §6 on-device probe');
    final body = probe.readAsStringSync();
    expect(
      body,
      contains('Future<void> main(List<String> args)'),
      reason: 'probe argv contract preserved',
    );
    expect(
      body,
      anyOf(contains('notes-indexer'), contains('Automations')),
      reason: 'semantic assertions preserved in probe script',
    );
  });

  test('harness tool/ has no *_test.dart files (dart test loader contract)', () {
    final toolDir = Directory(p.join(harnessRoot.path, 'tool'));
    expect(toolDir.existsSync(), isTrue);
    final offenders = toolDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .map((f) => p.relative(f.path, from: harnessRoot.path))
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'files named *_test.dart under packages/harness/tool/ are collected '
          'when dart test walks that tree and fail load if main takes args',
    );
  });
}
