// Tool-surface snapshot contract: locks the published MCP tool names for the
// default v3.0.0 config (capability kernel on, no dumps, resources on).
//
// Tracks tool/contracts/expected_tool_surface.txt. When a capability is added,
// removed, or renamed, update both the snapshot file and verify the new
// surface against this test in lockstep. Failure means accidental drift.

import 'dart:io';

import 'package:dart_mcp/server.dart' as dart_mcp;
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/host.dart';
import 'package:mcp_capability_core/mcp_capability_core.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_capability_kernel/testing.dart';
import 'package:test/test.dart';

void main() {
  test('published tool surface matches expected_tool_surface.txt', () async {
    final published = <dart_mcp.Tool>[];
    final host = McpHost(
      services: <Type, HostService>{CommandRunner: FakeCommandRunner()},
      // Default v3.0.0 config: dumps off, resources on, images on.
      config: CapabilityConfig(
        values: const <String, Object?>{
          'dumps_supported': false,
          'resources_supported': true,
          'images_supported': true,
        },
      ),
      dispatchBridge: DartMcpDispatchBridge(
        publish: (final tool, final _) => published.add(tool),
        unpublish: (_) {},
      ),
    );
    await host.registerCapability(const FmtCapability());

    final actual = published.map((final t) => t.name).toSet();

    final expectedFile = File(_resolveExpectedFile());
    expect(
      expectedFile.existsSync(),
      isTrue,
      reason: 'expected_tool_surface.txt not found at ${expectedFile.path}',
    );
    final expected = expectedFile
        .readAsLinesSync()
        .map((final l) => l.trim())
        .where((final l) => l.isNotEmpty && !l.startsWith('#'))
        .toSet();

    final missing = expected.difference(actual);
    final extra = actual.difference(expected);
    expect(
      missing,
      isEmpty,
      reason:
          'Tools in expected_tool_surface.txt but missing from actual surface: '
          '$missing. If intentional, update the snapshot file.',
    );
    expect(
      extra,
      isEmpty,
      reason:
          'Tools published but not in expected_tool_surface.txt: $extra. '
          'If intentional, update the snapshot file.',
    );
  });
}

String _resolveExpectedFile() {
  // Tests run with cwd = mcp_server_dart/. Walk one up to repo root.
  return '${Directory.current.parent.path}/tool/contracts/expected_tool_surface.txt';
}
