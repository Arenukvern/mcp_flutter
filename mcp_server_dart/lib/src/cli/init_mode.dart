enum InitMode {
  mcp,
  cli,
  auto;

  static InitMode parse(final String? input) {
    if (input == null) return InitMode.auto;
    for (final m in InitMode.values) {
      if (m.name == input) return m;
    }
    throw ArgumentError.value(input, 'mode', 'Valid: mcp, cli, auto');
  }
}
