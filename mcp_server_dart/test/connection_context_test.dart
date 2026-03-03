import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  test('seeds sticky endpoint with URI path token', () {
    final context = ConnectionContext(
      defaultHost: 'localhost',
      defaultPort: 8181,
      logger:
          (
            final LoggingLevel level,
            final String message, {
            final String logger = 'test',
          }) {},
      discoverPorts: () async => <int>[],
      initialStickyEndpointUri: 'ws://127.0.0.1:8181/pHDrCFCDBwg=/ws',
    );

    expect(
      context.stickyEndpoint?.display,
      equals('ws://127.0.0.1:8181/pHDrCFCDBwg=/ws'),
    );
  });
}
