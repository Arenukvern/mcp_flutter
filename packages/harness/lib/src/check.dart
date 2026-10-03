/// One assertion result; checks accumulate into a [ScenarioReport].
final class Check {
  Check({required this.name, required this.passed, this.detail = ''});

  final String name;
  final bool passed;
  final String detail;

  @override
  String toString() => passed
      ? 'PASS: $name'
      : 'FAIL: $name${detail.isEmpty ? '' : ' ($detail)'}';
}

/// Mutable collector passed through steps; failures are recorded, not thrown,
/// so a scenario can clean up its processes before exiting non-zero.
final class ScenarioReport {
  final List<Check> checks = <Check>[];

  void pass(final String name) => checks.add(Check(name: name, passed: true));

  void fail(final String name, [final String detail = '']) =>
      checks.add(Check(name: name, passed: false, detail: detail));

  bool get allPassed => checks.every((final c) => c.passed);

  void printSummary() {
    for (final check in checks) {
      // ignore: avoid_print
      print('  $check');
    }
    final failures = checks.where((final c) => !c.passed).length;
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

  T take<T>(final String key) {
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
