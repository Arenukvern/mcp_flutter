import 'dart:io';

import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('SessionManager', () {
    late Directory tempDir;
    late String statePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_session_');
      statePath = '${tempDir.path}/state.json';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('endSession removes active session and persists changes', () async {
      final now = DateTime.now().toUtc();
      final store = StateStore(path: statePath);
      await store.write(
        PersistedState(
          activeSessionId: 's1',
          stickyEndpoint: 'ws://127.0.0.1:8181/token/ws',
          sessions: {
            's1': SessionState(
              id: 's1',
              endpoint: 'ws://127.0.0.1:8181/token/ws',
              createdAt: now,
              lastUsedAt: now,
              mode: 'uri',
            ),
          },
        ),
      );

      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: (final level, final message, {final logger = 'test'}) {},
        discoverPorts: () async => <int>[8181],
      );

      final manager = SessionManager(
        connectionContext: context,
        stateStore: store,
      );
      await manager.load();

      final result = await manager.endSession('s1');
      expect(result.ok, isTrue);

      final loaded = await store.read();
      expect(loaded.activeSessionId, isNull);
      expect(loaded.sessions, isEmpty);
    });

    test('returns session_not_found for missing session', () async {
      final store = StateStore(path: statePath);
      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: (final level, final message, {final logger = 'test'}) {},
        discoverPorts: () async => <int>[8181],
      );

      final manager = SessionManager(
        connectionContext: context,
        stateStore: store,
      );
      await manager.load();

      final result = await manager.endSession('does-not-exist');
      expect(result.ok, isFalse);
      expect(result.error?.code, equals('session_not_found'));
    });
  });
}
