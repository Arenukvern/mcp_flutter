// mcp_server_dart/lib/src/mcp_toolkit_server/core/default_command_runner.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_server/src/shared_core/command_executor.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_override.dart'
    as core_connection_override;
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

/// Server-side [CommandRunner] implementation that delegates to
/// [DefaultCoreCommandExecutor].
///
/// Injected into [McpHost] during server construction so that capability
/// handlers can execute [CoreCommand]s through the full pipeline:
/// - per-call connection override (via [applyConnectionOverride])
/// - auto-reconnect with policy (via [_ensureVmConnected] in executor)
/// - structured [CoreResult] envelope with `{ok, data, error, meta}`
/// - [CoreError] with `{code, message, details, descriptor, recovery}`
final class DefaultCommandRunner implements CommandRunner {
  const DefaultCommandRunner({required this.executor});

  final CoreCommandExecutor executor;

  @override
  Future<CoreResult> execute(final CoreCommand command) =>
      executor.execute(command);

  @override
  Future<CoreResult?> applyConnectionOverride(
    final Map<String, Object?>? arguments,
  ) => core_connection_override.applyConnectionOverrideFromArguments(
    arguments: arguments,
    executor: executor,
  );
}
