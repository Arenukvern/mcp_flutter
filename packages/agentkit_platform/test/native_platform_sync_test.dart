import 'dart:io';

import 'package:agentkit_platform/agentkit_platform.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const manifestJson = '''
{
  "version": 1,
  "platform": "android",
  "shortcuts": [
    {
      "qualifiedName": "app_cart_total",
      "namespace": "app",
      "name": "cart_total",
      "description": "Return cart total",
      "kind": "tool",
      "inputSchema": {"type": "object"}
    }
  ]
}
''';

  test('PlatformSync syncs android, ios, linux, windows', () {
    final temp = Directory.systemTemp.createTempSync('agentkit_native_sync_');
    addTearDown(() => temp.deleteSync(recursive: true));

    File(p.join(temp.path, 'agent_manifest.json')).writeAsStringSync(manifestJson);
    Directory(p.join(temp.path, 'android', 'app', 'src', 'main', 'res', 'xml'))
        .createSync(recursive: true);
    Directory(p.join(temp.path, 'ios', 'Runner')).createSync(recursive: true);
    Directory(p.join(temp.path, 'macos', 'Runner')).createSync(recursive: true);
    Directory(p.join(temp.path, 'linux')).createSync();
    Directory(p.join(temp.path, 'windows')).createSync();

    const sync = PlatformSync();
    final result = sync.syncPlatforms(
      projectRoot: temp.path,
      platforms: ['android', 'ios', 'macos', 'linux', 'windows'],
    );

    expect(result.wroteAndroidShortcuts, isTrue);
    expect(result.wroteIosGenerated, isTrue);
    expect(result.wroteMacosGenerated, isTrue);
    expect(result.wroteLinuxDesktop, isTrue);
    expect(result.wroteWindowsProtocol, isTrue);

    expect(
      sync.checkPlatforms(
        temp.path,
        ['android', 'ios', 'macos', 'linux', 'windows'],
      ),
      isTrue,
    );
  });
}
