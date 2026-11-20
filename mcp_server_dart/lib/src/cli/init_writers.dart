// mcp_server_dart/lib/src/cli/init_writers.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/init_mode.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_target.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/mode_prelude.dart';
import 'package:flutter_mcp_toolkit_server/src/skill_assets.g.dart';
import 'package:meta/meta.dart';

// ignore: avoid_classes_with_only_static_members
class InitWriters {
  /// Tests inject an absolute server path so zcode init stays hermetic without
  /// relying on PATH. Production leaves this null and uses [_resolveServerCommand].
  @visibleForTesting
  static String Function()? debugResolveServerCommand;

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
        InitTarget.zcode,
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
      case InitTarget.zcode:
        _writeZcode(outputRoot, mode, scopeIsUserHome);
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

  /// ZCode reads MCP servers from the nested `mcp.servers` shape: user scope
  /// `~/.zcode/cli/config.json`, workspace scope `<repo>/.zcode/config.json`.
  /// Both scopes discover skills from `.agents/skills/`. The config-file
  /// server schema is strict and `${...}` templates are not expanded there,
  /// so the server binary is resolved to an absolute path at init time
  /// (falling back to the bare name when not on PATH). Existing configs are
  /// merged, never overwritten: the `flutter-mcp-toolkit` entry is written
  /// only when absent, so user-tuned args and unrelated servers survive.
  static void _writeZcode(String root, InitMode mode, bool scopeIsUserHome) {
    final configPath = scopeIsUserHome
        ? '$root/.zcode/cli/config.json'
        : '$root/.zcode/config.json';
    _mergeZcodeServerEntry(configPath);
    _writeZcodeSkills(root, mode);
  }

  static const String _zcodeServerKey = 'flutter-mcp-toolkit';

  static void _mergeZcodeServerEntry(String configPath) {
    final file = File(configPath);
    Map<String, dynamic> doc = {};
    if (file.existsSync()) {
      dynamic decoded;
      try {
        decoded = jsonDecode(file.readAsStringSync());
      } on FormatException {
        stdout.writeln(
          'WARN: $configPath is not valid JSON — left untouched. '
          'Register the server manually under mcp.servers.$_zcodeServerKey.',
        );
        return;
      }
      if (decoded is! Map<String, dynamic>) {
        stdout.writeln(
          'WARN: $configPath top level is not a JSON object — left untouched. '
          'Register the server manually under mcp.servers.$_zcodeServerKey.',
        );
        return;
      }
      doc = decoded;
    }
    final mcp = Map<String, dynamic>.from(
      doc['mcp'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final servers = Map<String, dynamic>.from(
      mcp['servers'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    if (servers.containsKey(_zcodeServerKey)) {
      stdout.writeln(
        'MCP server "$_zcodeServerKey" already registered in $configPath '
        '(left unchanged).',
      );
      return;
    }
    servers[_zcodeServerKey] = {
      'type': 'stdio',
      'command': _resolveServerCommand(),
      'args': [
        '--dart-vm-host=localhost',
        '--dart-vm-port=8181',
        '--resources',
        '--images',
        '--dynamics',
      ],
    };
    mcp['servers'] = servers;
    doc['mcp'] = mcp;
    Directory(file.parent.path).createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync('${encoder.convert(doc)}\n');
  }

  /// Skills that help end users drive and extend their own Flutter apps.
  /// Repo-maintainer skills (boundary audit, runtime validation, dogfood
  /// iterations, showcase platform maintenance, repo maintainer) describe
  /// mcp_flutter's own development workflow and stay plugin-local — vendoring
  /// them into a user's skill store is noise.
  static const Set<String> _zcodeUserSkillIds = {
    'flutter-mcp',
    'flutter-mcp-automation-chain',
    'flutter-mcp-e2e-harness',
    'flutter-mcp-toolkit-control',
    'flutter-mcp-toolkit-custom-tools',
    'flutter-mcp-toolkit-debug',
    'flutter-mcp-toolkit-guide',
    'flutter-mcp-toolkit-inspect',
    'flutter-mcp-toolkit-intentcall-migration',
    'flutter-mcp-toolkit-setup',
  };

  static void _writeZcodeSkills(String root, InitMode mode) {
    for (final s in SkillAssets.skills) {
      if (!_zcodeUserSkillIds.contains(s.id)) continue;
      _writeSkillFile('$root/.agents/skills/${s.id}/SKILL.md', s, mode);
    }
  }

  static String _resolveServerCommand() {
    final injected = debugResolveServerCommand;
    if (injected != null) {
      return injected();
    }
    final result = Process.runSync(Platform.isWindows ? 'where' : 'which', [
      'flutter-mcp-toolkit-server',
    ]);
    if (result.exitCode == 0) {
      final first = (result.stdout as String)
          .trim()
          .split('\n')
          .first
          .trim();
      if (first.isNotEmpty) return first;
    }
    return 'flutter-mcp-toolkit-server';
  }
}
