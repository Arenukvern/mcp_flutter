import 'dart:convert';

import 'package:flutter_mcp_toolkit_server/src/cli/webmcp_command.dart';
import 'package:test/test.dart';

void main() {
  test('webmcpChromeArgsJson includes browser flags and flutter run', () {
    final json = webmcpChromeArgsJson(webPort: 8080, vmHostPort: 8181);
    expect(json['ok'], isTrue);
    expect(json['browserFlags'], kWebmcpChromeBrowserFlags);
    final run = json['flutterRun'] as String;
    expect(run, contains('--web-browser-flag'));
    expect(run, contains('WebModelContext'));
  });

  test('runWebmcpChromeArgs prints JSON', () async {
    final exit = await runWebmcpChromeArgs();
    expect(exit, 0);
  });
}
