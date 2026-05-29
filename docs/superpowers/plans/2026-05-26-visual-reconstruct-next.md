# Plan — visual reconstruct (post warm-path)

**Status:** **Maintenance** — checkpoint protocol + optional runtime E2E only  
**Living tracker:** [`.showcase/dogfood_web_eval.yaml`](../../../.showcase/dogfood_web_eval.yaml) · [evals README](../evals/README.md)  
**Archived critique:** [evals/archive/2026-05-26-visual-reconstruct-critique.md](../evals/archive/2026-05-26-visual-reconstruct-critique.md)

## Key design decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Dogfood guild | Separate `dogfood_warm.yaml` | Strict `default_guild` for offline smoke; relaxed for live capture |
| Verdict artifact | Copy to `eval_runs/<id>/visual_verdict.yaml` | Avoid relying on harness example tree for history |
| Route to fixture | HS `navigate` + `DOGFOOD_VISUAL=1` boot | Shipped; canonical warm path is `warm_path_direct.hs.yaml` (not tap `warm_path.hs.yaml`) |
| IR / deconstruct | Offline green (Phase C) | Warm compare green; cold path: `deconstruct` CLI + HS smoke + `reconstruct.start` metadata |

## Phase A — Dogfood green (this sprint)

- [x] HS `warm_path_direct.hs.yaml` (canonical) + `warm_path.hs.yaml` (legacy tap path) + rubric dimension
- [x] `profiles/dogfood_warm.yaml` + normalize + warm_path guild pointer
- [x] Rubric weights = 100; dogfood scoring fix for skip path
- [x] `.gitignore` harness example artifacts
- [x] Copy verdict into eval run dir
- [x] Live warm path green (`DOGFOOD_VISUAL=1`, `flutter_layer` capture, introspection hardening)
- [x] Dogfood iterations 13–17 @ score 100, `visual_fidelity: 10`

**Repo roadmaps:** [flutter_harness/plans/2026-05-26-roadmap.md](https://github.com/Arenukvern/flutter_harness/blob/main/plans/2026-05-26-roadmap.md) · [flutter_visual_reconstruct/plans/2026-05-26-roadmap.md](https://github.com/Arenukvern/flutter_visual_reconstruct/blob/main/plans/2026-05-26-roadmap.md)

## Phase B — Reliability

- [x] HS `navigate` step (route name or URI) — harness v2 bump if needed
- [x] `compare.out` may be relative to `--bundle-dir` when set
- [x] Document viewport/DPR pinning for warm path (Chrome 8080) — [evals README](../evals/README.md), [goldens README](../../../flutter_test_app/test/goldens/README.md)
- [x] Dogfood merge records `visual_guild_weighted_score` (tracker iterations 13–17+)

## Phase 5 (v1) — Perceptual & semantic regions

- [x] `semantic_region_manifest.dart` + HS `regions_from_snap`
- [x] `global_phash` / `region_phash` judges + `perceptual_guild.yaml`
- [x] Profile pack (`profiles/pack.yaml`, `docs/profile-pack.md`)

## Phase C — Cold path

- [x] IR v0 schema draft in `flutter_harness` — [specs/ir_v0.schema.yaml](https://github.com/Arenukvern/flutter_harness/blob/main/specs/ir_v0.schema.yaml)
- [x] Deconstruct sidecar (MIT tile heuristics) — `flutter_visual_reconstruct` C2 (`deconstruct` CLI, `dart test` green)
- [x] HS `deconstruct` / `reconstruct` ops + `deconstruct_smoke.hs.yaml` offline — `flutter_harness` C3
- [x] intentcall: `dogfood_reconstruct_start` (`reconstruct.start` metadata, eval static hook) — [verification](../evals/2026-05-26-deconstruct-verification.md)
- [x] C5 offline integration — `check_hs_fixtures.sh`, `run_dogfood_eval.sh --skip-runtime --run-deconstruct-smoke`
- [ ] checkpoint protocol (HS + human `.approved`) — deferred past C4 metadata

## Verification

```bash
# Offline compare
cd flutter_harness && dart run bin/flutter_harness.dart run \
  harness/examples/visual_reconstruct/compare_smoke.hs.yaml

# Offline deconstruct (Phase C)
cd flutter_visual_reconstruct && dart test
cd flutter_harness && dart test
FLUTTER_MCP_TOOLKIT_ROOT=../mcp_flutter bash flutter_harness/tool/harness/check_hs_fixtures.sh
bash mcp_flutter/tool/evals/run_dogfood_eval.sh --skip-runtime --run-deconstruct-smoke

# Warm (requires WS_URI)
make -C mcp_flutter web-showcase
export WS_URI='ws://…'
bash mcp_flutter/tool/evals/run_dogfood_eval.sh --merge
```

## Resolved (VR-01–VR-06)

| ID | Issue | Resolution |
|----|-------|------------|
| VR-01 | default_guild too strict for warm capture | `dogfood_warm.yaml` + warm_path guild (Phase A) |
| VR-02 | Rubric 105/100 | Weights normalized to 100 (Phase A) |
| VR-03 | Dirty artifacts in harness repo | `.gitignore` + verdict copy to eval run dir (Phase A) |
| VR-04 | No navigate op | HS `navigate` shipped (Phase B) |
| VR-05 | bundle-relative compare out | `--bundle-dir` relative `compare.out` (Phase B) |
| VR-06 | Cold deconstruct pipeline | C2–C5 offline green; [deconstruct verification](../evals/2026-05-26-deconstruct-verification.md) |

## Remaining

| ID | Issue | Notes |
|----|-------|-------|
| VR-07 | Checkpoint protocol (HS + human `.approved`) | Deferred past C4 metadata; only open track item |
| — | Runtime warm-path E2E | Optional maintenance — iterations 13–17 @ 100; iter 18 `visual_fidelity_skipped` when harness/compare skipped |

## What's next

- Define and land **checkpoint protocol** (HS `checkpoint` + human `.approved` gate) in `flutter_harness` / `flutter_visual_reconstruct`.
- Re-run **warm-path dogfood** when changing goldens or guild thresholds (`DOGFOOD_VISUAL=1`, `warm_path_direct.hs.yaml`).
- Optional: full **runtime E2E** for cold reconstruct (beyond offline `deconstruct_smoke` + static eval hooks).
