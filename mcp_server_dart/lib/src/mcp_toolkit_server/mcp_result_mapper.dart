import 'package:intentcall_mcp/intentcall_mcp.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:dart_mcp/server.dart';

export 'package:intentcall_mcp/intentcall_mcp.dart'
    show agentResultToMcpResult, mcpResultToAgentResult;

/// Legacy alias used by server tests.
AgentResult mcpToolResultToAgentResult(final CallToolResult result) =>
    mcpResultToAgentResult(result);
