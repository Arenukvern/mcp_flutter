// mcp_server_dart/test/cli/init_mode_detector_test.dart
import 'package:flutter_mcp_toolkit_server/src/cli/init_mode.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_mode_detector.dart';
import 'package:test/test.dart';

void main() {
  group('detectMode', () {
    test('returns mcp if MCP server registration is found', () {
      final mode = detectMode(binaryOnPath: true, mcpServerRegistered: true);
      expect(mode, InitMode.mcp);
    });

    test('returns cli if binary on PATH but no MCP registration', () {
      final mode = detectMode(binaryOnPath: true, mcpServerRegistered: false);
      expect(mode, InitMode.cli);
    });

    test('throws if neither — fail loud', () {
      expect(
        () => detectMode(binaryOnPath: false, mcpServerRegistered: false),
        throwsStateError,
      );
    });
  });
}
