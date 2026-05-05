// mcp_server_dart/test/cli/init_command_test.dart
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/init_command.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_mode.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_target.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('init_cmd_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('explicit target + mode writes the right files', () async {
    final exitCode = await runInit(
      target: InitTarget.claudeCode,
      modeOverride: InitMode.mcp,
      outputRoot: tmp.path,
      scopeIsUserHome: false,
    );
    expect(exitCode, 0);
    final f = File(
      '${tmp.path}/.claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide/SKILL.md',
    );
    expect(f.existsSync(), isTrue);
    final c = f.readAsStringSync();
    expect(c, contains('fmt_'));
    expect(c, isNot(contains('<!-- @FMT_MODE_PRELUDE -->')));
  });

  test('init all writes for every target', () async {
    final exitCode = await runInit(
      target: InitTarget.all,
      modeOverride: InitMode.cli,
      outputRoot: tmp.path,
      scopeIsUserHome: false,
    );
    expect(exitCode, 0);
    expect(
      File(
        '${tmp.path}/.claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide/SKILL.md',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${tmp.path}/.cursor/plugins/local/flutter-mcp-toolkit/.cursor-plugin/plugin.json',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${tmp.path}/.codex/plugins/cache/local/flutter-mcp-toolkit/local/.codex-plugin/plugin.json',
      ).existsSync(),
      isTrue,
    );
    expect(
      File('${tmp.path}/.clinerules/flutter-mcp-toolkit-guide.md').existsSync(),
      isTrue,
    );
  });
}
