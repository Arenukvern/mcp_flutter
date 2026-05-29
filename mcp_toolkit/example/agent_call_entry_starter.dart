import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

/// Hand-written [AgentCallEntry] starter (Phase 5-C).
///
/// Codegen via `@AgentTool` is optional; this pattern stays first-class for
/// dynamic registration and hot-reload-friendly app tools.
AgentCallEntry buildDemoStatusEntry() => AgentCallEntry.resource(
  namespace: 'app',
  name: 'demo_status',
  description: 'Read-only demo status for AgentCallEntry authoring',
  handler: (_) => AgentResult.success(
    data: const {
      'authoring': 'hand_written',
      'bridge': 'AgentCallEntry.toRegistration()',
    },
  ),
);
