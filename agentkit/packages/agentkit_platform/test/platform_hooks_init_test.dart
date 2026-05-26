import 'dart:io';

import 'package:agentkit_platform/agentkit_platform.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('platform_hooks_init_');
    Directory(p.join(tmp.path, 'web')).createSync();
    Directory(p.join(tmp.path, 'android', 'app', 'src', 'main')).createSync(recursive: true);
    Directory(p.join(tmp.path, 'ios', 'Runner.xcodeproj')).createSync(recursive: true);
    Directory(p.join(tmp.path, 'macos', 'Runner.xcodeproj')).createSync(recursive: true);
    File(p.join(tmp.path, 'web', 'index.html')).writeAsStringSync('<html></html>\n');
    File(p.join(tmp.path, 'android', 'app', 'build.gradle.kts')).writeAsStringSync('plugins {}\n');
    File(p.join(tmp.path, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'))
        .writeAsStringSync('<manifest><application></application></manifest>\n');
    File(p.join(tmp.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj')).writeAsStringSync(
      '# agentkit-platform: begin\nflutter-mcp-toolkit codegen sync\n',
    );
    File(p.join(tmp.path, 'macos', 'Runner.xcodeproj', 'project.pbxproj')).writeAsStringSync(
      '# agentkit-platform: begin\nflutter-mcp-toolkit codegen sync\n',
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('apply then check passes for core hooks', () async {
    const init = PlatformHooksInit();
    final applied = await init.run(projectRoot: tmp.path);
    expect(applied.targets.firstWhere((final t) => t.id == 'web_index_html').ok, isTrue);

    final checked = await init.run(projectRoot: tmp.path, checkOnly: true);
    expect(checked.ok, isTrue);
  });
}
