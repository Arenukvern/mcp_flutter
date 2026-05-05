import 'package:flutter_mcp_toolkit_server/src/cli/init_mode.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/mode_prelude.dart';
import 'package:test/test.dart';

const _bodyTemplate = '''
---
name: x
description: y
---

<!-- @FMT_MODE_PRELUDE -->

## Body
''';

void main() {
  group('renderModePrelude', () {
    test('substitutes the marker for MCP mode', () {
      final out = renderModePrelude(_bodyTemplate, InitMode.mcp);
      expect(out, isNot(contains('<!-- @FMT_MODE_PRELUDE -->')));
      expect(out, contains('MCP tools'));
      expect(out, contains('fmt_'));
    });

    test('substitutes the marker for CLI mode', () {
      final out = renderModePrelude(_bodyTemplate, InitMode.cli);
      expect(out, isNot(contains('<!-- @FMT_MODE_PRELUDE -->')));
      expect(out, contains('flutter-mcp-toolkit exec'));
      expect(out, contains('--name'));
    });

    test('throws if marker is absent', () {
      expect(
        () => renderModePrelude('---\nname: x\n---\n## Body', InitMode.mcp),
        throwsStateError,
      );
    });

    test('throws on InitMode.auto (must be resolved before render)', () {
      expect(
        () => renderModePrelude(_bodyTemplate, InitMode.auto),
        throwsArgumentError,
      );
    });
  });
}
