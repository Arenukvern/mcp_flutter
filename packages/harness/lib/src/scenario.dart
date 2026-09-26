import 'dart:async';

import 'check.dart';

/// A named unit of scenario work: prepare, act, assert.
///
/// Steps are plain functions over [HarnessContext] — composable, typed, and
/// free of shell glue. A failing step records its error as a failed [Check]
/// and aborts the remaining steps (cleanup still happens in the caller's
/// `finally`).
typedef Step = Future<void> Function(HarnessContext context);

/// One entry of [Scenario.steps]: the display name and the work.
typedef NamedStep = (String, Step);

final class Scenario {
  Scenario(this.name, {required this.steps});

  final String name;
  final List<NamedStep> steps;
  final ScenarioReport report = ScenarioReport();

  /// Runs steps in order; stops at the first failure (a thrown error or a
  /// failing check). Returns whether all steps passed.
  Future<bool> run() async {
    // ignore: avoid_print
    print('$name:');
    final context = HarnessContext(report);
    for (final (title, step) in steps) {
      try {
        await step(context);
      } on Object catch (error) {
        report.fail(title, '$error');
        break;
      }
      if (!report.allPassed) break;
    }
    return report.allPassed;
  }
}

/// Retries [action] until it returns non-null or [attempts] run out.
Future<T?> retry<T>(
  final Future<T?> Function() action, {
  final int attempts = 5,
  final Duration delay = const Duration(seconds: 2),
}) async {
  for (var i = 0; i < attempts; i++) {
    final value = await action();
    if (value != null) return value;
    await Future<void>.delayed(delay);
  }
  return null;
}
