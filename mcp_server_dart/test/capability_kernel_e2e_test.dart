// End-to-end wiring test for the capability kernel flag-on path.
//
// Verifies that:
//   - McpHost + CoreCapability registration produces the expected prefixed
//     tool surface (27 tools with dumps_supported=false, 31 with it true).
//   - CapabilityConfig values flow from McpHost construction through the
//     CapabilityContext to CoreCapability's conditional registration logic.
//   - The DartMcpDispatchBridge publishes prefixed names to the dart_mcp
//     side and the legacy unprefixed surface is gated off (T8 cut).

import 'package:dart_mcp/server.dart' as dart_mcp;
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/host.dart';
import 'package:mcp_capability_core/mcp_capability_core.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_capability_kernel/testing.dart';
import 'package:test/test.dart';


/// Helper: build a [McpHost] with a [FakeCommandRunner] and the given config.
McpHost _makeHost({final bool dumpsSupported = false}) => McpHost(
  services: <Type, HostService>{CommandRunner: FakeCommandRunner()},
  config: CapabilityConfig(
    values: <String, Object?>{'dumps_supported': dumpsSupported},
  ),
);

// All 27 non-dump tool bare names registered by CoreCapability.
const _nonDumpToolNames = <String>[
  // flutter_inspector_tools (6)
  'core_hot_reload_flutter',
  'core_hot_restart_flutter',
  'core_connect_debug_app',
  'core_discover_debug_apps',
  'core_get_vm',
  'core_get_extension_rpcs',
  // interaction_tools (10)
  'core_tap_widget',
  'core_enter_text',
  'core_scroll',
  'core_long_press',
  'core_swipe',
  'core_drag',
  'core_hover',
  'core_press_key',
  'core_evaluate_dart_expression',
  'core_hot_reload_and_capture',
  // navigation_tools (2)
  'core_handle_dialog',
  'core_navigate',
  // log_tools (1)
  'core_get_recent_logs',
  // semantic_tools (1)
  'core_semantic_snapshot',
  // inspection_tools (5)
  'core_get_view_details',
  'core_inspect_widget_at_point',
  'core_get_app_errors',
  'core_get_screenshots',
  'core_capture_ui_snapshot',
  // wait_tools (1)
  'core_wait_for',
  // form_tools (1)
  'core_fill_form',
];

// The 4 dump tool names that appear only when dumps_supported=true.
const _dumpToolNames = <String>[
  'core_debug_dump_layer_tree',
  'core_debug_dump_semantics_tree',
  'core_debug_dump_render_tree',
  'core_debug_dump_focus_tree',
];

void main() {
  group('capability kernel e2e — CoreCapability wiring', () {
    test(
        'dumps_supported=false: 24 tools registered; no dump tool names present',
        () async {
      final host = _makeHost(dumpsSupported: false);
      await host.registerCapability(const CoreCapability());

      final names = host.toolNames.toSet();

      expect(
        names,
        containsAll(_nonDumpToolNames),
        reason: 'All 27 non-dump tools must be present with dumps_supported=false',
      );
      expect(
        names.length,
        equals(27),
        reason: 'Exactly 27 tools when dumps_supported=false',
      );
      for (final dumpName in _dumpToolNames) {
        expect(
          names,
          isNot(contains(dumpName)),
          reason: '$dumpName must NOT appear when dumps_supported=false',
        );
      }
    });

    test(
        'dumps_supported=true: 31 tools registered; all 4 dump tool names present',
        () async {
      final host = _makeHost(dumpsSupported: true);
      await host.registerCapability(const CoreCapability());

      final names = host.toolNames.toSet();

      expect(
        names,
        containsAll(_nonDumpToolNames),
        reason: 'All 27 non-dump tools must be present',
      );
      expect(
        names,
        containsAll(_dumpToolNames),
        reason: 'All 4 dump tools must be present with dumps_supported=true',
      );
      expect(
        names.length,
        equals(31),
        reason: 'Exactly 31 tools when dumps_supported=true',
      );
    });

    test('all prefixed tool names start with "core_"', () async {
      final host = _makeHost(dumpsSupported: true);
      await host.registerCapability(const CoreCapability());

      for (final name in host.toolNames) {
        expect(
          name,
          startsWith('core_'),
          reason: 'Every tool must carry the "core_" capability prefix',
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
        config: CapabilityConfig(
          values: const <String, Object?>{'dumps_supported': false},
        ),
        dispatchBridge: DartMcpDispatchBridge(
          publish: (final tool, final _) => published.add(tool),
          unpublish: unpublished.add,
        ),
      );
      await host.registerCapability(const CoreCapability());

      final publishedNames = published.map((final t) => t.name).toSet();
      expect(publishedNames, containsAll(_nonDumpToolNames));
      expect(publishedNames.length, equals(27));
      // Sanity: the legacy unprefixed names are NOT what the kernel publishes.
      expect(publishedNames, isNot(contains('tap_widget')));
      expect(publishedNames, isNot(contains('enter_text')));
      // No double-publish, and unpublish hasn't fired.
      expect(unpublished, isEmpty);
    });
  });
}
