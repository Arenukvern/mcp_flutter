import 'dart:convert';
import 'dart:io';

import 'check.dart';

/// Selects which machine-readable artifact to write after [Scenario.run].
enum HarnessReportFormat {
  agent,
  json,
  junit,
}

/// CLI / programmatic options for optional report output (console unchanged).
final class HarnessReportArgs {
  const HarnessReportArgs({
    this.format,
    this.reportOut,
    this.diffAgainst,
    this.scenarioId,
  });

  final HarnessReportFormat? format;
  final String? reportOut;
  final String? diffAgainst;
  final String? scenarioId;

  static const reportFlag = '--report=';
  static const reportOutFlag = '--report-out=';
  static const reportDiffFlag = '--report-diff=';
  static const scenarioIdFlag = '--scenario-id=';

  static const usage = '''
Harness report flags (composition roots & dart run packages/harness/tool/scenario_report.dart):
  --report=agent|json|junit   Machine-readable artifact (requires --report-out)
  --report-out=<path>         Output path for the report file
  --report-diff=<path>        Previous report (JSON or agent JSONL) for failure-id diff
  --scenario-id=<slug>        Stable scenario id (default: slug of scenario name)
''';

  /// Non-strict parse (unknown flags ignored, unknown --report= values ignored).
  static HarnessReportArgs parse(Iterable<String> args) {
    HarnessReportFormat? format;
    String? reportOut;
    String? diffAgainst;
    String? scenarioId;
    for (final arg in args) {
      if (arg.startsWith(reportFlag)) {
        format = tryParseFormat(arg.substring(reportFlag.length));
      } else if (arg.startsWith(reportOutFlag)) {
        reportOut = arg.substring(reportOutFlag.length);
      } else if (arg.startsWith(reportDiffFlag)) {
        diffAgainst = arg.substring(reportDiffFlag.length);
      } else if (arg.startsWith(scenarioIdFlag)) {
        scenarioId = arg.substring(scenarioIdFlag.length);
      }
    }
    return HarnessReportArgs(
      format: format,
      reportOut: reportOut,
      diffAgainst: diffAgainst,
      scenarioId: scenarioId,
    );
  }

  /// Non-null when report-related argv is invalid.
  static String? validationError(Iterable<String> args) {
    HarnessReportFormat? format;
    String? reportOut;
    for (final arg in args) {
      if (arg.startsWith(reportFlag)) {
        final raw = arg.substring(reportFlag.length);
        format = tryParseFormat(raw);
        if (format == null) {
          return 'unknown --report=$raw (expected agent, json, or junit)';
        }
      } else if (arg.startsWith(reportOutFlag)) {
        reportOut = arg.substring(reportOutFlag.length);
      }
    }
    if (format != null && (reportOut == null || reportOut.isEmpty)) {
      return '--report requires --report-out=<path>';
    }
    return null;
  }

  /// Validates report-related argv; prints [usage] and exits 2 on violation.
  static HarnessReportArgs parseValidated(List<String> args) {
    final err = validationError(args);
    if (err != null) _reportUsageAndExit(err);
    return parse(args);
  }

  static HarnessReportFormat? tryParseFormat(String raw) => switch (raw) {
        'agent' => HarnessReportFormat.agent,
        'json' => HarnessReportFormat.json,
        'junit' => HarnessReportFormat.junit,
        _ => null,
      };

  ScenarioRunOptions toRunOptions() => ScenarioRunOptions(
        format: format,
        reportOut: reportOut,
        diffAgainst: diffAgainst,
        scenarioId: scenarioId,
      );
}

void _reportUsageAndExit(String message) {
  // ignore: avoid_print
  print('error: $message\n$HarnessReportArgs.usage');
  exit(2);
}

/// Options passed to [Scenario.run] for optional report emission.
final class ScenarioRunOptions {
  const ScenarioRunOptions({
    this.format,
    this.reportOut,
    this.diffAgainst,
    this.scenarioId,
  });

  final HarnessReportFormat? format;
  final String? reportOut;
  final String? diffAgainst;
  final String? scenarioId;
}

/// Slug used as stable [scenarioId] when none is provided.
String scenarioIdFromName(String scenarioName) {
  final slug = scenarioName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'scenario' : slug;
}

String checkNameSlug(String checkName) {
  final slug = checkName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'check' : slug;
}

/// Stable check ids: `$scenarioId:$slug`, with `#2`… on slug collision within
/// a run. Explicit [Check.id] overrides win.
List<String> assignStableCheckIds(String scenarioId, List<Check> checks) {
  final slugCounts = <String, int>{};
  final ids = <String>[];
  for (final check in checks) {
    if (check.id != null) {
      ids.add(check.id!);
      continue;
    }
    final slug = checkNameSlug(check.name);
    final occurrence = slugCounts.update(slug, (v) => v + 1, ifAbsent: () => 1);
    ids.add(
      occurrence == 1 ? '$scenarioId:$slug' : '$scenarioId:$slug#$occurrence',
    );
  }
  return ids;
}

/// Builds and writes scenario report artifacts.
final class ScenarioReportWriter {
  ScenarioReportWriter({
    required this.scenarioName,
    required this.scenarioId,
    required this.report,
    required this.stepsNotRun,
    this.evidenceDir,
  }) : _checkIds = assignStableCheckIds(scenarioId, report.checks);

  final String scenarioName;
  final String scenarioId;
  final ScenarioReport report;
  final List<String> stepsNotRun;
  final String? evidenceDir;
  final List<String> _checkIds;

  bool get _hasFailures =>
      report.checks.any((c) => c.status == CheckStatus.fail);

  String get verdict => report.allPassed ? 'pass' : 'fail';

  Map<String, Object?> buildFullJson({ReportDiff? diff}) {
    final summary = _summaryCounts();
    return <String, Object?>{
      'schema': 'harness.scenario_report.v1',
      'scenarioId': scenarioId,
      'scenario': scenarioName,
      'verdict': verdict,
      'summary': summary,
      'stepsNotRun': stepsNotRun,
      if (evidenceDir != null && _hasFailures) 'evidenceDir': evidenceDir,
      'checks': _checksSummary(),
      'failures': _failureMaps(),
      if (diff != null) 'diff': diff.toJson(),
    };
  }

  List<Map<String, Object?>> _checksSummary() {
    final out = <Map<String, Object?>>[];
    for (var i = 0; i < report.checks.length; i++) {
      final check = report.checks[i];
      out.add(<String, Object?>{
        'id': _checkIds[i],
        'status': _statusName(check.status),
      });
    }
    return out;
  }

  static String _statusName(CheckStatus status) => switch (status) {
        CheckStatus.pass => 'pass',
        CheckStatus.fail => 'fail',
        CheckStatus.skip => 'skip',
        CheckStatus.notRun => 'not_run',
      };

  List<String> buildAgentJsonl({ReportDiff? diff}) {
    final summary = _summaryCounts();
    final header = <String, Object?>{
      'v': 1,
      'sid': scenarioId,
      if (scenarioIdFromName(scenarioName) != scenarioId) 'scenario': scenarioName,
      'verdict': verdict,
      'n': [
        summary['pass'],
        summary['fail'],
        summary['skip'],
        summary['not_run'],
        summary['steps_not_run'],
      ],
      if (stepsNotRun.isNotEmpty) 'stepsNotRun': stepsNotRun,
      if (evidenceDir != null && _hasFailures) 'evidenceDir': evidenceDir,
    };
    final lines = <String>[
      jsonEncode(header),
      ..._failureMaps().map(
        (f) => jsonEncode(_compactAgentFailureLine(f)),
      ),
    ];
    if (diff != null) {
      lines.add(jsonEncode(<String, Object?>{'kind': 'diff', ...diff.toJson()}));
    }
    return lines;
  }

  String buildJUnitXml() {
    final summary = _summaryCounts();
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<testsuite name="${_xmlEscape(scenarioName)}" '
        'tests="${report.checks.length}" '
        'failures="${summary['fail']}" '
        'skipped="${(summary['skip'] as int) + (summary['not_run'] as int)}" '
        'errors="0">',
      );
    for (var i = 0; i < report.checks.length; i++) {
      final check = report.checks[i];
      final id = _checkIds[i];
      buffer.writeln(
        '  <testcase classname="${_xmlEscape(scenarioId)}" '
        'name="${_xmlEscape(check.name)}" id="${_xmlEscape(id)}">',
      );
      switch (check.status) {
        case CheckStatus.fail:
          buffer.writeln(
            '    <failure message="${_xmlEscape(check.detail)}">'
            '${_xmlEscape(_failureBody(check))}</failure>',
          );
        case CheckStatus.skip:
        case CheckStatus.notRun:
          buffer.writeln('    <skipped/>');
        case CheckStatus.pass:
          break;
      }
      buffer.writeln('  </testcase>');
    }
    buffer.writeln('</testsuite>');
    return buffer.toString();
  }

  Future<void> write({
    required HarnessReportFormat format,
    required String path,
    ReportDiff? diff,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    switch (format) {
      case HarnessReportFormat.agent:
        await file.writeAsString('${buildAgentJsonl(diff: diff).join('\n')}\n');
      case HarnessReportFormat.json:
        await file.writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(buildFullJson(diff: diff))}\n',
        );
      case HarnessReportFormat.junit:
        await file.writeAsString(buildJUnitXml());
    }
  }

  Map<String, int> _summaryCounts() {
    var pass = 0, fail = 0, skip = 0, notRun = 0;
    for (final check in report.checks) {
      switch (check.status) {
        case CheckStatus.pass:
          pass++;
        case CheckStatus.fail:
          fail++;
        case CheckStatus.skip:
          skip++;
        case CheckStatus.notRun:
          notRun++;
      }
    }
    return <String, int>{
      'pass': pass,
      'fail': fail,
      'skip': skip,
      'not_run': notRun,
      'steps_not_run': stepsNotRun.length,
    };
  }

  Map<String, Object?> _compactAgentFailureLine(Map<String, Object?> full) {
    final line = <String, Object?>{'id': full['id']};
    final expected = full['expected'];
    if (expected != null) line['exp'] = expected;
    if (full.containsKey('observed')) line['obs'] = full['observed'];
    if (full['step'] != null) line['step'] = full['step'];
    final detail = full['detail'];
    if (detail is String && detail.isNotEmpty) line['det'] = detail;
    if (full['semanticDelta'] != null) line['delta'] = full['semanticDelta'];
    if (full['evidence'] != null) line['ev'] = full['evidence'];
    return line;
  }

  List<Map<String, Object?>> _failureMaps() {
    final out = <Map<String, Object?>>[];
    for (var i = 0; i < report.checks.length; i++) {
      final check = report.checks[i];
      if (check.status != CheckStatus.fail) continue;
      final id = _checkIds[i];
      final map = <String, Object?>{
        'id': id,
        if (check.step != null) 'step': check.step,
        if (check.expected != null) 'expected': check.expected,
        if (check.observed != null) 'observed': check.observed,
        if (check.detail.isNotEmpty) 'detail': check.detail,
        if (check.semanticDelta != null) 'semanticDelta': check.semanticDelta,
        if (check.evidencePaths.isNotEmpty) 'evidence': check.evidencePaths,
      };
      out.add(map);
    }
    return out;
  }

  String _failureBody(Check check) {
    final parts = <String>[
      if (check.expected != null) 'expected: ${check.expected}',
      if (check.observed != null) 'observed: ${check.observed}',
      if (check.detail.isNotEmpty) 'detail: ${check.detail}',
      if (check.semanticDelta != null) 'delta: ${check.semanticDelta}',
      if (check.evidencePaths.isNotEmpty) 'evidence: ${check.evidencePaths.join(', ')}',
    ];
    return parts.isEmpty ? check.name : parts.join('\n');
  }

  static String _xmlEscape(String raw) => raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Diff of failure ids vs a previous report (full JSON or agent JSONL).
final class ReportDiff {
  ReportDiff({
    required this.newFailures,
    required this.resolved,
    required this.unchanged,
    this.baselineMissing = false,
  });

  final List<String> newFailures;
  final List<String> resolved;
  final List<String> unchanged;
  final bool baselineMissing;

  factory ReportDiff.baselineMissing() => ReportDiff(
        newFailures: const [],
        resolved: const [],
        unchanged: const [],
        baselineMissing: true,
      );

  Map<String, Object?> toJson() => baselineMissing
      ? <String, Object?>{'baseline': 'missing'}
      : <String, Object?>{
          'newFailures': newFailures,
          'resolved': resolved,
          'unchangedFailures': unchanged,
        };

  static ReportDiff? compute(
    Map<String, Object?> current,
    Map<String, Object?>? previous,
  ) {
    if (previous == null) return ReportDiff.baselineMissing();
    final cur = _failureIds(current);
    final prev = _failureIds(previous);
    return ReportDiff(
      newFailures: cur.difference(prev).toList()..sort(),
      resolved: prev.difference(cur).toList()..sort(),
      unchanged: cur.intersection(prev).toList()..sort(),
    );
  }

  static Set<String> _failureIds(Map<String, Object?> doc) {
    final failures = doc['failures'];
    if (failures is! List) return {};
    return {
      for (final f in failures)
        if (f is Map && f['id'] is String) f['id'] as String,
    };
  }

  /// Loads a prior report from JSON (single object) or agent JSONL.
  static Future<Map<String, Object?>?> loadPrevious(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    final content = await file.readAsString();
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;

    if (!trimmed.contains('\n')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, Object?>) return decoded;
      if (decoded is Map) return decoded.cast<String, Object?>();
      return null;
    }

    final failures = <Map<String, Object?>>[];
    for (final line in content.split('\n')) {
      if (line.trim().isEmpty) continue;
      final decoded = jsonDecode(line);
      if (decoded is! Map) continue;
      final map = decoded.cast<String, Object?>();
      if (map['kind'] == 'diff') continue;
      final id = map['id'];
      if (id is String) failures.add(<String, Object?>{'id': id});
    }
    return <String, Object?>{'failures': failures};
  }
}

/// After [Scenario.run], writes the report when [options] requests it.
Future<void> writeScenarioReportIfRequested({
  required String scenarioName,
  required ScenarioReport report,
  required List<String> stepsNotRun,
  String? evidenceDir,
  ScenarioRunOptions? options,
}) async {
  final opts = options;
  if (opts == null || opts.format == null || opts.reportOut == null) return;
  final scenarioId = opts.scenarioId ?? scenarioIdFromName(scenarioName);
  final writer = ScenarioReportWriter(
    scenarioName: scenarioName,
    scenarioId: scenarioId,
    report: report,
    stepsNotRun: stepsNotRun,
    evidenceDir: evidenceDir,
  );
  ReportDiff? diff;
  final diffPath = opts.diffAgainst;
  if (diffPath != null && diffPath.isNotEmpty) {
    final previous = await ReportDiff.loadPrevious(diffPath);
    diff = ReportDiff.compute(writer.buildFullJson(), previous);
  }
  await writer.write(format: opts.format!, path: opts.reportOut!, diff: diff);
}