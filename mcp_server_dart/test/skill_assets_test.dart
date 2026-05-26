// mcp_server_dart/test/skill_assets_test.dart
import 'package:flutter_mcp_toolkit_server/src/skill_assets.g.dart';
import 'package:test/test.dart';

void main() {
  group('SkillAssets', () {
    test('exposes 10 skill bodies', () {
      expect(SkillAssets.skills.length, equals(10));
    });

    test('each skill has the required fields', () {
      for (final skill in SkillAssets.skills) {
        expect(skill.id, isNotEmpty);
        expect(skill.frontmatter, isNotEmpty);
        expect(skill.body, isNotEmpty);
        expect(skill.relativePath, startsWith('skills/'));
      }
    });

    test('every skill body contains the mode prelude marker', () {
      for (final skill in SkillAssets.skills) {
        expect(
          skill.body,
          contains('<!-- @FMT_MODE_PRELUDE -->'),
          reason: 'Skill ${skill.id} missing the FMT_MODE_PRELUDE placeholder',
        );
      }
    });

    test('skill ids match the expected list', () {
      final ids = SkillAssets.skills.map((final s) => s.id).toSet();
      expect(
        ids,
        equals({
          'flutter-mcp-toolkit-guide',
          'flutter-mcp-toolkit-setup',
          'flutter-mcp-toolkit-inspect',
          'flutter-mcp-toolkit-control',
          'flutter-mcp-toolkit-debug',
          'flutter-mcp-toolkit-custom-tools',
          'flutter-mcp-toolkit-agentkit-migration',
          'flutter-mcp',
          'flutter-mcp-cli-runtime-validation',
          'flutter-mcp-toolkit-repo-maintainer',
        }),
      );
    });

    test('hyperframes-video is not in default init bundle', () {
      final ids = SkillAssets.skills.map((final s) => s.id).toSet();
      expect(ids.contains('hyperframes-video'), isFalse);
    });

    test('plugin manifests are bundled', () {
      expect(SkillAssets.cursorPluginManifest, contains('flutter-mcp-toolkit'));
      expect(SkillAssets.codexPluginManifest, contains('flutter-mcp-toolkit'));
      expect(SkillAssets.mcpServerConfig, contains('flutter-mcp-toolkit'));
    });
  });
}
