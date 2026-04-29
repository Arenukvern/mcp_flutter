// mcp_capability_core/lib/src/tools/interaction_tools.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

/// Registers Playwright-parity interaction tools with the host through
/// [context]. Currently registers `tap_widget`; remaining tools land in
/// follow-up dispatches.
///
/// In T4-A only `tap_widget` is registered; remaining tools land in T4-B.
void registerInteractionTools(final CapabilityContext context) {
  // Populated in T4.3 (this dispatch) for tap_widget; remaining in T4-B.
}
