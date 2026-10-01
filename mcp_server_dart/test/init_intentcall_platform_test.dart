import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/init_intentcall_platform_command.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/intentcall_delegate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Hook-spine file-writing truth lives in the intentcall_cli suite — the
/// toolkit no longer compiles against it (ADR-0016). These tests verify the
/// delegation contract: spawned argv and exit-code forwarding.
void main() {
  late Directory tmp;
  late _FakeIntentcallCli fake;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('init_intentcall_platform_');
    Directory(p.join(tmp.path, 'web')).createSync();
    File(
      p.join(tmp.path, 'web', 'index.html'),
    ).writeAsStringSync('<html></html>\n');
    fake = _FakeIntentcallCli();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('init intentcall-platform delegates hooks init with the flutter host',
      () async {
    final exitCode = await runInitintentcallPlatform(
      projectRoot: tmp.path,
      cli: fake.checkout,
    );
    expect(exitCode, 0);
    final argv = fake.lastArgv!;
    expect(argv, containsAllInOrder(['platform', 'hooks', 'init']));
    expect(argv, containsAllInOrder(['--project-dir', tmp.path]));
    expect(argv, containsAllInOrder(['--host', 'flutter']));
  });

  test('--check is forwarded to the delegate', () async {
    final exitCode = await runInitintentcallPlatform(
      projectRoot: tmp.path,
      checkOnly: true,
      cli: fake.checkout,
    );
    expect(exitCode, 5); // fake exits 5 on --check
    expect(fake.lastArgv, contains('--check'));
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
