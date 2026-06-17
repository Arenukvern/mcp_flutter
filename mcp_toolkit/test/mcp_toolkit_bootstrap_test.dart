// ignore_for_file: invalid_use_of_protected_member, lines_longer_than_80_chars

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  group('VM service extension isolateId stripping', () {
    test(
      'callback succeeds when isolateId is injected on strict schemas',
      () async {
        final binding = _CapturingToolkitBinding()..initialize();
        Map<String, Object?>? capturedRequest;

        final tool = mcpToolkitTool(
          namespace: 'app',
          definition: MCPToolDefinition(
            name: 'inspect_number',
            description: 'Inspect a number',
            inputSchema: ObjectSchema(
              properties: {'x': IntegerSchema()},
              required: ['x'],
              additionalProperties: false,
            ),
          ),
          handler: (final request) {
            capturedRequest = request;
            return MCPCallResult(
              message: 'inspected',
              parameters: {'ok': true, 'x': request['x']},
            );
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
        expect(result['x'], '120');
        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.keys, ['x']);
        expect(capturedRequest, isNot(contains('isolateId')));
        expect(capturedRequest!['x'], '120');
      },
    );

    test(
      'raw VM service parameters with isolateId fail strict schema validation',
      () {
      final binding = _CapturingToolkitBinding()..initialize();
      final tool = mcpToolkitTool(
        namespace: 'app',
        definition: MCPToolDefinition(
          name: 'inspect_number',
          description: 'Inspect a number',
          inputSchema: ObjectSchema(
            properties: {'x': IntegerSchema()},
            required: ['x'],
            additionalProperties: false,
          ),
        ),
        handler: (final request) =>
            MCPCallResult(message: 'inspected', parameters: {'ok': true}),
      );
      final registration = tool.toRegistration();
      final rawWireArgs = <String, Object?>{
        'isolateId': 'isolates/4805254787721395',
        'x': '120',
      };

      expect(
        () => registration.validate(rawWireArgs),
        throwsA(isA<AgentValidationException>()),
        reason:
            'VM transport isolateId must not reach strict MCP tool schemas',
      );

      final strippedArgs = binding
          .mcpToolkitArgumentsFromServiceExtensionParameters(<String, String>{
            'isolateId': 'isolates/4805254787721395',
            'x': '120',
          });
      final coercedArgs = coerceArgumentsForSchema(
        registration.descriptor.inputSchema,
        strippedArgs,
      );

      expect(() => registration.validate(coercedArgs), returnsNormally);
      },
    );
  });

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
