// mcp_capability_core/test/core_capability_test.dart
import 'package:mcp_capability_core/src/core_capability.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_capability_kernel/testing.dart';
import 'package:test/test.dart';

import '_test_helpers.dart';

const _dumpToolNames = <String>[
  'debug_dump_layer_tree',
  'debug_dump_semantics_tree',
  'debug_dump_render_tree',
  'debug_dump_focus_tree',
];

FakeCapabilityContext _makeCtx({bool dumpsSupported = false}) {
  return FakeCapabilityContext(
    capabilityId: 'core',
    services: <Type, HostService>{
      CommandRunner: FakeCommandRunner(),
    },
    config: CapabilityConfig(
      values: <String, Object?>{
        'dumps_supported': dumpsSupported,
      },
    ),
  );
}

void main() {
  group('CoreCapability.register — dumps_supported gating', () {
    test('dumps_supported=false: dump tools are NOT registered', () async {
      final ctx = _makeCtx(dumpsSupported: false);
      await const CoreCapability().register(ctx);
      for (final name in _dumpToolNames) {
        expect(
          ctx.registeredToolNames,
          isNot(contains(name)),
          reason: '$name must not be registered when dumps_supported=false',
        );
      }
    });

    test('dumps_supported=true: all 4 dump tools ARE registered', () async {
      final ctx = _makeCtx(dumpsSupported: true);
      await const CoreCapability().register(ctx);
      expect(ctx.registeredToolNames, containsAll(_dumpToolNames));
    });

    test('other tools are registered regardless of dumps_supported', () async {
      final alwaysPresent = <String>[
        'hot_reload_flutter',
        'hot_restart_flutter',
        'connect_debug_app',
        'discover_debug_apps',
        'get_vm',
        'get_extension_rpcs',
        'tap_widget',
        'enter_text',
        'evaluate_dart_expression',
        'hot_reload_and_capture',
        'semantic_snapshot',
        'get_view_details',
        'get_app_errors',
        'get_screenshots',
        'capture_ui_snapshot',
        'get_recent_logs',
        'navigate',
        'fill_form',
      ];

      for (final dumps in [false, true]) {
        final ctx = _makeCtx(dumpsSupported: dumps);
        await const CoreCapability().register(ctx);
        expect(
          ctx.registeredToolNames,
          containsAll(alwaysPresent),
          reason:
              'Always-present tools must be registered regardless of dumps_supported=$dumps',
        );
      }
    });
  });
}
