/// MCP Toolkit for Flutter applications
///
/// Integrates Flutter debug apps with MCP servers via VM service extensions and
/// the intentcall dynamic registry.
///
/// **Public surface (intentional):**
/// - Re-exports [intentcall_core] and [intentcall_schema] for a single import in apps.
/// - Flutter binding: [MCPToolkitBinding], [addMcpTool], toolkits under `src/toolkits/`.
/// - Authoring: [AgentCallEntry] (register with [MCPToolkitBinding.addEntries]).
/// - Legacy handler bridge: [mcpToolkitTool], [mcpToolkitResource] for
///   [MCPToolDefinition] + [MCPCallResult] handlers.
/// - Wire types: [MCPCallResult], [MCPToolDefinition], [MCPResourceDefinition].
///
/// `MCPCallEntry` was removed in intentcall Phase 6b; use
/// [flutter-mcp-toolkit migrate agent-entries](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/start_here/migration_intentcall_phase6.md).
///
/// See [MCPToolkitBinding] for bootstrap and registration.
library;

export 'package:dart_mcp/client.dart' hide Icon;
export 'package:intentcall_core/intentcall_core.dart';
export 'package:intentcall_schema/intentcall_schema.dart';

export 'src/agent_call_entry_extensions.dart';
export 'src/agent_client_install.dart';
export 'src/agent_entry_helpers.dart';
export 'src/mcp_models.dart';
export 'src/mcp_toolkit_binding.dart';
export 'src/mcp_toolkit_binding_base.dart';
export 'src/mcp_toolkit_extensions.dart';
export 'src/services/control_flow_service.dart';
export 'src/services/error_monitor.dart';
export 'src/services/gesture_interaction_service.dart';
export 'src/services/log_capture_service.dart';
export 'src/services/platform_view_hints.dart';
export 'src/services/semantic_snapshot_service.dart';
export 'src/services/view_introspection_service.dart';
export 'src/services/wait_predicate_service.dart';
export 'src/toolkits/flutter_mcp_toolkit.dart';
export 'src/toolkits/flutter_permission_toolkit.dart';
export 'src/toolkits/interaction_toolkit.dart';
