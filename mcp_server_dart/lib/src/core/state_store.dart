// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_inspector_mcp_server/src/core/safe_writes.dart';
import 'package:flutter_inspector_mcp_server/src/core/state_lock_manager.dart';
import 'package:path/path.dart' as p;

final class SessionState {
  const SessionState({
    required this.id,
    required this.endpoint,
    required this.createdAt,
    required this.lastUsedAt,
    required this.mode,
    this.host,
    this.port,
    this.uri,
  });

  final String id;
  final String endpoint;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final String mode;
  final String? host;
  final int? port;
  final String? uri;

  SessionState copyWith({final DateTime? lastUsedAt, final String? endpoint}) =>
      SessionState(
        id: id,
        endpoint: endpoint ?? this.endpoint,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        mode: mode,
        host: host,
        port: port,
        uri: uri,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'endpoint': endpoint,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastUsedAt': lastUsedAt.toUtc().toIso8601String(),
    'mode': mode,
    'host': host,
    'port': port,
    'uri': uri,
  };

  static SessionState fromJson(final Map<String, Object?> json) => SessionState(
    id: '${json['id'] ?? ''}',
    endpoint: '${json['endpoint'] ?? ''}',
    createdAt:
        DateTime.tryParse('${json['createdAt'] ?? ''}')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    lastUsedAt:
        DateTime.tryParse('${json['lastUsedAt'] ?? ''}')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    mode: '${json['mode'] ?? 'auto'}',
    host: json['host']?.toString(),
    port: switch (json['port']) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v),
      _ => null,
    },
    uri: json['uri']?.toString(),
  );
}

final class PersistedState {
  const PersistedState({
    this.schemaVersion = 1,
    this.activeSessionId,
    this.sessions = const <String, SessionState>{},
    this.stickyEndpoint,
    this.lastMode,
  });

  final int schemaVersion;
  final String? activeSessionId;
  final Map<String, SessionState> sessions;
  final String? stickyEndpoint;
  final String? lastMode;

  SessionState? get activeSession {
    final id = activeSessionId;
    if (id == null || id.isEmpty) {
      return null;
    }
    return sessions[id];
  }

  PersistedState copyWith({
    final int? schemaVersion,
    final String? activeSessionId,
    final bool clearActiveSessionId = false,
    final Map<String, SessionState>? sessions,
    final String? stickyEndpoint,
    final bool clearStickyEndpoint = false,
    final String? lastMode,
    final bool clearLastMode = false,
  }) => PersistedState(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    activeSessionId: clearActiveSessionId
        ? null
        : (activeSessionId ?? this.activeSessionId),
    sessions: sessions ?? this.sessions,
    stickyEndpoint: clearStickyEndpoint
        ? null
        : (stickyEndpoint ?? this.stickyEndpoint),
    lastMode: clearLastMode ? null : (lastMode ?? this.lastMode),
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'activeSessionId': activeSessionId,
    'stickyEndpoint': stickyEndpoint,
    'lastMode': lastMode,
    'sessions': sessions.map(
      (final key, final value) => MapEntry(key, value.toJson()),
    ),
  };

  static PersistedState fromJson(final Map<String, Object?> json) {
    final rawSessions = json['sessions'];
    final sessions = <String, SessionState>{};
    if (rawSessions is Map) {
      for (final entry in rawSessions.entries) {
        final key = '${entry.key}';
        final value = entry.value;
        if (value is Map<String, Object?>) {
          sessions[key] = SessionState.fromJson(value);
        } else if (value is Map) {
          sessions[key] = SessionState.fromJson(value.cast<String, Object?>());
        }
      }
    }

    final rawVersion = json['schemaVersion'];
    final schemaVersion = switch (rawVersion) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? 1,
      _ => 1,
    };

    return PersistedState(
      schemaVersion: schemaVersion,
      activeSessionId: json['activeSessionId']?.toString(),
      stickyEndpoint: json['stickyEndpoint']?.toString(),
      lastMode: json['lastMode']?.toString(),
      sessions: sessions,
    );
  }
}

final class StateStore {
  StateStore({required this.path, StateLockManager? lockManager})
    : lockManager =
          lockManager ??
          StateLockManager(
            lockFilePath: p.normalize(p.join(p.dirname(path), 'state.lock')),
          );

  final String path;
  final StateLockManager lockManager;

  Future<T> withStateLock<T>(final Future<T> Function() action) {
    return lockManager.withLock(action);
  }

  Future<PersistedState> read() {
    return withStateLock(readUnlocked);
  }

  Future<void> write(final PersistedState state) {
    return withStateLock(() => writeUnlocked(state));
  }

  Future<PersistedState> readUnlocked() async {
    try {
      final file = io.File(path);
      if (!file.existsSync()) {
        return const PersistedState();
      }

      final raw = file.readAsStringSync();
      if (raw.trim().isEmpty) {
        return const PersistedState();
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return PersistedState.fromJson(decoded);
      }
      if (decoded is Map) {
        return PersistedState.fromJson(decoded.cast<String, Object?>());
      }
    } on Exception {
      return const PersistedState();
    }

    return const PersistedState();
  }

  Future<void> writeUnlocked(final PersistedState state) async {
    final file = io.File(path);
    final payload = const JsonEncoder.withIndent('  ').convert(state.toJson());
    await SafeFileWriter.writeTextFile(path: file.path, content: payload);

    if (!io.Platform.isWindows) {
      io.Process.runSync('chmod', ['600', p.normalize(file.path)]);
    }
  }
}
