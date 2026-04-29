// End-to-end wiring test for the capability kernel flag-on path.
//
// Verifies that:
//   - McpHost + CoreCapability registration produces the expected prefixed
//     tool surface (24 tools with dumps_supported=false, 28 with it true).
//   - CapabilityConfig values flow from McpHost construction through the
//     CapabilityContext to CoreCapability's conditional registration logic.
//
// This test does NOT go through MCPToolkitServer or dart_mcp dispatch;
// that plumbing belongs to T5/T8. The observable invariant here is the
// host tool registry, which is the single source of truth the server will
// delegate to once the dispatch layer is wired.

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

// All 24 non-dump tool bare names registered by CoreCapability.
const _nonDumpToolNames = <String>[
  // flutter_inspector_tools (5)
  'core_hot_reload_flutter',
  'core_connect_debug_app',
  'core_discover_debug_apps',
  'core_get_vm',
  'core_get_extension_rpcs',
  // interaction_tools (8)
  'core_tap_widget',
  'core_enter_text',
  'core_scroll',
  'core_long_press',
  'core_swipe',
  'core_drag',
  'core_hover',
  'core_press_key',
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
        reason: 'All 24 non-dump tools must be present with dumps_supported=false',
      );
      expect(
        names.length,
        equals(24),
        reason: 'Exactly 24 tools when dumps_supported=false',
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
        'dumps_supported=true: 28 tools registered; all 4 dump tool names present',
        () async {
      final host = _makeHost(dumpsSupported: true);
      await host.registerCapability(const CoreCapability());

      final names = host.toolNames.toSet();

      expect(
        names,
        containsAll(_nonDumpToolNames),
        reason: 'All 24 non-dump tools must be present',
      );
      expect(
        names,
        containsAll(_dumpToolNames),
        reason: 'All 4 dump tools must be present with dumps_supported=true',
      );
      expect(
        names.length,
        equals(28),
        reason: 'Exactly 28 tools when dumps_supported=true',
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
  });
}
