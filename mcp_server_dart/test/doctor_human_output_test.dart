import 'package:flutter_mcp_toolkit_server/src/cli/diagnostics/doctor_human_output.dart';
import 'package:test/test.dart';

void main() {
  group('doctor human output', () {
    tearDown(() {
      doctorStdoutIsTerminalOverride = null;
    });

    test('resolveDoctorStdoutFormat honors json, TTY, and non-TTY', () {
      doctorStdoutIsTerminalOverride = true;
      expect(
        resolveDoctorStdoutFormat(jsonFlag: true),
        DoctorStdoutFormat.jsonEnvelope,
      );
      expect(
        resolveDoctorStdoutFormat(jsonFlag: false),
        DoctorStdoutFormat.human,
      );

      doctorStdoutIsTerminalOverride = false;
      expect(
        resolveDoctorStdoutFormat(jsonFlag: false),
        DoctorStdoutFormat.jsonEnvelope,
      );
    });

    test('formatDoctorHuman renders checks and summary without ANSI', () {
      doctorStdoutIsTerminalOverride = false;
      final text = formatDoctorHuman({
        'target': 'ws://127.0.0.1:8181/token/ws',
        'checks': [
          {
            'id': 'dart_sdk',
            'status': 'pass',
            'critical': false,
            'diagnostic': 'Dart SDK version: 3.10.0',
          },
          {
            'id': 'vm_target_reachable',
            'status': 'fail',
            'critical': true,
            'diagnostic': 'Connection refused',
          },
        ],
        'summary': {
          'pass': 1,
          'warn': 0,
          'fail': 1,
          'criticalFailures': 1,
        },
      });

      expect(text, contains('target: ws://127.0.0.1:8181/token/ws'));
      expect(text, contains('pass  dart_sdk'));
      expect(text, contains('fail  vm_target_reachable (critical)'));
      expect(text, contains('fail — 1 pass, 0 warn, 1 fail (1 critical)'));
      expect(text, isNot(contains('\x1B[')));
    });
  });
}