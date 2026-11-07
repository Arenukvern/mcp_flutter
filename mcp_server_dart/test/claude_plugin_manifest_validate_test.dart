import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/plugin/claude_plugin_manifest_validate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final repoRoot = _findRepoRoot();
  final pluginRoot = p.join(repoRoot, 'plugin');
  final validManifestPath =
      p.join(pluginRoot, '.claude-plugin', 'plugin.json');

  group('validateClaudePluginManifest', () {
    test('current production manifest passes', () {
      final json = File(validManifestPath).readAsStringSync();
      expect(
        validateClaudePluginManifest(
          manifestJson: json,
          pluginRootPath: pluginRoot,
        ),
        isEmpty,
      );
    });

    test('rejects invalid agents directory override', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base['agents'] = './agents';
      final errors = validateClaudePluginManifest(
        manifestJson: jsonEncode(base),
        pluginRootPath: pluginRoot,
      );
      expect(errors, isNotEmpty);
      expect(errors.join(' '), contains('.md'));
    });

    test('rejects agents path without ./ prefix (repo policy)', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base['agents'] = 'agents/flutter-mcp-toolkit-runtime.md';
      final errors = validateClaudePluginManifest(
        manifestJson: jsonEncode(base),
        pluginRootPath: pluginRoot,
      );
      expect(errors.any((e) => e.contains('repository policy')), isTrue);
    });

    test('rejects absolute agents path', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base['agents'] = '/etc/passwd.md';
      final errors = validateClaudePluginManifest(
        manifestJson: jsonEncode(base),
        pluginRootPath: pluginRoot,
      );
      expect(errors.any((e) => e.contains('not absolute')), isTrue);
    });

    test('rejects agents path with parent segment', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base['agents'] = './agents/../outside.md';
      final errors = validateClaudePluginManifest(
        manifestJson: jsonEncode(base),
        pluginRootPath: pluginRoot,
      );
      expect(
        errors.any((e) => e.contains('must not contain ".." path segments')),
        isTrue,
      );
    });

    test('does not false-positive parent segment on literal dots in name', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base['agents'] = './agents/flutter-mcp-toolkit-runtime.md';
      expect(
        validateClaudePluginManifest(
          manifestJson: jsonEncode(base),
          pluginRootPath: pluginRoot,
        ),
        isEmpty,
      );
    });

    test('accepts agents pointing at an existing .md file', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base['agents'] = './agents/flutter-mcp-toolkit-runtime.md';
      expect(
        validateClaudePluginManifest(
          manifestJson: jsonEncode(base),
          pluginRootPath: pluginRoot,
        ),
        isEmpty,
      );
    });

    test('rejects agents .md path that does not exist', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base['agents'] = './agents/missing-agent.md';
      final errors = validateClaudePluginManifest(
        manifestJson: jsonEncode(base),
        pluginRootPath: pluginRoot,
      );
      expect(errors.any((e) => e.contains('does not exist')), isTrue);
    });

    test('rejects missing mcpServers (repo policy)', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base.remove('mcpServers');
      final errors = validateClaudePluginManifest(
        manifestJson: jsonEncode(base),
        pluginRootPath: pluginRoot,
      );
      expect(errors, isNotEmpty);
      expect(errors.join(' '), contains('repository policy'));
      expect(errors.join(' '), isNot(contains('agents')));
    });

    test('rejects missing mcpServers target file', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base['mcpServers'] = './missing-mcp.json';
      final errors = validateClaudePluginManifest(
        manifestJson: jsonEncode(base),
        pluginRootPath: pluginRoot,
      );
      expect(errors.any((e) => e.contains('missing-mcp.json')), isTrue);
    });

    test('rejects absolute mcpServers path', () {
      final base = jsonDecode(File(validManifestPath).readAsStringSync())
          as Map<String, dynamic>;
      base['mcpServers'] = '/tmp/mcp.json';
      final errors = validateClaudePluginManifest(
        manifestJson: jsonEncode(base),
        pluginRootPath: pluginRoot,
      );
      expect(errors.any((e) => e.contains('not absolute')), isTrue);
    });

    test('rejects malformed manifest JSON', () {
      expect(
        validateClaudePluginManifest(
          manifestJson: '{not json',
          pluginRootPath: pluginRoot,
        ),
        isNotEmpty,
      );
    });

    test('rejects malformed mcp.json referenced by mcpServers', () {
      final tmp = Directory.systemTemp.createTempSync('claude_manifest_test_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File(p.join(tmp.path, 'bad-mcp.json')).writeAsStringSync('{broken');
      final manifest = jsonEncode({
        'name': 'flutter-mcp-toolkit',
        'mcpServers': './bad-mcp.json',
      });
      final errors = validateClaudePluginManifest(
        manifestJson: manifest,
        pluginRootPath: tmp.path,
      );
      expect(errors.any((e) => e.contains('mcpServers') && e.contains('JSON')),
          isTrue);
    });
  });
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    final gitPath = p.join(dir.path, '.git');
    if (File(gitPath).existsSync() || Directory(gitPath).existsSync()) {
      return dir.path;
    }
    if (Directory(p.join(dir.path, 'plugin')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('repo root not found from ${Directory.current.path}');
}
