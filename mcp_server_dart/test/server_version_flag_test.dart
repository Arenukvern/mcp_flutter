// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:io';

import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

void main() {
  test('--version prints kFlutterMcpVersion and exits 0', () async {
    final result = await Process.run('dart', [
      'run',
      'bin/flutter_mcp_toolkit_server.dart',
      '--version',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0);
    expect((result.stdout as String).trim(), kFlutterMcpVersion);
  });
}
