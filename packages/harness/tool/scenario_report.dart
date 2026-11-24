// Report smoke check (ADR-0023): synthetic scenario + report flags.
//
//   dart run packages/harness/tool/scenario_report.dart --smoke
//   dart run packages/harness/tool/scenario_report.dart --smoke \
//     --report=agent --report-out=/tmp/harness-smoke.jsonl
//
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

import 'harness_report_argv.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    // ignore: avoid_print
    print('''
Usage: dart run packages/harness/tool/scenario_report.dart --smoke [report flags]

Runs a built-in pass/fail smoke scenario (no Flutter app) and writes an
optional machine-readable report. Agents use this to verify report shape
without a composition root.

$HarnessReportArgs.usage''');
    exit(0);
  }
  if (!args.contains('--smoke')) {
    // ignore: avoid_print
    print('error: --smoke is required\n$HarnessReportArgs.usage');
    exit(2);
  }

  final reportArgs = requireHarnessReportArgs(args);

  final scenario = Scenario(
    'harness report smoke',
    scenarioId: 'harness-report-smoke',
    steps: [
      (
        'synthetic checks',
        (context) async {
          context.report.pass('boot ok');
          context.report.pass('wiring ok');
          if (args.contains('--force-fail')) {
            context.report.failDetailed(
              'demo fail',
              expected: 'green',
              observed: 'red',
            );
          }
        },
      ),
    ],
  );

  final passed = await scenario.run(runOptions: reportArgs.toRunOptions());
  scenario.report.printSummary();
  if (reportArgs.reportOut != null) {
    // ignore: avoid_print
    print('report: ${reportArgs.reportOut}');
  }
  exit(passed ? 0 : 1);
}
