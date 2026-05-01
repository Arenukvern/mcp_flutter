// mcp_server_dart/test/cli/init_writers_test.dart
import 'dart:io';

import 'package:flutter_inspector_mcp_server/src/cli/init_mode.dart';
import 'package:flutter_inspector_mcp_server/src/cli/init_target.dart';
import 'package:flutter_inspector_mcp_server/src/cli/init_writers.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('init_writers_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('InitWriters', () {
    test(
      'Claude Code writes skills under .claude/skills/flutter-mcp-toolkit/',
      () {
        InitWriters.writeFor(
          target: InitTarget.claudeCode,
          mode: InitMode.mcp,
          outputRoot: tmp.path,
          scopeIsUserHome: false,
        );
        final f = File(
          '${tmp.path}/.claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide/SKILL.md',
        );
        expect(f.existsSync(), isTrue);
        final content = f.readAsStringSync();
        expect(content, contains('name: flutter-mcp-toolkit-guide'));
        expect(content, isNot(contains('<!-- @FMT_MODE_PRELUDE -->')));
        expect(content, contains('fmt_'));
      },
    );

    test('Cursor writes the whole plugin dir under .cursor/plugins/local/', () {
      InitWriters.writeFor(
        target: InitTarget.cursor,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      final manifest = File(
        '${tmp.path}/.cursor/plugins/local/flutter-mcp-toolkit/.cursor-plugin/plugin.json',
      );
      expect(manifest.existsSync(), isTrue);
      final skill = File(
        '${tmp.path}/.cursor/plugins/local/flutter-mcp-toolkit/skills/flutter-mcp-toolkit-guide/SKILL.md',
      );
      expect(skill.existsSync(), isTrue);
    });

    test('Codex writes plugin dir + marketplace registration', () {
      InitWriters.writeFor(
        target: InitTarget.codex,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      final manifest = File(
        '${tmp.path}/.codex/plugins/cache/local/flutter-mcp-toolkit/local/.codex-plugin/plugin.json',
      );
      expect(manifest.existsSync(), isTrue);
      final mp = File('${tmp.path}/.agents/plugins/marketplace.json');
      expect(mp.existsSync(), isTrue);
      expect(mp.readAsStringSync(), contains('flutter-mcp-toolkit'));
    });

    test('Cline writes flat-file rules', () {
      InitWriters.writeFor(
        target: InitTarget.cline,
        mode: InitMode.cli,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      final f = File('${tmp.path}/.clinerules/flutter-mcp-toolkit-guide.md');
      expect(f.existsSync(), isTrue);
      expect(f.readAsStringSync(), contains('flutter-mcp-toolkit exec'));
    });

    test('agents-skills writes to .agents/skills/', () {
      InitWriters.writeFor(
        target: InitTarget.agentsSkills,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      final f = File(
        '${tmp.path}/.agents/skills/flutter-mcp-toolkit-guide/SKILL.md',
      );
      expect(f.existsSync(), isTrue);
    });

    test('writes are idempotent (re-running is safe)', () {
      InitWriters.writeFor(
        target: InitTarget.claudeCode,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      InitWriters.writeFor(
        target: InitTarget.claudeCode,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      // No exception, file still readable.
      final f = File(
        '${tmp.path}/.claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide/SKILL.md',
      );
      expect(f.existsSync(), isTrue);
    });
  });
}
