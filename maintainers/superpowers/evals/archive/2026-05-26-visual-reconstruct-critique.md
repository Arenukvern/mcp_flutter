> **ARCHIVED** — Historical snapshot. For current status see [visual reconstruct plan](../../plans/2026-05-26-visual-reconstruct-next.md) and [evals README](../README.md).

# Critique — visual reconstruct program (agents 1–2)

**Date:** 2026-05-26  
**Scope:** `flutter_visual_reconstruct`, `flutter_harness` HS v2, `mcp_flutter` dogfood warm path, docs scaffolding.

## What works

| Area | Verdict |
|------|---------|
| **Offline loop** | `compare_smoke.hs.yaml` + guild CLI — proven in CI fixture gate |
| **HS v2 ops** | `compare` / `checkpoint` implemented; offline run skips VM |
| **Architecture** | Four-repo split is clear in specs and RELATED_REPOS |
| **Dogfood hook** | `visual_fidelity` dimension + `run_visual_warm_path()` exists |
| **Docs index** | Both sibling repos have `docs/README.md` + NORTH_STAR |

## Gaps and risks

### P0 — Warm path will often fail with `default_guild`

`default_guild.yaml` uses `global_pixel` pass_threshold **0.98**. Live `capture_ui_snapshot` (Chrome, DPR, fonts) will not match widget golden `test/goldens/visual_reconstruct.png` at that bar. Dogfood will report `visual_fidelity_compare_failed` even when navigation succeeds.

**Fix:** `profiles/dogfood_warm.yaml` with relaxed thresholds; warm_path references it.

### P0 — Rubric weights exceed `max_score: 100`

Dimensions sum to **105** (webmcp still weighted 15 while capture dropped to 10 and visual +10). Scores can read >100 or confuse pass logic.

**Fix:** Align weights to 100 (e.g. webmcp 10).

### P1 — Verdict path pollutes harness git tree

`warm_path` writes `artifacts/verdict.yaml` under the example dir. Dogfood runs create dirty tracked paths.

**Fix:** `.gitignore` for `artifacts/` + `.hs_checkpoint/`; copy verdict into `eval_runs/<id>/` in dogfood script.

### P1 — `visual_fidelity_skipped` scoring loop is fragile

Bash nested loop only checks one warning name; easy to mis-score partial credit.

**Fix:** Explicit `grep -q` on warnings array before assigning `dim_visual`.

### P2 — No HS `route` op

Warm path relies on scroll + tap label **Open reconstruct fixture** — brittle on layout/viewport changes. Documented, not solved.

**Fix (later):** `navigate: { route: /visual-reconstruct }` or deep-link HS step.

### P2 — Warm path not in default CI

`check_hs_fixtures.sh` lints warm_path but does not run it (needs VM). Acceptable; document in eval README.

### P2 — `flutter_visual_reconstruct` has no `decisions/` yet

Harness has ADR stub; visual repo does not. OK for v0; add when guild format ADR is needed.

### P3 — Agent 1 did not verify live `WS_URI` run

Implementation is structurally correct; first green warm run requires human/agent with `make web-showcase`.

## Security / license

- MIT-only stack: satisfied.
- Creative-tool framing in spec: satisfied.
- User-supplied goldens only: satisfied.

## Recommendations (priority)

1. Ship `dogfood_warm.yaml` + wire warm_path (P0).
2. Rebalance rubric to 100 (P0).
3. Gitignore + eval artifact copy (P1).
4. Plan HS `navigate` / route op (P2).
5. Optional: score visual from `run_dir` verdict only, not repo-relative path (P1).
