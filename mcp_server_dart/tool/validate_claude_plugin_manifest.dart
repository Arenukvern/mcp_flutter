// Validates plugin/.claude-plugin/plugin.json for targeted Claude Code rules.

import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/plugin/claude_plugin_manifest_validate.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final root = args.isNotEmpty ? args.first : _findRepoRoot();
  final pluginRoot = p.join(root, 'plugin');
  final manifestFile =
      File(p.join(pluginRoot, '.claude-plugin', 'plugin.json'));
  if (!manifestFile.existsSync()) {
    stderr.writeln('Missing ${manifestFile.path}');
    exit(1);
  }

  final errors = validateClaudePluginManifest(
    manifestJson: manifestFile.readAsStringSync(),
    pluginRootPath: pluginRoot,
  );
  if (errors.isEmpty) {
    stdout.writeln('Claude plugin manifest validation passed.');
    exit(0);
  }
  for (final error in errors) {
    stderr.writeln('claude-plugin-manifest: $error');
  }
  exit(1);
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    final gitPath = p.join(dir.path, '.git');
    if (File(gitPath).existsSync() || Directory(gitPath).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('Not in a git repo');
}
