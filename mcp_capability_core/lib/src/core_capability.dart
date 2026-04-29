// mcp_capability_core/lib/src/core_capability.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

import 'tools/debug_dump_tools.dart';
import 'tools/form_tools.dart';
import 'tools/inspection_tools.dart';
import 'tools/interaction_tools.dart';
import 'tools/log_tools.dart';
import 'tools/navigation_tools.dart';
import 'tools/semantic_tools.dart';
import 'tools/wait_tools.dart';

/// The core MCP capability for Flutter inspection and Playwright-parity
/// interaction.
final class CoreCapability implements Capability {
  const CoreCapability();

  @override
  String get id => 'core';

  @override
  String get description =>
      'Core Flutter inspector — interaction, inspection, hot reload, diagnostics.';

  @override
  String get version => '3.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    registerInteractionTools(context);
    registerNavigationTools(context);
    registerLogTools(context);
    registerSemanticTools(context);
    registerInspectionTools(context);
    registerWaitTools(context);
    registerFormTools(context);
    if (context.config.getBool('dumps_supported', defaultValue: false)) {
      registerDebugDumpTools(context);
    }
  }

  @override
  Future<void> dispose() async {}
}
