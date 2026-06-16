// ignore_for_file: invalid_use_of_protected_member, lines_longer_than_80_chars

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  test(
    'service extension callbacks do not treat isolateId as a tool argument',
    () async {
      final binding = _CapturingToolkitBinding()..initialize();
      Map<String, String>? capturedRequest;

      final tool = mcpToolkitTool(
        namespace: 'app',
        definition: MCPToolDefinition(
          name: 'inspect_number',
          description: 'Inspect a number',
          inputSchema: ObjectSchema(
            properties: {'x': IntegerSchema()},
            required: ['x'],
          ),
        ),
        handler: (final request) {
          capturedRequest = request;
          return MCPCallResult(message: 'inspected', parameters: {'ok': true});
        },
      );

      binding.initializeServiceExtensions(
        errorMonitor: _TestErrorMonitor(),
        entries: {tool},
      );

      final callback = binding.callbacks['inspect_number'];
      expect(callback, isNotNull);

      final result = await callback!({
        'isolateId': 'isolates/4805254787721395',
        'x': '120',
      });

      expect(result['ok'], isTrue);
      expect(capturedRequest, isNotNull);
      expect(capturedRequest, isNot(contains('isolateId')));
      expect(capturedRequest?['x'], '120');
    },
  );

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

final class _CapturingToolkitBinding extends MCPToolkitBindingBase
    with MCPToolkitExtensions {
  final callbacks = <String, ServiceExtensionCallback>{};

  @override
  void registerServiceExtension({
    required final String name,
    required final ServiceExtensionCallback callback,
  }) {
    callbacks[name] = callback;
  }
}

final class _TestErrorMonitor with ErrorMonitor {}
