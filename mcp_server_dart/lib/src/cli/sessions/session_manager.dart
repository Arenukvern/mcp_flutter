// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:math';

import 'package:flutter_inspector_mcp_server/src/cli/sessions/state_store.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/commands/commands_catalogue.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/results.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/state_lock_manager.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/vm_connections/connection_context.dart';

final class SessionManager {
  SessionManager({required this.connectionContext, required this.stateStore});

  final ConnectionContext connectionContext;
  final StateStore stateStore;

  PersistedState _state = const PersistedState();

  PersistedState get state => _state;

  Future<void> load() async {
    _state = await stateStore.read();
  }

  SessionState? getSession(final String? sessionId) {
    final resolvedId = _resolveSessionId(sessionId);
    if (resolvedId == null || resolvedId.isEmpty) {
      return null;
    }
    return _state.sessions[resolvedId];
  }

  String? _resolveSessionId(final String? sessionId) {
    if (sessionId != null && sessionId.isNotEmpty) {
      return sessionId;
    }
    return _state.activeSessionId;
  }

  String? get stickyEndpoint =>
      _state.activeSession?.endpoint ?? _state.stickyEndpoint;

  Future<CoreResult> startSession(final SessionStartCommand command) async {
    try {
      final connectionData = await connectionContext.connect(
        mode: command.mode,
        targetId: command.targetId,
        uri: command.uri,
        host: command.host,
        port: command.port,
        forceReconnect: command.forceReconnect,
      );

      final endpoint = connectionContext.activeEndpoint?.display;
      if (endpoint == null || endpoint.isEmpty) {
        return CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'Failed to resolve active endpoint after session start',
        );
      }

      final id = command.sessionId ?? _newSessionId();

      return await _withLockedResult(() async {
        final current = await stateStore.readUnlocked();
        final now = DateTime.now().toUtc();
        final nextSession = SessionState(
          id: id,
          endpoint: endpoint,
          createdAt: now,
          lastUsedAt: now,
          mode: command.mode.name,
          host: command.host,
          port: command.port,
          uri: command.uri,
        );

        final nextSessions = <String, SessionState>{
          ...current.sessions,
          id: nextSession,
        };

        final nextState = current.copyWith(
          activeSessionId: id,
          sessions: nextSessions,
          stickyEndpoint: endpoint,
          lastMode: command.mode.name,
        );

        await stateStore.writeUnlocked(nextState);
        _state = nextState;

        return CoreResult.success(
          data: {
            'sessionId': id,
            'endpoint': endpoint,
            'mode': command.mode.name,
            'connected': true,
            'reusedConnection': connectionData['reusedConnection'] == true,
            'selectionDiagnostics': connectionContext.lastSelectionDiagnostics,
          },
          meta: {'sessionId': id},
        );
      });
    } on CoreConnectionException catch (e) {
      if (e.reason == CoreConnectionFailureReason.multipleTargets) {
        return CoreResult.failure(
          code: CoreErrorCode.connectionSelectionRequired,
          message: e.message,
          details: e.details,
        );
      }

      return CoreResult.failure(
        code: CoreErrorCode.connectFailed,
        message: 'Failed to start session: ${e.message}',
        details: e.details,
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.connectFailed,
        message: 'Failed to start session: $e',
      );
    }
  }

  Future<CoreResult> attachSession({
    final String? sessionId,
    final bool forceReconnect = false,
  }) async {
    final resolvedSession = await _withLockedResult(() async {
      final current = await stateStore.readUnlocked();
      _state = current;

      final resolvedId = _resolveSessionId(sessionId);
      if (resolvedId == null || resolvedId.isEmpty) {
        return CoreResult.failure(
          code: CoreErrorCode.sessionNotFound,
          message: 'Session not found',
          details: {'requestedSessionId': sessionId},
        );
      }

      final session = current.sessions[resolvedId];
      if (session == null) {
        return CoreResult.failure(
          code: CoreErrorCode.sessionNotFound,
          message: 'Session not found',
          details: {'requestedSessionId': sessionId},
        );
      }

      return CoreResult.success(data: {'session': session.toJson()});
    });

    if (!resolvedSession.ok) {
      return resolvedSession;
    }

    final sessionJson =
        (resolvedSession.data! as Map<String, Object?>)['session'];
    final session = SessionState.fromJson(
      (sessionJson! as Map).cast<String, Object?>(),
    );

    try {
      final data = await connectionContext.connect(
        mode: CoreConnectionMode.uri,
        uri: session.endpoint,
        forceReconnect: forceReconnect,
      );

      final markResult = await _withLockedResult(() async {
        await _markSessionUsedLocked(
          session.id,
          endpointOverride: session.endpoint,
        );

        return CoreResult.success(
          data: {'sessionId': session.id, ...data},
          meta: {'sessionId': session.id},
        );
      });

      return markResult;
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.connectFailed,
        message: 'Failed to attach session ${session.id}: $e',
        details: {'sessionId': session.id},
      );
    }
  }

  Future<CoreResult> endSession(final String? sessionId) async {
    bool shouldDisconnect = false;

    final result = await _withLockedResult(() async {
      final current = await stateStore.readUnlocked();
      _state = current;

      final resolvedId = _resolveSessionId(sessionId);
      if (resolvedId == null || resolvedId.isEmpty) {
        return CoreResult.failure(
          code: CoreErrorCode.sessionNotFound,
          message: 'Session not found',
          details: {'requestedSessionId': sessionId},
        );
      }

      final existing = current.sessions[resolvedId];
      if (existing == null) {
        return CoreResult.failure(
          code: CoreErrorCode.sessionNotFound,
          message: 'Session not found',
          details: {'requestedSessionId': resolvedId},
        );
      }

      shouldDisconnect = current.activeSessionId == resolvedId;

      final nextSessions = <String, SessionState>{...current.sessions}
        ..remove(resolvedId);

      final nextActive = current.activeSessionId == resolvedId
          ? null
          : current.activeSessionId;

      final sticky = nextActive == null
          ? (nextSessions.values.isEmpty
                ? current.stickyEndpoint
                : nextSessions.values.last.endpoint)
          : current.stickyEndpoint;

      final nextState = current.copyWith(
        sessions: nextSessions,
        activeSessionId: nextActive,
        clearActiveSessionId: nextActive == null,
        stickyEndpoint: sticky,
        clearStickyEndpoint: sticky == null || sticky.isEmpty,
      );

      await stateStore.writeUnlocked(nextState);
      _state = nextState;

      return CoreResult.success(
        data: {
          'sessionId': resolvedId,
          'ended': true,
          'activeSessionId': nextState.activeSessionId,
          'remainingSessions': nextState.sessions.length,
        },
        meta: {'sessionId': resolvedId},
      );
    });

    if (result.ok && shouldDisconnect) {
      await connectionContext.disconnect();
    }

    return result;
  }

  Future<void> markSessionUsed(
    final String? sessionId, {
    final String? endpointOverride,
  }) async {
    final resolvedId = _resolveSessionId(sessionId);
    if (resolvedId == null || resolvedId.isEmpty) {
      return;
    }

    await _withLockedResult(() async {
      await _markSessionUsedLocked(
        resolvedId,
        endpointOverride: endpointOverride,
      );
      return CoreResult.success();
    });
  }

  Future<void> _markSessionUsedLocked(
    final String resolvedSessionId, {
    final String? endpointOverride,
  }) async {
    final current = await stateStore.readUnlocked();
    final existing = current.sessions[resolvedSessionId];
    if (existing == null) {
      _state = current;
      return;
    }

    final endpoint = endpointOverride ?? existing.endpoint;
    final next = existing.copyWith(
      lastUsedAt: DateTime.now().toUtc(),
      endpoint: endpoint,
    );

    final nextSessions = <String, SessionState>{
      ...current.sessions,
      resolvedSessionId: next,
    };

    final nextState = current.copyWith(
      sessions: nextSessions,
      activeSessionId: resolvedSessionId,
      stickyEndpoint: endpoint,
      lastMode: existing.mode,
    );

    await stateStore.writeUnlocked(nextState);
    _state = nextState;
  }

  Future<CoreResult> _withLockedResult(
    final Future<CoreResult> Function() action,
  ) async {
    try {
      return await stateStore.withStateLock(action);
    } on StateLockException catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.stateLockTimeout,
        message: e.message,
        details: {'lockFilePath': e.lockFilePath, 'owner': e.owner},
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.stateStoreWriteFailed,
        message: 'State operation failed: $e',
      );
    }
  }

  String _newSessionId() {
    final rand = Random();
    final suffix = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 's_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }
}
