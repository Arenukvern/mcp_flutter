// End-to-end wiring test for the capability kernel flag-on path.
//
// Verifies that:
//   - McpHost + FmtCapability registration produces the expected prefixed
//     tool surface tracked by tool/contracts/expected_tool_surface.txt
//     (plus 4 dump tools when dumps_supported=true).
//   - CapabilityConfig values flow from McpHost construction through the
//     CapabilityContext to FmtCapability's conditional registration logic.
//   - The DartMcpDispatchBridge publishes prefixed names to the dart_mcp
//     side and the legacy unprefixed surface is gated off (T8 cut).

import 'dart:io';

import 'package:dart_mcp/server.dart' as dart_mcp;
import 'package:flutter_mcp_toolkit_capability_core/flutter_mcp_toolkit_capability_core.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/testing.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/host.dart';
import 'package:test/test.dart';

/// Helper: build a [McpHost] with a [FakeCommandRunner] and the given config.
McpHost _makeHost({final bool dumpsSupported = false}) => McpHost(
  services: <Type, HostService>{CommandRunner: FakeCommandRunner()},
  config: CapabilityConfig(
    values: <String, Object?>{'dumps_supported': dumpsSupported},
  ),
);

// Non-dump fmt_* tools locked by tool/contracts/expected_tool_surface.txt.
// Keep capability_kernel_e2e and tool_surface_snapshot_test in lockstep by
// updating that file only — do not duplicate tool names here.
Set<String> _expectedNonDumpToolNames() {
  final expectedFile = File(_resolveExpectedToolSurfaceFile());
  expect(
    expectedFile.existsSync(),
    isTrue,
    reason:
        'expected_tool_surface.txt not found at ${expectedFile.path}',
  );
  return expectedFile
      .readAsLinesSync()
      .map((final line) => line.trim())
      .where((final line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
}

String _resolveExpectedToolSurfaceFile() =>
    '${Directory.current.parent.path}/tool/contracts/expected_tool_surface.txt';

// The 4 dump tool names that appear only when dumps_supported=true.
const _dumpToolNames = <String>[
  'fmt_debug_dump_layer_tree',
  'fmt_debug_dump_semantics_tree',
  'fmt_debug_dump_render_tree',
  'fmt_debug_dump_focus_tree',
];

void main() {
  group('capability kernel e2e — FmtCapability wiring', () {
    test(
      'dumps_supported=false: tool surface matches expected_tool_surface.txt',
      () async {
        final expected = _expectedNonDumpToolNames();
        final host = _makeHost();
        await host.registerCapability(const FmtCapability());

        final names = host.toolNames.toSet();

        expect(
          names,
          equals(expected),
          reason:
              'FmtCapability must register exactly the tools in '
              'expected_tool_surface.txt',
        );
        for (final dumpName in _dumpToolNames) {
          expect(
            names,
            isNot(contains(dumpName)),
            reason: '$dumpName must NOT appear when dumps_supported=false',
          );
        }
      },
    );

    test(
      'dumps_supported=true: expected surface plus all dump tools',
      () async {
        final expected = _expectedNonDumpToolNames();
        final host = _makeHost(dumpsSupported: true);
        await host.registerCapability(const FmtCapability());

        final names = host.toolNames.toSet();

        expect(names, containsAll(expected));
        expect(
          names,
          containsAll(_dumpToolNames),
          reason: 'All 4 dump tools must be present with dumps_supported=true',
        );
        expect(
          names.length,
          equals(expected.length + _dumpToolNames.length),
          reason:
              'Exactly ${expected.length + _dumpToolNames.length} tools when '
              'dumps_supported=true',
        );
      },
    );

    test('all prefixed tool names start with "fmt_"', () async {
      final host = _makeHost(dumpsSupported: true);
      await host.registerCapability(const FmtCapability());

      for (final name in host.toolNames) {
        expect(
          name,
          startsWith('fmt_'),
          reason: 'Every tool must carry the "fmt_" capability prefix',
        );
      }
    });

    test(
      'dispatch bridge publishes prefixed names; legacy unprefixed are absent',
      () async {
        // The cut codified: when capabilities register tools, they are exposed
        // to dart_mcp under the prefixed name. Legacy unprefixed names never
        // reach dart_mcp through the kernel — they would have to be registered
        // by the legacy mixin path, which T8 gates off.
        final published = <dart_mcp.Tool>[];
        final unpublished = <String>[];
        final host = McpHost(
          services: <Type, HostService>{CommandRunner: FakeCommandRunner()},
          config: const CapabilityConfig(
            values: <String, Object?>{'dumps_supported': false},
          ),
          dispatchBridge: DartMcpDispatchBridge(
            publish: (final tool, final _) => published.add(tool),
            unpublish: unpublished.add,
          ),
        );
        await host.registerCapability(const FmtCapability());

        final expected = _expectedNonDumpToolNames();
        final publishedNames = published.map((final t) => t.name).toSet();
        expect(publishedNames, equals(expected));
        // Sanity: the legacy unprefixed names are NOT what the kernel publishes.
        expect(publishedNames, isNot(contains('tap_widget')));
        expect(publishedNames, isNot(contains('enter_text')));
        // No double-publish, and unpublish hasn't fired.
        expect(unpublished, isEmpty);
      },
    );
  });
}
