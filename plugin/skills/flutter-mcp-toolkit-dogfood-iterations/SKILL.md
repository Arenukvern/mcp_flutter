---
name: flutter-mcp-toolkit-dogfood-iterations
description: Runs and records flutter_test_app dogfood iterations (tool_quality_rubric, run_dogfood_eval.sh, dogfood_web_eval.yaml). Use when scoring MCP/agentkit quality, appending iteration N, comparing regressions, or CI static/weekly eval gates.
---

<!-- @FMT_MODE_PRELUDE -->

# Dogfood iterations

Tracker: `.showcase/dogfood_web_eval.yaml`  
Rubric: `docs/superpowers/evals/tool_quality_rubric.yaml`  
Overview: `docs/superpowers/evals/README.md`

## Pass threshold

**≥80/100** weighted; ship at **≥90** or accepted `pass_with_warnings`.

| Dimension | Weight |
|-----------|--------|
| connectivity | 20 |
| schema_validity | 10 |
| handler_correctness | 20 |
| capture_quality | 10 |
| visual_fidelity | 10 |
| webmcp_parity | 10 |
| agentkit_authoring | 10 |
| docs_truth | 10 |

## Iteration workflow

```
Task Progress:
- [ ] Start app (web-showcase or make showcase)
- [ ] Fresh WS_URI from log (not stale after hot reload)
- [ ] Run battery
- [ ] Record score + warnings in tracker
- [ ] Promote recurring patterns if repeated ≥2 times
```

### Web iteration

```bash
make web-showcase
export WS_URI="$(grep -Eo 'ws://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' .showcase/web_app.log | tail -1)"
bash tool/evals/run_dogfood_eval.sh --ws-uri "$WS_URI" --merge --skip-visual   # yq or dart fallback
# or without merge:
bash tool/evals/run_dogfood_eval.sh --ws-uri "$WS_URI"
```

Auto-runs: static gates + `validate-runtime` + `webmcp verify`.

### Static only (CI / PR)

```bash
make dogfood-eval-static
```

### Makefile

```bash
make dogfood-eval          # needs WS_URI in env
make dogfood-eval-static
```

## Artifacts

- Per run: `.showcase/eval_runs/<timestamp>/eval_run.yaml`
- Snapshot: `.showcase/eval_run_<timestamp>.yaml`
- With `--merge`: updates `dogfood_web_eval.yaml` (`yq` or `dart run mcp_server_dart/tool/merge_dogfood_tracker.dart`)

## Verdicts

| Verdict | Meaning |
|---------|---------|
| `pass` | score ≥80, no blocking warnings |
| `pass_with_warnings` | score ≥80, e.g. `visual_capture_truth_mode` |
| `fail` | score <80 |
| `blocked_no_runtime` | `--skip-runtime` only |

## Exec vs MCP names

Document in iteration notes when testing invoke:

- **exec:** bare names (`get_recent_logs`, `dogfood_ping`) — also accepts `fmt_*` aliases
- **MCP:** `fmt_` prefix (`fmt_get_recent_logs`, `fmt_client_tool` + listing `name`)
- **Connection:** global `--vm-service-uri` (not `exec --target`)

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart \
  --vm-service-uri "$WS_URI" exec --name get_recent_logs --args '{}'
```

## Chrome battery notes

- Skip heavy visual harness unless `HARNESS_ROOT` points at `flutter_harness`: add `--skip-visual`
- `validate-runtime --save-images` can hang >5m on Chrome; battery omits it unless `DOGFOOD_SAVE_IMAGES=1`

## CI (branch)

`.github/workflows/agentkit_eval.yml` — PR: `dogfood-eval-static`; weekly/main: agentkit package tests + static.

Full Chrome runtime dogfood stays **local** until headless WebMCP is cost-effective.

## After each iteration

1. Diff `dimension_scores` vs previous iteration in tracker.
2. Add to `recurring_warnings` / `recurring_errors` when repeated.
3. Update `fix_recommendations` with actionable doc/code deltas.
4. Do **not** treat tracker YAML as gate without a fresh battery run.

## Related skills

- `flutter-mcp-toolkit-maintain-web` — WebMCP launch + verify
- `flutter-mcp-toolkit-maintain-macos` — macOS showcase
- `flutter-mcp-toolkit-repo-maintainer` — `make sync-skills` after editing this skill
