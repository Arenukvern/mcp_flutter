// mcp_capability_core/test/tools/interaction_tools_test.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_core/src/tools/interaction_tools.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';
import 'package:test/test.dart';

import '../_test_helpers.dart';

// ---------------------------------------------------------------------------
// Fake CommandRunner for unit tests.
// ---------------------------------------------------------------------------

final class _FakeCommandRunner implements CommandRunner {
  final List<CoreCommand> executedCommands = <CoreCommand>[];
  final List<Map<String, Object?>?> overrideArguments =
      <Map<String, Object?>?>[];

  CoreResult nextExecuteResult = CoreResult.success(data: {'tapped': true});
  CoreResult? nextOverrideResult; // null = no error

  @override
  Future<CoreResult> execute(final CoreCommand command) async {
    executedCommands.add(command);
    return nextExecuteResult;
  }

  @override
  Future<CoreResult?> applyConnectionOverride(
    final Map<String, Object?>? arguments,
  ) async {
    overrideArguments.add(arguments);
    return nextOverrideResult;
  }
}

void main() {
  group('interaction tools — tap_widget', () {
    test('registers tap_widget with the bare name (no prefix)', () {
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{
          CommandRunner: _FakeCommandRunner(),
        },
      );
      registerInteractionTools(ctx);
      expect(
        ctx.registeredToolNames,
        contains('tap_widget'),
        reason:
            'capability registers BARE name; kernel/host applies prefix '
            'only at the host boundary',
      );
    });

    test('tap_widget input schema has correct type and required fields', () {
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{
          CommandRunner: _FakeCommandRunner(),
        },
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget');
      expect(reg, isNotNull);
      final schema = reg!.inputSchema;
      expect(schema['type'], 'object');
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List<Object?>;
      expect(required, contains('ref'));
      final properties = schema['properties'] as Map<String, Object?>;
      expect(properties.containsKey('ref'), isTrue);
      expect(properties.containsKey('snapshotId'), isTrue);
    });

    test('tap_widget schema includes connection override property', () {
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{
          CommandRunner: _FakeCommandRunner(),
        },
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget')!;
      final properties = reg.inputSchema['properties'] as Map<String, Object?>;
      expect(
        properties.containsKey('connection'),
        isTrue,
        reason: 'connection override property must be present in schema',
      );
      final connSchema = properties['connection'] as Map<String, Object?>;
      expect(connSchema['type'], equals('object'));
      final connProps = connSchema['properties'] as Map<String, Object?>;
      expect(connProps.containsKey('targetId'), isTrue);
      expect(connProps.containsKey('mode'), isTrue);
    });

    test('tap_widget handler delegates to CommandRunner.execute', () async {
      final fakeRunner = _FakeCommandRunner();
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{CommandRunner: fakeRunner},
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{
            'ref': 's_0',
            'snapshotId': 42,
          },
        ),
      );
      expect(fakeRunner.executedCommands, hasLength(1));
      final cmd = fakeRunner.executedCommands.first as TapWidgetCommand;
      expect(cmd.ref, equals('s_0'));
      expect(cmd.snapshotId, equals(42));
      expect(result, isA<CallToolResult>());
      expect(result.isError, isNot(true));
    });

    test('tap_widget handler omits snapshotId when not provided', () async {
      final fakeRunner = _FakeCommandRunner();
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{CommandRunner: fakeRunner},
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget')!;
      await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{'ref': 'btn-submit'},
        ),
      );
      expect(fakeRunner.executedCommands, hasLength(1));
      final cmd = fakeRunner.executedCommands.first as TapWidgetCommand;
      expect(cmd.snapshotId, isNull);
    });

    test('tap_widget handler treats snapshotId == 0 as absent (legacy parity)',
        () async {
      final fakeRunner = _FakeCommandRunner();
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{CommandRunner: fakeRunner},
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget')!;
      await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{'ref': 's_1', 'snapshotId': 0},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as TapWidgetCommand;
      expect(cmd.snapshotId, isNull);
    });

    test('tap_widget handler calls applyConnectionOverride before execute',
        () async {
      final fakeRunner = _FakeCommandRunner();
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{CommandRunner: fakeRunner},
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget')!;
      final args = const <String, Object?>{
        'ref': 's_2',
        'connection': {'port': 9999},
      };
      await reg.handler(CallToolRequest(name: 'tap_widget', arguments: args));
      expect(fakeRunner.overrideArguments, hasLength(1));
      expect(fakeRunner.overrideArguments.first, equals(args));
      // execute is also called (override returned null = success)
      expect(fakeRunner.executedCommands, hasLength(1));
    });

    test('tap_widget handler short-circuits on connection override failure',
        () async {
      final fakeRunner = _FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'No app running on port 9999',
        );
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{CommandRunner: fakeRunner},
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{
            'ref': 's_0',
            'connection': {'port': 9999},
          },
        ),
      );
      // Must not execute the tap command when override fails.
      expect(fakeRunner.executedCommands, isEmpty);
      expect(result.isError, isTrue);
      // Error content must be the structured JSON envelope.
      final text = (result.content.first as TextContent).text;
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['code'], equals(CoreErrorCode.connectFailed));
      expect(json.containsKey('message'), isTrue);
      expect(json.containsKey('descriptor'), isTrue);
      expect(json.containsKey('recovery'), isTrue);
    });

    test('tap_widget handler returns structured error envelope on execute failure',
        () async {
      final fakeRunner = _FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'Widget not found',
        );
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{CommandRunner: fakeRunner},
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{'ref': 's_0'},
        ),
      );
      expect(result.isError, isTrue);
      final text = (result.content.first as TextContent).text;
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['code'], equals(CoreErrorCode.interactionFailed));
      expect(json['message'], equals('Widget not found'));
      expect(json.containsKey('descriptor'), isTrue);
      expect(json.containsKey('recovery'), isTrue);
    });
  });
}
