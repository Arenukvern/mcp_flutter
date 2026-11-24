import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Map<String, Object?> _loadReportSchema() {
  final raw = File('schema/harness_scenario_report_v1.schema.json')
      .readAsStringSync();
  return (jsonDecode(raw) as Map).cast<String, Object?>();
}

ScenarioReport _fixtureReport() {
  final report = ScenarioReport();
  report.setCurrentStep('boot');
  for (var i = 0; i < 10; i++) {
    report.pass('check-$i ok');
  }
  report.setCurrentStep('assert cart');
  report.failDetailed(
    'total rendered',
    detail: 'no total in snapshot',
    expected: 'total in snapshot',
    observed: false,
    semanticDelta: 'snapshot nodes=41, none with role=total',
  );
  report.failDetailed(
    'pay button',
    detail: 'Pay disabled',
    expected: 'Pay enabled',
    observed: 'Pay disabled',
    evidencePaths: ['/tmp/checkout-e2e/host.log'],
  );
  return report;
}

void main() {
  group('HarnessReportArgs', () {
    test('parses report flags', () {
      final parsed = HarnessReportArgs.parse([
        '--skip-build',
        '--report=agent',
        '--report-out=/tmp/out.jsonl',
        '--report-diff=/tmp/prev.json',
        '--scenario-id=checkout-e2e',
      ]);
      expect(parsed.format, HarnessReportFormat.agent);
      expect(parsed.reportOut, '/tmp/out.jsonl');
      expect(parsed.diffAgainst, '/tmp/prev.json');
      expect(parsed.scenarioId, 'checkout-e2e');
    });
  });

  group('ScenarioReportWriter', () {
    late ScenarioReport report;
    late ScenarioReportWriter writer;

    setUp(() {
      report = _fixtureReport();
      writer = ScenarioReportWriter(
        scenarioName: 'checkout E2E',
        scenarioId: 'checkout-e2e',
        report: report,
        stepsNotRun: const ['teardown metrics'],
        evidenceDir: '/tmp/checkout-e2e',
      );
    });

    test('full JSON validates against published schema', () {
      final doc = writer.buildFullJson();
      final schema = _loadReportSchema();
      expect(() => validateAgainstSchema(schema, doc), returnsNormally);
    });

    test('agent JSONL is smaller than console when passes dominate', () {
      final passOnly = ScenarioReport();
      for (var i = 0; i < 24; i++) {
        passOnly.pass('gate-$i');
      }
      passOnly.failDetailed(
        'total rendered',
        detail: 'no total',
        expected: 'total in snapshot',
        observed: false,
      );
      final compactWriter = ScenarioReportWriter(
        scenarioName: 'checkout E2E',
        scenarioId: 'checkout-e2e',
        report: passOnly,
        stepsNotRun: const [],
      );
      final agentBytes =
          utf8.encode(compactWriter.buildAgentJsonl().join('\n')).length;
      final buffer = StringBuffer();
      for (final check in passOnly.checks) {
        buffer.writeln('  $check');
      }
      buffer.writeln('FAILURES: 1/${passOnly.checks.length}');
      final consoleBytes = utf8.encode(buffer.toString()).length;
      expect(agentBytes, lessThan(consoleBytes));
    });

    test('fixture token sizes match ADR-0023 table (regression)', () {
      final agentBytes = utf8.encode(writer.buildAgentJsonl().join('\n')).length;
      final buffer = StringBuffer();
      for (final check in report.checks) {
        buffer.writeln('  $check');
      }
      buffer.writeln('FAILURES: 2/${report.checks.length}');
      final consoleBytes = utf8.encode(buffer.toString()).length;
      final jsonBytes = utf8.encode(
        const JsonEncoder().convert(writer.buildFullJson()),
      ).length;
      expect(agentBytes, inInclusiveRange(500, 560));
      expect(consoleBytes, inInclusiveRange(270, 320));
      expect(jsonBytes, inInclusiveRange(600, 680));
    });

    test('writes agent, json, and junit artifacts', () async {
      final dir = await Directory.systemTemp.createTemp('harness-report-');
      addTearDown(() => dir.delete(recursive: true));

      await writer.write(
        format: HarnessReportFormat.agent,
        path: p.join(dir.path, 'agent.jsonl'),
      );
      await writer.write(
        format: HarnessReportFormat.json,
        path: p.join(dir.path, 'full.json'),
      );
      await writer.write(
        format: HarnessReportFormat.junit,
        path: p.join(dir.path, 'junit.xml'),
      );

      final agent = File(p.join(dir.path, 'agent.jsonl')).readAsStringSync();
      expect(agent.split('\n').first, contains('"verdict":"fail"'));
      expect(agent, contains('"obs":'));

      final full = jsonDecode(
        File(p.join(dir.path, 'full.json')).readAsStringSync(),
      ) as Map<String, Object?>;
      validateAgainstSchema(_loadReportSchema(), full);

      final junit = File(p.join(dir.path, 'junit.xml')).readAsStringSync();
      expect(junit, contains('<testsuite'));
      expect(junit, contains('<failure'));
    });

    test('diff mode compares failure ids', () {
      final prev = <String, Object?>{
        'failures': [
          {'id': 'checkout-e2e:c10:old-fail'},
        ],
      };
      final diff = ReportDiff.compute(writer.buildFullJson(), prev);
      expect(diff, isNotNull);
      expect(diff!.newFailures, contains('checkout-e2e:c10:total-rendered'));
      expect(diff.resolved, contains('checkout-e2e:c10:old-fail'));
    });
  });

  group('Scenario.run report emission', () {
    test('writes agent report when runOptions set', () async {
      final dir = await Directory.systemTemp.createTemp('harness-run-report-');
      addTearDown(() => dir.delete(recursive: true));
      final out = p.join(dir.path, 'report.jsonl');

      final scenario = Scenario('token fixture', steps: [
        (
          'one',
          (context) async {
            context.report.pass('a');
            context.report.pass('b');
          },
        ),
        (
          'two',
          (context) async {
            context.report.failDetailed(
              'boom',
              expected: 'ok',
              observed: false,
            );
          },
        ),
        (
          'three',
          (context) async {
            context.report.pass('never');
          },
        ),
      ]);

      final ok = await scenario.run(
        runOptions: ScenarioRunOptions(
          format: HarnessReportFormat.agent,
          reportOut: out,
        ),
      );
      expect(ok, isFalse);
      final lines = File(out).readAsLinesSync();
      expect(lines.length, greaterThanOrEqualTo(2));
      final header = jsonDecode(lines.first) as Map<String, Object?>;
      expect(header['stepsNotRun'], ['three']);
    });
  });
}