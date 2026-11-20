// packages/server_capability_core/lib/src/tools/codegen/get_recent_logs_tool.dart
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

part 'get_recent_logs_tool.g.dart';

/// Pilot for `fmt_get_recent_logs` (registration in [get_recent_logs_tool.g.dart]).
///
/// Runtime execution is wired in [registerLogTools] via
/// [agentCallEntryToToolRegistration] so the handler receives full wire args
/// (including `connection` override) and a host [CommandRunner].
/// Regenerate `.g.dart` with `intentcall_codegen` + `build_runner` when the
/// handler signature changes (sibling IntentCall checkout / overrides).
Future<AgentResult> fmtGetRecentLogs(int? count) async {
  return AgentResult.success(data: <String, Object?>{'count': count ?? 50});
}
