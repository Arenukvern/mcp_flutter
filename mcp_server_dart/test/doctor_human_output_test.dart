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

    test('formatDoctorHuman uses inline detail for pass and wrapped detail for warn/fail', () {
      doctorStdoutIsTerminalOverride = false;
      final longWarn =
          'Visual capture backend could not be resolved because the app did not '
          'advertise any supported capture modes during the preflight probe.';
      final text = formatDoctorHuman({
        'checks': [
          {
            'id': 'dart_sdk',
            'status': 'pass',
            'critical': false,
            'diagnostic': 'Dart SDK version: 3.10.0',
          },
          {
            'id': 'visual_capture_backend',
            'status': 'warn',
            'critical': false,
            'diagnostic': longWarn,
          },
        ],
        'summary': {'pass': 1, 'warn': 1, 'fail': 0, 'criticalFailures': 0},
      });

      expect(text, contains('pass  dart_sdk  Dart SDK version: 3.10.0'));
      expect(text, contains('warn  visual_capture_backend'));
      expect(text, contains('Visual capture backend could not be resolved'));
      expect(text, contains('preflight probe.'));
      expect(text, contains('ok (1 warning)'));
    });

    test('overall headline ok', () {
      final text = formatDoctorHuman({
        'checks': [
          {
            'id': 'dart_sdk',
            'status': 'pass',
            'critical': false,
            'diagnostic': 'ok',
          },
        ],
        'summary': {'pass': 1, 'warn': 0, 'fail': 0, 'criticalFailures': 0},
      });
      expect(text.trim(), endsWith('ok — 1 pass, 0 warn, 0 fail (0 critical)'));
    });

    test('overall headline ok (n warnings)', () {
      final text = formatDoctorHuman({
        'checks': [],
        'summary': {'pass': 6, 'warn': 4, 'fail': 0, 'criticalFailures': 0},
      });
      expect(
        text.trim(),
        endsWith('ok (4 warnings) — 6 pass, 4 warn, 0 fail (0 critical)'),
      );
    });

    test('overall headline degraded (n non-critical failures)', () {
      final text = formatDoctorHuman({
        'checks': [],
        'summary': {'pass': 5, 'warn': 1, 'fail': 2, 'criticalFailures': 0},
      });
      expect(
        text.trim(),
        endsWith(
          'degraded (2 non-critical failures) — 5 pass, 1 warn, 2 fail (0 critical)',
        ),
      );
    });

    test('overall headline degraded (singular failure)', () {
      final text = formatDoctorHuman({
        'checks': [],
        'summary': {'pass': 1, 'warn': 0, 'fail': 1, 'criticalFailures': 0},
      });
      expect(
        text.trim(),
        endsWith(
          'degraded (1 non-critical failure) — 1 pass, 0 warn, 1 fail (0 critical)',
        ),
      );
    });

    test('overall headline fail on critical failures', () {
      final text = formatDoctorHuman({
        'checks': [
          {
            'id': 'vm_target_reachable',
            'status': 'fail',
            'critical': true,
            'diagnostic': 'Connection refused',
          },
        ],
        'summary': {'pass': 1, 'warn': 0, 'fail': 1, 'criticalFailures': 1},
      });
      expect(
        text.trim(),
        endsWith('fail — 1 pass, 0 warn, 1 fail (1 critical)'),
      );
      expect(text, isNot(contains('\x1B[')));
    });
  });
}
