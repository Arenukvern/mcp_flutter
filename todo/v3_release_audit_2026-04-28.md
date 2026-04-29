# v3.0.0 Release Audit — 2026-04-28

> **UPDATE 2026-04-29:** Live edit excised from v3.0.0. See scope note below.

**Branch:** `live-edit-v2-plannig` · **Versions:** `mcp_server_dart` 3.0.0, `mcp_toolkit` 3.0.0 · **Last tag:** v2.6.0
**Branch state:** 173 commits ahead of main · 748 files changed · 86k insertions / 180k deletions

This branch *is* the v3.0.0 release candidate, not a side feature branch. The number of touched files reflects a docs/structure overhaul bundled with the parity work.

---

## ✅ Working / shipped on the branch

- **Playwright parity P0–P2 fully landed:**
  - P0: `wait_for` (text / noText / stable / time predicates) + timeout payload shape + malformed-payload routing
  - P1: `press_key`, `handle_dialog` (dismiss), `navigate` (push/pop/popUntil), `MCPToolkitBinding.setNavigatorKey` opt-in API, ControlFlowService
  - P2: `fill_form` (stops on first toolkit-side failure), `hover` (PointerHoverEvent)
  - Server executors + handlers + tool registrations all in for each phase
- **DPR coordinate bug fixed** (commit `340e729`) — `resolveCenter/Bounds` return logical (not physical) coords. Regression test parameterized over DPR 1.0 / 2.0 / 3.0 lives at `mcp_toolkit/mcp_toolkit/test/semantic_snapshot_dpr_test.dart`.
- **Test coverage:** dedicated `p1_commands_test.dart`, `p2_commands_test.dart`, wait_for timeout/malformed-payload coverage, DPR regression. ~56 test files across server, toolkit, live_edit packages.
- **Toolkit polish:** P1 control-flow logging + popUntil guard (`a4b99ee`), error-code playbook path repair (`a0e2d4b`), `navigator_not_registered` recategorized as validation (`0bc907c`).

## 🛑 Not working / blockers

### 1. `make check-contracts` is RED
SDK parity fails: `pubspec.yaml` requires `^3.11.0`, both `Dockerfile` and `Dockerfile.dev` pin `dart:3.10.0-sdk`.

```
SDK parity failure: Dockerfile uses 3.10.0 but pubspec requires 3.11.0
make: *** [check-contracts] Error 1
```

Two-line fix in each Dockerfile. Currently gates the release (CI fails before remaining contract checks run, so plugin-surface and docs-drift status are also unverified).

### 2. Branch entanglement
`live-edit-v2-plannig` mixes three independent efforts:
- **Shippable:** Playwright parity P0–P2 + DPR fix
- **In-flight scaffolding:** selection state machine (new `flutter_live_edit/flutter_live_edit_toolkit/lib/src/services/selection_state_machine/`, modified `live_edit_host_overlay.dart`, currently uncommitted; design in `todo/selection_state_machine.md` — 5-phase plan, Phase 0 is a no-behavior-change harness)
- **Restructure:** large docs/file moves (180k deletions implies relocations, not pure removals)

This makes review and risk assessment harder than necessary.

### 3. Tool surface coupling — RESOLVED 2026-04-29
Live-edit's tools and the entire `flutter_live_edit/` subtree have been removed from the v3.0.0 release.

- `flutter_live_edit/` deleted: commit `d0a11c9`
- All live_edit code excised from `mcp_server_dart`: commit `2cea690`
- `mcp_server_dart/pubspec.yaml` no longer depends on any Flutter packages.
- The `uses-material-design` warnings noted in `CLAUDE.md` no longer appear.

The tool-surface inversion design (`todo/tool_surface_inversion.md`) is preserved for post-v3.0.0 re-integration of live_edit as an optional capability.

## ⚠️ Decisions required before tagging

1. **Release scope** — DECIDED 2026-04-29: **Option A selected.** v3.0.0 = Playwright parity + DPR fix. Live edit and tool-surface inversion deferred to post-v3.0.0.
2. **State-machine work:** stash/branch off (untracked files in `flutter_live_edit/` deleted with the subtree; design in `todo/selection_state_machine.md` preserved).
3. **Live-edit tool flagging** — RESOLVED: deferred entirely. No flag needed since live_edit is not shipped.

## 📋 Deferred / nice-to-have

- `select_option` (P2 audit deferral)
- `file_upload` (no host driver yet)
- Deep-section semantics polish — `todo/deep_section_semantics.md`
- P3 network introspection — spec implementation-ready, see `todo/p3_network_introspection_deferred.md`
- P4 tool consolidation — see `todo/p4_consolidation_research_2026-04-28.md`; defer until usage data

## Recommended next steps (in order)

1. ~~Decide release scope (A / B / C above).~~ — DONE: Option A, live_edit deferred.
2. Fix Dockerfile SDK pin → `dart:3.11.0-sdk` in both `Dockerfile` and `Dockerfile.dev`.
3. Re-run `make check-contracts` until fully green; resolve any remaining drift (plugin surfaces, docs).
4. ~~Either commit or stash the uncommitted state-machine work.~~ — DONE: `flutter_live_edit/` deleted.
5. ~~Resolve tool-surface inversion question.~~ — DONE: deferred to post-v3.0.0.
6. Audit `CHANGELOG` / release notes against actual shipped surface (P0–P2 + DPR fix).
7. Tag v3.0.0.

**Bottom line:** the shippable core (P0–P2 + DPR) is solid. The release is now gated only on a 2-line Dockerfile fix and a CHANGELOG audit — live_edit and tool-surface inversion no longer block the tag.
