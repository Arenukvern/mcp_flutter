// End-to-end wiring test for the capability kernel flag-on path.
//
// Verifies that:
//   - McpHost + FmtCapability registration produces the expected prefixed
//     tool surface (30 tools with dumps_supported=false, 34 with it true).
//   - CapabilityConfig values flow from McpHost construction through the
//     CapabilityContext to FmtCapability's conditional registration logic.
//   - The DartMcpDispatchBridge publishes prefixed names to the dart_mcp
//     side and the legacy unprefixed surface is gated off (T8 cut).

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

// All 30 non-dump tool bare names registered by FmtCapability.
const _nonDumpToolNames = <String>[
  // flutter_inspector_tools (6)
  'fmt_hot_reload_flutter',
  'fmt_hot_restart_flutter',
  'fmt_connect_debug_app',
  'fmt_discover_debug_apps',
  'fmt_get_vm',
  'fmt_get_extension_rpcs',
  // interaction_tools (11)
  'fmt_tap_widget',
  'fmt_enter_text',
  'fmt_reveal_search',
  'fmt_scroll',
  'fmt_long_press',
  'fmt_swipe',
  'fmt_drag',
  'fmt_hover',
  'fmt_press_key',
  'fmt_evaluate_dart_expression',
  'fmt_hot_reload_and_capture',
  // navigation_tools (2)
  'fmt_handle_dialog',
  'fmt_navigate',
  // log_tools (1)
  'fmt_get_recent_logs',
  // migrate (1)
  'fmt_migrate_agent_entries',
  // semantic_tools (1)
  'fmt_semantic_snapshot',
  // inspection_tools (6)
  'fmt_get_view_details',
  'fmt_inspect_widget_at_point',
  'fmt_get_app_errors',
  'fmt_get_screenshots',
  'fmt_focus_window',
  'fmt_capture_ui_snapshot',
  // wait_tools (1)
  'fmt_wait_for',
  // form_tools (1)
  'fmt_fill_form',
];

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
      'dumps_supported=false: 30 tools registered; no dump tool names present',
      () async {
        final host = _makeHost();
        await host.registerCapability(const FmtCapability());

        final names = host.toolNames.toSet();

        expect(
          names,
          containsAll(_nonDumpToolNames),
          reason:
              'All 30 non-dump tools must be present with dumps_supported=false',
        );
        expect(
          names.length,
          equals(30),
          reason: 'Exactly 30 tools when dumps_supported=false',
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
      'dumps_supported=true: 34 tools registered; all 4 dump tool names present',
      () async {
        final host = _makeHost(dumpsSupported: true);
        await host.registerCapability(const FmtCapability());

        final names = host.toolNames.toSet();

        expect(
          names,
          containsAll(_nonDumpToolNames),
          reason: 'All 30 non-dump tools must be present',
        );
        expect(
          names,
          containsAll(_dumpToolNames),
          reason: 'All 4 dump tools must be present with dumps_supported=true',
        );
        expect(
          names.length,
          equals(34),
          reason: 'Exactly 34 tools when dumps_supported=true',
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

        final publishedNames = published.map((final t) => t.name).toSet();
        expect(publishedNames, containsAll(_nonDumpToolNames));
        expect(publishedNames.length, equals(30));
        // Sanity: the legacy unprefixed names are NOT what the kernel publishes.
        expect(publishedNames, isNot(contains('tap_widget')));
        expect(publishedNames, isNot(contains('enter_text')));
        // No double-publish, and unpublish hasn't fired.
        expect(unpublished, isEmpty);
      },
    );
  });
}
