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

/// The last http VM service announcement in a whole log [contents], or null
/// (later announcements win — a hot restart re-announces a fresh token).
Uri? lastVmServiceUriIn(final String contents) {
  final match = vmServiceUriPattern.allMatches(contents).lastOrNull;
  return match == null ? null : Uri.parse(match.group(1)!);
}

/// The last web (DWDS) `ws://` announcement in log [contents], or null.
Uri? lastVmServiceWsUriIn(final String contents) {
  final match = vmServiceWsUriPattern.allMatches(contents).lastOrNull;
  return match == null ? null : Uri.parse(match.group(0)!);
}

/// Converts an http VM service URI to the WebSocket form its clients dial:
/// `http://127.0.0.1:PORT/TOKEN=` → `ws://127.0.0.1:PORT/TOKEN/ws`.
Uri canonicalVmServiceWsUri(final Uri httpUri) {
  // Idempotent: an endpoint published in ws shape (`…/TOKEN/ws`, as oka's
  // forwarded contract does) must not grow a second `/ws`.
  final path = httpUri.path.endsWith('/')
      ? '${httpUri.path}ws'
      : httpUri.path.endsWith('/ws')
          ? httpUri.path
          : '${httpUri.path}/ws';
  return httpUri.replace(scheme: 'ws', path: path);
}
