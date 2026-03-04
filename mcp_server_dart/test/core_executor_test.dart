import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultCoreCommandExecutor', () {
    late DefaultCoreCommandExecutor executor;

    setUp(() {
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

      executor = DefaultCoreCommandExecutor(
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
    });

    test('status command returns normalized data', () async {
      final result = await executor.execute(const StatusCommand());

      expect(result.ok, isTrue);
      final data = result.data! as Map<String, Object?>;
      expect(data['connected'], isFalse);
      expect(result.meta.containsKey('durationMs'), isTrue);
      expect(result.meta['schemaVersion'], equals('core-envelope/v1'));
      expect(result.meta['command'], equals('status'));
      expect(result.meta['timestamp'], isA<String>());
    });

    test('dynamic commands are rejected when disabled', () async {
      final result = await executor.execute(
        const ListClientToolsAndResourcesCommand(),
      );

      expect(result.ok, isFalse);
      expect(result.error?.code, equals('dynamic_registry_disabled'));
    });

    test('auto ambiguity returns connection_selection_required', () async {
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
        discoverPorts: () async => <int>[8181, 8182],
      );

      final localExecutor = DefaultCoreCommandExecutor(
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

      final result = await localExecutor.execute(const GetVmCommand());

      expect(result.ok, isFalse);
      expect(
        result.error?.code,
        equals(CoreErrorCode.connectionSelectionRequired),
      );

      final details = result.error?.details as Map<String, Object?>?;
      expect(details?['reason'], equals('multiple_targets'));
      expect(details?['availableTargets'], isA<List<Object?>>());
      expect(
        details?['suggestedAction'],
        equals('retry_with_connection_target'),
      );
      expect(details?['example'], isA<Map<String, Object?>>());
      final available = (details?['availableTargets'] as List<Object?>?) ?? [];
      final firstTarget = available.first as Map<String, Object?>;
      expect(firstTarget['targetId'], startsWith('ws://'));
    });

    test('unknown targetId returns connect_failed target_not_found', () async {
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
        discoverPorts: () async => <int>[8181, 8182],
      );

      final localExecutor = DefaultCoreCommandExecutor(
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

      final result = await localExecutor.execute(
        const ConnectCommand(
          mode: CoreConnectionMode.auto,
          targetId: 'ws://localhost:9999/ws',
        ),
      );

      expect(result.ok, isFalse);
      expect(result.error?.code, equals(CoreErrorCode.connectFailed));
      final details = result.error?.details as Map<String, Object?>?;
      expect(details?['reason'], equals('target_not_found'));
      expect(details?['availableTargets'], isA<List<Object?>>());
    });

    test(
      'tokenized targetId bypasses discovery lookup and attempts direct connect',
      () async {
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
          discoverPorts: () async => <int>[8181, 8182],
        );

        final localExecutor = DefaultCoreCommandExecutor(
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

        final result = await localExecutor.execute(
          const ConnectCommand(
            mode: CoreConnectionMode.auto,
            targetId: 'ws://127.0.0.1:9999/token/ws',
          ),
        );

        expect(result.ok, isFalse);
        expect(result.error?.code, equals(CoreErrorCode.connectFailed));

        final details = result.error?.details;
        if (details is Map<String, Object?>) {
          expect(details['reason'], isNot(equals('target_not_found')));
        }
      },
    );

    test('legacy host:port targetId returns migration error', () async {
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

      final localExecutor = DefaultCoreCommandExecutor(
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

      final result = await localExecutor.execute(
        const ConnectCommand(
          mode: CoreConnectionMode.auto,
          targetId: 'localhost:8181',
        ),
      );

      expect(result.ok, isFalse);
      expect(result.error?.code, equals(CoreErrorCode.connectFailed));
      final details = result.error?.details as Map<String, Object?>?;
      expect(details?['reason'], equals('invalid_target_id_legacy_host_port'));
      expect(details?['migrationHint'], isA<String>());
    });
  });
}
