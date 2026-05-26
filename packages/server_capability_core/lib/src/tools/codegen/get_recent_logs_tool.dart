// packages/server_capability_core/lib/src/tools/codegen/get_recent_logs_tool.dart
import 'package:agentkit_codegen/agentkit_codegen.dart';
import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';

part 'get_recent_logs_tool.g.dart';

/// `@AgentTool` pilot for `fmt_get_recent_logs`.
///
/// Runtime execution is wired in [registerLogTools] via
/// [agentCallEntryToToolRegistration] so the handler receives full wire args
/// (including `connection` override) and a host [CommandRunner].
@AgentTool(
  namespace: 'fmt',
  name: 'get_recent_logs',
  description:
      'Get recent print() and log output from the running Flutter app.',
)
Future<AgentResult> fmtGetRecentLogs(
  @AgentParam('Number of recent log entries (default: 50).', required: false)
  int? count,
) async {
  return AgentResult.success(
    data: <String, Object?>{'count': count ?? 50},
  );
}
