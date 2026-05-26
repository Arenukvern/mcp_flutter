import 'package:agentkit_core/agentkit_core.dart';

import 'agent_web_mcp_bootstrap_stub.dart'
    if (dart.library.js_interop) 'agent_web_mcp_bootstrap_web.dart'
    as impl;

/// Registers WebMCP tools from [AgentCallEntry] values (Flutter web path C).
void registerAgentWebMcpFromEntries(final Set<AgentCallEntry> entries) =>
    impl.registerFromEntries(entries);
