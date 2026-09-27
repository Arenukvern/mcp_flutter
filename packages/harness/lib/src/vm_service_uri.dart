/// VM service URI detection shared by every launch path.
library;

/// Matches the debug VM service announcement in a Flutter process's output:
/// `… Dart VM Service … is available at: http://127.0.0.1:PORT/TOKEN=` (the
/// token's trailing `/` is not captured — [vmServiceUriFromLine] keeps the
/// exact capture the [VmClient] websocket conversion expects).
final RegExp vmServiceUriPattern = RegExp(
  r'(?:vm service|Dart VM Service)[^\n]*?(http://127\.0\.0\.1:\d+/[\w_-]+=)',
  caseSensitive: false,
);

/// Web (DWDS) announcements already speak `ws://`:
/// `ws://127.0.0.1:PORT/TOKEN/=ws` — used when the port is pinned via
/// `--host-vmservice-port` and scraped from a log file (detached sessions).
final RegExp vmServiceWsUriPattern = RegExp(
  r'ws://127\.0\.0\.1:\d+/[\w_-]+/ws',
);

/// Extracts the first VM service http URI from [line], or null.
Uri? vmServiceUriFromLine(final String line) {
  final match = vmServiceUriPattern.firstMatch(line);
  if (match == null) return null;
  return Uri.parse(match.group(1)!);
}
