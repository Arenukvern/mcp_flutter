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

int _consoleBytes(ScenarioReport report, {bool allPassed = false}) {
  final buffer = StringBuffer();
  for (final check in report.checks) {
    buffer.writeln('  $check');
  }
  buffer.writeln(
    allPassed
        ? 'ALL PASS (${report.checks.length})'
        : 'FAILURES: ${report.checks.where((c) => c.status == CheckStatus.fail).length}/${report.checks.length}',
  );
  return utf8.encode(buffer.toString()).length;
}

void main() {
  group('HarnessReportArgs', () {
    test('validationError rejects unknown report format', () {
      expect(
        HarnessReportArgs.validationError(['--report=jsonl']),
        contains('unknown --report=jsonl'),
      );
    });

    test('validationError requires report-out when report set', () {
      expect(
        HarnessReportArgs.validationError(['--report=agent']),
        '--report requires --report-out=<path>',
      );
    });

    test('HarnessReportParseResult accepts valid report flags', () {
      final parsed = HarnessReportParseResult.parse([
        '--report=agent',
        '--report-out=/tmp/out.jsonl',
        '--report-diff=/tmp/prev.json',
        '--scenario-id=checkout-e2e',
      ]);
      expect(parsed.isOk, isTrue);
      expect(parsed.args!.format, HarnessReportFormat.agent);
      expect(parsed.args!.reportOut, '/tmp/out.jsonl');
    });
  });

  group('stable check ids', () {
    test('slug-only ids with collision suffix', () {
      final report = ScenarioReport()
        ..pass('Same Name')
        ..pass('same name')
        ..fail('other');
      final ids = assignStableCheckIds('checkout-e2e', report.checks);
      expect(ids, [
        'checkout-e2e:same-name',
        'checkout-e2e:same-name#2',
        'checkout-e2e:other',
      ]);
    });

    test('inserting a check does not shift later ids', () {
      final before = ScenarioReport()
        ..pass('alpha')
        ..failDetailed('beta', expected: 'ok');
      final after = ScenarioReport()
        ..pass('inserted')
        ..pass('alpha')
        ..failDetailed('beta', expected: 'ok');
      final idsBefore = assignStableCheckIds('s', before.checks);
      final idsAfter = assignStableCheckIds('s', after.checks);
      expect(idsBefore, ['s:alpha', 's:beta']);
      expect(idsAfter[1], idsBefore[0]);
      expect(idsAfter[2], idsBefore[1]);
    });
  });

  group('observed encoding', () {
    test('agent omits obs when absent; keeps literal false', () {
      final report = ScenarioReport()
        ..failDetailed('a', expected: 'x', observed: false)
        ..failDetailed('b', expected: 'y')
        ..failDetailed('c', detail: '');
      final writer = ScenarioReportWriter(
        scenarioName: 'checkout E2E',
        scenarioId: 'checkout-e2e',
        report: report,
        stepsNotRun: const [],
      );
      final lines = writer.buildAgentJsonl();
      expect(lines[1], contains('"obs":false'));
      expect(lines[2], isNot(contains('"obs"')));
      expect(lines[3], isNot(contains('"obs"')));
    });

    test('full JSON failures omit observed when absent', () {
      final report = ScenarioReport()..fail('bare');
      final writer = ScenarioReportWriter(
        scenarioName: 't',
        scenarioId: 't',
        report: report,
        stepsNotRun: const [],
      );
      final failures = writer.buildFullJson()['failures']! as List;
      expect((failures.single as Map).containsKey('observed'), isFalse);
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
      validateAgainstSchema(_loadReportSchema(), doc);
      final checks = doc['checks']! as List;
      expect(checks.length, report.checks.length);
      expect((checks.first as Map)['status'], 'pass');
    });

    test('all-pass agent line is smaller than console', () {
      final passOnly = ScenarioReport();
      for (var i = 0; i < 10; i++) {
        passOnly.pass('gate-$i');
      }
      final w = ScenarioReportWriter(
        scenarioName: 'checkout E2E',
        scenarioId: 'checkout-e2e',
        report: passOnly,
        stepsNotRun: const [],
      );
      final agentBytes = utf8.encode(w.buildAgentJsonl().single).length;
      final consoleBytes = _consoleBytes(passOnly, allPassed: true);
      expect(agentBytes, lessThan(consoleBytes));
    });

    test('token sizes (ADR-0023 regression)', () {
      final fixtureAgent = utf8.encode(writer.buildAgentJsonl().join('\n')).length;
      final fixtureConsole = _consoleBytes(report);
      final fixtureJson = utf8.encode(
        const JsonEncoder().convert(writer.buildFullJson()),
      ).length;

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
      final w24 = ScenarioReportWriter(
        scenarioName: 'checkout E2E',
        scenarioId: 'checkout-e2e',
        report: passOnly,
        stepsNotRun: const [],
      );
      final agent24 = utf8.encode(w24.buildAgentJsonl().join('\n')).length;
      final console24 = _consoleBytes(passOnly);

      final allPass = ScenarioReport();
      for (var i = 0; i < 10; i++) {
        allPass.pass('gate-$i');
      }
      final wAll = ScenarioReportWriter(
        scenarioName: 'checkout E2E',
        scenarioId: 'checkout-e2e',
        report: allPass,
        stepsNotRun: const [],
      );
      final allPassAgent = utf8.encode(wAll.buildAgentJsonl().single).length;
      final allPassConsole = _consoleBytes(allPass, allPassed: true);

      expect(allPassAgent, lessThan(allPassConsole));
      expect(agent24, lessThan(console24));
      expect(fixtureAgent, inInclusiveRange(400, 520));
      expect(fixtureConsole, inInclusiveRange(260, 330));
      expect(fixtureJson, inInclusiveRange(1100, 1300));
    });

    test('writes junit with a testcase per check', () async {
      final xml = writer.buildJUnitXml();
      expect(xml.split('<testcase').length - 1, report.checks.length);
      expect(xml, contains('<failure'));
    });

    test('diff uses stable ids without index prefix', () {
      final prev = <String, Object?>{
        'failures': [
          {'id': 'checkout-e2e:old-fail'},
        ],
      };
      final diff = ReportDiff.fromBaseline(
        writer.buildFullJson(),
        PreviousBaseline.ok(prev),
      );
      expect(diff.newFailures, contains('checkout-e2e:total-rendered'));
      expect(diff.resolved, contains('checkout-e2e:old-fail'));
    });

    test('missing diff baseline emits baseline missing', () async {
      final dir = await Directory.systemTemp.createTemp('harness-diff-');
      addTearDown(() => dir.delete(recursive: true));
      final out = p.join(dir.path, 'out.jsonl');
      final missing = p.join(dir.path, 'nope.json');

      final scenario = Scenario('diff missing', steps: [
        (
          'one',
          (c) async {
            c.report.fail('x');
          },
        ),
      ]);
      await scenario.run(
        runOptions: ScenarioRunOptions(
          format: HarnessReportFormat.agent,
          reportOut: out,
          diffAgainst: missing,
        ),
      );
      final last = File(out)
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .last;
      expect(jsonDecode(last), {'kind': 'diff', 'baseline': 'missing'});
    });

    test('agent JSONL baseline loads for diff', () async {
      final dir = await Directory.systemTemp.createTemp('harness-jsonl-diff-');
      addTearDown(() => dir.delete(recursive: true));
      final baseline = p.join(dir.path, 'prev.jsonl');
      final writerPrev = ScenarioReportWriter(
        scenarioName: 'checkout E2E',
        scenarioId: 'checkout-e2e',
        report: ScenarioReport()..failDetailed('total rendered'),
        stepsNotRun: const [],
      );
      await writerPrev.write(
        format: HarnessReportFormat.agent,
        path: baseline,
      );

      final loaded = await ReportDiff.loadPrevious(baseline);
      expect(loaded.status, BaselineStatus.ok);
      final diff = ReportDiff.fromBaseline(writer.buildFullJson(), loaded);
      expect(diff.newFailures, contains('checkout-e2e:pay-button'));
    });

    test('indented full JSON baseline loads for diff', () async {
      final dir = await Directory.systemTemp.createTemp('harness-json-diff-');
      addTearDown(() => dir.delete(recursive: true));
      final baseline = p.join(dir.path, 'prev.json');
      await writer.write(
        format: HarnessReportFormat.json,
        path: baseline,
      );
      final loaded = await ReportDiff.loadPrevious(baseline);
      expect(loaded.status, BaselineStatus.ok);
      final diff = ReportDiff.fromBaseline(writer.buildFullJson(), loaded);
      expect(diff.unchanged, contains('checkout-e2e:total-rendered'));
    });

    test('HarnessReportParseResult never calls exit', () {
      final bad = HarnessReportParseResult.parse(['--report=jsonl']);
      expect(bad.isOk, isFalse);
      expect(bad.error, isNotNull);
    });

    test('JSON array baseline file is unreadable', () async {
      final dir = await Directory.systemTemp.createTemp('harness-array-diff-');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'prev.json');
      File(path).writeAsStringSync('[1,2,3]');
      expect(
        (await ReportDiff.loadPrevious(path)).status,
        BaselineStatus.unreadable,
      );
    });

    test('JSONL with no harness lines is unreadable', () async {
      final dir = await Directory.systemTemp.createTemp('harness-garbage-jsonl-');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'prev.jsonl');
      File(path).writeAsStringSync('{"foo":"bar"}\n{"other":1}\n');
      expect(
        (await ReportDiff.loadPrevious(path)).status,
        BaselineStatus.unreadable,
      );
    });

    test('skip then pass: verdict pass and skip in n vector', () async {
      final dir = await Directory.systemTemp.createTemp('harness-skip-report-');
      addTearDown(() => dir.delete(recursive: true));
      final out = p.join(dir.path, 'skip.jsonl');
      final scenario = Scenario('skip flow', scenarioId: 'skip-flow', steps: [
        (
          'a',
          (c) async {
            c.report.skip('probe', 'n/a');
          },
        ),
        (
          'b',
          (c) async {
            c.report.pass('ok');
          },
        ),
      ]);
      expect(
        await scenario.run(
          runOptions: ScenarioRunOptions(
            format: HarnessReportFormat.agent,
            reportOut: out,
          ),
        ),
        isTrue,
      );
      final header =
          jsonDecode(File(out).readAsLinesSync().first) as Map<String, Object?>;
      expect(header['verdict'], 'pass');
      expect(header['n'], [1, 0, 1, 0, 0]);
    });

    test('malformed diff baseline is unreadable', () async {
      final dir = await Directory.systemTemp.createTemp('harness-bad-diff-');
      addTearDown(() => dir.delete(recursive: true));
      final bad = p.join(dir.path, 'prev.json');
      File(bad).writeAsStringSync('{\nnot json\n{{{');
      final loaded = await ReportDiff.loadPrevious(bad);
      expect(loaded.status, BaselineStatus.unreadable);
      final diff = ReportDiff.fromBaseline(writer.buildFullJson(), loaded);
      expect(diff.toJson(), {'baseline': 'unreadable'});

      final out = p.join(dir.path, 'out.jsonl');
      final scenario = Scenario('unreadable baseline', steps: [
        (
          'one',
          (c) async {
            c.report.fail('x');
          },
        ),
      ]);
      await scenario.run(
        runOptions: ScenarioRunOptions(
          format: HarnessReportFormat.agent,
          reportOut: out,
          diffAgainst: bad,
        ),
      );
      final last = File(out)
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .last;
      expect(jsonDecode(last), {'kind': 'diff', 'baseline': 'unreadable'});
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
            context.report.failDetailed('boom', expected: 'ok', observed: 'nope');
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
      final header = jsonDecode(File(out).readAsLinesSync().first) as Map;
      expect(header['v'], 1);
      expect(header['stepsNotRun'], ['three']);
    });
  });
}
