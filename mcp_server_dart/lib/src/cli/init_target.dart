enum InitTarget {
  claudeCode('claude-code'),
  cursor('cursor'),
  codex('codex'),
  cline('cline'),
  agentsSkills('agents-skills'),
  all('all');

  const InitTarget(this.canonicalName);
  final String canonicalName;

  static InitTarget parse(final String input) {
    for (final t in InitTarget.values) {
      if (t.canonicalName == input) return t;
    }
    throw ArgumentError.value(
      input,
      'target',
      'Unknown init target. Valid: ${InitTarget.values.map((t) => t.canonicalName).join(", ")}',
    );
  }
}
