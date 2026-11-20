// mcp_server_dart/test/cli/init_writers_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/init_mode.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_target.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_writers.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String injectedServerCommand;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('init_writers_');
    injectedServerCommand =
        '${tmp.path}/bin/flutter-mcp-toolkit-server';
    Directory('${tmp.path}/bin').createSync(recursive: true);
    InitWriters.debugResolveServerCommand = () => injectedServerCommand;
  });
  tearDown(() {
    InitWriters.debugResolveServerCommand = null;
    tmp.deleteSync(recursive: true);
  });

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

    test('zcode workspace scope writes .zcode/config.json + .agents/skills/', () {
      InitWriters.writeFor(
        target: InitTarget.zcode,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      final config = File('${tmp.path}/.zcode/config.json');
      expect(config.existsSync(), isTrue);
      final content = config.readAsStringSync();
      expect(content, contains('"mcp"'));
      expect(content, contains('"servers"'));
      expect(content, contains('flutter-mcp-toolkit-server'));
      expect(content, isNot(contains(r'${')));
      final skill = File(
        '${tmp.path}/.agents/skills/flutter-mcp-toolkit-guide/SKILL.md',
      );
      expect(skill.existsSync(), isTrue);
    });

    test('zcode user scope merges into .zcode/cli/config.json', () {
      final configPath = '${tmp.path}/.zcode/cli/config.json';
      final existing = {
        'plugins': {
          'enabledPlugins': {'other@marketplace': true},
        },
        'mcp': {
          'servers': {
            'gitnexus': {'type': 'stdio', 'command': '/bin/gitnexus'},
          },
        },
      };
      File(configPath).parent.createSync(recursive: true);
      File(configPath).writeAsStringSync(jsonEncode(existing));

      InitWriters.writeFor(
        target: InitTarget.zcode,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: true,
      );

      final doc =
          jsonDecode(File(configPath).readAsStringSync()) as Map<String, dynamic>;
      // Unrelated config and servers survive the merge.
      final servers = (doc['mcp'] as Map)['servers'] as Map;
      expect(servers.keys, containsAll(['gitnexus', 'flutter-mcp-toolkit']));
      final entry = servers['flutter-mcp-toolkit'] as Map;
      expect(entry['command'], contains('flutter-mcp-toolkit-server'));
      expect(entry['command'], startsWith('/'), reason:
          'config-file servers get no template expansion, so the command '
          'must be an absolute path when the binary is on PATH');
    });

    test('zcode init never overwrites an existing server entry', () {
      final configPath = '${tmp.path}/.zcode/cli/config.json';
      File(configPath).parent.createSync(recursive: true);
      File(configPath).writeAsStringSync(
        jsonEncode({
          'mcp': {
            'servers': {
              'flutter-mcp-toolkit': {
                'type': 'stdio',
                'command': '/custom/server',
                'args': ['--dart-vm-port=9999'],
              },
            },
          },
        }),
      );

      InitWriters.writeFor(
        target: InitTarget.zcode,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: true,
      );

      final servers =
          (((jsonDecode(File(configPath).readAsStringSync()) as Map)['mcp']
                      as Map)['servers'] as Map)['flutter-mcp-toolkit'] as Map;
      expect(servers['command'], '/custom/server');
      expect(servers['args'], ['--dart-vm-port=9999']);
    });

    test('zcode init leaves an invalid JSON config untouched', () {
      final configPath = '${tmp.path}/.zcode/config.json';
      File(configPath).parent.createSync(recursive: true);
      File(configPath).writeAsStringSync('{not valid json');

      InitWriters.writeFor(
        target: InitTarget.zcode,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );

      expect(File(configPath).readAsStringSync(), '{not valid json');
    });

    test('zcode vendors only user-facing skills (maintainer skills stay out)', () {
      InitWriters.writeFor(
        target: InitTarget.zcode,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      final skillsRoot = Directory('${tmp.path}/.agents/skills');
      final vendored = skillsRoot
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split('/').last)
          .toSet();
      expect(vendored, contains('flutter-mcp-toolkit-guide'));
      expect(
        vendored,
        isNot(contains('flutter-mcp-toolkit-repo-maintainer')),
        reason: 'repo-maintainer skills describe mcp_flutter itself',
      );
      expect(
        vendored,
        isNot(contains('flutter-mcp-boundary-audit')),
      );
      expect(
        vendored,
        isNot(contains('flutter-mcp-toolkit-dogfood-iterations')),
      );
      expect(vendored.length, lessThan(16));
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
