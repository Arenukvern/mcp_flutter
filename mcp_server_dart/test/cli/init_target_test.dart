import 'package:flutter_inspector_mcp_server/src/cli/init_target.dart';
import 'package:test/test.dart';

void main() {
  group('InitTarget.parse', () {
    test('accepts canonical names', () {
      expect(InitTarget.parse('claude-code'), InitTarget.claudeCode);
      expect(InitTarget.parse('cursor'), InitTarget.cursor);
      expect(InitTarget.parse('codex'), InitTarget.codex);
      expect(InitTarget.parse('cline'), InitTarget.cline);
      expect(InitTarget.parse('agents-skills'), InitTarget.agentsSkills);
      expect(InitTarget.parse('all'), InitTarget.all);
    });
    test('rejects unknown', () {
      expect(() => InitTarget.parse('vim'), throwsArgumentError);
    });
    test('canonical names round-trip', () {
      for (final t in InitTarget.values) {
        expect(InitTarget.parse(t.canonicalName), t);
      }
    });
  });
}
