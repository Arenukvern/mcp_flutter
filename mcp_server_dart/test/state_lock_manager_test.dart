import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('StateLockManager', () {
    late Directory tempDir;
    late String lockPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_lock_');
      lockPath = '${tempDir.path}/state.lock';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('acquires and releases lock through withLock', () async {
      final manager = StateLockManager(lockFilePath: lockPath);
      var called = false;

      await manager.withLock(() async {
        called = true;
        expect(File(lockPath).existsSync(), isTrue);
      });

      expect(called, isTrue);
      expect(File(lockPath).existsSync(), isFalse);
    });

    test('recovers stale lock based on TTL', () async {
      final lockFile = File(lockPath)..createSync(recursive: true);
      lockFile.writeAsStringSync(
        jsonEncode({
          'token': 'old',
          'pid': 123,
          'createdAt': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
        }),
      );

      final manager = StateLockManager(
        lockFilePath: lockPath,
        staleLockTtl: const Duration(seconds: 1),
      );

      final acquisition = await manager.acquire();
      expect(acquisition.staleLockRecovered, isTrue);
      await manager.release(acquisition);
    });

    test('returns timeout diagnostics on lock contention', () async {
      final managerA = StateLockManager(
        lockFilePath: lockPath,
        acquireTimeout: const Duration(seconds: 5),
      );
      final managerB = StateLockManager(
        lockFilePath: lockPath,
        acquireTimeout: const Duration(milliseconds: 150),
        pollInterval: const Duration(milliseconds: 20),
      );

      final hold = managerA.withLock(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(managerB.acquire, throwsA(isA<StateLockException>()));

      await hold;
    });
  });
}
