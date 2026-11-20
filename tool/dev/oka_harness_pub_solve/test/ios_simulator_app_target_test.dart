import 'dart:async';
import 'dart:io';

import 'package:oka_harness/oka_harness.dart';
import 'package:test/test.dart';

/// A fake `flutter` CLI: prints its args, announces a VM service (the same
/// line shape the real tool emits), and stays alive like the real owning
/// `flutter run` session.
const String _fakeFlutterScript = r'''
#!/bin/sh
echo "fake-flutter args: $*"
echo "The Dart VM Service is running on the host at http://127.0.0.1:45681/AbC123=/"
sleep 300
''';

Future<Directory> _withFakeFlutter() async {
  final dir = await Directory.systemTemp.createTemp('oka_harness_ios_test');
  final scriptFile = File('${dir.path}/fake_flutter')
    ..writeAsStringSync(_fakeFlutterScript);
  await Process.run('chmod', ['+x', scriptFile.path]);
  return dir;
}

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await _withFakeFlutter();
  });

  tearDown(() async {
    await workspace.delete(recursive: true);
  });

  test('launch publishes the runner-session contract and returns the VM URI',
      () async {
    final target = IosSimulatorAppTarget(
      projectDir: workspace.path,
      udid: 'AAAAAAAA-1111-2222-3333-444444444444',
      dartDefines: const {'INSPECTOR_EVIDENCE': 'fixture'},
      flutterBin: '${workspace.path}/fake_flutter',
      vmServiceTimeout: const Duration(seconds: 10),
    );
    final app = await target.launch();

    addTearDown(app.stop);
    expect(app.vmUri.host, '127.0.0.1');
    expect(app.vmUri.port, 45681);
    // Args threaded to the owning session.
    expect(
      app.stdout.firstMatch('-d AAAAAAAA-1111-2222-3333-444444444444'),
      isNotNull,
    );
    expect(
      app.stdout.firstMatch('--dart-define INSPECTOR_EVIDENCE=fixture'),
      isNotNull,
    );
    // The contract file is published (spec-v2 shape, written by the same
    // store `oka dev` uses).
    final sessionFile =
        File('${workspace.path}/.flutter_mcp/runner-session.json');
    expect(sessionFile.existsSync(), isTrue);
    expect(sessionFile.readAsStringSync(), contains('"vm_service_uri"'));
    expect(sessionFile.readAsStringSync(), contains('AAAAAAAA-1111'));
  });

  test('stop clears the contract file (absence is the liveness signal)',
      () async {
    final target = IosSimulatorAppTarget(
      projectDir: workspace.path,
      udid: 'AAAAAAAA-1111-2222-3333-444444444444',
      flutterBin: '${workspace.path}/fake_flutter',
      vmServiceTimeout: const Duration(seconds: 10),
    );
    final app = await target.launch();
    final sessionFile =
        File('${workspace.path}/.flutter_mcp/runner-session.json');
    expect(sessionFile.existsSync(), isTrue);
    await app.stop();
    expect(sessionFile.existsSync(), isFalse);
  });

  test('launch(build: false) refuses — never a second owner', () async {
    final target = IosSimulatorAppTarget(
      projectDir: workspace.path,
      udid: 'AAAAAAAA-1111-2222-3333-444444444444',
      flutterBin: '${workspace.path}/fake_flutter',
    );
    await expectLater(
      target.launch(build: false),
      throwsArgumentError,
    );
  });
}
