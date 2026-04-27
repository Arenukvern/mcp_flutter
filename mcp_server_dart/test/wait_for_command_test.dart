import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('WaitForCommand', () {
    final catalog = CommandCatalog.instance;

    test('round-trips arbitrary timeoutMs', () {
      final cmd = catalog.buildCommand('wait_for', {
        'predicate': {'kind': 'text', 'text': 'foo'},
        'timeoutMs': 12345,
      }) as WaitForCommand;
      expect(cmd.timeoutMs, 12345);
      expect(cmd.predicate['kind'], 'text');
      expect(cmd.predicate['text'], 'foo');
    });

    test('default timeoutMs is 5000 when omitted', () {
      final cmd = catalog.buildCommand('wait_for', {
        'predicate': {'kind': 'time', 'ms': 10},
      }) as WaitForCommand;
      expect(cmd.timeoutMs, 5000);
    });
  });
}
