@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Documents pub.dev [universal_capture_flutter] 0.2.0 vs Dart 3.13.4 compiler.
/// Run: `dart test test/support/universal_capture_compile_repro_test.dart`
/// Expectation: kernel compile of hosted source fails on `final` parameters.
Future<void> ensureHostedUcf020InPubCache() async {
  final add = await Process.run(
    'dart',
    ['pub', 'cache', 'add', 'universal_capture_flutter', '--version', '0.2.0'],
  );
  expect(add.exitCode, 0, reason: '${add.stderr}');
}

void main() {
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final grabPath =
      '$pubCache/hosted/pub.dev/universal_capture_flutter-0.2.0/lib/src/vm_screenshot_grab.dart';

  setUpAll(ensureHostedUcf020InPubCache);

  test(
    'hosted universal_capture_flutter 0.2.0 kernel compile diagnostic',
    () async {
      expect(File(grabPath).existsSync(), isTrue, reason: grabPath);
      final dir = Directory.systemTemp.createTempSync('ucf_compile_');
      final mainDart = File('${dir.path}/main.dart')
        ..writeAsStringSync(
          "import 'package:universal_capture_flutter/universal_capture_flutter.dart';\nvoid main() {}\n",
        );
      addTearDown(() => dir.deleteSync(recursive: true));

      final pubspec = File('${dir.path}/pubspec.yaml')
        ..writeAsStringSync('''
name: ucf_repro
environment:
  sdk: ">=3.13.0 <4.0.0"
dependencies:
  universal_capture_flutter: 0.2.0
''');
      expect(pubspec.existsSync(), isTrue);
      final get = await Process.run('dart', ['pub', 'get'], workingDirectory: dir.path);
      expect(get.exitCode, 0, reason: '${get.stderr}');

      final compile = await Process.run(
        'dart',
        ['compile', 'kernel', mainDart.path],
        workingDirectory: dir.path,
      );
      expect(
        compile.exitCode,
        isNot(0),
        reason: 'expected compile failure; stdout=${compile.stdout}',
      );
      final diag = '${compile.stderr}${compile.stdout}';
      expect(diag, contains("Can't have modifier 'final' here"));
      expect(diag, contains('vm_screenshot_grab.dart'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('hosted grab source still contains final formal parameters', () {
    final source = File(grabPath).readAsStringSync();
    expect(source, contains('connect(final Uri vmServiceUri)'));
    expect(source, contains('normalizeWsUri(final Uri uri)'));
  });
}
