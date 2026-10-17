// mcp_server_dart/lib/src/cli/init_writers.dart
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/init_mode.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_target.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/mode_prelude.dart';
import 'package:flutter_mcp_toolkit_server/src/skill_assets.g.dart';

// ignore: avoid_classes_with_only_static_members
class InitWriters {
  static void writeFor({
    required InitTarget target,
    required InitMode mode,
    required String outputRoot,
    required bool scopeIsUserHome,
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

  static void _writeSkillFile(
    String path,
    SkillAsset s,
    InitMode mode,
  ) {
    final dir = Directory(File(path).parent.path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final body = renderModePrelude(_reassemble(s), mode);
    File(path).writeAsStringSync(body);
  }

  static String _reassemble(SkillAsset s) =>
      '---\n${s.frontmatter}\n---\n${s.body}';

  static void _writeClaudeCode(String root, InitMode mode) {
    for (final s in SkillAssets.skills) {
      final path = '$root/.claude/skills/flutter-mcp-toolkit/${s.id}/SKILL.md';
      _writeSkillFile(path, s, mode);
    }
  }

  static void _writeCursor(String root, InitMode mode) {
    final base = '$root/.cursor/plugins/local/flutter-mcp-toolkit';
    Directory('$base/.cursor-plugin').createSync(recursive: true);
    File(
      '$base/.cursor-plugin/plugin.json',
    ).writeAsStringSync(SkillAssets.cursorPluginManifest);
    File('$base/mcp.json').writeAsStringSync(SkillAssets.mcpServerConfig);
    for (final s in SkillAssets.skills) {
      _writeSkillFile('$base/skills/${s.id}/SKILL.md', s, mode);
    }
  }

  static void _writeCodex(String root, InitMode mode) {
    final base = '$root/.codex/plugins/cache/local/flutter-mcp-toolkit/local';
    Directory('$base/.codex-plugin').createSync(recursive: true);
    File(
      '$base/.codex-plugin/plugin.json',
    ).writeAsStringSync(SkillAssets.codexPluginManifest);
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

  static void _writeCline(String root, InitMode mode) {
    final dir = Directory('$root/.clinerules');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final s in SkillAssets.skills) {
      final body = renderModePrelude(_reassemble(s), mode);
      File('$root/.clinerules/${s.id}.md').writeAsStringSync(body);
    }
  }

  static void _writeAgentsSkills(String root, InitMode mode) {
    for (final s in SkillAssets.skills) {
      _writeSkillFile('$root/.agents/skills/${s.id}/SKILL.md', s, mode);
    }
  }
}
