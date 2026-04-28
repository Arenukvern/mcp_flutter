// mcp_capability_kernel/lib/src/host_service.dart
/// Marker interface for host-provided services that capabilities can require.
///
/// Capabilities resolve services through [CapabilityContext.require] at
/// registration time. Concrete implementations live in `mcp_server_dart`;
/// the kernel only defines the interfaces.
abstract interface class HostService {}

/// Bridge to the dynamic-registry that surfaces app-side
/// `MCPToolkitBinding.addEntries` registrations as MCP tools.
///
/// A capability that wants to expose its app-side tools under its own
/// namespace calls [claim] during [Capability.register]. Subsequent dynamic
/// entries tagged with the same namespace are exposed with the
/// `<namespace>_` prefix.
abstract interface class DynamicRegistryBridge implements HostService {
  /// Reserve a namespace. Throws [StateError] if the namespace is already
  /// claimed by a different capability.
  void claim({required String namespace});
}

/// Read-only access to the running Flutter app's VM service. Capabilities
/// that need to invoke service extensions go through this.
abstract interface class VmServiceClient implements HostService {
  /// Invoke a service extension on the running app, returning the raw
  /// response map.
  Future<Map<String, Object?>> callServiceExtension(
    final String method, {
    final Map<String, Object?>? args,
  });
}

/// Hot-reload coordinator. Capabilities that orchestrate code generation
/// + reload (live-edit) request reloads through this.
abstract interface class HotReloadCoordinator implements HostService {
  Future<HotReloadResult> reload({final bool pause = false});
}

/// Result of [HotReloadCoordinator.reload].
final class HotReloadResult {
  const HotReloadResult({required this.success, this.message});
  final bool success;
  final String? message;
}
