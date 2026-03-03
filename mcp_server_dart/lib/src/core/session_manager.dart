// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:math';

import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/connection_context.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';
import 'package:flutter_inspector_mcp_server/src/core/state_store.dart';

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
    if (resolvedId == null || resolvedId.isEmpty) return null;
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
        ..._state.sessions,
        id: nextSession,
      };

      _state = _state.copyWith(
        activeSessionId: id,
        sessions: nextSessions,
        stickyEndpoint: endpoint,
        lastMode: command.mode.name,
      );
      await stateStore.write(_state);

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
    final session = getSession(sessionId);
    if (session == null) {
      return CoreResult.failure(
        code: CoreErrorCode.sessionNotFound,
        message: 'Session not found',
        details: {'requestedSessionId': sessionId},
      );
    }

    try {
      final data = await connectionContext.connect(
        mode: CoreConnectionMode.uri,
        uri: session.endpoint,
        forceReconnect: forceReconnect,
      );
      await _markSessionUsed(session.id, endpointOverride: session.endpoint);
      return CoreResult.success(
        data: {'sessionId': session.id, ...data},
        meta: {'sessionId': session.id},
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.connectFailed,
        message: 'Failed to attach session ${session.id}: $e',
        details: {'sessionId': session.id},
      );
    }
  }

  Future<CoreResult> endSession(final String? sessionId) async {
    final resolvedId = _resolveSessionId(sessionId);
    if (resolvedId == null || resolvedId.isEmpty) {
      return CoreResult.failure(
        code: CoreErrorCode.sessionNotFound,
        message: 'Session not found',
        details: {'requestedSessionId': sessionId},
      );
    }

    final existing = _state.sessions[resolvedId];
    if (existing == null) {
      return CoreResult.failure(
        code: CoreErrorCode.sessionNotFound,
        message: 'Session not found',
        details: {'requestedSessionId': resolvedId},
      );
    }

    if (_state.activeSessionId == resolvedId) {
      await connectionContext.disconnect();
    }

    final nextSessions = <String, SessionState>{..._state.sessions}
      ..remove(resolvedId);

    final nextActive = _state.activeSessionId == resolvedId
        ? null
        : _state.activeSessionId;

    final sticky = nextActive == null
        ? (nextSessions.values.isEmpty
              ? _state.stickyEndpoint
              : nextSessions.values.last.endpoint)
        : _state.stickyEndpoint;

    _state = _state.copyWith(
      sessions: nextSessions,
      activeSessionId: nextActive,
      clearActiveSessionId: nextActive == null,
      stickyEndpoint: sticky,
      clearStickyEndpoint: sticky == null || sticky.isEmpty,
    );
    await stateStore.write(_state);

    return CoreResult.success(
      data: {
        'sessionId': resolvedId,
        'ended': true,
        'activeSessionId': _state.activeSessionId,
        'remainingSessions': _state.sessions.length,
      },
      meta: {'sessionId': resolvedId},
    );
  }

  Future<void> markSessionUsed(
    final String? sessionId, {
    final String? endpointOverride,
  }) async {
    final resolvedId = _resolveSessionId(sessionId);
    if (resolvedId == null || resolvedId.isEmpty) {
      return;
    }
    await _markSessionUsed(resolvedId, endpointOverride: endpointOverride);
  }

  Future<void> _markSessionUsed(
    final String resolvedSessionId, {
    final String? endpointOverride,
  }) async {
    final existing = _state.sessions[resolvedSessionId];
    if (existing == null) return;

    final endpoint = endpointOverride ?? existing.endpoint;
    final next = existing.copyWith(
      lastUsedAt: DateTime.now().toUtc(),
      endpoint: endpoint,
    );

    final nextSessions = <String, SessionState>{
      ..._state.sessions,
      resolvedSessionId: next,
    };

    _state = _state.copyWith(
      sessions: nextSessions,
      activeSessionId: resolvedSessionId,
      stickyEndpoint: endpoint,
      lastMode: existing.mode,
    );
    await stateStore.write(_state);
  }

  String _newSessionId() {
    final rand = Random();
    final suffix = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 's_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }
}
