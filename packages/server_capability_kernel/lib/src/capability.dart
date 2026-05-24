// packages/server_capability_kernel/lib/src/capability.dart
import 'capability_context.dart';

/// A unit of MCP functionality that a host (server or CLI) can load.
///
/// Implementations are stateless types; per-host state lives on the host
/// side, accessed via [CapabilityContext.require].
abstract interface class Capability {
  /// Stable id used for the tool-name prefix (`<id>_<tool>`) and for
  /// configuration. Must match `^[a-z][a-z0-9_]*$`. Examples: `core`,
  /// `live_edit`. Reserved: `app` (used for unscoped dynamic registrations).
  String get id;

  /// Human-readable description, surfaced in `--list-capabilities` output.
  String get description;

  /// Semver of this capability package, surfaced in `doctor` output.
  String get version;

  /// Called once at host startup. Register tools, resources, and
  /// host-service claims here. Calling twice on the same host throws
  /// [CapabilityAlreadyRegisteredError]. Must not perform I/O.
  Future<void> register(final CapabilityContext context);

  /// Called once at host shutdown. Release resources, cancel subscriptions.
  Future<void> dispose();
}
