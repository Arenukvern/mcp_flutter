import 'dart:io';

import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('StateStore', () {
    late Directory tempDir;
    late String statePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_state_');
      statePath = '${tempDir.path}/state.json';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('persists and restores sessions', () async {
      final store = StateStore(path: statePath);

      final now = DateTime.now().toUtc();
      final session = SessionState(
        id: 's1',
        endpoint: 'ws://127.0.0.1:8181/token/ws',
        createdAt: now,
        lastUsedAt: now,
        mode: 'uri',
        uri: 'ws://127.0.0.1:8181/token/ws',
      );

      await store.write(
        PersistedState(
          activeSessionId: 's1',
          stickyEndpoint: session.endpoint,
          lastMode: 'uri',
          sessions: {'s1': session},
        ),
      );

      final loaded = await store.read();
      expect(loaded.activeSessionId, equals('s1'));
      expect(loaded.stickyEndpoint, equals('ws://127.0.0.1:8181/token/ws'));
      expect(loaded.sessions.length, equals(1));
      expect(loaded.sessions['s1']?.endpoint, equals(session.endpoint));
    });

    test('recovers to default state on malformed json', () async {
      final file = File(statePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('{ not json');
      expect(file.existsSync(), isTrue);

      final store = StateStore(path: statePath);
      final loaded = await store.read();

      expect(loaded.sessions, isEmpty);
      expect(loaded.activeSessionId, isNull);
      expect(loaded.schemaVersion, equals(1));
    });
  });
}
