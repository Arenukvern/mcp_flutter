// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  testWidgets(
    'bootstrapFlutter initializes toolkit, adds entries, and forwards zone errors',
    (final tester) async {
      final binding = MCPToolkitBinding.instance;
      var ensured = 0;
      Object? forwardedError;
      StackTrace? forwardedStackTrace;
      var runCount = 0;

      final diagnosticResource = mcpToolkitResource(
        namespace: 'app',
        definition: MCPResourceDefinition(
          name: 'starter_runtime_status',
          description: 'Starter diagnostics resource',
          mimeType: 'application/json',
        ),
        handler: (final request) => MCPCallResult(
          message: 'Starter diagnostics',
          parameters: {'ready': true},
        ),
      );
      final mutatingTool = mcpToolkitTool(
        namespace: 'app',
        definition: MCPToolDefinition(
          name: 'starter_increment_counter',
          description: 'Starter action tool',
          inputSchema: ObjectSchema(properties: const {}),
        ),
        handler: (final request) => MCPCallResult(
          message: 'Counter incremented',
          parameters: {'ok': true},
        ),
      );

      await binding.bootstrapFlutter(
        ensureInitialized: () {
          ensured += 1;
        },
        additionalEntries: {diagnosticResource, mutatingTool},
        runApp: () {
          runCount += 1;
        },
      );

      expect(ensured, equals(1));
      expect(runCount, equals(1));
      expect(binding.isInitialized, isTrue);
      expect(
        binding.allEntries.map((final entry) => entry.serviceExtensionName),
        containsAll(<String>[
          'view_details',
          'inspect_widget_at_point',
          'starter_runtime_status',
          'starter_increment_counter',
        ]),
      );

      await binding.bootstrapFlutter(
        ensureInitialized: () {
          ensured += 1;
        },
        onZoneError: (final error, final stackTrace) {
          forwardedError = error;
          forwardedStackTrace = stackTrace;
        },
        runApp: () {
          throw StateError('bootstrap failure');
        },
      );

      expect(ensured, equals(2));
      expect(forwardedError, isA<StateError>());
      expect('$forwardedError', contains('bootstrap failure'));
      expect(forwardedStackTrace, isNotNull);
    },
  );
}
