// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_inspector_mcp_server/src/cli/session/session_manager.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/commands/commands.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/command_executor.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/types/results.dart';

/// Shared pre-connect policy for CLI one-shot, daemon requests, and snapshots.
Future<CoreResult?> preconnectForExecution({
  required final CoreCommand command,
  required final DefaultCoreCommandExecutor executor,
  required final SessionManager? sessionManager,
  final ConnectCommand? explicitConnectionOverride,
  final String? explicitVmServiceUri,
}) async {
  if (_isPreconnectSkippedCommand(command)) {
    return null;
  }

  if (explicitConnectionOverride != null) {
    final explicitOverrideResult = await executor.execute(
      explicitConnectionOverride,
    );
    if (!explicitOverrideResult.ok) {
      return explicitOverrideResult;
    }
  }

  final globalUri = explicitVmServiceUri?.trim();
  if (globalUri != null && globalUri.isNotEmpty) {
    final explicitUriResult = await executor.execute(
      ConnectCommand(mode: CoreConnectionMode.uri, uri: globalUri),
    );
    if (!explicitUriResult.ok) {
      return explicitUriResult;
    }
  }

  final manager = sessionManager;
  if (manager == null) {
    return null;
  }

  final requestedSessionId = _sessionIdForCommand(command);
  if (requestedSessionId != null && requestedSessionId.isNotEmpty) {
    final explicitAttach = await manager.attachSession(
      sessionId: requestedSessionId,
    );
    if (!explicitAttach.ok) {
      return explicitAttach;
    }
    return null;
  }

  final hasImplicitSession = manager.state.activeSessionId != null;
  if (!hasImplicitSession) {
    return null;
  }

  // Best-effort attach for implicit active session.
  // On failure, execution continues and VM auto policy resolves the target.
  await manager.attachSession();
  return null;
}

bool _isPreconnectSkippedCommand(final CoreCommand command) =>
    command is ConnectCommand ||
    command is SessionStartCommand ||
    command is SessionEndCommand;

String? _sessionIdForCommand(final CoreCommand command) {
  if (command case final SessionExecCommand c) {
    return c.sessionId;
  }
  if (command case final WatchCommand c) {
    return c.sessionId;
  }
  if (command case final SessionEndCommand c) {
    return c.sessionId;
  }
  if (command case final SessionStartCommand c) {
    return c.sessionId;
  }
  return null;
}
