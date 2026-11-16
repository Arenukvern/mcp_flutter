// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:io' as io;

import 'package:meta/meta.dart';

/// When non-null, overrides [io.stdout.hasTerminal] for doctor output mode.
@visibleForTesting
bool? doctorStdoutIsTerminalOverride;

enum DoctorStdoutFormat { jsonEnvelope, human }

const _detailIndent = '      ';
const _wrapWidth = 76;

bool _envTruthy(String name) {
  final raw = io.Platform.environment[name];
  if (raw == null || raw.isEmpty) {
    return false;
  }
  final normalized = raw.trim().toLowerCase();
  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'on';
}

bool doctorStdoutHasTerminal() {
  if (doctorStdoutIsTerminalOverride != null) {
    return doctorStdoutIsTerminalOverride!;
  }
  final forced =
      io.Platform.environment['FLUTTER_MCP_TOOLKIT_DOCTOR_STDOUT_IS_TTY'];
  if (forced != null && forced.trim().isNotEmpty) {
    return _envTruthy('FLUTTER_MCP_TOOLKIT_DOCTOR_STDOUT_IS_TTY');
  }
  return io.stdout.hasTerminal;
}

bool doctorUseAnsiColor() {
  if (!doctorStdoutHasTerminal()) {
    return false;
  }
  if (_envTruthy('NO_COLOR')) {
    return false;
  }
  final clicolor = io.Platform.environment['CLICOLOR']?.trim();
  if (clicolor == '0') {
    return false;
  }
  if (io.Platform.environment.containsKey('CLICOLOR_FORCE')) {
    return _envTruthy('CLICOLOR_FORCE');
  }
  return io.stdout.supportsAnsiEscapes;
}

DoctorStdoutFormat resolveDoctorStdoutFormat({required bool jsonFlag}) {
  if (jsonFlag) {
    return DoctorStdoutFormat.jsonEnvelope;
  }
  if (doctorStdoutHasTerminal()) {
    return DoctorStdoutFormat.human;
  }
  return DoctorStdoutFormat.jsonEnvelope;
}

String formatDoctorHuman(Map<String, Object?> doctorData) {
  final checks = doctorData['checks'];
  if (checks is! List) {
    return 'doctor: missing checks in result';
  }

  final summary = _asMap(doctorData['summary']);
  final pass = _asInt(summary?['pass']);
  final warn = _asInt(summary?['warn']);
  final fail = _asInt(summary?['fail']);
  final critical = _asInt(summary?['criticalFailures']);
  final target = doctorData['target'];

  final useColor = doctorUseAnsiColor();
  final buffer = StringBuffer();

  if (target is String && target.isNotEmpty) {
    buffer.writeln('target: $target');
  }

  for (final entry in checks) {
    if (entry is! Map) {
      continue;
    }
    final id = '${entry['id'] ?? 'unknown'}';
    final status = '${entry['status'] ?? 'unknown'}';
    final criticalCheck = entry['critical'] == true;
    final rawDiagnostic = '${entry['diagnostic'] ?? ''}';

    final statusLabel = _statusLabel(status, useColor: useColor);
    final idLabel = criticalCheck ? '$id (critical)' : id;
    if (status == 'pass') {
      final diagnostic = _shortPassDetail(rawDiagnostic);
      buffer.writeln('$statusLabel  $idLabel  $diagnostic');
      continue;
    }

    buffer.writeln('$statusLabel  $idLabel');
    for (final line in _wrapDiagnostic(rawDiagnostic)) {
      buffer.writeln('$_detailIndent$line');
    }
  }

  final overall = _overallHeadline(critical: critical, fail: fail, warn: warn);
  final overallLabel = _overallLabel(overall, useColor: useColor);
  buffer.write(
    '$overallLabel — $pass pass, $warn warn, $fail fail ($critical critical)\n',
  );
  return buffer.toString();
}

String _shortPassDetail(String diagnostic) {
  final collapsed = diagnostic.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= 88) {
    return collapsed;
  }
  return '${collapsed.substring(0, 85)}...';
}

List<String> _wrapDiagnostic(String diagnostic) {
  final collapsed = diagnostic.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) {
    return const ['(no detail)'];
  }
  final words = collapsed.split(' ');
  final lines = <String>[];
  var current = StringBuffer();
  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (candidate.length > _wrapWidth && current.isNotEmpty) {
      lines.add(current.toString());
      current = StringBuffer(word);
    } else {
      current.clear();
      current.write(candidate);
    }
  }
  if (current.isNotEmpty) {
    lines.add(current.toString());
  }
  return lines;
}

String _overallHeadline({
  required int critical,
  required int fail,
  required int warn,
}) {
  if (critical > 0) {
    return 'fail';
  }
  if (fail > 0) {
    final noun = fail == 1 ? 'failure' : 'failures';
    return 'degraded ($fail non-critical $noun)';
  }
  if (warn > 0) {
    final noun = warn == 1 ? 'warning' : 'warnings';
    return 'ok ($warn $noun)';
  }
  return 'ok';
}

String _statusLabel(String status, {required bool useColor}) {
  final padded = status.padRight(4);
  if (!useColor) {
    return padded;
  }
  return switch (status) {
    'pass' => '\x1B[32m$padded\x1B[0m',
    'warn' => '\x1B[33m$padded\x1B[0m',
    'fail' => '\x1B[31m$padded\x1B[0m',
    _ => padded,
  };
}

String _overallLabel(String overall, {required bool useColor}) {
  if (!useColor) {
    return overall;
  }
  if (overall == 'fail' || overall.startsWith('degraded')) {
    return '\x1B[31m$overall\x1B[0m';
  }
  if (overall.startsWith('ok (')) {
    return '\x1B[33m$overall\x1B[0m';
  }
  if (overall == 'ok') {
    return '\x1B[32m$overall\x1B[0m';
  }
  return overall;
}

Map<String, Object?>? _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return null;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}
