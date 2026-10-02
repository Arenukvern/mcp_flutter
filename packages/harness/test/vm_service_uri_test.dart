import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

void main() {
  group('vm service URI helpers', () {
    const httpLine =
        'A Dart VM Service on macOS is available at: http://127.0.0.1:45671/abc123_=/';

    test('vmServiceUriFromLine extracts the announcement URI', () {
      final uri = vmServiceUriFromLine(httpLine);
      expect(uri, isNotNull);
      expect(uri!.host, '127.0.0.1');
      expect(uri.port, 45671);
      // The token's trailing slash is intentionally not captured.
      expect(uri.path, '/abc123_=');
    });

    test('lastVmServiceUriIn prefers the freshest announcement', () {
      final contents =
          '$httpLine\nlater noise\n'
          'A Dart VM Service on macOS is available at: '
          'http://127.0.0.1:50099/restarted_=/\n';
      expect(lastVmServiceUriIn(contents)!.port, 50099);
      expect(lastVmServiceUriIn('no announcements here'), isNull);
    });

    test('lastVmServiceWsUriIn finds the DWDS form', () {
      final contents = 'noise\n'
          'A Dart VM Service is available at: ws://127.0.0.1:8181/abc_-token/ws\n';
      final uri = lastVmServiceWsUriIn(contents);
      expect(uri, isNotNull);
      expect(uri!.port, 8181);
      expect(lastVmServiceWsUriIn('http://127.0.0.1:8181/x='), isNull);
    });

    test('canonicalVmServiceWsUri converts the http announcement', () {
      final ws = canonicalVmServiceWsUri(vmServiceUriFromLine(httpLine)!);
      expect(ws.scheme, 'ws');
      expect(ws.toString(), 'ws://127.0.0.1:45671/abc123_=/ws');
    });

    test('canonicalVmServiceWsUri keeps a path-less trailing slash sane', () {
      final ws = canonicalVmServiceWsUri(Uri.parse('http://127.0.0.1:8181/'));
      expect(ws.toString(), 'ws://127.0.0.1:8181/ws');
    });
  });
}
