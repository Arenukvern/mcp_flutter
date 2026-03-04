import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('SnapshotStore', () {
    late Directory tempDir;
    late String snapshotsDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_snapshots_');
      snapshotsDir = '${tempDir.path}/snapshots';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('creates snapshot deterministically from command plan', () async {
      final store = SnapshotStore(snapshotsDir: snapshotsDir);
      final catalog = CommandCatalog.instance;

      final logger =
          (
            final LoggingLevel level,
            final String message, {
            final String logger = 'test',
          }) {};

      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: logger,
        discoverPorts: () async => <int>[8181],
      );

      final executor = DefaultCoreCommandExecutor(
        connectionContext: context,
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
        ),
      );

      final snapshot = await store.createSnapshot(
        id: 's1',
        executor: executor,
        catalog: catalog,
        args: {
          'commands': [
            {'name': 'status', 'args': {}},
          ],
        },
      );

      expect(snapshot['id'], equals('s1'));
      final results = (snapshot['results'] as List)
          .cast<Map<String, Object?>>();
      expect(results.length, equals(1));
      expect(results.first['name'], equals('status'));
      expect(File('$snapshotsDir/s1.json').existsSync(), isTrue);
    });

    test('computes structural diff with path-level changes', () async {
      final store = SnapshotStore(snapshotsDir: snapshotsDir);
      await Directory(snapshotsDir).create(recursive: true);

      final a = File('$snapshotsDir/a.json');
      final b = File('$snapshotsDir/b.json');

      await a.writeAsString(
        jsonEncode({
          'id': 'a',
          'value': {
            'x': 1,
            'list': [1, 2],
          },
        }),
      );

      await b.writeAsString(
        jsonEncode({
          'id': 'b',
          'value': {
            'x': 2,
            'list': [1, 3],
            'extra': true,
          },
        }),
      );

      final diff = await store.diffSnapshots(fromId: 'a', toId: 'b');
      final changes = (diff['changes'] as List).cast<Map<String, Object?>>();

      expect(changes, isNotEmpty);
      final paths = changes.map((final c) => c['path'] as String).toSet();
      expect(paths.contains(r'$.value.x'), isTrue);
      expect(paths.contains(r'$.value.list[1]'), isTrue);
      expect(paths.contains(r'$.value.extra'), isTrue);

      final summary = diff['summary'] as Map<String, Object?>;
      expect((summary['totalChanges'] as int) >= 3, isTrue);
    });

    test('honors per-step args.connection before step execution', () async {
      final store = SnapshotStore(snapshotsDir: snapshotsDir);
      final catalog = CommandCatalog.instance;

      final logger =
          (
            final LoggingLevel level,
            final String message, {
            final String logger = 'test',
          }) {};

      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: logger,
        discoverPorts: () async => <int>[8181],
      );

      final executor = DefaultCoreCommandExecutor(
        connectionContext: context,
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
        ),
      );

      final snapshot = await store.createSnapshot(
        id: 's2',
        executor: executor,
        catalog: catalog,
        args: {
          'commands': [
            {
              'name': 'status',
              'args': {
                'connection': {'targetId': 'ws://localhost:9999/ws'},
              },
            },
          ],
        },
      );

      final results = (snapshot['results'] as List)
          .cast<Map<String, Object?>>();
      expect(results, hasLength(1));

      final envelope = results.first['result'] as Map<String, Object?>;
      expect(envelope['ok'], isFalse);
      final error = envelope['error'] as Map<String, Object?>;
      expect(error['code'], equals(CoreErrorCode.connectFailed));
      expect(
        (error['details'] as Map<String, Object?>)['reason'],
        equals('target_not_found'),
      );
    });

    test(
      '--check mode reports planned snapshot drift without writing file',
      () async {
        final store = SnapshotStore(snapshotsDir: snapshotsDir);
        final catalog = CommandCatalog.instance;

        final logger =
            (
              final LoggingLevel level,
              final String message, {
              final String logger = 'test',
            }) {};

        final context = ConnectionContext(
          defaultHost: 'localhost',
          defaultPort: 8181,
          logger: logger,
          discoverPorts: () async => <int>[8181],
        );

        final executor = DefaultCoreCommandExecutor(
          connectionContext: context,
          portScanner: CorePortScanner(logger: logger),
          imageFileSaver: CoreImageFileSaver(logger: logger),
          configuration: const CoreRuntimeConfiguration(
            vmHost: 'localhost',
            vmPort: 8181,
            resourcesSupported: true,
            imagesSupported: true,
            dumpsSupported: false,
            dynamicRegistrySupported: false,
            saveImagesToFiles: false,
          ),
        );

        final snapshot = await store.createSnapshot(
          id: 'check_only',
          executor: executor,
          catalog: catalog,
          args: {
            'commands': [
              {'name': 'status', 'args': {}},
            ],
          },
          writeOptions: const SafeWriteOptions(check: true, diff: true),
        );

        final writes = (snapshot['writeResults'] as List)
            .cast<Map<String, Object?>>();
        expect(writes.single['status'], equals(SafeWriteStatus.added));
        expect(writes.single['wrote'], isFalse);
        expect(writes.single['diff'], isA<Map<String, Object?>>());
        expect(File('$snapshotsDir/check_only.json').existsSync(), isFalse);
      },
    );

    test('--no-overwrite blocks existing snapshot target', () async {
      final store = SnapshotStore(snapshotsDir: snapshotsDir);
      final catalog = CommandCatalog.instance;
      final logger =
          (
            final LoggingLevel level,
            final String message, {
            final String logger = 'test',
          }) {};
      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: logger,
        discoverPorts: () async => <int>[8181],
      );
      final executor = DefaultCoreCommandExecutor(
        connectionContext: context,
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
        ),
      );

      await store.createSnapshot(
        id: 'existing',
        executor: executor,
        catalog: catalog,
        args: {
          'commands': [
            {'name': 'status', 'args': {}},
          ],
        },
      );

      final snapshot = await store.createSnapshot(
        id: 'existing',
        executor: executor,
        catalog: catalog,
        args: {
          'commands': [
            {'name': 'status', 'args': {}},
          ],
        },
        writeOptions: const SafeWriteOptions(noOverwrite: true),
      );

      final writes = (snapshot['writeResults'] as List)
          .cast<Map<String, Object?>>();
      expect(writes.single['status'], equals(SafeWriteStatus.blocked));
      expect(writes.single['wrote'], isFalse);
    });
  });
}
