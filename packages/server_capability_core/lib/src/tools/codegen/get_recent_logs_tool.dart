// packages/server_capability_core/lib/src/tools/codegen/get_recent_logs_tool.dart
import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

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
