// mcp_server_dart/lib/src/cli/init_writers.dart
import 'dart:io';
import 'init_target.dart';
import 'init_mode.dart';
import 'mode_prelude.dart';
import '../skill_assets.g.dart';

class InitWriters {
  static void writeFor({
    required final InitTarget target,
    required final InitMode mode,
    required final String outputRoot,
    required final bool scopeIsUserHome,
  }) {
    if (target == InitTarget.all) {
      for (final t in [
        InitTarget.claudeCode,
        InitTarget.cursor,
        InitTarget.codex,
        InitTarget.cline,
      ]) {
        writeFor(
          target: t,
          mode: mode,
          outputRoot: outputRoot,
          scopeIsUserHome: scopeIsUserHome,
        );
      }
      return;
    }
    switch (target) {
      case InitTarget.claudeCode:
        _writeClaudeCode(outputRoot, mode);
      case InitTarget.cursor:
        _writeCursor(outputRoot, mode);
      case InitTarget.codex:
        _writeCodex(outputRoot, mode);
      case InitTarget.cline:
        _writeCline(outputRoot, mode);
      case InitTarget.agentsSkills:
        _writeAgentsSkills(outputRoot, mode);
      case InitTarget.all:
        throw StateError('handled above');
    }
  }

  static void _writeSkillFile(final String path, final SkillAsset s, final InitMode mode) {
    final dir = Directory(File(path).parent.path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final body = renderModePrelude(_reassemble(s), mode);
    File(path).writeAsStringSync(body);
  }

  static String _reassemble(final SkillAsset s) =>
      '---\n${s.frontmatter}\n---\n${s.body}';

  static void _writeClaudeCode(final String root, final InitMode mode) {
    for (final s in SkillAssets.skills) {
      final path = '$root/.claude/skills/flutter-mcp-toolkit/${s.id}/SKILL.md';
      _writeSkillFile(path, s, mode);
    }
  }

  static void _writeCursor(final String root, final InitMode mode) {
    final base = '$root/.cursor/plugins/local/flutter-mcp-toolkit';
    Directory('$base/.cursor-plugin').createSync(recursive: true);
    File('$base/.cursor-plugin/plugin.json')
        .writeAsStringSync(SkillAssets.cursorPluginManifest);
    File('$base/mcp.json').writeAsStringSync(SkillAssets.mcpServerConfig);
    for (final s in SkillAssets.skills) {
      _writeSkillFile('$base/skills/${s.id}/SKILL.md', s, mode);
    }
  }

  static void _writeCodex(final String root, final InitMode mode) {
    final base = '$root/.codex/plugins/cache/local/flutter-mcp-toolkit/local';
    Directory('$base/.codex-plugin').createSync(recursive: true);
    File('$base/.codex-plugin/plugin.json')
        .writeAsStringSync(SkillAssets.codexPluginManifest);
    File('$base/mcp.json').writeAsStringSync(SkillAssets.mcpServerConfig);
    for (final s in SkillAssets.skills) {
      _writeSkillFile('$base/skills/${s.id}/SKILL.md', s, mode);
    }
    final mpPath = '$root/.agents/plugins/marketplace.json';
    Directory(File(mpPath).parent.path).createSync(recursive: true);
    File(mpPath).writeAsStringSync(
      '{"plugins":[{"name":"flutter-mcp-toolkit","source":"$base","version":"local"}]}',
    );
  }

  static void _writeCline(final String root, final InitMode mode) {
    final dir = Directory('$root/.clinerules');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final s in SkillAssets.skills) {
      final body = renderModePrelude(_reassemble(s), mode);
      File('$root/.clinerules/${s.id}.md').writeAsStringSync(body);
    }
  }

  static void _writeAgentsSkills(final String root, final InitMode mode) {
    for (final s in SkillAssets.skills) {
      _writeSkillFile('$root/.agents/skills/${s.id}/SKILL.md', s, mode);
    }
  }
}
