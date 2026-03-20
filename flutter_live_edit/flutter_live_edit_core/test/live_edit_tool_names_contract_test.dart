import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:test/test.dart';

void main() {
  group('LiveEditMcpToolNames', () {
    test('allSorted is lexicographically sorted and unique', () {
      final sorted = List<String>.from(LiveEditMcpToolNames.allSorted)..sort();
      expect(LiveEditMcpToolNames.allSorted, orderedEquals(sorted));
      expect(LiveEditMcpToolNames.allSorted.toSet().length,
          LiveEditMcpToolNames.allSorted.length);
    });

    test('every entry is the live_edit_ server namespace', () {
      for (final name in LiveEditMcpToolNames.allSorted) {
        expect(name, startsWith('live_edit_'));
        expect(name, isNot(contains('runtime')));
      }
    });
  });

  group('LiveEditRuntimeToolNames', () {
    test('runtime bridge names stay distinct from MCP server list', () {
      final mcp = LiveEditMcpToolNames.allSorted.toSet();
      expect(mcp.contains(LiveEditRuntimeToolNames.startSession), isFalse);
      expect(mcp.contains(LiveEditRuntimeToolNames.selectAtPoint), isFalse);
    });
  });
}
