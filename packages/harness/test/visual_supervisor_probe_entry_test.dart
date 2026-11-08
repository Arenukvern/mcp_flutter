import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Coherent graph: LA automations visual acceptance is an on-device probe, not
/// a headless dart test. Run:
/// `dart run tool/visual_supervisor_probe.dart <out-dir>` with `LA_VM_URI` set
/// (see [packages/harness/tool/visual_probe.dart]).
void main() {
  final repoRoot = Directory.current;
  final probe = File(
    p.join(repoRoot.path, 'tool', 'visual_supervisor_probe.dart'),
  );

  test('visual_supervisor_probe.dart exists as dart run entry (not dart test)', () {
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

  test('tool/ has no *_test.dart files (dart test loader contract)', () {
    final toolDir = Directory(p.join(repoRoot.path, 'tool'));
    final offenders = toolDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .map((f) => p.relative(f.path, from: repoRoot.path))
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'files named *_test.dart under tool/ are collected by dart test '
          'and fail load if main takes args',
    );
  });
}
