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

  /// Parses harness report flags from composition-root argv (first-class, no
  /// shell glue).
  static HarnessReportArgs parse(Iterable<String> args) {
    HarnessReportFormat? format;
    String? reportOut;
    String? diffAgainst;
    String? scenarioId;
    for (final arg in args) {
      if (arg.startsWith(reportFlag)) {
        format = _parseFormat(arg.substring(reportFlag.length));
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

  static HarnessReportFormat? _parseFormat(String raw) => switch (raw) {
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

String checkStableId(String scenarioId, int index, String checkName) {
  final slug = checkName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final namePart = slug.isEmpty ? 'check' : slug;
  return '$scenarioId:c$index:$namePart';
}

/// Builds and writes scenario report artifacts.
final class ScenarioReportWriter {
  ScenarioReportWriter({
    required this.scenarioName,
    required this.scenarioId,
    required this.report,
    required this.stepsNotRun,
    this.evidenceDir,
  });

  final String scenarioName;
  final String scenarioId;
  final ScenarioReport report;
  final List<String> stepsNotRun;
  final String? evidenceDir;

  String get verdict => report.allPassed ? 'pass' : 'fail';

  Map<String, Object?> buildFullJson({ReportDiff? diff}) {
    final failures = _failureMaps();
  final summary = _summaryCounts();
    return <String, Object?>{
      'schema': 'harness.scenario_report.v1',
      'scenarioId': scenarioId,
      'scenario': scenarioName,
      'verdict': verdict,
      'summary': summary,
      'stepsNotRun': stepsNotRun,
      if (evidenceDir != null) 'evidenceDir': evidenceDir,
      'failures': failures,
      if (diff != null) 'diff': diff.toJson(),
    };
  }

  List<String> buildAgentJsonl({ReportDiff? diff}) {
    final summary = _summaryCounts();
    final header = <String, Object?>{
      '\$schema': 'harness.agent.v1',
      'sid': scenarioId,
      'scenario': scenarioName,
      'verdict': verdict,
      'n': [
        summary['pass'],
        summary['fail'],
        summary['skip'],
        summary['not_run'],
        summary['steps_not_run'],
      ],
      if (stepsNotRun.isNotEmpty) 'stepsNotRun': stepsNotRun,
      if (evidenceDir != null) 'evidenceDir': evidenceDir,
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
      if (check.status != CheckStatus.fail) continue;
      final id = check.id ?? checkStableId(scenarioId, i, check.name);
      buffer
        ..writeln(
          '  <testcase classname="${_xmlEscape(scenarioId)}" '
          'name="${_xmlEscape(check.name)}" id="${_xmlEscape(id)}">',
        )
        ..writeln(
          '    <failure message="${_xmlEscape(check.detail)}">'
          '${_xmlEscape(_failureBody(check))}</failure>',
        )
        ..writeln('  </testcase>');
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
    final line = <String, Object?>{
      'id': full['id'],
      'obs': full['observed'],
    };
    final expected = full['expected'];
    final name = full['id']?.toString() ?? '';
    if (expected != null && expected != name.split(':').last) {
      line['exp'] = expected;
    }
    if (full['step'] != null) line['step'] = full['step'];
    if (full['detail'] != null && '$full[detail]'.isNotEmpty) {
      line['det'] = full['detail'];
    }
    if (full['semanticDelta'] != null) line['delta'] = full['semanticDelta'];
    if (full['evidence'] != null) line['ev'] = full['evidence'];
    return line;
  }

  List<Map<String, Object?>> _failureMaps() {
    final out = <Map<String, Object?>>[];
    for (var i = 0; i < report.checks.length; i++) {
      final check = report.checks[i];
      if (check.status != CheckStatus.fail) continue;
      final id = check.id ?? checkStableId(scenarioId, i, check.name);
      out.add(<String, Object?>{
        'id': id,
        if (check.step != null) 'step': check.step,
        'expected': check.expected ?? check.name,
        'observed': _observedJson(check),
        if (check.detail.isNotEmpty) 'detail': check.detail,
        if (check.semanticDelta != null) 'semanticDelta': check.semanticDelta,
        if (check.evidencePaths.isNotEmpty) 'evidence': check.evidencePaths,
      });
    }
    return out;
  }

  Object? _observedJson(Check check) {
    if (check.observed != null) return check.observed;
    if (check.detail.isNotEmpty) return check.detail;
    return false;
  }

  String _failureBody(Check check) {
    final parts = <String>[
      if (check.expected != null) 'expected: ${check.expected}',
      'observed: ${_observedJson(check)}',
      if (check.semanticDelta != null) 'delta: ${check.semanticDelta}',
      if (check.evidencePaths.isNotEmpty) 'evidence: ${check.evidencePaths.join(', ')}',
    ];
    return parts.join('\n');
  }

  static String _xmlEscape(String raw) => raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Diff of failure ids vs a previous full JSON report.
final class ReportDiff {
  ReportDiff({
    required this.newFailures,
    required this.resolved,
    required this.unchanged,
  });

  final List<String> newFailures;
  final List<String> resolved;
  final List<String> unchanged;

  Map<String, Object?> toJson() => <String, Object?>{
        'newFailures': newFailures,
        'resolved': resolved,
        'unchangedFailures': unchanged,
      };

  static ReportDiff? compute(
    Map<String, Object?> current,
    Map<String, Object?>? previous,
  ) {
    if (previous == null) return null;
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

  static Future<Map<String, Object?>?> loadPrevious(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
    return null;
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
  final previous = await ReportDiff.loadPrevious(opts.diffAgainst);
  final writer = ScenarioReportWriter(
    scenarioName: scenarioName,
    scenarioId: scenarioId,
    report: report,
    stepsNotRun: stepsNotRun,
    evidenceDir: evidenceDir,
  );
  final diff = previous == null
      ? null
      : ReportDiff.compute(writer.buildFullJson(), previous);
  await writer.write(format: opts.format!, path: opts.reportOut!, diff: diff);
}