import 'dart:convert';
import 'dart:io';

import 'package:intentcall_platform/intentcall_platform.dart';

/// `flutter-mcp-toolkit init intentcall-platform [--project-dir PATH] [--check]`
Future<int> runInitintentcallPlatform({
  required final String projectRoot,
  final bool checkOnly = false,
}) async {
  final report = await const PlatformHooksInit().run(
    projectRoot: projectRoot,
    checkOnly: checkOnly,
  );

  stdout.writeln(
    jsonEncode(<String, Object?>{
      'ok': report.ok,
      'checkOnly': checkOnly,
      'projectRoot': report.projectRoot,
      'targets': report.targets
          .map(
            (final t) => <String, Object?>{
              'id': t.id,
              'path': t.path,
              'ok': t.ok,
              if (t.message != null) 'message': t.message,
            },
          )
          .toList(),
    }),
  );

  if (!report.ok) {
    for (final target in report.targets.where((final t) => !t.ok)) {
      stderr.writeln(
        '${target.id}: ${target.message ?? "not configured"} (${target.path})',
      );
    }
  }

  return report.ok ? 0 : 1;
}
