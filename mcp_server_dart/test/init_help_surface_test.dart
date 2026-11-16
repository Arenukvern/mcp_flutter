import 'dart:io';

import 'package:test/test.dart';

Map<String, String> _helpTestEnvironment() {
  final home = Platform.environment['HOME'];
  final pubCache =
      Platform.environment['PUB_CACHE'] ??
      (home == null ? null : '$home/.pub-cache');
  return <String, String>{
    'HOME': '/tmp',
    'DART_SUPPRESS_ANALYTICS': 'true',
    if (pubCache != null) 'PUB_CACHE': pubCache,
  };
}

void main() {
  test('init --help lists zcode target', () async {
    final result = await Process.run(
      'dart',
      ['run', 'bin/flutter_mcp_toolkit.dart', 'init', '--help'],
      workingDirectory: Directory.current.path,
      environment: _helpTestEnvironment(),
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
      environment: _helpTestEnvironment(),
    );
    expect(result.exitCode, 64);
    final err = '${result.stderr}';
    expect(err, contains('zcode'));
  });
}
