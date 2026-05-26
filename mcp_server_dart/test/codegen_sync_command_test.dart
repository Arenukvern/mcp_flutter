import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/codegen_sync_command.dart';
import 'package:test/test.dart';

void main() {
  test('runCodegenSync writes web artifacts', () async {
    final temp = Directory.systemTemp.createTempSync('codegen_sync_cli_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final webDir = Directory('${temp.path}/web')..createSync();
    File('${temp.path}/agent_manifest.json').writeAsStringSync('''
{
  "version": 1,
  "platform": "web",
  "tools": [
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
''');
    File('${webDir.path}/manifest.json').writeAsStringSync('''
{
  "name": "demo",
  "start_url": "."
}
''');

    final exitCode = await runCodegenSync(
      platform: 'web',
      projectRoot: temp.path,
    );
    expect(exitCode, 0);
    expect(File('${webDir.path}/agentkit_webmcp.generated.js').existsSync(), isTrue);

    final checkExit = await runCodegenSync(
      platform: 'web',
      projectRoot: temp.path,
      checkOnly: true,
    );
    expect(checkExit, 0);
  });

  test('runCodegenSync writes android shortcuts xml', () async {
    final temp = Directory.systemTemp.createTempSync('codegen_sync_android_');
    addTearDown(() => temp.deleteSync(recursive: true));

    File('${temp.path}/agent_manifest.json').writeAsStringSync('''
{
  "version": 1,
  "platform": "android",
  "shortcuts": [
    {
      "qualifiedName": "app_ping",
      "namespace": "app",
      "name": "ping",
      "description": "Ping",
      "kind": "tool",
      "inputSchema": {"type": "object"}
    }
  ]
}
''');
    Directory(
      '${temp.path}/android/app/src/main/res/xml',
    ).createSync(recursive: true);

    final exitCode = await runCodegenSync(
      platform: 'android',
      projectRoot: temp.path,
    );
    expect(exitCode, 0);
    expect(
      File(
        '${temp.path}/android/app/src/main/res/xml/agentkit_shortcuts.xml',
      ).existsSync(),
      isTrue,
    );
  });
}
