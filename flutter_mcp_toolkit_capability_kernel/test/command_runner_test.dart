// flutter_mcp_toolkit_capability_kernel/test/command_runner_test.dart
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/testing.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

void main() {
  group('CommandRunner — interface contract', () {
    test('CommandRunner implements HostService', () {
      final runner = FakeCommandRunner();
      expect(runner, isA<HostService>());
      expect(runner, isA<CommandRunner>());
    });

    test('execute returns CoreResult.ok on success', () async {
      final runner = FakeCommandRunner();
      final result = await runner.execute(const StatusCommand());
      expect(result.ok, isTrue);
    });

    test('execute records the dispatched command', () async {
      final runner = FakeCommandRunner();
      await runner.execute(const TapWidgetCommand(ref: 's_0'));
      expect(runner.executedCommands, hasLength(1));
      expect(runner.executedCommands.first, isA<TapWidgetCommand>());
    });

    test(
      'applyConnectionOverride returns null when no connection key',
      () async {
        final runner = FakeCommandRunner();
        final result = await runner.applyConnectionOverride({'ref': 's_0'});
        expect(result, isNull);
      },
    );

    test(
      'applyConnectionOverride returns failure CoreResult when set',
      () async {
        final runner = FakeCommandRunner()
          ..nextOverrideResult = CoreResult.failure(
            code: CoreErrorCode.connectFailed,
            message: 'test failure',
          );
        final result = await runner.applyConnectionOverride({
          'connection': {'port': 9999},
        });
        expect(result, isNotNull);
        expect(result!.ok, isFalse);
        expect(result.error?.code, equals(CoreErrorCode.connectFailed));
      },
    );

    test('execute returns failure CoreResult when set', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'tap failed',
        );
      final result = await runner.execute(const TapWidgetCommand(ref: 's_1'));
      expect(result.ok, isFalse);
      expect(result.error?.code, equals(CoreErrorCode.interactionFailed));
      final errorJson = result.error!.toJson();
      expect(errorJson.containsKey('code'), isTrue);
      expect(errorJson.containsKey('message'), isTrue);
      expect(errorJson.containsKey('details'), isTrue);
      expect(errorJson.containsKey('descriptor'), isTrue);
      expect(errorJson.containsKey('recovery'), isTrue);
    });

    test('callLog records applyConnectionOverride before execute', () async {
      final runner = FakeCommandRunner();
      await runner.applyConnectionOverride({'ref': 's_0'});
      await runner.execute(const TapWidgetCommand(ref: 's_0'));
      expect(runner.callLog, equals(['applyConnectionOverride', 'execute']));
    });
  });
}
