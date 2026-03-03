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
  });
}
