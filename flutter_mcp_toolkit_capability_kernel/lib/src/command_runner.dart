// flutter_mcp_toolkit_capability_kernel/lib/src/command_runner.dart
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

import 'host_service.dart';

/// Bridge from capability code to the server's [CoreCommandExecutor] pipeline.
///
/// Capabilities that need to execute [CoreCommand]s (with connection override,
/// auto-reconnect, and structured [CoreResult] envelope) resolve this service
/// via [CapabilityContext.require<CommandRunner>()].
///
/// The server provides [DefaultCommandRunner] which wraps
/// [DefaultCoreCommandExecutor]. Tests supply a fake.
abstract interface class CommandRunner implements HostService {
  /// Execute [command] through the full executor pipeline.
  ///
  /// Returns a [CoreResult] — always check [CoreResult.ok] before using
  /// [CoreResult.data]. On failure, [CoreResult.error] contains the structured
  /// [CoreError] envelope with `{code, message, details, descriptor, recovery}`.
  Future<CoreResult> execute(final CoreCommand command);

  /// Apply a per-call connection override from a raw argument map.
  ///
  /// [arguments] is the raw MCP tool arguments map. The `connection` key (if
  /// present) is parsed, a [ConnectCommand] is executed, and the result is
  /// returned. Returns `null` when no override was requested or the connect
  /// succeeded. Returns a failure [CoreResult] if the connection override
  /// failed — callers should short-circuit and return an error result in that
  /// case.
  ///
  /// Mirrors the legacy [applyConnectionOverride] helper so that capability
  /// handlers can reproduce the full interaction_handler.dart behaviour.
  Future<CoreResult?> applyConnectionOverride(
    final Map<String, Object?>? arguments,
  );
}
