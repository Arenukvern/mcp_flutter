/// MCP Toolkit for Flutter applications
///
/// Provides tools for integrating Flutter apps with
/// MCP (Model Context Protocol) servers,
/// including dynamic tool and resource registration capabilities.
///
/// This package is a part of the MCP Flutter project and is used to register
/// tools and resources in the Flutter app.
///
/// See [MCPToolkitBinding] for more information on how to use this package.
library;

export 'package:agentkit_core/agentkit_core.dart';
export 'package:agentkit_schema/agentkit_schema.dart';
export 'package:dart_mcp/client.dart' hide Icon;

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
