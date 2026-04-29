// mcp_capability_core/lib/src/core_capability.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

import 'tools/interaction_tools.dart';

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
    // Other tool groups (inspection, wait, nav, form, log, etc.) added in
    // follow-up dispatches.
  }

  @override
  Future<void> dispose() async {}
}
