import 'package:flutter_mcp_toolkit_server/src/cli/cli_port_options.dart';
import 'package:test/test.dart';

void main() {
  group('cliPositivePort', () {
    test('empty uses fallback', () {
      expect(cliPositivePort(null, fallback: 8181, flag: 'dart-vm-port'), 8181);
      expect(cliPositivePort('', fallback: 8181, flag: 'dart-vm-port'), 8181);
    });

    test('parses strict decimal', () {
      expect(cliPositivePort('8181', fallback: 1, flag: 'dart-vm-port'), 8181);
    });

    test('rejects hex and junk', () {
      expect(
        () => cliPositivePort('0x8181', fallback: 1, flag: 'dart-vm-port'),
        throwsFormatException,
      );
      expect(
        () => cliPositivePort('81a', fallback: 1, flag: 'dart-vm-port'),
        throwsFormatException,
      );
    });
  });

  group('cliOptionalPort', () {
    test('empty is null', () {
      expect(cliOptionalPort(null, flag: 'web-port'), isNull);
    });

    test('parses port', () {
      expect(cliOptionalPort('9222', flag: 'cdp-port'), 9222);
    });
  });
}