// flutter_mcp_toolkit_capability_core/lib/src/fmt_capability.dart
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';

import 'tools/debug_dump_tools.dart';
import 'tools/flutter_inspector_tools.dart';
import 'tools/form_tools.dart';
import 'tools/inspection_tools.dart';
import 'tools/interaction_tools.dart';
import 'tools/log_tools.dart';
import 'tools/navigation_tools.dart';
import 'tools/semantic_tools.dart';
import 'tools/wait_tools.dart';

/// The Flutter MCP Toolkit (`fmt`) capability — Flutter inspection and
/// Playwright-parity interaction. The capability id `'fmt'` is the user-facing
/// MCP tool prefix (e.g. `fmt_tap_widget`).
final class FmtCapability implements Capability {
  const FmtCapability();

  @override
  String get id => 'fmt';

  @override
  String get description =>
      'Flutter MCP Toolkit — interaction, inspection, hot reload, diagnostics.';

  @override
  String get version => '3.0.6'; // x-release-please-version

  @override
  Future<void> register(final CapabilityContext context) async {
    registerFlutterInspectorTools(context);
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
