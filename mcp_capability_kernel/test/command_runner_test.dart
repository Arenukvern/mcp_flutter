// mcp_capability_kernel/test/command_runner_test.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Minimal fake for unit-testing the CommandRunner contract surface.
// ---------------------------------------------------------------------------

final class _FakeCommandRunner implements CommandRunner {
  final List<CoreCommand> executedCommands = <CoreCommand>[];
  final List<Map<String, Object?>?> overrideArguments =
      <Map<String, Object?>?>[];

  CoreResult nextExecuteResult = CoreResult.success(data: {'ok': true});
  CoreResult? nextOverrideResult;

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
  group('CommandRunner — interface contract', () {
    test('CommandRunner implements HostService', () {
      final runner = _FakeCommandRunner();
      expect(runner, isA<HostService>());
      expect(runner, isA<CommandRunner>());
    });

    test('execute returns CoreResult.ok on success', () async {
      final runner = _FakeCommandRunner();
      final result = await runner.execute(const StatusCommand());
      expect(result.ok, isTrue);
    });

    test('execute records the dispatched command', () async {
      final runner = _FakeCommandRunner();
      await runner.execute(const TapWidgetCommand(ref: 's_0'));
      expect(runner.executedCommands, hasLength(1));
      expect(runner.executedCommands.first, isA<TapWidgetCommand>());
    });

    test('applyConnectionOverride returns null when no connection key', () async {
      final runner = _FakeCommandRunner();
      final result = await runner.applyConnectionOverride({'ref': 's_0'});
      expect(result, isNull);
    });

    test('applyConnectionOverride returns failure CoreResult when set', () async {
      final runner = _FakeCommandRunner()
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
    });

    test('execute returns failure CoreResult when set', () async {
      final runner = _FakeCommandRunner()
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
      expect(errorJson.containsKey('descriptor'), isTrue);
      expect(errorJson.containsKey('recovery'), isTrue);
    });
  });
}
