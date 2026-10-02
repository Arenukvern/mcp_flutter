import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/codegen_sync_command.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/intentcall_delegate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Emitter/file-writing truth (web artifacts, shortcuts XML) lives in the
/// intentcall_cli suite — the toolkit no longer compiles against it
/// (ADR-0016). These tests verify the delegation contract instead: argument
/// validation, spawned argv, and exit-code forwarding.
void main() {
  test('runCodegenSync rejects an empty platform list', () async {
    final exitCode = await runCodegenSync(platform: '', projectRoot: '.');
    expect(exitCode, 64);
  });

  test('runCodegenSync rejects unknown platforms', () async {
    final exitCode = await runCodegenSync(
      platform: 'web,beos',
      projectRoot: '.',
    );
    expect(exitCode, 64);
  });

  test('delegatePlatformSync spawns the CLI with the flutter-host argv',
      () async {
    final fake = _FakeIntentcallCli();
    final exitCode = await delegatePlatformSync(
      projectRoot: '/tmp/demo',
      platforms: const ['web', 'android'],
      cli: fake.checkout,
    );
    expect(exitCode, 0);
    final argv = fake.lastArgv!;
    expect(argv, contains('platform'));
    expect(argv, contains('sync'));
    expect(argv, containsAllInOrder(['--project-dir', '/tmp/demo']));
    expect(argv, containsAllInOrder(['--host', 'flutter']));
    expect(argv, containsAllInOrder(['--platform', 'web']));
    expect(argv, containsAllInOrder(['--platform', 'android']));
  });

  test('delegatePlatformSync absolutizes a relative project root', () async {
    final fake = _FakeIntentcallCli();
    final exitCode = await delegatePlatformSync(
      projectRoot: 'relative/demo',
      platforms: const ['web'],
      cli: fake.checkout,
    );
    expect(exitCode, 0);
    final projectDir = fake.lastArgv![fake.lastArgv!.indexOf('--project-dir') + 1];
    expect(p.isAbsolute(projectDir), isTrue);
    expect(projectDir, endsWith('relative/demo'));
  });

  test('delegatePlatformSync forwards the delegate exit code', () async {
    final fake = _FakeIntentcallCli();
    final exitCode = await delegatePlatformSync(
      projectRoot: '/tmp/demo',
      platforms: const ['web'],
      checkOnly: true,
      cli: fake.checkout,
    );
    expect(exitCode, 5); // fake exits 5 on --check
  });

  test('delegatePlatformHooksInit spawns hooks init with the flutter host',
      () async {
    final fake = _FakeIntentcallCli();
    final exitCode = await delegatePlatformHooksInit(
      projectRoot: '/tmp/demo',
      cli: fake.checkout,
    );
    expect(exitCode, 0);
    final argv = fake.lastArgv!;
    expect(argv, containsAllInOrder(['platform', 'hooks', 'init']));
    expect(argv, containsAllInOrder(['--host', 'flutter']));
  });
}

/// A minimal `intentcall_cli` checkout whose `dart run bin/intentcall.dart`
/// records argv to `.argv.json` and exits 5 on `--check`, 0 otherwise.
final class _FakeIntentcallCli {
  _FakeIntentcallCli() {
    final temp = Directory.systemTemp.createTempSync('fake_intentcall_cli_');
    dir = '${temp.path}/packages/intentcall_cli';
    Directory(dir).createSync(recursive: true);
    File('$dir/pubspec.yaml').writeAsStringSync(
      'name: intentcall_cli\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n',
    );
    Directory('$dir/bin').createSync();
    File('$dir/bin/intentcall.dart').writeAsStringSync('''
import 'dart:convert';
import 'dart:io';

Future<void> main(final List<String> args) async {
  await File('.argv.json').writeAsString(jsonEncode(args));
  exit(args.contains('--check') ? 5 : 0);
}
''');
  }

  late final String dir;

  IntentcallCli get checkout => IntentcallCli.checkout(dir);

  List<String>? get lastArgv {
    final file = File('$dir/.argv.json');
    if (!file.existsSync()) return null;
    return (jsonDecode(file.readAsStringSync()) as List).cast<String>();
  }
}
