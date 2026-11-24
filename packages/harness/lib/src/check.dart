/// Outcome of a single assertion; absent values are never implied — use
/// [CheckStatus] explicitly (`not_run`, `skip`, etc.).
enum CheckStatus {
  pass,
  fail,
  skip,
  notRun,
}

/// One assertion result; checks accumulate into a [ScenarioReport].
final class Check {
  Check({
    required this.name,
    required this.status,
    this.detail = '',
    this.id,
    this.step,
    this.expected,
    this.observed,
    this.semanticDelta,
    this.evidencePaths = const [],
  });

  final String name;
  final CheckStatus status;
  final String detail;
  final String? id;
  final String? step;
  final String? expected;
  final Object? observed;
  final String? semanticDelta;
  final List<String> evidencePaths;

  bool get passed => status == CheckStatus.pass;

  bool get isFailure => status == CheckStatus.fail;

  @override
  String toString() => switch (status) {
        CheckStatus.pass => 'PASS: $name',
        CheckStatus.fail =>
          'FAIL: $name${detail.isEmpty ? '' : ' ($detail)'}',
        CheckStatus.skip => 'SKIP: $name${detail.isEmpty ? '' : ' ($detail)'}',
        CheckStatus.notRun => 'NOT_RUN: $name',
      };
}

/// Mutable collector passed through steps; failures are recorded, not thrown,
/// so a scenario can clean up its processes before exiting non-zero.
final class ScenarioReport {
  final List<Check> checks = <Check>[];

  String? _currentStep;
  String? evidenceDir;

  void setCurrentStep(String stepTitle) => _currentStep = stepTitle;

  void pass(String name) => checks.add(
        Check(name: name, status: CheckStatus.pass, step: _currentStep),
      );

  void fail(
    String name, [
    String detail = '',
  ]) => failDetailed(name, detail: detail);

  void failDetailed(
    String name, {
    String detail = '',
    String? expected,
    Object? observed,
    String? semanticDelta,
    List<String>? evidencePaths,
    String? id,
  }) {
    checks.add(
      Check(
        name: name,
        status: CheckStatus.fail,
        detail: detail,
        step: _currentStep,
        expected: expected,
        observed: observed,
        semanticDelta: semanticDelta,
        evidencePaths: evidencePaths ?? const [],
        id: id,
      ),
    );
  }

  void skip(String name, [String detail = '']) => checks.add(
        Check(
          name: name,
          status: CheckStatus.skip,
          detail: detail,
          step: _currentStep,
        ),
      );

  void notRun(String name, [String detail = '']) => checks.add(
        Check(
          name: name,
          status: CheckStatus.notRun,
          detail: detail,
          step: _currentStep,
        ),
      );

  /// True when no check has [CheckStatus.fail] (skip and not_run are allowed).
  bool get allPassed => !checks.any((c) => c.isFailure);

  bool get hasFailures => checks.any((c) => c.isFailure);

  void printSummary() {
    for (final check in checks) {
      // ignore: avoid_print
      print('  $check');
    }
    final failures = checks.where((c) => c.status == CheckStatus.fail).length;
    // ignore: avoid_print
    print(
      allPassed
          ? 'ALL PASS (${checks.length})'
          : 'FAILURES: $failures/${checks.length}',
    );
  }
}

/// Context handed to every step: the report plus a scratch bag so steps
/// can hand each other values (e.g., a code read in step 1 used in step 3)
/// without globals.
final class HarnessContext {
  HarnessContext(this.report);

  final ScenarioReport report;
  final Map<String, Object?> bag = <String, Object?>{};

  T take<T>(String key) {
    final value = bag[key];
    if (value is! T) {
      throw StateError(
        'no $T under "$key" in the scenario bag '
        '(have: ${bag.keys.toList()})',
      );
    }
    return value;
  }
}
