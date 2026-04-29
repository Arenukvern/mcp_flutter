// mcp_capability_kernel/lib/src/testing/fake_command_runner.dart
import 'package:mcp_shared_core/mcp_shared_core.dart';

import '../command_runner.dart';

/// In-memory CommandRunner for unit tests. Records calls in [callLog]
/// (in invocation order) and returns the configurable values
/// [nextOverrideResult] / [nextExecuteResult].
final class FakeCommandRunner implements CommandRunner {
  FakeCommandRunner({
    this.nextOverrideResult,
    this.nextExecuteResult,
  });

  /// What `applyConnectionOverride` returns next. null = no override
  /// (default). Non-null = short-circuit failure.
  CoreResult? nextOverrideResult;

  /// What `execute` returns next. Defaults to a generic success with no
  /// data — override per test for specific outcomes.
  CoreResult? nextExecuteResult;

  /// Arguments passed to applyConnectionOverride, in call order.
  final List<Map<String, Object?>?> overrideArguments = [];

  /// Commands passed to execute, in call order.
  final List<CoreCommand> executedCommands = [];

  /// All calls in interleaved order. Each entry is one of:
  ///   - 'applyConnectionOverride'
  ///   - 'execute'
  /// Use to assert call ordering.
  final List<String> callLog = [];

  @override
  Future<CoreResult?> applyConnectionOverride(
    final Map<String, Object?>? arguments,
  ) async {
    overrideArguments.add(arguments);
    callLog.add('applyConnectionOverride');
    return nextOverrideResult;
  }

  @override
  Future<CoreResult> execute(final CoreCommand command) async {
    executedCommands.add(command);
    callLog.add('execute');
    return nextExecuteResult ?? CoreResult.success();
  }
}
