> **ARCHIVED** — Historical snapshot (Complete 2026-05-27). For current status see [Phase 7 extract](../2026-05-27-intentcall-phase7-extract.md) and [tracker](../../tracker/intentcall-rollout.yaml).

# intentcall — integration completion plan (in-repo only)

**Date:** 2026-05-26 (updated after dogfood iterations 7–10)  
**Status:** Complete (2026-05-27) — I2 gating shipped; I4/I5/I6 documented or scripted  
**Source of truth:** Code + CI + [tracker](../../tracker/intentcall-rollout.yaml). Do **not** trust unchecked boxes in archived plans.

**Out of scope:** Phase 7 monorepo extract, pub.dev publish, Gemma product wiring, HarmonyOS.

**Dogfood tracker:** [`.showcase/dogfood_web_eval.yaml`](../../../.showcase/dogfood_web_eval.yaml) (10 iterations; spec gap matrix: [evals/archive/2026-05-26-dogfood-spec-gap-matrix.md](../../evals/archive/2026-05-26-dogfood-spec-gap-matrix.md)).

---

## Verified state (audit 2026-05-26, refreshed)

| Area | Verdict | Evidence |
|------|---------|----------|
| Registry + MCP adapter | **Done** | `intentcall_core`, `intentcall_mcp`, `McpHost` registry-only path |
| `MCPCallEntry` hard cut | **Done** | Grep clean in `mcp_toolkit/`, `flutter_test_app/` |
| Platform emitters + `codegen sync` | **Done** | `intentcall/packages/intentcall_platform`, dogfood artifacts; static `--check` in dogfood battery |
| `init intentcall-platform` | **Done** | `init_intentcall_platform_command.dart`, tests; `--check` in dogfood battery |
| `fmt_migrate_agent_entries` | **Done** | `migrate_agent_entries_tool.dart`, `expected_tool_surface.txt`; migration skill |
| Client DX tests | **Done** | `entry_invoke_test.dart` envelope pattern |
| Operator docs / skills | **Done** | `flutter-mcp-toolkit-intentcall-migration` SKILL: `fmt_migrate_agent_entries` shipped; `migration_intentcall_phase6.md` present-tense + `INTENTCALL_PLATFORM.md` link |
| CI enforcement | **Done** | Gating: `intentcall-static` + `intentcall-integration` (`make check-intentcall-integration`) on every PR |
| Live manifest pipeline | **Gap** | Manual `web/agent_manifest.json` (tracker `deferred_work`) |
| `flutter_test_app` authoring demo | **Done** | Hand-written `AgentCallEntry` in `lib/agent_dogfood_entries.dart` (`dogfood_ping`, `dogfood_visual_reconstruct_info`); legacy `mcpToolkitTool` retained for fibonacci/preferences demos |
| Web dogfood / WebMCP | **Done** | Iterations 1–7 score 100; iter 7 `webmcp_verdict: webmcp_active` (CDP). Iters 8–10: `pass_with_warnings` (visual harness warm-path; runtime green) |
| Showcase validate-runtime | **Done (web)** | Dogfood iters 1–10 `validate_runtime_ok: true` on chrome; macOS tracker series still optional (I5) |

**Program label:** `complete_in_repo_product` means **product code shipped**. Remaining integration hardening: **I2 full CI parity**, **I4 manifest automation**, **I5 macOS re-verify**, **I6 release hygiene**.

---

## Key design decisions

1. **No new phases in tracker** — use this plan + tracker `deferred_work` only; archive executable phase-6 plan.
2. **CI is part of “integration complete”** — local `make check-contracts` must match a gating GitHub job.
3. **Docs follow code** — regenerate `skill_assets` after skill edits; closures are historical snapshots with banners.
4. **Manifest automation is optional for gate** — document manual workflow until registry→manifest wiring ships.
5. **Second `@AgentTool` fmt_* stays pilot-only** — not required for integration complete.

---

## Workstreams (priority order)

### I1 — Doc & operator truth (P0) — **done**

| Task | Status | Evidence |
|------|--------|----------|
| Fix migration skill: `fmt_migrate_agent_entries` shipped | **done** | `plugin/skills/flutter-mcp-toolkit-intentcall-migration/SKILL.md` |
| `make sync-skills` | **done** | `mcp_server_dart/lib/src/skill_assets.g.dart` (run after skill edits) |
| Present-tense `migration_intentcall_phase6.md` | **done** | No “ahead of 6b”; § Platform hooks → `INTENTCALL_PLATFORM.md` |
| CLI `migrate` help text | **done** | `flutter_mcp_toolkit.dart` usage (verify on CLI touch) |
| Archive `2026-05-26-intentcall-phase6-pre-extract.md` | **done** | `plans/archive/` + “ARCHIVED — do not execute” banner |
| Closure README + historical banners | **done** | `docs/superpowers/closure/README.md` |

### I2 — CI integration gate (P0) — **done**

| Task | Status | Evidence |
|------|--------|----------|
| Gating static dogfood on PR/push | **done** | `.github/workflows/intentcall_eval.yml` job `intentcall-static` |
| Weekly intentcall package matrix | **done** | Job `intentcall-weekly` |
| Full matrix + contract tests on every PR | **done** | Job `intentcall-integration` → `make check-intentcall-integration` |
| `check_intentcall_skills_grep.sh` on every PR | **done** | Included in integration script |
| Tracker `ci_gates` updated | **done** | `intentcall-rollout.yaml` |

Canonical integration gate (Phase 7 workspace):

```bash
make check-intentcall-integration
make dogfood-eval-static
# Runtime: make web-showcase → export WS_URI → make dogfood-eval
```

Equivalent manual breakdown:

```bash
cd intentcall && make test && make analyze
dart test packages/server_capability_kernel packages/server_capability_core
cd mcp_server_dart && dart test && dart test test/contract/
bash tool/contracts/check_intentcall_skills_grep.sh
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart migrate agent-entries --check flutter_test_app/lib
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init intentcall-platform --check --project-dir flutter_test_app
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
  --platform web,android,ios,macos,linux,windows --project-dir flutter_test_app --check
```

Optional: `cd mcp_toolkit && flutter test` (slower; run on main or nightly — partially covered by `intentcall-weekly` package tests).

### I3 — Dogfood authoring (P1) — **done**

| Task | Status | Evidence |
|------|--------|----------|
| Hand-written `AgentCallEntry.tool` in `flutter_test_app` | **done** | `lib/agent_dogfood_entries.dart`; wired in `main.dart`; iter 5 invoke `dogfood_ping`; iter 8–10 visual reconstruct metadata tool |
| Document platform ops in migration doc | **done** | `migration_intentcall_phase6.md` § Platform hooks → `flutter_test_app/INTENTCALL_PLATFORM.md` |
| Optional: `AgentClientInstall.once` example | **deferred** | Not required for gate |

### I4 — Platform loop (P1–P2, optional for “strict” complete)

| Task | Done when |
|------|-----------|
| Wire `generateWebAgentManifest` from descriptor export OR | `codegen sync` reads generated manifest |
| Document single workflow in `intentcall_platform/README` | Errors in `PlatformSync` match workflow |

### I5 — Runtime re-verification (P0 before release tag)

| Task | Status | Evidence |
|------|--------|----------|
| `make check-contracts` exit 0 | **done** at product gate | Re-run before release tag if contracts touched |
| `make showcase` + macOS `validate-runtime` | **scripted** | `make macos-validate-runtime` (needs `MACOS_WS_URI`); not gating CI |
| Web showcase + `validate-runtime` chrome | **done** | Dogfood iters 1–10; `make web-showcase` + battery |
| Closer append to product closure | **open** | Optional fresh timestamps before merge to `main` |

### I6 — Semver & release hygiene (P1, when merging to main)

| Task | Done when |
|------|-----------|
| `mcp_toolkit` major bump plan in CHANGELOG | Phase 6 breaking section complete |
| Plugin marketplace copy points to migration doc | `docs/ai_agents/marketplace_copy.yaml` |

---

## Definition of done — “integration complete” (in-repo)

1. **Zero stale operator lies** — skills, migration doc, CLI help match shipped tools. (**I1 done**)
2. **CI gates** — intentcall matrix + contracts + grep + migrate + init + codegen `--check` fail PRs. (**I2 partial** — static dogfood gating only)
3. **Dogfood** — `flutter_test_app` demonstrates `AgentCallEntry` + platform hooks + validate-runtime green. (**I3 + web runtime done**)
4. **Tracker** — `deferred_work` only lists real future work (extract, manifest automation, second codegen pilot, Gemma product, HarmonyOS).
5. **Phase 7** — still `pending`; no extract work started.

---

## Explicit non-goals

- Standalone intentcall monorepo (Phase 7)
- `flutter_gemma` in shipping app
- HarmonyOS / Intents Kit
- Mandatory second `@AgentTool` server tool
- Flutter `/agent/invoke` route (ADR 0008: JS + WebMCP sufficient)

---

## References

| Doc | Role |
|-----|------|
| [2026-05-25-intentcall-design.md](../../specs/2026-05-25-intentcall-design.md) | Architecture north star |
| [2026-05-26-intentcall-pre-extract-completion-design.md](../../specs/2026-05-26-intentcall-pre-extract-completion-design.md) | Bar D (delivered) |
| [intentcall-rollout.yaml](../../tracker/intentcall-rollout.yaml) | Machine state |
| [2026-05-26-intentcall-product-complete-in-repo.md](../../closure/2026-05-26-intentcall-product-complete-in-repo.md) | Product gate snapshot |
| [2026-05-26-dogfood-spec-gap-matrix.md](../../evals/archive/2026-05-26-dogfood-spec-gap-matrix.md) | Spec vs dogfood gaps |
| [migration_intentcall_phase6.md](../../../start_here/migration_intentcall_phase6.md) | Operator migration |
