import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterToolMachineDiscovery', () {
    test('parseMachineEvent extracts canonical VM WS URI and DTD URI', () {
      final parsed = FlutterToolMachineDiscovery.parseMachineEvent({
        'event': 'app.debugPort',
        'params': {
          'app': {
            'debugPort': {'wsUri': 'WS://LOCALHOST:59490/qwerty/ws'},
            'dtd': {'uri': 'ws://127.0.0.1:59490/dtd/ws'},
          },
        },
      });

      expect(
        parsed.vmServiceWsUri?.toString(),
        equals('ws://localhost:59490/qwerty/ws'),
      );
      expect(parsed.dtdUri?.toString(), equals('ws://127.0.0.1:59490/dtd/ws'));
    });

    test('parseMachineEvent extracts dtd URI from app.dtd.uri event', () {
      final parsed = FlutterToolMachineDiscovery.parseMachineEvent({
        'event': 'app.dtd.uri',
        'params': {'uri': 'ws://127.0.0.1:59490/dtd'},
      });

      expect(parsed.vmServiceWsUri, isNull);
      expect(parsed.dtdUri?.toString(), equals('ws://127.0.0.1:59490/dtd'));
    });

    test('parseVmServiceWsUri rejects legacy host:port style values', () {
      final parsed = FlutterToolMachineDiscovery.parseVmServiceWsUri(
        'localhost:59490',
      );
      expect(parsed, isNull);
    });

    test(
      'parseProcessVmServiceWsUri upgrades http VM URI to canonical ws URI',
      () {
        final parsed = FlutterToolMachineDiscovery.parseProcessVmServiceWsUri(
          '/path/to/dart development-service --vm-service-uri=http://127.0.0.1:55571/jafDCsl7Cz4=/ --bind-address=127.0.0.1 --bind-port=0',
        );

        expect(
          parsed?.toString(),
          equals('ws://127.0.0.1:55571/jafDCsl7Cz4=/ws'),
        );
      },
    );

    test('parseProcessDiscoveryLine extracts target from DDS command line', () {
      final parsed = FlutterToolMachineDiscovery.parseProcessDiscoveryLine(
        '76597 /Users/anton/flutter/bin/cache/dart-sdk/bin/dart development-service --vm-service-uri=http://127.0.0.1:55571/jafDCsl7Cz4=/ --bind-address=127.0.0.1 --bind-port=0 --serve-devtools',
      );

      expect(
        parsed?.vmServiceWsUri.toString(),
        equals('ws://127.0.0.1:55571/jafDCsl7Cz4=/ws'),
      );
      expect(parsed?.sourceEvent, equals('process.vmServiceUri'));
    });
  });
}
