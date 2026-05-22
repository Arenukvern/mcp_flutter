# Plan A — Skill Bundle Infrastructure

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish `plugin/` as the canonical source for the `flutter-mcp-toolkit` plugin, write the 5 skill bodies, and bake them into the CLI binary as a generated Dart asset, with CI drift enforcement.

**Architecture:** Single source-of-truth dir (`plugin/`) at repo root. Build-time codegen (`tool/build_skill_assets.dart`) reads the dir and emits `mcp_server_dart/lib/src/skill_assets.g.dart` containing the skill bodies as string constants. `make sync-skills` regenerates locally; CI fails if regeneration produces a diff.

**Tech Stack:** Dart, repository-root build tooling (Makefile), GitHub Actions for CI drift check.

**Spec reference:** `specs/2026-04-29-flutter-mcp-toolkit-plugin-design.md` §3.1, §3.2, §3.5.

**Dependencies:** None. Independent of Plans B/C/D. Runs in **Wave 1** in parallel with Plan C.

**Downstream:** Plan B consumes `skill_assets.g.dart`. Plan D references the migrated content in skill bodies.

---

## File Structure

**Create:**
- `plugin/.cursor-plugin/plugin.json`
- `plugin/.codex-plugin/plugin.json`
- `plugin/mcp.json`
- `plugin/README.md`
- `plugin/skills/flutter-mcp-toolkit-guide/SKILL.md`
- `plugin/skills/flutter-mcp-toolkit-setup/SKILL.md`
- `plugin/skills/flutter-mcp-toolkit-inspect/SKILL.md`
- `plugin/skills/flutter-mcp-toolkit-control/SKILL.md`
- `plugin/skills/flutter-mcp-toolkit-debug/SKILL.md`
- `mcp_server_dart/tool/build_skill_assets.dart`
- `mcp_server_dart/lib/src/skill_assets.g.dart` (generated)
- `mcp_server_dart/test/skill_assets_test.dart`
- `.github/workflows/skill_assets_drift.yml`

**Modify:**
- `mcp_server_dart/Makefile` — hook asset build, add `sync-skills` target
- `Makefile` — add top-level `sync-skills` passthrough
- `tool/contracts/check_plugin_surfaces.sh` — add plugin source structure check (or new sibling script)

---

## Task 1: Scaffold plugin/ directory and Cursor manifest

**Files:**
- Create: `plugin/.cursor-plugin/plugin.json`

- [ ] **Step 1.1: Create `plugin/.cursor-plugin/plugin.json`**

```json
{
  "name": "flutter-mcp-toolkit",
  "description": "Inspect and drive a running Flutter app from your AI assistant — semantic snapshot, tap, scroll, type, hot-reload, debug.",
  "version": "3.0.0",
  "author": { "name": "Arenukvern" }
}
```

- [ ] **Step 1.2: Verify JSON parses**

Run: `python3 -c "import json; json.load(open('plugin/.cursor-plugin/plugin.json'))"`
Expected: no output (success).

- [ ] **Step 1.3: Commit**

```bash
git add plugin/.cursor-plugin/plugin.json
git commit -m "feat(plugin): add Cursor plugin manifest"
```

---

## Task 2: Codex manifest

**Files:**
- Create: `plugin/.codex-plugin/plugin.json`

- [ ] **Step 2.1: Create `plugin/.codex-plugin/plugin.json`**

```json
{
  "name": "flutter-mcp-toolkit",
  "version": "3.0.0",
  "description": "Inspect and drive a running Flutter app from your AI assistant — semantic snapshot, tap, scroll, type, hot-reload, debug.",
  "author": "Arenukvern",
  "homepage": "https://github.com/Arenukvern/flutter-mcp-toolkit",
  "repository": "https://github.com/Arenukvern/flutter-mcp-toolkit",
  "license": "MIT",
  "skills": "./skills",
  "mcpServers": "./mcp.json"
}
```

- [ ] **Step 2.2: Verify JSON parses**

Run: `python3 -c "import json; json.load(open('plugin/.codex-plugin/plugin.json'))"`
Expected: no output.

- [ ] **Step 2.3: Commit**

```bash
git add plugin/.codex-plugin/plugin.json
git commit -m "feat(plugin): add Codex plugin manifest"
```

---

## Task 3: MCP server config (`mcp.json`)

**Files:**
- Create: `plugin/mcp.json`

- [ ] **Step 3.1: Create `plugin/mcp.json`**

```json
{
  "mcpServers": {
    "flutter-mcp-toolkit": {
      "command": "flutter-mcp-toolkit-server",
      "args": ["--dart-vm-port", "8181"],
      "env": {}
    }
  }
}
```

- [ ] **Step 3.2: Verify JSON parses**

Run: `python3 -c "import json; json.load(open('plugin/mcp.json'))"`

- [ ] **Step 3.3: Commit**

```bash
git add plugin/mcp.json
git commit -m "feat(plugin): add MCP server config for Cursor + Codex"
```

---

## Task 4: Plugin README (human entry)

**Files:**
- Create: `plugin/README.md`

- [ ] **Step 4.1: Write `plugin/README.md`**

```markdown
# flutter-mcp-toolkit (plugin)

The shippable plugin source for `flutter-mcp-toolkit`. End users install via the
CLI (`flutter-mcp-toolkit init <agent>`); this directory is the source of truth
for skill bodies and platform manifests.

## Layout

- `.cursor-plugin/plugin.json` — Cursor plugin manifest
- `.codex-plugin/plugin.json` — Codex plugin manifest
- `mcp.json` — MCP server registration consumed by Cursor + Codex
- `skills/` — 5 task-focused skills (guide, setup, inspect, control, debug)

## Editing skills

Edit any `skills/<id>/SKILL.md`, then run `make sync-skills` from the repo
root. CI fails if the generated `skill_assets.g.dart` is out of sync.
```

- [ ] **Step 4.2: Commit**

```bash
git add plugin/README.md
git commit -m "docs(plugin): add plugin source README"
```

---

## Task 5: Skill scaffolds — create dirs + frontmatter for all 5 skills

**Files:**
- Create: `plugin/skills/flutter-mcp-toolkit-guide/SKILL.md`
- Create: `plugin/skills/flutter-mcp-toolkit-setup/SKILL.md`
- Create: `plugin/skills/flutter-mcp-toolkit-inspect/SKILL.md`
- Create: `plugin/skills/flutter-mcp-toolkit-control/SKILL.md`
- Create: `plugin/skills/flutter-mcp-toolkit-debug/SKILL.md`

- [ ] **Step 5.1: Create the 5 SKILL.md files with minimum frontmatter + prelude marker**

For each skill below, create the file with EXACTLY this body shape (replace `<id>`, `<description>`):

```markdown
---
name: <id>
description: <description>
---

<!-- @FMT_MODE_PRELUDE -->

<!-- BODY-TBD: Task 6 fills in the sections below. -->
```

**Skill list (all 5):**

| Path | `name` | `description` |
|---|---|---|
| `plugin/skills/flutter-mcp-toolkit-guide/SKILL.md` | `flutter-mcp-toolkit-guide` | `Entry point for inspecting or driving a running Flutter app from your AI assistant — routes to the right task skill (inspect / control / debug) and runs preflight.` |
| `plugin/skills/flutter-mcp-toolkit-setup/SKILL.md` | `flutter-mcp-toolkit-setup` | `Verify the flutter-mcp-toolkit install, run doctor preflight, troubleshoot connection issues. Use when the toolkit isn't responding or first-time setup.` |
| `plugin/skills/flutter-mcp-toolkit-inspect/SKILL.md` | `flutter-mcp-toolkit-inspect` | `Read state from a running Flutter app — semantic snapshot, view details, errors, screenshots, VM info. Use when you need to understand what the app is showing.` |
| `plugin/skills/flutter-mcp-toolkit-control/SKILL.md` | `flutter-mcp-toolkit-control` | `Drive a running Flutter app — tap, scroll, type, fill forms, hot-reload, navigate. Use when you need to interact with the UI.` |
| `plugin/skills/flutter-mcp-toolkit-debug/SKILL.md` | `flutter-mcp-toolkit-debug` | `Diagnose problems in a running Flutter app — read logs, evaluate Dart expressions, interpret error envelopes. Use when something broke.` |

- [ ] **Step 5.2: Verify all 5 files exist and start with `---`**

Run: `for f in plugin/skills/flutter-mcp-toolkit-*/SKILL.md; do head -1 "$f"; done`
Expected: 5 lines of `---`.

- [ ] **Step 5.3: Commit**

```bash
git add plugin/skills/
git commit -m "feat(plugin): scaffold 5 skill files with frontmatter"
```

---

## Task 6: Author skill body — `flutter-mcp-toolkit-guide`

**Files:**
- Modify: `plugin/skills/flutter-mcp-toolkit-guide/SKILL.md`

- [ ] **Step 6.1: Replace `<!-- BODY-TBD -->` with the guide body**

The body must include these sections in order. Total target: ~80 lines.

```markdown
## When to use

Use this skill when the user wants to inspect or drive a running Flutter app
from this conversation. Examples:
- "Tap the login button in my app"
- "Why is the home screen blank?"
- "Take a screenshot and tell me what's broken"

If the user is asking about Flutter concepts unrelated to a running app
(architecture questions, package selection), this skill does not apply.

## Step 1: Preflight

Always run `flutter-mcp-toolkit doctor --json` first. Parse the output:

- `status: "ok"` — proceed to Step 2.
- `status: "error"` and `error.code: "binary_not_found"` — load
  `flutter-mcp-toolkit-setup` and follow its install instructions.
- `status: "error"` and `error.code: "vm_not_connected"` — load
  `flutter-mcp-toolkit-setup` and follow its troubleshooting section.
- Any other error — load `flutter-mcp-toolkit-debug` and read the error
  envelope playbook.

## Step 2: Pick the right skill for the user's intent

| User intent | Load skill |
|---|---|
| Read state ("what's on screen?", "show me errors", "screenshot") | `flutter-mcp-toolkit-inspect` |
| Drive UI ("tap X", "type into Y", "scroll to Z", "hot reload") | `flutter-mcp-toolkit-control` |
| Diagnose ("why is X failing?", "show recent logs", "evaluate expression") | `flutter-mcp-toolkit-debug` |

If the task spans more than one (e.g. "tap the button and show me what
changed"), load `inspect` AND `control`. Skills are additive.

## Step 3: Execute

Each task skill has the tool list, parameter shapes, and example calls. Follow
the prelude at the top of the skill — it tells you whether you're calling MCP
tools or shelling out to the CLI.

## Tool taxonomy reference

The 27 tools in this toolkit fall into these categories. The full list with
parameter shapes lives in the task skills.

- **Inspection (read-only):** `discover_debug_apps`, `get_app_errors`,
  `get_screenshots`, `get_view_details`, `get_vm`, `get_extension_rpcs`,
  `semantic_snapshot`, `inspect_widget_at_point`, `capture_ui_snapshot`,
  `connect_debug_app`. → `flutter-mcp-toolkit-inspect`.
- **Interaction (mutating):** `tap_widget`, `long_press`, `enter_text`,
  `fill_form`, `scroll`, `swipe`, `drag`, `hover`, `press_key`, `wait_for`,
  `navigate`, `handle_dialog`, `hot_reload_flutter`, `hot_restart_flutter`,
  `hot_reload_and_capture`. → `flutter-mcp-toolkit-control`.
- **Debug:** `get_recent_logs`, `evaluate_dart_expression`. →
  `flutter-mcp-toolkit-debug`.

## When in doubt

If `doctor` is green but a tool call fails, read the returned `error.code`
and `error.recovery` fields. The full code → recovery table is in
`flutter-mcp-toolkit-debug`.
```

- [ ] **Step 6.2: Verify file is ~80 lines and frontmatter intact**

Run: `wc -l plugin/skills/flutter-mcp-toolkit-guide/SKILL.md && head -5 plugin/skills/flutter-mcp-toolkit-guide/SKILL.md`
Expected: ~80 lines, frontmatter present, prelude marker present.

- [ ] **Step 6.3: Commit**

```bash
git add plugin/skills/flutter-mcp-toolkit-guide/SKILL.md
git commit -m "feat(plugin): write guide skill body"
```

---

## Task 7: Author skill body — `flutter-mcp-toolkit-setup`

**Files:**
- Modify: `plugin/skills/flutter-mcp-toolkit-setup/SKILL.md`

- [ ] **Step 7.1: Replace `<!-- BODY-TBD -->` with the setup body**

Sections required (target: ~150 lines):

1. **When to use** — first-time install, doctor reports red, MCP server not connected.
2. **Verify install** — run `flutter-mcp-toolkit --version`, expected output, troubleshooting if not found.
3. **Run doctor** — `flutter-mcp-toolkit doctor --json` flag-by-flag, sample green output, sample red output, what each error code means and how to recover.
4. **Connection issues** — port conflicts (`--dart-vm-port`), Flutter app not running in debug mode, `mcp_toolkit` package not initialized.
5. **CLI surface beyond `exec`** — list every subcommand: `init <agent>`, `codegen-init`, `doctor`, `exec`, `snapshot`, `bundle`, `--version`, `--help`. For each: one-line purpose + minimal example.
6. **Reinstall / upgrade** — `curl ... | bash` re-runs are idempotent.

For each `doctor` error code, document recovery steps. The complete error code list to cover (migrate from existing `docs/core/error_code_playbook.mdx`):
- `binary_not_found`, `vm_not_connected`, `connect_failed`, `connection_selection_required`, `hot_reload_failed`, `visual_capture_unsupported`.

Use the same single-source-of-truth content; full prose can be cribbed from `docs/core/error_code_playbook.mdx` and `docs/getting_started/manual_installation.mdx` (Plan D will delete those).

- [ ] **Step 7.2: Verify length**

Run: `wc -l plugin/skills/flutter-mcp-toolkit-setup/SKILL.md`
Expected: 100-200 lines.

- [ ] **Step 7.3: Commit**

```bash
git add plugin/skills/flutter-mcp-toolkit-setup/SKILL.md
git commit -m "feat(plugin): write setup skill body"
```

---

## Task 8: Author skill body — `flutter-mcp-toolkit-inspect`

**Files:**
- Modify: `plugin/skills/flutter-mcp-toolkit-inspect/SKILL.md`

- [ ] **Step 8.1: Replace `<!-- BODY-TBD -->` with the inspect body**

Sections (target: ~200 lines):

1. **When to use** — read-only state inspection.
2. **Recipes** — at minimum: "snapshot the visible UI", "find an error by message", "list debug-mode apps", "get widget at coordinates", "save a screenshot to a file".
3. **Tool reference** — for each of the 10 inspection tools, document:
   - Bare tool name (e.g. `tap_widget`)
   - Parameters: name, type, required/optional, default
   - Example call (use bare-name form; the prelude defines syntax)
   - Expected return shape (one example)
   - Common failure modes

Tools to cover: `discover_debug_apps`, `get_app_errors`, `get_screenshots`, `get_view_details`, `get_vm`, `get_extension_rpcs`, `semantic_snapshot`, `inspect_widget_at_point`, `capture_ui_snapshot`, `connect_debug_app`.

Source content: `docs/core/built_in_tools.mdx` (inspection sections); migrate verbatim where shape matches.

- [ ] **Step 8.2: Verify length and tool coverage**

Run: `wc -l plugin/skills/flutter-mcp-toolkit-inspect/SKILL.md && for t in discover_debug_apps get_app_errors get_screenshots get_view_details get_vm get_extension_rpcs semantic_snapshot inspect_widget_at_point capture_ui_snapshot connect_debug_app; do grep -q "$t" plugin/skills/flutter-mcp-toolkit-inspect/SKILL.md || echo "MISSING: $t"; done`
Expected: 150-250 lines, no MISSING output.

- [ ] **Step 8.3: Commit**

```bash
git add plugin/skills/flutter-mcp-toolkit-inspect/SKILL.md
git commit -m "feat(plugin): write inspect skill body"
```

---

## Task 9: Author skill body — `flutter-mcp-toolkit-control`

**Files:**
- Modify: `plugin/skills/flutter-mcp-toolkit-control/SKILL.md`

- [ ] **Step 9.1: Replace `<!-- BODY-TBD -->` with the control body**

Sections (target: ~250 lines):

1. **When to use** — UI mutation, hot-reload, navigation.
2. **Recipes** — at minimum: "tap a widget by text", "fill a login form", "scroll to find an item", "wait for a widget to appear", "navigate to a route", "hot reload after a code change", "press the back hardware button".
3. **Selectors** — explain `selector` shape (text vs key vs type-and-text), when to use each.
4. **Tool reference** — for each of the 15 interaction tools, document name + params + example + return shape. Tools: `tap_widget`, `long_press`, `enter_text`, `fill_form`, `scroll`, `swipe`, `drag`, `hover`, `press_key`, `wait_for`, `navigate`, `handle_dialog`, `hot_reload_flutter`, `hot_restart_flutter`, `hot_reload_and_capture`.
5. **Patterns** — "always `wait_for` before `tap_widget` after navigation"; "prefer `fill_form` over multiple `enter_text` calls".

Source: `docs/core/built_in_tools.mdx` (interaction sections).

- [ ] **Step 9.2: Verify length and tool coverage**

Run: `wc -l plugin/skills/flutter-mcp-toolkit-control/SKILL.md && for t in tap_widget long_press enter_text fill_form scroll swipe drag hover press_key wait_for navigate handle_dialog hot_reload_flutter hot_restart_flutter hot_reload_and_capture; do grep -q "$t" plugin/skills/flutter-mcp-toolkit-control/SKILL.md || echo "MISSING: $t"; done`
Expected: 200-300 lines, no MISSING output.

- [ ] **Step 9.3: Commit**

```bash
git add plugin/skills/flutter-mcp-toolkit-control/SKILL.md
git commit -m "feat(plugin): write control skill body"
```

---

## Task 10: Author skill body — `flutter-mcp-toolkit-debug`

**Files:**
- Modify: `plugin/skills/flutter-mcp-toolkit-debug/SKILL.md`

- [ ] **Step 10.1: Replace `<!-- BODY-TBD -->` with the debug body**

Sections (target: ~200 lines):

1. **When to use** — something broke; user wants to know why.
2. **Tool reference** — `get_recent_logs` (params, log levels, filtering), `evaluate_dart_expression` (params, sandbox limits, security).
3. **Error envelope playbook** — for EVERY error code from `flutter_mcp_toolkit_core/lib/src/types/results.dart`, document: code, what it means, common cause, recovery action. This is the migrated content from `docs/core/error_code_playbook.mdx`.
4. **Triage flow** — when to use `get_recent_logs` vs `evaluate_dart_expression`; how to chain with `inspect` skill calls.
5. **`connect_debug_app` flows** — what to do when multiple debug apps are running.

To enumerate error codes: run `grep -rn "ErrorCode\|errorCode:" flutter_mcp_toolkit_core/lib/ flutter_mcp_toolkit_capability_core/lib/` and ensure all unique codes appear in the playbook.

- [ ] **Step 10.2: Verify length and error code coverage**

Run: `wc -l plugin/skills/flutter-mcp-toolkit-debug/SKILL.md`
Then enumerate error codes and verify each appears: `grep -roh "ErrorCode\.[a-z_]\+" flutter_mcp_toolkit_core/lib flutter_mcp_toolkit_capability_core/lib | sort -u | while read code; do name=$(echo "$code" | cut -d. -f2); grep -q "$name" plugin/skills/flutter-mcp-toolkit-debug/SKILL.md || echo "MISSING: $name"; done`
Expected: 150-250 lines, no MISSING output.

- [ ] **Step 10.3: Commit**

```bash
git add plugin/skills/flutter-mcp-toolkit-debug/SKILL.md
git commit -m "feat(plugin): write debug skill body"
```

---

## Task 11: Asset bundler — failing test

**Files:**
- Create: `mcp_server_dart/test/skill_assets_test.dart`

- [ ] **Step 11.1: Write failing test for `skill_assets.g.dart` consumer API**

```dart
// mcp_server_dart/test/skill_assets_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server_dart/src/skill_assets.g.dart';

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
```

- [ ] **Step 11.2: Run — expect FAIL (skill_assets.g.dart does not exist)**

Run: `cd mcp_server_dart && flutter test test/skill_assets_test.dart`
Expected: build error — no such file `package:mcp_server_dart/src/skill_assets.g.dart`.

- [ ] **Step 11.3: Commit failing test**

```bash
git add mcp_server_dart/test/skill_assets_test.dart
git commit -m "test(skill_assets): failing test for bundled skill assets"
```

---

## Task 12: Asset bundler — implementation

**Files:**
- Create: `mcp_server_dart/tool/build_skill_assets.dart`
- Create: `mcp_server_dart/lib/src/skill_assets.g.dart` (committed initially as placeholder; regenerated in Step 12.4)

- [ ] **Step 12.1: Write generator script `mcp_server_dart/tool/build_skill_assets.dart`**

```dart
// mcp_server_dart/tool/build_skill_assets.dart
//
// Reads `<repo_root>/plugin/` and emits
// `mcp_server_dart/lib/src/skill_assets.g.dart`. Run via
// `dart run mcp_server_dart/tool/build_skill_assets.dart` or
// `make sync-skills` from the repo root.

import 'dart:io';
import 'dart:convert';

const expectedSkillIds = [
  'flutter-mcp-toolkit-guide',
  'flutter-mcp-toolkit-setup',
  'flutter-mcp-toolkit-inspect',
  'flutter-mcp-toolkit-control',
  'flutter-mcp-toolkit-debug',
];

void main() {
  final repoRoot = _findRepoRoot();
  final pluginDir = Directory('${repoRoot.path}/plugin');
  if (!pluginDir.existsSync()) {
    stderr.writeln('plugin/ not found at ${pluginDir.path}');
    exit(1);
  }

  final cursorManifest =
      File('${pluginDir.path}/.cursor-plugin/plugin.json').readAsStringSync();
  final codexManifest =
      File('${pluginDir.path}/.codex-plugin/plugin.json').readAsStringSync();
  final mcpConfig = File('${pluginDir.path}/mcp.json').readAsStringSync();

  final skills = <_Skill>[];
  for (final id in expectedSkillIds) {
    final file = File('${pluginDir.path}/skills/$id/SKILL.md');
    if (!file.existsSync()) {
      stderr.writeln('Missing skill: ${file.path}');
      exit(1);
    }
    final content = file.readAsStringSync();
    final parts = _splitFrontmatter(content);
    skills.add(_Skill(
      id: id,
      frontmatter: parts.frontmatter,
      body: parts.body,
      relativePath: 'skills/$id/SKILL.md',
    ));
  }

  final out = File('${repoRoot.path}/mcp_server_dart/lib/src/skill_assets.g.dart');
  out.writeAsStringSync(_render(
    skills: skills,
    cursorManifest: cursorManifest,
    codexManifest: codexManifest,
    mcpConfig: mcpConfig,
  ));
  stdout.writeln('Wrote ${out.path}');
}

class _Skill {
  _Skill({
    required this.id,
    required this.frontmatter,
    required this.body,
    required this.relativePath,
  });
  final String id;
  final String frontmatter;
  final String body;
  final String relativePath;
}

class _Parts {
  _Parts(this.frontmatter, this.body);
  final String frontmatter;
  final String body;
}

_Parts _splitFrontmatter(String content) {
  if (!content.startsWith('---\n')) {
    throw FormatException('SKILL.md must start with frontmatter');
  }
  final end = content.indexOf('\n---\n', 4);
  if (end < 0) throw FormatException('Unterminated frontmatter');
  return _Parts(content.substring(4, end), content.substring(end + 5));
}

Directory _findRepoRoot() {
  var dir = Directory.current;
  while (dir.parent.path != dir.path) {
    if (Directory('${dir.path}/.git').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('Not in a git repo');
}

String _render({
  required List<_Skill> skills,
  required String cursorManifest,
  required String codexManifest,
  required String mcpConfig,
}) {
  final buf = StringBuffer();
  buf.writeln('// AUTOGENERATED by tool/build_skill_assets.dart. Do not edit.');
  buf.writeln('// Run `make sync-skills` from the repo root to regenerate.');
  buf.writeln();
  buf.writeln('class SkillAsset {');
  buf.writeln('  const SkillAsset({');
  buf.writeln('    required this.id,');
  buf.writeln('    required this.frontmatter,');
  buf.writeln('    required this.body,');
  buf.writeln('    required this.relativePath,');
  buf.writeln('  });');
  buf.writeln('  final String id;');
  buf.writeln('  final String frontmatter;');
  buf.writeln('  final String body;');
  buf.writeln('  final String relativePath;');
  buf.writeln('}');
  buf.writeln();
  buf.writeln('class SkillAssets {');
  buf.writeln('  static const List<SkillAsset> skills = [');
  for (final s in skills) {
    buf.writeln('    SkillAsset(');
    buf.writeln("      id: '${s.id}',");
    buf.writeln('      frontmatter: ${_dartString(s.frontmatter)},');
    buf.writeln('      body: ${_dartString(s.body)},');
    buf.writeln("      relativePath: '${s.relativePath}',");
    buf.writeln('    ),');
  }
  buf.writeln('  ];');
  buf.writeln();
  buf.writeln('  static const String cursorPluginManifest = ${_dartString(cursorManifest)};');
  buf.writeln('  static const String codexPluginManifest = ${_dartString(codexManifest)};');
  buf.writeln('  static const String mcpServerConfig = ${_dartString(mcpConfig)};');
  buf.writeln('}');
  return buf.toString();
}

String _dartString(String s) {
  // Use raw triple-quoted strings; escape any `'''` sequences inside.
  if (s.contains("'''")) {
    return jsonEncode(s);
  }
  return "r'''$s'''";
}
```

- [ ] **Step 12.2: Run the generator**

Run: `cd /Users/antonio/mcp/cline/mcp_flutter && dart run mcp_server_dart/tool/build_skill_assets.dart`
Expected: `Wrote /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart/lib/src/skill_assets.g.dart`.

- [ ] **Step 12.3: Verify generated file compiles**

Run: `cd mcp_server_dart && dart analyze lib/src/skill_assets.g.dart`
Expected: No issues.

- [ ] **Step 12.4: Run the failing test from Task 11 — expect PASS**

Run: `cd mcp_server_dart && flutter test test/skill_assets_test.dart`
Expected: All 5 tests pass.

- [ ] **Step 12.5: Commit**

```bash
git add mcp_server_dart/tool/build_skill_assets.dart \
        mcp_server_dart/lib/src/skill_assets.g.dart
git commit -m "feat(skill_assets): bundle skill bodies into mcp_server_dart"
```

---

## Task 13: Make targets — `sync-skills`

**Files:**
- Modify: `Makefile`
- Modify: `mcp_server_dart/Makefile`

- [ ] **Step 13.1: Read root `Makefile`**

Run: `cat Makefile`

- [ ] **Step 13.2: Append `sync-skills` target to root Makefile**

Add to `Makefile`:

```makefile
.PHONY: sync-skills
sync-skills:
	dart run mcp_server_dart/tool/build_skill_assets.dart
	@echo "OK: skill assets regenerated"
```

- [ ] **Step 13.3: Append `sync-skills` target to `mcp_server_dart/Makefile`**

Add to `mcp_server_dart/Makefile`:

```makefile
.PHONY: sync-skills
sync-skills:
	cd .. && dart run mcp_server_dart/tool/build_skill_assets.dart
```

- [ ] **Step 13.4: Run `make sync-skills` from repo root**

Run: `make sync-skills`
Expected: `Wrote .../skill_assets.g.dart` then `OK: skill assets regenerated`. Git diff should show no change (file is up-to-date).

- [ ] **Step 13.5: Commit**

```bash
git add Makefile mcp_server_dart/Makefile
git commit -m "build: add sync-skills make target"
```

---

## Task 14: Hook asset build into compile pipeline

**Files:**
- Modify: `mcp_server_dart/Makefile`

- [ ] **Step 14.1: Inspect existing compile target**

Run: `grep -n compile mcp_server_dart/Makefile`

- [ ] **Step 14.2: Add `sync-skills` as a dependency of `compile`**

In `mcp_server_dart/Makefile`, change the `compile:` line so it depends on `sync-skills` (e.g. `compile: sync-skills`). If `compile` already depends on other targets, add `sync-skills` to the list.

- [ ] **Step 14.3: Verify build still passes**

Run: `cd mcp_server_dart && make compile`
Expected: build succeeds, binaries produced in `build/`.

- [ ] **Step 14.4: Commit**

```bash
git add mcp_server_dart/Makefile
git commit -m "build: regenerate skill assets before compile"
```

---

## Task 15: CI drift check

**Files:**
- Create: `.github/workflows/skill_assets_drift.yml`

- [ ] **Step 15.1: Create the workflow**

```yaml
name: skill-assets-drift

on:
  pull_request:
    paths:
      - 'plugin/**'
      - 'mcp_server_dart/lib/src/skill_assets.g.dart'
      - 'mcp_server_dart/tool/build_skill_assets.dart'
  push:
    branches: [main]

jobs:
  check-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - name: Install deps
        run: cd mcp_server_dart && dart pub get
      - name: Regenerate skill assets
        run: dart run mcp_server_dart/tool/build_skill_assets.dart
      - name: Verify no drift
        run: |
          if ! git diff --exit-code mcp_server_dart/lib/src/skill_assets.g.dart; then
            echo "::error::skill_assets.g.dart is out of sync with plugin/. Run 'make sync-skills' and commit the result."
            exit 1
          fi
```

- [ ] **Step 15.2: Validate YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/skill_assets_drift.yml'))"`
Expected: no output.

- [ ] **Step 15.3: Commit**

```bash
git add .github/workflows/skill_assets_drift.yml
git commit -m "ci: fail PRs that don't regenerate skill_assets.g.dart"
```

---

## Task 16: Plan A self-verify

- [ ] **Step 16.1: Run the full test suite to ensure no regressions**

Run: `cd mcp_server_dart && flutter test`
Expected: all tests pass, including new `skill_assets_test.dart`.

- [ ] **Step 16.2: Run `make build`**

Run: `make build`
Expected: build succeeds.

- [ ] **Step 16.3: Verify manual install path works** — copy a skill into `.claude/skills/` and verify it loads.

Run:
```bash
mkdir -p .claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide
cp plugin/skills/flutter-mcp-toolkit-guide/SKILL.md \
   .claude/skills/flutter-mcp-toolkit/flutter-mcp-toolkit-guide/SKILL.md
```

Confirm in your Claude Code session that `flutter-mcp-toolkit-guide` appears in available skills (this is the manual install path users have today; Plan B automates it).

Cleanup if desired: `rm -rf .claude/skills/flutter-mcp-toolkit/`.

- [ ] **Step 16.4: Mark Plan A complete**

Run: `git log --oneline -16`
Expected: 16 commits matching this plan's task structure.

---

## Self-Review

**Spec coverage:** §3.1 (5 skills) ✓, §3.2 (canonical layout, manifests) ✓, §3.5 (build pipeline + CI drift) ✓. Mode prelude marker (`<!-- @FMT_MODE_PRELUDE -->`) inserted in scaffolds (Task 5); substitution itself is Plan B.

**Placeholders:** Skill body tasks (6-10) specify required sections, target line counts, and concrete tools/error codes to cover. Source files for migration are cited. Body content is authoring work but the deliverable shape is fully specified.

**Type consistency:** `SkillAsset` class fields (`id`, `frontmatter`, `body`, `relativePath`) match between test (Task 11) and generator (Task 12). `SkillAssets.skills` list and `SkillAssets.{cursorPluginManifest, codexPluginManifest, mcpServerConfig}` constants used identically.

**Test discipline:** Task 11 (failing test) → Task 12 (impl makes it pass) → Task 13-14 (build wiring) → Task 15 (CI gate) → Task 16 (full verify).

**Frequent commits:** 16 distinct commits, one per logical step.
