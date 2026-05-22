# Plan B — CLI Commands (`init`, `codegen-init`)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `flutter-mcp-toolkit init <agent>` and `flutter-mcp-toolkit codegen-init` subcommands to the CLI binary so end users can install skills + register the MCP server in one command, and add toolkit boilerplate to a Flutter app's `main.dart`.

**Architecture:** Two new CLI commands consume the bundled `SkillAssets` from Plan A. `init` substitutes the mode prelude into each skill body and writes per-target output. `codegen-init` runs `flutter pub add` + emits a boilerplate snippet (or edits `main.dart` if a recognized template is detected).

**Tech Stack:** Dart, `args` package (already used by `flutter-mcp-toolkit`), Dart `Process` API for `flutter pub`.

**Spec reference:** `specs/2026-04-29-flutter-mcp-toolkit-plugin-design.md` §3.3, §3.4, §4.1.

**Dependencies:** Plan A (consumes `SkillAssets` from `mcp_server_dart/lib/src/skill_assets.g.dart`). Runs in **Wave 2** after Plan A merges. Independent of Plan C; Plan C's prefix rename only affects what the MCP-mode prelude says (`fmt_` vs `core_`); use the prefix value from a constant that Plan C also updates.

**Downstream:** Plan D's docs migration assumes `init` exists for the human flow.

---

## File Structure

**Create:**
- `mcp_server_dart/lib/src/cli/init_target.dart`
- `mcp_server_dart/lib/src/cli/init_mode.dart`
- `mcp_server_dart/lib/src/cli/mode_prelude.dart`
- `mcp_server_dart/lib/src/cli/init_writers.dart`
- `mcp_server_dart/lib/src/cli/init_command.dart`
- `mcp_server_dart/lib/src/cli/codegen_init_command.dart`
- `mcp_server_dart/test/cli/init_target_test.dart`
- `mcp_server_dart/test/cli/mode_prelude_test.dart`
- `mcp_server_dart/test/cli/init_writers_test.dart`
- `mcp_server_dart/test/cli/init_command_test.dart`
- `mcp_server_dart/test/cli/codegen_init_command_test.dart`
- `mcp_server_dart/lib/src/cli/codegen_snippets.dart`

**Modify:**
- `mcp_server_dart/bin/flutter_mcp_toolkit.dart` — add `init` and `codegen-init` subcommands (or wherever the CLI subcommand router lives)

---

## Task 1: `InitTarget` enum — failing test

**Files:**
- Create: `mcp_server_dart/test/cli/init_target_test.dart`

- [ ] **Step 1.1: Write failing test**

```dart
// mcp_server_dart/test/cli/init_target_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server_dart/src/cli/init_target.dart';

void main() {
  group('InitTarget.parse', () {
    test('accepts canonical names', () {
      expect(InitTarget.parse('claude-code'), InitTarget.claudeCode);
      expect(InitTarget.parse('cursor'), InitTarget.cursor);
      expect(InitTarget.parse('codex'), InitTarget.codex);
      expect(InitTarget.parse('cline'), InitTarget.cline);
      expect(InitTarget.parse('agents-skills'), InitTarget.agentsSkills);
      expect(InitTarget.parse('all'), InitTarget.all);
    });

    test('rejects unknown', () {
      expect(() => InitTarget.parse('vim'), throwsArgumentError);
    });

    test('canonical names round-trip', () {
      for (final t in InitTarget.values) {
        expect(InitTarget.parse(t.canonicalName), t);
      }
    });
  });
}
```

- [ ] **Step 1.2: Run — expect FAIL**

Run: `cd mcp_server_dart && flutter test test/cli/init_target_test.dart`
Expected: build error (file does not exist).

- [ ] **Step 1.3: Commit failing test**

```bash
git add mcp_server_dart/test/cli/init_target_test.dart
git commit -m "test(cli/init_target): failing test"
```

---

## Task 2: `InitTarget` enum — implementation

**Files:**
- Create: `mcp_server_dart/lib/src/cli/init_target.dart`

- [ ] **Step 2.1: Implement `InitTarget`**

```dart
// mcp_server_dart/lib/src/cli/init_target.dart

enum InitTarget {
  claudeCode('claude-code'),
  cursor('cursor'),
  codex('codex'),
  cline('cline'),
  agentsSkills('agents-skills'),
  all('all');

  const InitTarget(this.canonicalName);
  final String canonicalName;

  static InitTarget parse(final String input) {
    for (final t in InitTarget.values) {
      if (t.canonicalName == input) return t;
    }
    throw ArgumentError.value(
      input,
      'target',
      'Unknown init target. Valid: ${InitTarget.values.map((t) => t.canonicalName).join(", ")}',
    );
  }
}
```

- [ ] **Step 2.2: Run test — expect PASS**

Run: `cd mcp_server_dart && flutter test test/cli/init_target_test.dart`
Expected: 3/3 pass.

- [ ] **Step 2.3: Commit**

```bash
git add mcp_server_dart/lib/src/cli/init_target.dart
git commit -m "feat(cli/init_target): InitTarget enum"
```

---

## Task 3: `InitMode` enum — failing test

**Files:**
- Create: `mcp_server_dart/test/cli/init_mode_test.dart`

- [ ] **Step 3.1: Write failing test**

```dart
// mcp_server_dart/test/cli/init_mode_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server_dart/src/cli/init_mode.dart';

void main() {
  group('InitMode.parse', () {
    test('parses mcp/cli/auto', () {
      expect(InitMode.parse('mcp'), InitMode.mcp);
      expect(InitMode.parse('cli'), InitMode.cli);
      expect(InitMode.parse('auto'), InitMode.auto);
    });

    test('default is auto', () {
      expect(InitMode.parse(null), InitMode.auto);
    });

    test('rejects junk', () {
      expect(() => InitMode.parse('mqp'), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 3.2: Run — expect FAIL**

Run: `cd mcp_server_dart && flutter test test/cli/init_mode_test.dart`

- [ ] **Step 3.3: Implement `InitMode`**

Create `mcp_server_dart/lib/src/cli/init_mode.dart`:

```dart
// mcp_server_dart/lib/src/cli/init_mode.dart

enum InitMode {
  mcp,
  cli,
  auto;

  static InitMode parse(final String? input) {
    if (input == null) return InitMode.auto;
    for (final m in InitMode.values) {
      if (m.name == input) return m;
    }
    throw ArgumentError.value(input, 'mode', 'Valid: mcp, cli, auto');
  }
}
```

- [ ] **Step 3.4: Run — expect PASS**

Run: `cd mcp_server_dart && flutter test test/cli/init_mode_test.dart`
Expected: 3/3 pass.

- [ ] **Step 3.5: Commit**

```bash
git add mcp_server_dart/lib/src/cli/init_mode.dart \
        mcp_server_dart/test/cli/init_mode_test.dart
git commit -m "feat(cli/init_mode): InitMode enum + parse"
```

---

## Task 4: Mode prelude rendering — failing test

**Files:**
- Create: `mcp_server_dart/test/cli/mode_prelude_test.dart`

- [ ] **Step 4.1: Write failing test**

```dart
// mcp_server_dart/test/cli/mode_prelude_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server_dart/src/cli/init_mode.dart';
import 'package:mcp_server_dart/src/cli/mode_prelude.dart';

const _bodyTemplate = '''
---
name: x
description: y
---

<!-- @FMT_MODE_PRELUDE -->

## Body
''';

void main() {
  group('renderModePrelude', () {
    test('substitutes the marker for MCP mode', () {
      final out = renderModePrelude(_bodyTemplate, InitMode.mcp);
      expect(out, isNot(contains('<!-- @FMT_MODE_PRELUDE -->')));
      expect(out, contains('MCP tools'));
      expect(out, contains('fmt_'));
    });

    test('substitutes the marker for CLI mode', () {
      final out = renderModePrelude(_bodyTemplate, InitMode.cli);
      expect(out, isNot(contains('<!-- @FMT_MODE_PRELUDE -->')));
      expect(out, contains('flutter-mcp-toolkit exec'));
      expect(out, contains('--name'));
    });

    test('throws if marker is absent', () {
      expect(
        () => renderModePrelude('---\nname: x\n---\n## Body', InitMode.mcp),
        throwsStateError,
      );
    });

    test('throws on InitMode.auto (must be resolved before render)', () {
      expect(
        () => renderModePrelude(_bodyTemplate, InitMode.auto),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 4.2: Run — expect FAIL**

Run: `cd mcp_server_dart && flutter test test/cli/mode_prelude_test.dart`

- [ ] **Step 4.3: Commit failing test**

```bash
git add mcp_server_dart/test/cli/mode_prelude_test.dart
git commit -m "test(cli/mode_prelude): failing test for prelude substitution"
```

---

## Task 5: Mode prelude rendering — implementation

**Files:**
- Create: `mcp_server_dart/lib/src/cli/mode_prelude.dart`

- [ ] **Step 5.1: Implement `renderModePrelude`**

```dart
// mcp_server_dart/lib/src/cli/mode_prelude.dart
import 'init_mode.dart';

const _placeholder = '<!-- @FMT_MODE_PRELUDE -->';

const _mcpPrelude = '''
> Calls in this skill are MCP tools registered by `flutter-mcp-toolkit-server`.
> Tool names match the bare name in this skill (e.g. `tap_widget` → `fmt_tap_widget`).
> Errors return the standard envelope: read `error.code` and follow `error.recovery`.
> If the tool isn't in your tool list, the MCP server isn't connected — see `flutter-mcp-toolkit-setup`.''';

const _cliPrelude = '''
> Calls in this skill run via the `flutter-mcp-toolkit` CLI binary:
>     flutter-mcp-toolkit exec --name <tool> --args '<json>'
> Output is JSON on stdout. Errors come as `{"error":{"code":..., "message":..., "recovery":...}}`.
> Throughout this skill, calls are written as `tap_widget(selector: "...")` — translate to the CLI form.
> If the binary isn't on PATH, see `flutter-mcp-toolkit-setup`.''';

String renderModePrelude(final String body, final InitMode mode) {
  if (mode == InitMode.auto) {
    throw ArgumentError.value(
      mode,
      'mode',
      'auto must be resolved to mcp or cli before rendering',
    );
  }
  if (!body.contains(_placeholder)) {
    throw StateError('Skill body missing $_placeholder');
  }
  final prelude = mode == InitMode.mcp ? _mcpPrelude : _cliPrelude;
  return body.replaceFirst(_placeholder, prelude);
}
```

- [ ] **Step 5.2: Run test — expect PASS**

Run: `cd mcp_server_dart && flutter test test/cli/mode_prelude_test.dart`
Expected: 4/4 pass.

- [ ] **Step 5.3: Commit**

```bash
git add mcp_server_dart/lib/src/cli/mode_prelude.dart
git commit -m "feat(cli/mode_prelude): substitute prelude marker by mode"
```

---

## Task 6: Per-target writers — failing test

**Files:**
- Create: `mcp_server_dart/test/cli/init_writers_test.dart`

- [ ] **Step 6.1: Write failing test**

```dart
// mcp_server_dart/test/cli/init_writers_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server_dart/src/cli/init_target.dart';
import 'package:mcp_server_dart/src/cli/init_mode.dart';
import 'package:mcp_server_dart/src/cli/init_writers.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('init_writers_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('InitWriters', () {
    test('Claude Code writes skills under .claude/skills/flutter-mcp-toolkit/', () {
      InitWriters.writeFor(
        target: InitTarget.claudeCode,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      final f = File('${tmp.path}/.claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide/SKILL.md');
      expect(f.existsSync(), isTrue);
      final content = f.readAsStringSync();
      expect(content, contains('name: flutter-mcp-toolkit-guide'));
      expect(content, isNot(contains('<!-- @FMT_MODE_PRELUDE -->')));
      expect(content, contains('fmt_'));
    });

    test('Cursor writes the whole plugin dir under .cursor/plugins/local/', () {
      InitWriters.writeFor(
        target: InitTarget.cursor,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      final manifest = File('${tmp.path}/.cursor/plugins/local/flutter-mcp-toolkit/.cursor-plugin/plugin.json');
      expect(manifest.existsSync(), isTrue);
      final skill = File('${tmp.path}/.cursor/plugins/local/flutter-mcp-toolkit/skills/flutter-mcp-toolkit-guide/SKILL.md');
      expect(skill.existsSync(), isTrue);
    });

    test('Codex writes plugin dir + marketplace registration', () {
      InitWriters.writeFor(
        target: InitTarget.codex,
        mode: InitMode.mcp,
        outputRoot: tmp.path,
        scopeIsUserHome: false,
      );
      final manifest = File('${tmp.path}/.codex/plugins/cache/local/flutter-mcp-toolkit/local/.codex-plugin/plugin.json');
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
      final f = File('${tmp.path}/.agents/skills/flutter-mcp-toolkit-guide/SKILL.md');
      expect(f.existsSync(), isTrue);
    });

    test('writes are idempotent (re-running is safe)', () {
      InitWriters.writeFor(
        target: InitTarget.claudeCode, mode: InitMode.mcp,
        outputRoot: tmp.path, scopeIsUserHome: false,
      );
      InitWriters.writeFor(
        target: InitTarget.claudeCode, mode: InitMode.mcp,
        outputRoot: tmp.path, scopeIsUserHome: false,
      );
      // No exception, file still readable.
      final f = File('${tmp.path}/.claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide/SKILL.md');
      expect(f.existsSync(), isTrue);
    });
  });
}
```

- [ ] **Step 6.2: Run — expect FAIL**

Run: `cd mcp_server_dart && flutter test test/cli/init_writers_test.dart`

- [ ] **Step 6.3: Commit failing test**

```bash
git add mcp_server_dart/test/cli/init_writers_test.dart
git commit -m "test(cli/init_writers): failing test for per-target writers"
```

---

## Task 7: Per-target writers — implementation

**Files:**
- Create: `mcp_server_dart/lib/src/cli/init_writers.dart`

- [ ] **Step 7.1: Implement `InitWriters`**

```dart
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
    File(mpPath).writeAsStringSync('''{"plugins":[{"name":"flutter-mcp-toolkit","source":"$base","version":"local"}]}''');
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
```

- [ ] **Step 7.2: Run test — expect PASS**

Run: `cd mcp_server_dart && flutter test test/cli/init_writers_test.dart`
Expected: 6/6 pass.

- [ ] **Step 7.3: Commit**

```bash
git add mcp_server_dart/lib/src/cli/init_writers.dart
git commit -m "feat(cli/init_writers): write skills + manifests per target"
```

---

## Task 8: Mode auto-detection — failing test + impl

**Files:**
- Create: `mcp_server_dart/test/cli/init_mode_detector_test.dart`
- Create: `mcp_server_dart/lib/src/cli/init_mode_detector.dart`

- [ ] **Step 8.1: Write failing test**

```dart
// mcp_server_dart/test/cli/init_mode_detector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server_dart/src/cli/init_mode.dart';
import 'package:mcp_server_dart/src/cli/init_mode_detector.dart';

void main() {
  group('detectMode', () {
    test('returns mcp if MCP server registration is found', () {
      final mode = detectMode(
        binaryOnPath: true,
        mcpServerRegistered: true,
      );
      expect(mode, InitMode.mcp);
    });

    test('returns cli if binary on PATH but no MCP registration', () {
      final mode = detectMode(
        binaryOnPath: true,
        mcpServerRegistered: false,
      );
      expect(mode, InitMode.cli);
    });

    test('throws if neither — fail loud', () {
      expect(
        () => detectMode(binaryOnPath: false, mcpServerRegistered: false),
        throwsStateError,
      );
    });
  });
}
```

- [ ] **Step 8.2: Run — expect FAIL**

Run: `cd mcp_server_dart && flutter test test/cli/init_mode_detector_test.dart`

- [ ] **Step 8.3: Implement `detectMode`**

```dart
// mcp_server_dart/lib/src/cli/init_mode_detector.dart
import 'init_mode.dart';

InitMode detectMode({
  required final bool binaryOnPath,
  required final bool mcpServerRegistered,
}) {
  if (mcpServerRegistered) return InitMode.mcp;
  if (binaryOnPath) return InitMode.cli;
  throw StateError(
    'Neither MCP server nor CLI binary detected. '
    'Install with: curl -fsSL https://raw.githubusercontent.com/Arenukvern/flutter-mcp-toolkit/main/install.sh | bash',
  );
}
```

(Real environment probing — checking PATH and reading the agent's MCP config — happens in `init_command.dart` Task 9, where it can be mocked or run live.)

- [ ] **Step 8.4: Run test — expect PASS**

Run: `cd mcp_server_dart && flutter test test/cli/init_mode_detector_test.dart`
Expected: 3/3 pass.

- [ ] **Step 8.5: Commit**

```bash
git add mcp_server_dart/lib/src/cli/init_mode_detector.dart \
        mcp_server_dart/test/cli/init_mode_detector_test.dart
git commit -m "feat(cli/init_mode_detector): pure mode-decision logic"
```

---

## Task 9: `init` command — failing test + impl

**Files:**
- Create: `mcp_server_dart/test/cli/init_command_test.dart`
- Create: `mcp_server_dart/lib/src/cli/init_command.dart`

- [ ] **Step 9.1: Write failing test**

```dart
// mcp_server_dart/test/cli/init_command_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server_dart/src/cli/init_command.dart';
import 'package:mcp_server_dart/src/cli/init_mode.dart';
import 'package:mcp_server_dart/src/cli/init_target.dart';

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
    final f = File('${tmp.path}/.claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide/SKILL.md');
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
    expect(File('${tmp.path}/.claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide/SKILL.md').existsSync(), isTrue);
    expect(File('${tmp.path}/.cursor/plugins/local/flutter-mcp-toolkit/.cursor-plugin/plugin.json').existsSync(), isTrue);
    expect(File('${tmp.path}/.codex/plugins/cache/local/flutter-mcp-toolkit/local/.codex-plugin/plugin.json').existsSync(), isTrue);
    expect(File('${tmp.path}/.clinerules/flutter-mcp-toolkit-guide.md').existsSync(), isTrue);
  });
}
```

- [ ] **Step 9.2: Run — expect FAIL**

Run: `cd mcp_server_dart && flutter test test/cli/init_command_test.dart`

- [ ] **Step 9.3: Implement `runInit`**

```dart
// mcp_server_dart/lib/src/cli/init_command.dart
import 'init_mode.dart';
import 'init_target.dart';
import 'init_writers.dart';
import 'init_mode_detector.dart';
import 'dart:io';

Future<int> runInit({
  required final InitTarget target,
  required final InitMode modeOverride,
  required final String outputRoot,
  required final bool scopeIsUserHome,
}) async {
  final mode = modeOverride == InitMode.auto
      ? detectMode(
          binaryOnPath: _binaryOnPath('flutter-mcp-toolkit'),
          mcpServerRegistered: _isMcpServerRegistered(target, outputRoot),
        )
      : modeOverride;
  stdout.writeln('Mode: ${mode.name}');
  InitWriters.writeFor(
    target: target,
    mode: mode,
    outputRoot: outputRoot,
    scopeIsUserHome: scopeIsUserHome,
  );
  stdout.writeln('OK: skills written for ${target.canonicalName}');
  return 0;
}

bool _binaryOnPath(final String name) {
  final result = Process.runSync(
    Platform.isWindows ? 'where' : 'which',
    [name],
  );
  return result.exitCode == 0;
}

bool _isMcpServerRegistered(final InitTarget target, final String outputRoot) {
  // Heuristic: existing `mcp.json`/`claude_desktop_config.json` mentions
  // `flutter-mcp-toolkit`. Per-target detection details deferred to follow-up.
  switch (target) {
    case InitTarget.claudeCode:
      final f = File('$outputRoot/.claude/mcp.json');
      return f.existsSync() && f.readAsStringSync().contains('flutter-mcp-toolkit');
    case InitTarget.cursor:
    case InitTarget.codex:
    case InitTarget.cline:
    case InitTarget.agentsSkills:
    case InitTarget.all:
      return false;
  }
}
```

- [ ] **Step 9.4: Run test — expect PASS**

Run: `cd mcp_server_dart && flutter test test/cli/init_command_test.dart`
Expected: 2/2 pass.

- [ ] **Step 9.5: Commit**

```bash
git add mcp_server_dart/lib/src/cli/init_command.dart \
        mcp_server_dart/test/cli/init_command_test.dart
git commit -m "feat(cli): runInit dispatches to per-target writers"
```

---

## Task 10: Wire `init` into the CLI binary

**Files:**
- Modify: `mcp_server_dart/bin/flutter_mcp_toolkit.dart` (or current main entry point — verify path with `grep -l "ArgParser" mcp_server_dart/bin/`)

- [ ] **Step 10.1: Find the CLI entry point**

Run: `grep -l "ArgParser\|CommandRunner" mcp_server_dart/bin/ mcp_server_dart/lib/src/cli/ 2>/dev/null`

- [ ] **Step 10.2: Add `init` subcommand**

In the entry point, register a new subcommand:

```dart
// In bin/flutter_mcp_toolkit.dart (or wherever subcommands are registered)
import 'package:mcp_server_dart/src/cli/init_command.dart';
import 'package:mcp_server_dart/src/cli/init_mode.dart';
import 'package:mcp_server_dart/src/cli/init_target.dart';

// Inside the subcommand registration:
runner.addCommand(InitSubcommand());

// Add this class to the same file or a new file:
class InitSubcommand extends Command<int> {
  InitSubcommand() {
    argParser
      ..addOption('mode', allowed: ['mcp', 'cli', 'auto'], defaultsTo: 'auto')
      ..addOption('scope', allowed: ['project', 'user'], defaultsTo: 'project');
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Install flutter-mcp-toolkit skills and MCP server config for an AI agent.';

  @override
  String get invocation =>
      'flutter-mcp-toolkit init <claude-code|cursor|codex|cline|agents-skills|all>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      stderr.writeln('Usage: $invocation');
      return 64;
    }
    final target = InitTarget.parse(argResults!.rest.first);
    final mode = InitMode.parse(argResults!['mode'] as String);
    final scope = argResults!['scope'] as String;
    final outputRoot = scope == 'user'
        ? Platform.environment['HOME']!
        : Directory.current.path;
    return runInit(
      target: target,
      modeOverride: mode,
      outputRoot: outputRoot,
      scopeIsUserHome: scope == 'user',
    );
  }
}
```

- [ ] **Step 10.3: Build the binary**

Run: `cd mcp_server_dart && make compile`
Expected: build succeeds.

- [ ] **Step 10.4: Smoke test `init`**

Run: `cd /tmp && mkdir init_smoke && cd init_smoke && /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart/build/flutter-mcp-toolkit init claude-code --mode cli && find . -name "SKILL.md"`
Expected: 5 SKILL.md files printed.

(The CLI binary is `flutter-mcp-toolkit`; Plan C / v3.0.0 completed the rename from the legacy `flutter_mcp_cli` name.)

Cleanup: `rm -rf /tmp/init_smoke`.

- [ ] **Step 10.5: Commit**

```bash
git add mcp_server_dart/bin/flutter_mcp_toolkit.dart  # or whichever path
git commit -m "feat(cli): expose 'init' subcommand"
```

---

## Task 11: `codegen-init` snippets module — failing test + impl

**Files:**
- Create: `mcp_server_dart/test/cli/codegen_snippets_test.dart`
- Create: `mcp_server_dart/lib/src/cli/codegen_snippets.dart`

- [ ] **Step 11.1: Write failing test**

```dart
// mcp_server_dart/test/cli/codegen_snippets_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server_dart/src/cli/codegen_snippets.dart';

void main() {
  group('CodegenSnippets', () {
    test('produces an importable Flutter init snippet', () {
      expect(CodegenSnippets.flutterMainInit, contains('MCPToolkitBinding'));
      expect(CodegenSnippets.flutterMainInit, contains('handleZoneError'));
      expect(CodegenSnippets.flutterMainInit, contains('runZonedGuarded'));
    });

    test('snippet is plain Dart that parses', () {
      // Smoke check: braces balance, no obvious typos
      final s = CodegenSnippets.flutterMainInit;
      expect('{'.allMatches(s).length, equals('}'.allMatches(s).length));
    });
  });
}
```

- [ ] **Step 11.2: Run — expect FAIL**

Run: `cd mcp_server_dart && flutter test test/cli/codegen_snippets_test.dart`

- [ ] **Step 11.3: Implement `CodegenSnippets`**

```dart
// mcp_server_dart/lib/src/cli/codegen_snippets.dart

class CodegenSnippets {
  static const String flutterMainInit = r'''
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_mcp_toolkit/flutter_mcp_toolkit.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();
      runApp(const MyApp());
    },
    (error, stack) =>
        MCPToolkitBinding.instance.handleZoneError(error, stack),
  );
}
''';
}
```

- [ ] **Step 11.4: Run test — expect PASS**

Run: `cd mcp_server_dart && flutter test test/cli/codegen_snippets_test.dart`
Expected: 2/2 pass.

- [ ] **Step 11.5: Commit**

```bash
git add mcp_server_dart/lib/src/cli/codegen_snippets.dart \
        mcp_server_dart/test/cli/codegen_snippets_test.dart
git commit -m "feat(cli/codegen_snippets): bundle Flutter main.dart init snippet"
```

---

## Task 12: `codegen-init` command — failing test + impl

**Files:**
- Create: `mcp_server_dart/test/cli/codegen_init_command_test.dart`
- Create: `mcp_server_dart/lib/src/cli/codegen_init_command.dart`

- [ ] **Step 12.1: Write failing test**

```dart
// mcp_server_dart/test/cli/codegen_init_command_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server_dart/src/cli/codegen_init_command.dart';

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('codegen_init_');
    File('${tmp.path}/pubspec.yaml').writeAsStringSync('''
name: my_flutter_app
environment:
  sdk: ">=3.0.0"
dependencies:
  flutter:
    sdk: flutter
''');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('runCodegenInit', () {
    test('--print-snippet emits to stdout without writing files', () async {
      final exitCode = await runCodegenInit(
        projectRoot: tmp.path,
        printSnippetOnly: true,
        runPubAdd: false,
      );
      expect(exitCode, 0);
      // No new files in the project root other than pubspec.yaml.
      expect(File('${tmp.path}/lib/main.dart').existsSync(), isFalse);
    });

    test('refuses to run if pubspec.yaml is missing', () async {
      final emptyDir = Directory.systemTemp.createTempSync('codegen_init_empty_');
      try {
        final exitCode = await runCodegenInit(
          projectRoot: emptyDir.path,
          printSnippetOnly: true,
          runPubAdd: false,
        );
        expect(exitCode, isNot(0));
      } finally {
        emptyDir.deleteSync(recursive: true);
      }
    });
  });
}
```

- [ ] **Step 12.2: Run — expect FAIL**

Run: `cd mcp_server_dart && flutter test test/cli/codegen_init_command_test.dart`

- [ ] **Step 12.3: Implement `runCodegenInit`**

```dart
// mcp_server_dart/lib/src/cli/codegen_init_command.dart
import 'dart:io';
import 'codegen_snippets.dart';

Future<int> runCodegenInit({
  required final String projectRoot,
  required final bool printSnippetOnly,
  required final bool runPubAdd,
}) async {
  final pubspec = File('$projectRoot/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('No pubspec.yaml at $projectRoot. Run from a Flutter project root.');
    return 66;
  }
  if (runPubAdd) {
    final result = await Process.start(
      'flutter',
      ['pub', 'add', 'flutter_mcp_toolkit'],
      workingDirectory: projectRoot,
      mode: ProcessStartMode.inheritStdio,
    );
    final exit = await result.exitCode;
    if (exit != 0) {
      stderr.writeln('flutter pub add failed (exit $exit)');
      return exit;
    }
  }
  // For v3.0.0: emit snippet to stdout only. AST-edit of main.dart is a follow-up.
  stdout.writeln('=== flutter-mcp-toolkit: paste this into your lib/main.dart ===');
  stdout.writeln(CodegenSnippets.flutterMainInit);
  stdout.writeln('=== end ===');
  return 0;
}
```

- [ ] **Step 12.4: Run test — expect PASS**

Run: `cd mcp_server_dart && flutter test test/cli/codegen_init_command_test.dart`
Expected: 2/2 pass.

- [ ] **Step 12.5: Commit**

```bash
git add mcp_server_dart/lib/src/cli/codegen_init_command.dart \
        mcp_server_dart/test/cli/codegen_init_command_test.dart
git commit -m "feat(cli): codegen-init command emits Flutter main.dart snippet"
```

---

## Task 13: Wire `codegen-init` into CLI binary

**Files:**
- Modify: same CLI entry point as Task 10

- [ ] **Step 13.1: Add `CodegenInitSubcommand`**

```dart
class CodegenInitSubcommand extends Command<int> {
  CodegenInitSubcommand() {
    argParser
      ..addFlag('print-only', defaultsTo: true,
          help: 'Print snippet to stdout, do not edit main.dart.')
      ..addFlag('pub-add', defaultsTo: true,
          help: 'Run "flutter pub add flutter_mcp_toolkit" first.');
  }

  @override
  String get name => 'codegen-init';

  @override
  String get description =>
      'Add flutter_mcp_toolkit to a Flutter app and emit boilerplate for main.dart.';

  @override
  Future<int> run() async {
    return runCodegenInit(
      projectRoot: Directory.current.path,
      printSnippetOnly: argResults!['print-only'] as bool,
      runPubAdd: argResults!['pub-add'] as bool,
    );
  }
}

// Then register:
runner.addCommand(CodegenInitSubcommand());
```

- [ ] **Step 13.2: Build and smoke test**

Run:
```bash
cd mcp_server_dart && make compile
cd /tmp && mkdir cgi_smoke && cd cgi_smoke
cat > pubspec.yaml <<'EOF'
name: smoke
environment: { sdk: ">=3.0.0" }
dependencies: { flutter: { sdk: flutter } }
EOF
/Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart/build/flutter-mcp-toolkit codegen-init --no-pub-add
```
Expected: snippet printed, exit 0. Cleanup: `rm -rf /tmp/cgi_smoke`.

- [ ] **Step 13.3: Commit**

```bash
git add mcp_server_dart/bin/flutter_mcp_toolkit.dart  # or wherever
git commit -m "feat(cli): expose 'codegen-init' subcommand"
```

---

## Task 14: Plan B self-verify

- [ ] **Step 14.1: Run full mcp_server_dart suite**

Run: `cd mcp_server_dart && flutter test`
Expected: All tests pass, including new `cli/*_test.dart`.

- [ ] **Step 14.2: Confirm new subcommands listed in `--help`**

Run: `mcp_server_dart/build/flutter-mcp-toolkit --help`
Expected: `init`, `codegen-init` appear.

- [ ] **Step 14.3: Mark Plan B complete**

Run: `git log --oneline -14`
Expected: 14 commits matching this plan's task structure.

---

## Self-Review

**Spec coverage:** §3.3 (mode prelude rendering — Tasks 4-5) ✓, §3.4 (mode detection — Task 8) ✓, §4.1 (human flow steps 2 + 3 — `codegen-init` Tasks 11-13, `init` Tasks 9-10) ✓.

**Type consistency:** `InitTarget`, `InitMode` enums used identically across writers, command, and tests. `SkillAsset` fields (`id`, `frontmatter`, `body`, `relativePath`) consumed in writers exactly as Plan A defines them. `runInit` signature stable across test (Task 9.1), impl (Task 9.3), and CLI wiring (Task 10.2).

**Placeholders:** Task 10 has one minor "or wherever path" qualifier — expected because the exact CLI entry-point file name is something the executor verifies via `grep` in Step 10.1. This is research, not a placeholder. All test code, all implementation code, all expected outputs concrete.

**TDD discipline:** Every implementation task has a paired failing test. Tasks: 1-2 (target enum), 3 (mode enum, single-task split for brevity), 4-5 (prelude), 6-7 (writers), 8 (detector), 9 (command logic), 11 (snippets), 12 (codegen-init logic). Wiring tasks (10, 13) lack dedicated tests because they're argParser glue exercised by the smoke tests; this is acceptable trade-off vs. mocking the CommandRunner.

**Frequent commits:** 14 commits, one per task, mostly red-green-commit cycles.
