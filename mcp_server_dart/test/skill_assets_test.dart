// mcp_server_dart/test/skill_assets_test.dart
import 'package:test/test.dart';
import 'package:flutter_inspector_mcp_server/src/skill_assets.g.dart';

void main() {
  group('SkillAssets', () {
    test('exposes 5 skill bodies', () {
      expect(SkillAssets.skills.length, equals(5));
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
      final ids = SkillAssets.skills.map((s) => s.id).toSet();
      expect(ids, equals({
        'flutter-mcp-toolkit-guide',
        'flutter-mcp-toolkit-setup',
        'flutter-mcp-toolkit-inspect',
        'flutter-mcp-toolkit-control',
        'flutter-mcp-toolkit-debug',
      }));
    });

    test('plugin manifests are bundled', () {
      expect(SkillAssets.cursorPluginManifest, contains('flutter-mcp-toolkit'));
      expect(SkillAssets.codexPluginManifest, contains('flutter-mcp-toolkit'));
      expect(SkillAssets.mcpServerConfig, contains('flutter-mcp-toolkit'));
    });
  });
}
