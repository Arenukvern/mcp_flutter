import 'dart:async';

/// One cleanup step that failed while unwinding a native capture session.
final class NativeCaptureCleanupFailure {
  const NativeCaptureCleanupFailure({
    required this.label,
    required this.error,
    this.stack,
  });

  final String label;
  final Object error;
  final StackTrace? stack;

  Map<String, Object?> toJson() => {
        'label': label,
        'error': error.toString(),
        if (stack != null) 'stack': '$stack',
      };
}

/// Outcome of [runWithPreservedPrimaryFailure] for artifact persistence.
final class NativeCaptureRunOutcome {
  NativeCaptureRunOutcome();

  Object? primaryError;
  StackTrace? primaryStack;
  final List<NativeCaptureCleanupFailure> cleanupFailures = [];

  bool get hasPrimary => primaryError != null;
  bool get hasCleanupFailures => cleanupFailures.isNotEmpty;

  Map<String, Object?> toJson() => {
        'primaryError': primaryError?.toString(),
        if (primaryStack != null) 'primaryStack': '$primaryStack',
        'cleanupFailures':
            cleanupFailures.map((failure) => failure.toJson()).toList(),
      };
}

typedef NativeCaptureCleanupStep = Future<void> Function();

/// Runs [body], then every [cleanupSteps] label/step pair in order.
///
/// Cleanup errors never replace [body]'s exception: the primary failure is
/// rethrown with its original stack. When [body] succeeds but cleanup fails,
/// throws [StateError] aggregating cleanup failures.
Future<T> runWithPreservedPrimaryFailure<T>({
  required Future<T> Function() body,
  required List<(String label, NativeCaptureCleanupStep step)> cleanupSteps,
  Future<void> Function(NativeCaptureRunOutcome outcome)? onOutcome,
}) async {
  final outcome = NativeCaptureRunOutcome();
  T? result;
  Object? primary;
  StackTrace? stack;
  try {
    result = await body();
  } on Object catch (error, st) {
    primary = error;
    stack = st;
    outcome.primaryError = error;
    outcome.primaryStack = st;
  }

  for (final entry in cleanupSteps) {
    final (label, step) = entry;
    try {
      await step();
    } on Object catch (error, st) {
      outcome.cleanupFailures.add(
        NativeCaptureCleanupFailure(label: label, error: error, stack: st),
      );
    }
  }

  if (onOutcome != null) {
    await onOutcome(outcome);
  }

  if (primary != null) {
    Error.throwWithStackTrace(primary, stack ?? StackTrace.current);
  }
  if (outcome.cleanupFailures.isNotEmpty) {
    throw StateError(
      'native capture cleanup failed (${outcome.cleanupFailures.length}): '
      '${outcome.cleanupFailures.map((failure) => '${failure.label}: '
          '${failure.error}').join('; ')}',
    );
  }
  return result as T;
}
