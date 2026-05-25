import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:dart_mcp/server.dart';

export 'package:agentkit_mcp/agentkit_mcp.dart'
    show agentResultToMcpResult, mcpResultToAgentResult;

/// Legacy alias used by server tests.
AgentResult mcpToolResultToAgentResult(final CallToolResult result) =>
    mcpResultToAgentResult(result);
