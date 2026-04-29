import 'package:flutter_inspector_mcp_server/src/cli/init_mode.dart';
import 'package:test/test.dart';

void main() {
  group('InitMode.parse', () {
    test('parses mcp/cli/auto', () {
      expect(InitMode.parse('mcp'), InitMode.mcp);
      expect(InitMode.parse('cli'), InitMode.cli);
      expect(InitMode.parse('auto'), InitMode.auto);
    });

    test('default is auto', () {
      expect(InitMode.parse(null), InitMode.auto);
    });

    test('rejects junk', () {
      expect(() => InitMode.parse('mqp'), throwsArgumentError);
    });
  });
}
