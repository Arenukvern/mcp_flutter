// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_context.dart';
import 'package:intentcall_session/intentcall_session.dart';

final class FlutterSessionConnector implements IntentSessionConnector {
  const FlutterSessionConnector({required this.connectionContext});

  final ConnectionContext connectionContext;

  @override
  String? get activeEndpointDisplay =>
      connectionContext.activeEndpoint?.display;

  @override
  Map<String, Object?> get lastSelectionDiagnostics =>
      connectionContext.lastSelectionDiagnostics;

  @override
  Future<Map<String, Object?>> connect({
    final IntentSessionConnectionMode mode = IntentSessionConnectionMode.auto,
    final String? targetId,
    final String? uri,
    final String? host,
    final int? port,
    final bool forceReconnect = false,
  }) async {
    try {
      return await connectionContext.connect(
        mode: _toCoreMode(mode),
        targetId: targetId,
        uri: uri,
        host: host,
        port: port,
        forceReconnect: forceReconnect,
      );
    } on CoreConnectionException catch (e) {
      throw _FlutterSessionConnectionException(
        reasonName: e.reason.name,
        message: e.message,
        details: e.details,
      );
    }
  }

  @override
  Future<void> disconnect() => connectionContext.disconnect();

  CoreConnectionMode _toCoreMode(final IntentSessionConnectionMode mode) =>
      switch (mode) {
        IntentSessionConnectionMode.auto => CoreConnectionMode.auto,
        IntentSessionConnectionMode.manual => CoreConnectionMode.manual,
        IntentSessionConnectionMode.uri => CoreConnectionMode.uri,
      };
}

final class _FlutterSessionConnectionException
    implements IntentSessionConnectionException {
  const _FlutterSessionConnectionException({
    required this.reasonName,
    required this.message,
    this.details,
  });

  @override
  final String reasonName;

  @override
  final String message;

  @override
  final Object? details;

  @override
  String toString() => message;
}
