// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:io';

import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

void main() {
  test('--version prints kFlutterMcpVersion and exits 0', () async {
    final packageRoot = Directory.current.path.endsWith('mcp_server_dart')
        ? Directory.current
        : Directory.fromUri(Directory.current.uri.resolve('mcp_server_dart'));
    final result = await Process.run('dart', [
      'run',
      'bin/flutter_mcp_toolkit_server.dart',
      '--version',
    ], workingDirectory: packageRoot.path);

    expect(result.exitCode, 0);
    expect((result.stdout as String).trim(), kFlutterMcpVersion);
  });
}
