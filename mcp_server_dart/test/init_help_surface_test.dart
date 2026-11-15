import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('init --help lists zcode target', () async {
    final result = await Process.run(
      'dart',
      ['run', 'bin/flutter_mcp_toolkit.dart', 'init', '--help'],
      workingDirectory: Directory.current.path,
      environment: {'HOME': '/tmp', 'DART_SUPPRESS_ANALYTICS': 'true'},
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final out = '${result.stdout}';
    expect(out, contains('zcode'));
  });

  test('init without args mentions zcode in usage', () async {
    final result = await Process.run(
      'dart',
      ['run', 'bin/flutter_mcp_toolkit.dart', 'init'],
      workingDirectory: Directory.current.path,
      environment: {'HOME': '/tmp', 'DART_SUPPRESS_ANALYTICS': 'true'},
    );
    expect(result.exitCode, 64);
    final err = '${result.stderr}';
    expect(err, contains('zcode'));
  });
}
