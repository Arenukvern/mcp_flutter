// packages/server_capability_kernel/lib/flutter_mcp_toolkit_capability_kernel.dart
/// Contracts for composable MCP capability units.
///
/// A [Capability] is a unit of MCP functionality (a set of tools and/or
/// resources) that can be loaded into a host (server or CLI). Capabilities
/// register their surface through a [CapabilityContext] supplied by the host;
/// the kernel applies a `<capabilityId>_` prefix to all exposed names.
library;

export 'src/capability.dart';
export 'src/capability_config.dart';
export 'src/capability_context.dart';
export 'src/command_runner.dart';
export 'src/host_service.dart';
export 'src/kernel_errors.dart';
export 'src/resource_registration.dart';
export 'src/resource_template_registration.dart';
export 'src/tool_registration.dart';
export 'src/validators.dart';
