// Re-exports shared migrator; CLI runner stays here for stderr/stdout UX.
import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';

export 'package:intentcall_core/intentcall_core.dart'
    show
        MigrateAgentEntriesMigrator,
        MigrateAgentEntriesPathNotFound,
        MigrateAgentEntriesReport,
        migrateAgentEntriesAtPath;

Future<int> runMigrateAgentEntries({
  required final String path,
  required final bool checkOnly,
  required final bool write,
  final String defaultNamespace = 'app',
}) async {
  if (checkOnly && write) {
    stderr.writeln('Use either --check or --write, not both.');
    return 64;
  }

  late final MigrateAgentEntriesReport report;
  try {
    report = await migrateAgentEntriesAtPath(
      path: path,
      write: write,
      checkOnly: checkOnly,
      defaultNamespace: defaultNamespace,
    );
  } on MigrateAgentEntriesPathNotFound catch (error) {
    stderr.writeln(error);
    return 66;
  }

  for (final result in report.results.where((final r) => r.changed)) {
    stdout.writeln('would migrate: ${result.path}');
    if (write && !checkOnly) {
      stdout.writeln('  wrote: ${result.path}');
    }
  }

  if (report.filesChanged == 0) {
    stdout.writeln(
      'OK: no MCPCallEntry migrations needed (${report.filesScanned} dart files scanned)',
    );
  } else {
    stdout.writeln(
      '${report.filesChanged} file(s) ${checkOnly || !write ? 'would change' : 'migrated'} '
      '(${report.filesScanned} dart files scanned)',
    );
  }

  if (checkOnly && report.wouldChange) {
    return 1;
  }
  return 0;
}
