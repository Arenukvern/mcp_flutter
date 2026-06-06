import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/init_intentcall_platform_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('init_intentcall_platform_');
    Directory(p.join(tmp.path, 'web')).createSync();
    Directory(
      p.join(tmp.path, 'android', 'app', 'src', 'main'),
    ).createSync(recursive: true);
    Directory(
      p.join(tmp.path, 'ios', 'Runner.xcodeproj'),
    ).createSync(recursive: true);
    Directory(
      p.join(tmp.path, 'macos', 'Runner.xcodeproj'),
    ).createSync(recursive: true);
    File(
      p.join(tmp.path, 'web', 'index.html'),
    ).writeAsStringSync('<html></html>\n');
    File(
      p.join(tmp.path, 'android', 'app', 'build.gradle.kts'),
    ).writeAsStringSync('plugins {}\n');
    File(
      p.join(tmp.path, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    ).writeAsStringSync('<manifest><application></application></manifest>\n');
    File(
      p.join(tmp.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    ).writeAsStringSync(
      '# intentcall-platform: begin\nflutter-mcp-toolkit codegen sync\n',
    );
    File(
      p.join(tmp.path, 'macos', 'Runner.xcodeproj', 'project.pbxproj'),
    ).writeAsStringSync(
      '# intentcall-platform: begin\nflutter-mcp-toolkit codegen sync\n',
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('init intentcall-platform applies hooks', () async {
    expect(await runInitintentcallPlatform(projectRoot: tmp.path), 0);
    final html = File(p.join(tmp.path, 'web', 'index.html')).readAsStringSync();
    expect(html, contains('intentcall-platform: begin'));
  });

  test('--check fails before apply', () async {
    expect(
      await runInitintentcallPlatform(projectRoot: tmp.path, checkOnly: true),
      isNot(0),
    );
  });
}
