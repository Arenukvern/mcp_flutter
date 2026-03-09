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

export 'package:dart_mcp/client.dart' hide Icon;

export 'src/mcp_models.dart';
export 'src/mcp_toolkit_binding.dart';
export 'src/mcp_toolkit_binding_base.dart';
export 'src/mcp_toolkit_extensions.dart';
export 'src/services/error_monitor.dart';
export 'src/toolkits/flutter_mcp_toolkit.dart';
export 'src/toolkits/flutter_permission_toolkit.dart';
