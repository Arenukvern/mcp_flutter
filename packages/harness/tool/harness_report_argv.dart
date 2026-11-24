import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Composition-root helper: validates report argv and exits 2 with [usage].
///
/// Library code should use [HarnessReportParseResult.parse] instead (no `exit`).
HarnessReportArgs requireHarnessReportArgs(List<String> args) {
  final result = HarnessReportParseResult.parse(args);
  if (!result.isOk) {
    // ignore: avoid_print
    print('error: ${result.error}\n$HarnessReportArgs.usage');
    exit(2);
  }
  return result.args!;
}