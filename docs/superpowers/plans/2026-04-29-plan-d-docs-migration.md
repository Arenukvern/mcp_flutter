# Plan D — Docs Migration + README Rewrite

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make docs match reality. Delete the 7 docs that the new `init` command supersedes. Migrate AI-agent docs into the skills (already happened in Plan A's skill bodies). Rewrite the README hero around the four-step install. Update `docs.json` navigation.

**Architecture:** This is mostly a deletion + redirect pass. Skill bodies authored in Plan A are the new source of truth for AI-agent guidance. Human docs shrink to: README → `docs/start_here/` → install.sh + `init <agent>`.

**Tech Stack:** Markdown / MDX, `docs.json` (the docs site nav config).

**Spec reference:** `docs/superpowers/specs/2026-04-29-flutter-mcp-toolkit-plugin-design.md` §6.2.

**Dependencies:** Plan A (skills must exist before migrating docs into them). Plan B (`init` command must exist before docs reference it). Plan C (binary names + tool prefix must be renamed before docs reference them). Runs in **Wave 3** after A+B+C.

---

## File Structure

**Delete:**
- `docs/ai_agents/cursor.mdx`
- `docs/ai_agents/codex.mdx`
- `docs/ai_agents/claude.mdx`
- `docs/ai_agents/cline.mdx` (verify exists; spec assumed it might)
- `docs/getting_started/manual_installation.mdx`
- `docs/getting_started/manual_client_setup.mdx`
- `docs/getting_started/llm_install_files.mdx`
- `docs/core/built_in_tools.mdx` (content already migrated to skills in Plan A)
- `docs/core/error_code_playbook.mdx` (content already migrated to skills in Plan A)

**Modify:**
- `docs/ai_agents/execution_playbook.mdx` — shrink to redirect
- `docs/ai_agents/overview.mdx` — shrink to point at plugin
- `docs/start_here/why_this_repo_matters.mdx` — rewrite step 1
- `docs/start_here/feature_map.mdx` — refresh names
- `docs/start_here/cli_vs_mcp.mdx` — refresh + reference `init`
- `README.md` — rewrite hero
- `docs.json` — remove deleted-page entries, add new ones if any

**Create:**
- `docs/start_here/index.mdx` — single canonical "start here" entry (optional if nav serves this role)

---

## Task 1: Inventory current docs structure

**Files:** None. Research only.

- [ ] **Step 1.1: List all current docs**

Run: `find docs -name "*.mdx" -o -name "*.md" | sort`

- [ ] **Step 1.2: Read docs.json**

Run: `cat docs.json | python3 -m json.tool | head -100`

- [ ] **Step 1.3: Verify deletions match reality**

Confirm each file in the "Delete" list above actually exists. For ones that don't exist (e.g. `cline.mdx`), drop them from the deletion list — no action needed.

Run:
```bash
for f in docs/ai_agents/cursor.mdx docs/ai_agents/codex.mdx \
         docs/ai_agents/claude.mdx docs/ai_agents/cline.mdx \
         docs/getting_started/manual_installation.mdx \
         docs/getting_started/manual_client_setup.mdx \
         docs/getting_started/llm_install_files.mdx \
         docs/core/built_in_tools.mdx \
         docs/core/error_code_playbook.mdx; do
  [[ -f "$f" ]] && echo "EXISTS: $f" || echo "MISSING: $f"
done
```
Note any MISSING — those are skipped in Tasks 2-3.

No commit — research only.

---

## Task 2: Delete superseded per-agent docs

**Files:**
- Delete: `docs/ai_agents/cursor.mdx`, `codex.mdx`, `claude.mdx`, `cline.mdx`

- [ ] **Step 2.1: Delete the per-agent docs (those that exist per Task 1.3)**

Run:
```bash
for f in docs/ai_agents/cursor.mdx docs/ai_agents/codex.mdx \
         docs/ai_agents/claude.mdx docs/ai_agents/cline.mdx; do
  [[ -f "$f" ]] && git rm "$f"
done
```

- [ ] **Step 2.2: Commit**

```bash
git commit -m "docs: remove per-agent setup docs (superseded by 'flutter-mcp-toolkit init <agent>')"
```

---

## Task 3: Delete superseded manual-install docs

**Files:**
- Delete: `docs/getting_started/manual_installation.mdx`, `manual_client_setup.mdx`, `llm_install_files.mdx`

- [ ] **Step 3.1: Delete (those that exist)**

Run:
```bash
for f in docs/getting_started/manual_installation.mdx \
         docs/getting_started/manual_client_setup.mdx \
         docs/getting_started/llm_install_files.mdx; do
  [[ -f "$f" ]] && git rm "$f"
done
```

- [ ] **Step 3.2: Commit**

```bash
git commit -m "docs: remove manual install/client-setup docs (superseded by install.sh + init)"
```

---

## Task 4: Delete migrated tool/error reference docs

**Files:**
- Delete: `docs/core/built_in_tools.mdx`, `docs/core/error_code_playbook.mdx`

- [ ] **Step 4.1: Verify content is in skills**

Run:
```bash
# Sanity check: error code names from the old doc appear in the debug skill
grep -oh "code:.*" docs/core/error_code_playbook.mdx 2>/dev/null | head -5
grep -c "ErrorCode\|error.code" plugin/skills/flutter-mcp-toolkit-debug/SKILL.md 2>/dev/null
```
Expected: Plan A's debug skill body has migrated content. If the count is suspiciously low (< 5), do not delete yet — fix the skill body first.

- [ ] **Step 4.2: Delete**

Run:
```bash
[[ -f docs/core/built_in_tools.mdx ]] && git rm docs/core/built_in_tools.mdx
[[ -f docs/core/error_code_playbook.mdx ]] && git rm docs/core/error_code_playbook.mdx
```

- [ ] **Step 4.3: Commit**

```bash
git commit -m "docs(core): remove built_in_tools + error_code_playbook (migrated to skills)"
```

---

## Task 5: Shrink `docs/ai_agents/execution_playbook.mdx` to a redirect

**Files:**
- Modify: `docs/ai_agents/execution_playbook.mdx`

- [ ] **Step 5.1: Replace contents with redirect**

```mdx
---
title: AI Agent Execution Playbook
description: This guide moved into the flutter-mcp-toolkit plugin.
---

# AI Agent Execution Playbook (moved)

The execution playbook is now the **`flutter-mcp-toolkit-setup`** skill, shipped
inside the plugin. To install it for your agent, run:

```bash
flutter-mcp-toolkit init claude-code   # or: cursor | codex | cline | all
```

This installs the `flutter-mcp-toolkit-{guide,setup,inspect,control,debug}`
skills into your agent's expected location. The setup skill covers preflight
(`flutter-mcp-toolkit doctor`), connection troubleshooting, and the full CLI
surface.

For a quick orientation without installing, browse the source skills:
[plugin/skills/](https://github.com/Arenukvern/flutter-mcp-toolkit/tree/main/plugin/skills).
```

- [ ] **Step 5.2: Commit**

```bash
git add docs/ai_agents/execution_playbook.mdx
git commit -m "docs(ai_agents): redirect execution_playbook to plugin skills"
```

---

## Task 6: Shrink `docs/ai_agents/overview.mdx`

**Files:**
- Modify: `docs/ai_agents/overview.mdx`

- [ ] **Step 6.1: Replace with overview that points at the plugin**

```mdx
---
title: AI Agent Setup
description: One-command install for Claude Code, Cursor, Codex, and Cline.
---

# AI Agent Setup

`flutter-mcp-toolkit` ships as a plugin with five task-focused skills:

| Skill | Purpose |
|---|---|
| `flutter-mcp-toolkit-guide` | Entry point — routes to the right skill |
| `flutter-mcp-toolkit-setup` | Install verification + preflight |
| `flutter-mcp-toolkit-inspect` | Read app state |
| `flutter-mcp-toolkit-control` | Drive UI |
| `flutter-mcp-toolkit-debug` | Diagnose problems |

## Install for your agent

```bash
flutter-mcp-toolkit init claude-code   # or: cursor | codex | cline | agents-skills | all
```

This writes the skills + plugin manifest + MCP server registration to your
agent's expected path. The `init` command auto-detects whether to use MCP or
CLI mode; override with `--mode mcp|cli|auto`.

## Browse the skills

The canonical source is in [plugin/skills/](https://github.com/Arenukvern/flutter-mcp-toolkit/tree/main/plugin/skills).
Skills are markdown — readable without an agent.
```

- [ ] **Step 6.2: Commit**

```bash
git add docs/ai_agents/overview.mdx
git commit -m "docs(ai_agents): rewrite overview around the plugin"
```

---

## Task 7: Update `docs/start_here/why_this_repo_matters.mdx`

**Files:**
- Modify: `docs/start_here/why_this_repo_matters.mdx`

- [ ] **Step 7.1: Read current content**

Run: `cat docs/start_here/why_this_repo_matters.mdx`

- [ ] **Step 7.2: Rewrite "step 1" section to be the four-step install**

Locate the section that explains how to get started. Replace with:

```mdx
## Get started in 4 steps

```bash
# 1. Install the binary
curl -fsSL https://raw.githubusercontent.com/Arenukvern/flutter-mcp-toolkit/main/install.sh | bash

# 2. Add the toolkit to your Flutter app
cd my-flutter-app
flutter-mcp-toolkit codegen-init   # adds flutter_mcp_toolkit + emits main.dart snippet

# 3. Install skills for your AI agent
flutter-mcp-toolkit init claude-code   # or: cursor | codex | cline | all

# 4. Run the app
flutter run --debug
```

That's it. Your AI agent can now inspect and drive the running app.
```

(Adjust surrounding prose so the step block flows naturally; keep voice and structure of the rest of the doc.)

- [ ] **Step 7.3: Commit**

```bash
git add docs/start_here/why_this_repo_matters.mdx
git commit -m "docs(start_here): replace step 1 with four-step install"
```

---

## Task 8: Update `docs/start_here/feature_map.mdx` and `cli_vs_mcp.mdx`

**Files:**
- Modify: `docs/start_here/feature_map.mdx`
- Modify: `docs/start_here/cli_vs_mcp.mdx`

- [ ] **Step 8.1: Update feature_map.mdx**

Run: `grep -n "core_\|flutter_mcp_cli\|flutter_inspector_mcp\|mcp_toolkit" docs/start_here/feature_map.mdx`
For each match, update names to v3.0.0 forms (`fmt_*`, `flutter-mcp-toolkit`, `flutter-mcp-toolkit-server`, `flutter_mcp_toolkit` for the Pub package).

- [ ] **Step 8.2: Update cli_vs_mcp.mdx**

Run: `grep -n "core_\|flutter_mcp_cli\|flutter_inspector_mcp" docs/start_here/cli_vs_mcp.mdx`
Replace as above. Add a paragraph explaining the `init` command picks mode automatically:

```mdx
> If you're not sure whether to use CLI or MCP mode, run
> `flutter-mcp-toolkit init <your-agent>` and let it auto-detect. Override
> with `--mode mcp` or `--mode cli` if needed.
```

- [ ] **Step 8.3: Commit**

```bash
git add docs/start_here/
git commit -m "docs(start_here): refresh names + reference init command"
```

---

## Task 9: Rewrite README.md hero

**Files:**
- Modify: `README.md`

- [ ] **Step 9.1: Read current README**

Run: `cat README.md`

- [ ] **Step 9.2: Replace the top section (above the first `##`) with the new hero**

```markdown
# flutter-mcp-toolkit

> Inspect and drive a running Flutter app from your AI assistant.

`flutter-mcp-toolkit` is a Dart MCP server + Flutter package that lets AI
assistants (Claude Code, Cursor, Codex, Cline) take semantic snapshots, tap
widgets, type into forms, hot-reload, and read logs from a Flutter app —
without leaving the conversation.

## Get started in 4 steps

```bash
# 1. Install
curl -fsSL https://raw.githubusercontent.com/Arenukvern/flutter-mcp-toolkit/main/install.sh | bash

# 2. Add to your Flutter app
cd my-flutter-app
flutter-mcp-toolkit codegen-init

# 3. Install skills for your agent
flutter-mcp-toolkit init claude-code   # or: cursor | codex | cline | all

# 4. Run
flutter run --debug
```

That's it.

## Documentation

- **[Why this repo matters](docs/start_here/why_this_repo_matters.mdx)** — what
  it is, why it exists.
- **[CLI vs MCP](docs/start_here/cli_vs_mcp.mdx)** — pick the right mode.
- **[Feature map](docs/start_here/feature_map.mdx)** — the 27 tools.
- **[AI agent setup](docs/ai_agents/overview.mdx)** — for non-Claude Code
  agents.
- **[Architecture](ARCHITECTURE.md)** — for contributors.

## What it does

The toolkit exposes 27 MCP tools across four categories:

- **Inspection** — semantic snapshot, view details, errors, screenshots, VM info
- **Interaction** — tap, scroll, type, fill forms, hot-reload, navigate, wait_for
- **Debug** — recent logs, evaluate Dart expressions
- **Lifecycle** — discover apps, hot-reload, hot-restart

See `flutter-mcp-toolkit-{guide,inspect,control,debug}` skills for the full
reference.

## License

[MIT](LICENSE)
```

(Keep the rest of the README — badges, status, contributing — below this hero.)

- [ ] **Step 9.3: Verify length and links**

Run: `wc -l README.md && grep -o "\[[^]]*\](docs/[^)]*)" README.md`
Expected: ≤ 100-line README; every doc link points to a file that exists post-deletions.

- [ ] **Step 9.4: Commit**

```bash
git add README.md
git commit -m "docs(readme): rewrite hero around the four-step install"
```

---

## Task 10: Update `docs.json` navigation

**Files:**
- Modify: `docs.json`

- [ ] **Step 10.1: Read docs.json**

Run: `cat docs.json | python3 -m json.tool`

- [ ] **Step 10.2: Remove entries for deleted docs**

For each deletion in Tasks 2-4 that was a `.mdx` file, find the matching entry in `docs.json` (search for the path/title) and remove it. Likely affected sections: `getting_started`, `core`, `ai_agents`.

- [ ] **Step 10.3: Validate JSON**

Run: `python3 -m json.tool docs.json > /dev/null`
Expected: no output (success).

- [ ] **Step 10.4: If you have a doc-site preview command, run it**

Run: `make docs-preview 2>/dev/null || echo "no preview target"`
If a preview is available, sanity-check that the navigation renders without 404s.

- [ ] **Step 10.5: Commit**

```bash
git add docs.json
git commit -m "docs: remove deleted-page entries from navigation"
```

---

## Task 11: Update CONTRIBUTING / contributing docs

**Files:**
- Modify: `docs/contributing/*` (whichever file describes editing docs/skills)

- [ ] **Step 11.1: Find the contributing doc most relevant**

Run: `ls docs/contributing/`

- [ ] **Step 11.2: Add a short section on editing skills**

In the most relevant file, add:

```mdx
## Editing skills

Skill bodies are the canonical source of AI-agent guidance, located in
`plugin/skills/<skill-id>/SKILL.md`. After editing any skill:

```bash
make sync-skills   # regenerates mcp_server_dart/lib/src/skill_assets.g.dart
```

CI fails if the generated file is out of sync with `plugin/`. Commit both the
`SKILL.md` change and the regenerated `skill_assets.g.dart`.
```

- [ ] **Step 11.3: Commit**

```bash
git add docs/contributing/
git commit -m "docs(contributing): add section on editing skills"
```

---

## Task 12: Run all docs / contracts checks

**Files:** None modified. Verification.

- [ ] **Step 12.1: Run check_docs_drift**

Run: `bash tool/contracts/check_docs_drift.sh`
Expected: pass.

- [ ] **Step 12.2: Run all contracts**

Run: `make check-contracts`
Expected: pass.

- [ ] **Step 12.3: Verify no broken internal links in remaining docs**

Run:
```bash
grep -roh "(docs/[^)]*)" docs README.md ARCHITECTURE.md CLAUDE.md 2>/dev/null \
  | sed 's/[()]//g' \
  | sort -u \
  | while read p; do [[ -f "$p" ]] || echo "MISSING: $p"; done
```
Expected: no MISSING output. If any links broken, fix them in a final patch:

```bash
# Targeted edit of the file containing the broken link
git add <fixed-file>
git commit -m "docs: fix broken link to <path>"
```

---

## Task 13: Plan D self-verify

- [ ] **Step 13.1: Confirm net file change**

Run: `git diff --stat $(git merge-base HEAD main)..HEAD docs/ README.md docs.json`
Expected: ≥ 7 deletions for the deleted docs, modifications to ~5 files (README, overview, execution_playbook, why_this_repo_matters, feature_map, cli_vs_mcp, docs.json, contributing).

- [ ] **Step 13.2: Final smoke test of the human onboarding doc path**

Read `README.md` start to finish. As a fresh reader, would you know what to do? If yes, ship.

- [ ] **Step 13.3: Mark Plan D complete**

Run: `git log --oneline -13`
Expected: ~13 commits across the docs migration.

---

## Self-Review

**Spec coverage:** §6.2 docs migration table ✓ — every row has a task. Per-agent doc deletes (Task 2). Manual-install doc deletes (Task 3). `built_in_tools.mdx` + `error_code_playbook.mdx` deletes (Task 4 — content already migrated to Plan A skills). `execution_playbook.mdx` redirect (Task 5). `overview.mdx` rewrite (Task 6). `start_here/*` updates (Tasks 7-8). README hero rewrite (Task 9). `docs.json` nav update (Task 10). Contributing section (Task 11).

**Type consistency:** All doc paths cited match Task 1.3's existence-check pattern, so the plan handles "doesn't exist" gracefully without breaking. New names (`flutter-mcp-toolkit`, `fmt_`, `flutter-mcp-toolkit-server`) are used consistently per Plan C's renames.

**Placeholders:** Task 8 and Task 11 reference "the most relevant file" — that's intentional ambiguity because the executor must inspect the directory to choose the right target. The acceptance criteria (what content must end up where) is concrete; the file-selection is one shell command of inspection.

**Independence + ordering:** Plan D depends on Plans A+B+C complete. Specifically: Plan A's debug skill must contain the migrated error-code content before Task 4 deletes the source MDX (Task 4.1 verifies this). Plan B's `init` command must exist before README and docs reference it (Tasks 7, 9). Plan C's renames must complete before docs use the new names (Tasks 7, 8, 9, 10).

**Frequent commits:** 13 commits, one per logical step (delete batches grouped, since they're trivially safe).
