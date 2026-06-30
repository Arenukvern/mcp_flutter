// packages/server_capability_kernel/lib/src/host_service.dart
import 'package:meta/meta.dart';

/// Marker interface for host-provided services that capabilities can require.
///
/// Capabilities resolve services through [CapabilityContext.require] at
/// registration time. Concrete implementations live in `mcp_server_dart`;
/// the kernel only defines the interfaces.
abstract interface class HostService {}

/// Reserved bridge to the dynamic registry that surfaces app-side
/// `MCPToolkitBinding.addEntries` registrations as MCP tools.
///
/// A capability that wants to expose its app-side tools under its own
/// namespace calls [claim] during [Capability.register]. Subsequent dynamic
/// entries tagged with the same namespace are exposed with the
/// `<namespace>_` prefix.
abstract interface class DynamicRegistryBridge implements HostService {
  /// Reserve a namespace. Throws [StateError] if the namespace is already
  /// claimed by a different capability.
  void claim({required final String namespace});
}

/// Reserved read-only access to the running Flutter app's VM service.
///
/// Current built-in capabilities use [CommandRunner] for most operations. Keep
/// this contract available for future host services without moving VM-specific
/// code into the kernel.
abstract interface class VmServiceClient implements HostService {
  /// Invoke a service extension on the running app, returning the raw
  /// response map.
  Future<Map<String, Object?>> callServiceExtension(
    final String method, {
    final Map<String, Object?>? args,
  });
}

/// Reserved hot-reload coordinator for capabilities that orchestrate code
/// generation plus reload requests.
abstract interface class HotReloadCoordinator implements HostService {
  Future<HotReloadResult> reload({final bool pause = false});
}

/// Result of [HotReloadCoordinator.reload].
@immutable
final class HotReloadResult {
  const HotReloadResult({required this.success, this.message});
  final bool success;
  final String? message;
}
