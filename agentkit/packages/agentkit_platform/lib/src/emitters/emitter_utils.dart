/// Shared helpers for platform artifact emitters.
String humanizeAgentName(final String name) =>
    name.split('_').map(_titleCaseWord).join(' ');

String _titleCaseWord(final String word) {
  if (word.isEmpty) {
    return word;
  }
  return '${word[0].toUpperCase()}${word.substring(1)}';
}

/// `app_cart_total` → `AppCartTotalIntent`
String swiftIntentTypeName(final String qualifiedName) {
  final parts = qualifiedName.split('_').where((final p) => p.isNotEmpty);
  final base = parts.map(_titleCaseWord).join();
  return '${base}Intent';
}

String escapeXml(final String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String escapeSwiftString(final String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

String agentkitInvokeUri(final String qualifiedName) =>
    'agentkit://invoke/$qualifiedName';
