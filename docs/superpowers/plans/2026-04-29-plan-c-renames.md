# Plan C — Renames (Tool Prefix + Binaries)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the MCP tool prefix `core_*` → `fmt_*`, the CLI binary `flutter_mcp_cli` → `flutter-mcp-toolkit`, and the MCP server binary `flutter_inspector_mcp` → `flutter-mcp-toolkit-server`, with snapshot tests enforcing the new surface.

**Architecture:** The tool prefix comes from `CoreCapability.id` (`mcp_capability_core/lib/src/core_capability.dart`). The kernel constructs MCP tool names as `<capability_id>_<tool_name>`. Renaming `id` from `'core'` to `'fmt'` flips the prefix everywhere atomically. Binary renames are `makefile` + `install.sh` checksum updates.

**Tech Stack:** Dart, Make, shell.

**Spec reference:** `docs/superpowers/specs/2026-04-29-flutter-mcp-toolkit-plugin-design.md` §5, §6.1.

**Dependencies:** None on Plan A or Plan B for the prefix rename itself. Independent of all other plans. Runs in **Wave 1** in parallel with Plan A.

**Coordination note:** Plan B's MCP-mode prelude string mentions `fmt_` (e.g. "`tap_widget` → `fmt_tap_widget`"). If Plan C lands first, Plan B's prelude is correct. If Plan B lands first while Plan C is in flight, Plan B's tests still pass (the string is hardcoded in Plan B). Either order works.

**Downstream:** Plan D's docs migration assumes the new tool prefix and binary names; should land after Plan C.

---

## File Structure

**Modify:**
- `mcp_capability_core/lib/src/core_capability.dart` — id `'core'` → `'fmt'`; consider class rename
- `tool/contracts/expected_tool_surface.txt` — bulk `core_` → `fmt_` (27 entries)
- `mcp_server_dart/test/tool_surface_snapshot_test.dart` — verify new prefix
- `mcp_server_dart/makefile` — binary names
- `mcp_server_dart/pubspec.yaml` — `executables` block
- `install.sh` — binary names + checksums
- Root `makefile` — top-level passthrough names if any
- All test/source files that reference `core_*` tool names — bulk update
- `CLAUDE.md` — references to `core_*` and old binary names
- `mcp_capability_core/lib/mcp_capability_core.dart` — export rename if class renamed

---

## Task 1: Inventory current `core_` usage

**Files:** None modified. Research only.

- [ ] **Step 1.1: Find every occurrence of `core_` in code + contracts**

Run:
```bash
grep -rn "core_" \
  --include="*.dart" \
  --include="*.txt" \
  --include="*.md" \
  --include="*.mdx" \
  --include="makefile" \
  --include="*.sh" \
  --exclude-dir=build \
  --exclude-dir=.dart_tool \
  --exclude-dir=node_modules \
  > /tmp/core_inventory.txt
wc -l /tmp/core_inventory.txt
```
Expected: substantial list (~30-50 hits). Save the file for reference during the rename.

- [ ] **Step 1.2: Find binary name occurrences**

Run:
```bash
grep -rn "flutter_mcp_cli\|flutter_inspector_mcp" \
  --include="*.dart" --include="*.sh" --include="*.md" --include="*.mdx" \
  --include="makefile" --include="*.yaml" --include="*.json" \
  --exclude-dir=build --exclude-dir=.dart_tool \
  > /tmp/binary_inventory.txt
wc -l /tmp/binary_inventory.txt
```
Expected: list of every reference. Skim for surprising hits (third-party deps, generated files).

- [ ] **Step 1.3: Verify capability id is the prefix source**

Run: `grep -n "id =>" mcp_capability_core/lib/src/core_capability.dart`
Expected: `String get id => 'core';` on one line. This is the surface to rename.

- [ ] **Step 1.4: Verify snapshot test path**

Run: `find mcp_server_dart/test -name "*surface*"`
Expected: `mcp_server_dart/test/tool_surface_snapshot_test.dart` (per CLAUDE.md).

No commit — research only.

---

## Task 2: Tool prefix — failing snapshot test

**Files:**
- Modify: `mcp_server_dart/test/tool_surface_snapshot_test.dart`

- [ ] **Step 2.1: Read the existing snapshot test**

Run: `cat mcp_server_dart/test/tool_surface_snapshot_test.dart`

- [ ] **Step 2.2: Update assertions to expect `fmt_` prefix**

The snapshot test compares the live tool surface against `tool/contracts/expected_tool_surface.txt`. After the rename, both must use `fmt_`. The test code itself should reference the prefix as a constant or read directly from the contract file. If hardcoded, update accordingly.

If the test reads from `expected_tool_surface.txt`, no change here — the test will start failing as soon as Task 3 changes the contract file. If the test has hardcoded `core_*` names anywhere, update them to `fmt_*`.

- [ ] **Step 2.3: Run test — expect FAIL** (because contract file still says `core_*` and live id is `core`)

Run: `cd mcp_server_dart && flutter test test/tool_surface_snapshot_test.dart`
Expected: any modification to test expectations causes a fail; if the test purely reads the contract, it still passes here. Either way, capture the current state — the rename in Task 4 should keep the test green.

- [ ] **Step 2.4: Commit**

If you modified the test:
```bash
git add mcp_server_dart/test/tool_surface_snapshot_test.dart
git commit -m "test(tool_surface): expect fmt_ prefix"
```
If no modification was needed (test reads contract dynamically), skip this commit.

---

## Task 3: Bulk-update the contract file

**Files:**
- Modify: `tool/contracts/expected_tool_surface.txt`

- [ ] **Step 3.1: Verify contents**

Run: `head -50 tool/contracts/expected_tool_surface.txt`
Expected: lines like `core_tap_widget`, `core_semantic_snapshot`, etc. (27 tool entries).

- [ ] **Step 3.2: Replace `core_` → `fmt_`**

Run: `sed -i.bak 's/^core_/fmt_/' tool/contracts/expected_tool_surface.txt`
Verify: `head -10 tool/contracts/expected_tool_surface.txt`
Expected: lines now start with `fmt_`.

- [ ] **Step 3.3: Remove the .bak file**

Run: `rm tool/contracts/expected_tool_surface.txt.bak`

- [ ] **Step 3.4: Confirm the diff is exactly the prefix change**

Run: `git diff tool/contracts/expected_tool_surface.txt | head -30`
Expected: every changed line is `-core_X` → `+fmt_X`, no other modifications.

- [ ] **Step 3.5: Commit**

```bash
git add tool/contracts/expected_tool_surface.txt
git commit -m "chore(contracts): rename tool prefix core_ → fmt_"
```

---

## Task 4: Rename `CoreCapability.id` to `'fmt'`

**Files:**
- Modify: `mcp_capability_core/lib/src/core_capability.dart`

- [ ] **Step 4.1: Update the id getter**

Edit `mcp_capability_core/lib/src/core_capability.dart`:

```dart
@override
String get id => 'fmt';
```

(Class name `CoreCapability` and file path stay the same for now — see Task 5 for optional class rename. The MCP-visible prefix is what `id` returns; that's the only thing that affects the public surface.)

- [ ] **Step 4.2: Run snapshot test — expect PASS**

Run: `cd mcp_server_dart && flutter test test/tool_surface_snapshot_test.dart`
Expected: All 27 tools register with `fmt_` prefix matching contract. Test green.

- [ ] **Step 4.3: Run the full mcp_server_dart suite**

Run: `cd mcp_server_dart && flutter test`
Expected: existing tests pass. Some tests may have hardcoded `core_*` strings; address those in Task 6.

- [ ] **Step 4.4: Commit**

```bash
git add mcp_capability_core/lib/src/core_capability.dart
git commit -m "feat(core_capability): rename MCP tool prefix core_ → fmt_"
```

---

## Task 5: (Optional) Rename `CoreCapability` class → `FmtCapability`

This task is **optional** for v3.0.0. The class name is internal — only `mcp_server_dart` consumes it. Rename improves consistency but is not user-facing. Skip if you want to minimize churn.

**Files:**
- Modify: `mcp_capability_core/lib/src/core_capability.dart` (or rename to `fmt_capability.dart`)
- Modify: `mcp_capability_core/lib/mcp_capability_core.dart` — update export
- Modify: every consumer of `CoreCapability` in `mcp_server_dart/`

- [ ] **Step 5.1: Decide — skip or proceed**

If skipping: jump to Task 6.

- [ ] **Step 5.2 (proceed): Find consumers**

Run: `grep -rn "CoreCapability" mcp_server_dart/ mcp_capability_core/lib/`

- [ ] **Step 5.3: Rename file**

```bash
git mv mcp_capability_core/lib/src/core_capability.dart \
       mcp_capability_core/lib/src/fmt_capability.dart
```

- [ ] **Step 5.4: Find/replace `CoreCapability` → `FmtCapability` across the inventory**

For each file in Step 5.2's output, edit `CoreCapability` → `FmtCapability` and update the import path from `'src/core_capability.dart'` to `'src/fmt_capability.dart'`.

- [ ] **Step 5.5: Run tests**

Run: `cd mcp_server_dart && flutter test && cd ../mcp_capability_core && dart test`
Expected: all pass.

- [ ] **Step 5.6: Commit**

```bash
git add -A
git commit -m "refactor(core_capability): rename class CoreCapability → FmtCapability"
```

---

## Task 6: Fix tests with hardcoded `core_*` tool names

**Files:**
- Modify: any `*_test.dart` files containing `core_<tool_name>` literals (per Step 1.1's inventory)

- [ ] **Step 6.1: Re-run inventory targeted at tests**

Run: `grep -rn "'core_" --include="*.dart" mcp_server_dart/test mcp_capability_core/test mcp_capability_kernel/test 2>/dev/null`
Expected: a finite list of test files referencing tool names by their string literal.

- [ ] **Step 6.2: Update each match**

For each line `'core_<tool>'` → `'fmt_<tool>'`. Be careful: only update strings that are MCP tool names. Do not touch `core_capability` (filename) or `CoreCapability` (class — handled by Task 5 if proceeded).

- [ ] **Step 6.3: Run all package tests**

Run:
```bash
cd mcp_server_dart && flutter test
cd ../mcp_capability_core && dart test
cd ../mcp_capability_kernel && dart test
cd ../mcp_shared_core && dart test
cd ../mcp_toolkit && flutter test
```
Expected: all green.

- [ ] **Step 6.4: Commit**

```bash
git add -A
git commit -m "test: update tool-name string literals core_ → fmt_"
```

---

## Task 7: Rename `flutter_mcp_cli` binary → `flutter-mcp-toolkit` *(completed in v3.0.0)*

**Files (current repo state):**
- `mcp_server_dart/makefile` — emits `build/flutter-mcp-toolkit`
- `mcp_server_dart/pubspec.yaml` — `executables` block
- `mcp_server_dart/bin/flutter_mcp_toolkit.dart` — CLI entry (renamed from legacy `flutter_mcp_cli.dart`)
- Root `makefile` if it references the binary

- [ ] **Step 7.1: Rename the bin entry-point Dart file** *(historical — already applied)*

The live entry point is `mcp_server_dart/bin/flutter_mcp_toolkit.dart`. When replaying history:

```bash
git mv mcp_server_dart/bin/flutter_mcp_cli.dart \
       mcp_server_dart/bin/flutter_mcp_toolkit.dart
```

- [ ] **Step 7.2: Update pubspec executables block**

Edit `mcp_server_dart/pubspec.yaml`:

```yaml
executables:
  flutter-mcp-toolkit: flutter_mcp_toolkit
  flutter-mcp-toolkit-server: <existing-server-entry-point>
```

(Replace `<existing-server-entry-point>` with whatever the current value is; see Task 8 for the server-side rename which fills this in.)

- [ ] **Step 7.3: Update `mcp_server_dart/makefile`**

Find every legacy reference to `flutter_mcp_cli` in `mcp_server_dart/makefile` — typically `dart compile exe bin/flutter_mcp_cli.dart -o build/flutter_mcp_cli` became `dart compile exe bin/flutter_mcp_toolkit.dart -o build/flutter-mcp-toolkit`.

- [ ] **Step 7.4: Update root makefile if applicable**

Run: `grep -n flutter_mcp_cli makefile Makefile 2>/dev/null || true`
Update any matches.

- [ ] **Step 7.5: Build**

Run: `cd mcp_server_dart && make compile`
Expected: produces `mcp_server_dart/build/flutter-mcp-toolkit`.

- [ ] **Step 7.6: Smoke test**

Run: `mcp_server_dart/build/flutter-mcp-toolkit --version`
Expected: prints version.

- [ ] **Step 7.7: Commit**

```bash
git add -A
git commit -m "build: rename CLI binary flutter_mcp_cli → flutter-mcp-toolkit"
```

---

## Task 8: Rename `flutter_inspector_mcp` server binary → `flutter-mcp-toolkit-server`

**Files:**
- Modify: `mcp_server_dart/makefile`
- Modify: `mcp_server_dart/pubspec.yaml`
- Modify: `mcp_server_dart/bin/flutter_inspector_mcp.dart` (rename)

- [ ] **Step 8.1: Find current bin file name**

Run: `ls mcp_server_dart/bin/`

- [ ] **Step 8.2: Rename**

```bash
git mv mcp_server_dart/bin/<current-server-bin>.dart \
       mcp_server_dart/bin/flutter_mcp_toolkit_server.dart
```

(Use `<current-server-bin>` from Step 8.1 — likely `flutter_inspector_mcp` or similar.)

- [ ] **Step 8.3: Update pubspec executables**

Edit `mcp_server_dart/pubspec.yaml`:

```yaml
executables:
  flutter-mcp-toolkit: flutter_mcp_toolkit
  flutter-mcp-toolkit-server: flutter_mcp_toolkit_server
```

- [ ] **Step 8.4: Update `mcp_server_dart/makefile`**

Replace every `flutter_inspector_mcp` (or current name) with `flutter-mcp-toolkit-server` for output paths and `flutter_mcp_toolkit_server` for source paths.

- [ ] **Step 8.5: Build**

Run: `cd mcp_server_dart && make compile`
Expected: produces both `flutter-mcp-toolkit` and `flutter-mcp-toolkit-server` in `build/`.

- [ ] **Step 8.6: Smoke test**

Run: `mcp_server_dart/build/flutter-mcp-toolkit-server --help`
Expected: prints help text.

- [ ] **Step 8.7: Commit**

```bash
git add -A
git commit -m "build: rename server binary → flutter-mcp-toolkit-server"
```

---

## Task 9: Update `install.sh` for new binaries

**Files:**
- Modify: `install.sh`

- [ ] **Step 9.1: Read current install.sh**

Run: `cat install.sh`

- [ ] **Step 9.2: Replace binary names**

In `install.sh`:
- `flutter_mcp_cli` → `flutter-mcp-toolkit`
- `flutter_inspector_mcp` (or current server name) → `flutter-mcp-toolkit-server`

- [ ] **Step 9.3: Update SHA256 placeholders if present**

If `install.sh` checks SHA256s of release artifacts, those values are tied to release artifacts that don't exist yet. Replace with `TBD-RELEASE` placeholders or remove the check pending the actual v3.0.0 release artifact build (Plan D / release ops).

- [ ] **Step 9.4: Add PATH update**

Per the spec (§3 Goals), `install.sh` should auto-update `$PATH` if `~/.local/bin` is not in it. Append:

```bash
# Append to user's shell profile if ~/.local/bin not in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
    profile="${ZDOTDIR:-$HOME}/.zshrc"
    [[ -f "$profile" ]] || profile="$HOME/.bashrc"
    if [[ -f "$profile" ]] && ! grep -q '\.local/bin' "$profile"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$profile"
        echo "Added ~/.local/bin to PATH in $profile (restart your shell)"
    fi
fi
```

- [ ] **Step 9.5: Smoke test the install script (dry-run)**

Run: `bash -n install.sh`
Expected: no syntax errors.

- [ ] **Step 9.6: Commit**

```bash
git add install.sh
git commit -m "build(install): update binary names and add PATH update"
```

---

## Task 10: Update CLAUDE.md and ARCHITECTURE.md references

**Files:**
- Modify: `CLAUDE.md`
- Modify: `ARCHITECTURE.md`

- [ ] **Step 10.1: Find references**

Run: `grep -n "core_\|flutter_mcp_cli\|flutter_inspector_mcp" CLAUDE.md ARCHITECTURE.md`

- [ ] **Step 10.2: Update each**

Replace:
- `core_<tool>` → `fmt_<tool>`
- `flutter_mcp_cli` → `flutter-mcp-toolkit`
- `flutter_inspector_mcp` → `flutter-mcp-toolkit-server`

- [ ] **Step 10.3: Commit**

```bash
git add CLAUDE.md ARCHITECTURE.md
git commit -m "docs: update CLAUDE.md + ARCHITECTURE.md for v3.0.0 names"
```

---

## Task 11: Run all contracts checks

**Files:** None modified. Verification only.

- [ ] **Step 11.1: Run check_sdk_parity**

Run: `bash tool/contracts/check_sdk_parity.sh`
Expected: pass.

- [ ] **Step 11.2: Run check_plugin_surfaces**

Run: `bash tool/contracts/check_plugin_surfaces.sh`
Expected: pass.

- [ ] **Step 11.3: Run check_error_code_playbook**

Run: `bash tool/contracts/check_error_code_playbook.sh`
Expected: pass. If this references `core_` strings inside `error_code_playbook.mdx`, update them in Task 12.

- [ ] **Step 11.4: Run check_docs_drift**

Run: `bash tool/contracts/check_docs_drift.sh`
Expected: pass OR report drift in `docs/core/built_in_tools.mdx` referring to `core_*`. That drift is fixed by Plan D's docs migration; for now, accept the failure or apply a targeted patch in Task 12.

---

## Task 12: Patch docs that contracts checks complained about

**Files:**
- Modify: any `docs/core/*.mdx` flagged by Task 11 contracts checks

- [ ] **Step 12.1: For each flagged doc, replace `core_` → `fmt_`**

Run targeted replacements only on the files contracts called out. Example for `error_code_playbook.mdx`:

```bash
sed -i.bak 's/core_/fmt_/g' docs/core/error_code_playbook.mdx
rm docs/core/error_code_playbook.mdx.bak
```

(Plan D will delete or migrate this file shortly; the patch ensures contracts pass in the interim.)

- [ ] **Step 12.2: Re-run all contracts checks from Task 11**

Run: `make check-contracts`
Expected: all green.

- [ ] **Step 12.3: Commit**

```bash
git add docs/
git commit -m "docs(core): update tool prefix in docs to satisfy contracts"
```

---

## Task 13: Plan C self-verify

- [ ] **Step 13.1: Run all package tests**

```bash
cd mcp_server_dart && flutter test
cd ../mcp_capability_core && dart test
cd ../mcp_capability_kernel && dart test
cd ../mcp_shared_core && dart test
cd ../mcp_toolkit && flutter test
```
Expected: all green.

- [ ] **Step 13.2: Build everything**

Run: `make build`
Expected: succeeds, both binaries with new names produced.

- [ ] **Step 13.3: Smoke test renamed binaries**

```bash
mcp_server_dart/build/flutter-mcp-toolkit --version
mcp_server_dart/build/flutter-mcp-toolkit-server --help
```
Expected: both work.

- [ ] **Step 13.4: Verify no remaining `core_` in tool names**

Run: `grep -rn "core_[a-z]" --include="*.dart" --include="*.txt" --include="*.mdx" mcp_server_dart mcp_capability_core mcp_capability_kernel tool docs 2>/dev/null | grep -v "core_capability"`
Expected: no matches (the only `core_capability` references are file names and class names, which are not user-facing tool prefixes).

- [ ] **Step 13.5: Mark Plan C complete**

Run: `git log --oneline -13`
Expected: ~13 commits.

---

## Self-Review

**Spec coverage:** §5 (naming alignment row) ✓ — tool prefix `fmt_` (Task 4), CLI binary `flutter-mcp-toolkit` (Task 7), server binary `flutter-mcp-toolkit-server` (Task 8), `install.sh` updates (Task 9). §6.1 rename table ✓ — every row has a task or is explicitly deferred (CorePrefix constant rename ride-along into Task 4; class rename Task 5 marked optional; pub package rename is operational and out-of-scope here per spec §6.1's "Pub" row notes the deprecated alias path which is a release-ops step).

**Type consistency:** `id => 'fmt'` is the single source of truth for the prefix. The contract file (`expected_tool_surface.txt`) and snapshot test agree. Class rename (`CoreCapability` → `FmtCapability`) is internal-only and explicitly optional.

**Placeholders:** Task 9 SHA256 step uses `TBD-RELEASE` deliberately — that placeholder is by design until Plan D's release-build pipeline fills it. This is documented intent, not unfilled-spec.

**TDD discipline:** The snapshot test (Task 2) is the failing test for the prefix rename; Task 4's id change makes it pass. Tasks 7-8 (binary renames) are build-config changes verified by smoke tests rather than unit tests — appropriate trade-off (no test framework for "`makefile` produces a binary at this path"; the smoke is the test).

**Independence:** Plan C does not consume Plan A's `SkillAssets` and does not produce inputs Plan B depends on at compile time (Plan B's prelude string `fmt_` is hardcoded). True parallel execution with Plan A is safe.

**Frequent commits:** 13 commits, one per task or sub-task.
