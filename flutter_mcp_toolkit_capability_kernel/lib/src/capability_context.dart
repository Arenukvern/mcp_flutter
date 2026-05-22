// flutter_mcp_toolkit_capability_kernel/lib/src/capability_context.dart
import 'capability_config.dart';
import 'host_service.dart';
import 'resource_registration.dart';
import 'tool_registration.dart';

/// What the host hands a [Capability] when calling `register()`.
///
/// Capabilities use this to declare their surface and resolve host services.
/// The context is per-capability and per-registration; capabilities should
/// not retain it past `register()`.
abstract interface class CapabilityContext {
  /// The capability's id. Convenience copy; equal to the capability's id.
  String get capabilityId;

  /// Capability-scoped configuration.
  CapabilityConfig get config;

  /// Register an MCP tool. The kernel applies the `<capabilityId>_` prefix
  /// to [registration.name] before exposing it; capabilities must NOT
  /// pre-prefix.
  ///
  /// Throws [PrePrefixedToolNameError] if [registration.name] starts with
  /// the capability prefix. Throws [ToolNameCollisionError] if another
  /// registration with the same final name exists.
  void registerTool(final ToolRegistration registration);

  /// Register an MCP resource. URIs are not prefixed by the kernel
  /// (URIs already encode their authority).
  void registerResource(final ResourceRegistration registration);

  /// Resolve a host service the capability needs.
  ///
  /// Throws [HostServiceUnavailableError] if the host did not provide
  /// an instance for [T].
  T require<T extends HostService>();

  /// Optional logger sink. Implementation-defined.
  void log(final String message, {final LogLevel level = LogLevel.info});
}

enum LogLevel { trace, debug, info, warning, error }
