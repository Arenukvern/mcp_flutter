# Deconstruct / reconstruct.start verification — Phase C (intentcall)

**Date:** 2026-05-26 (updated 2026-05-27)  
**Scope:** `mcp_flutter` C4 — app-side `reconstruct.start` metadata; dogfood eval hooks.  
**Depends on:** C2 `deconstruct` CLI (`flutter_visual_reconstruct`), C3 `deconstruct_smoke.hs.yaml` (`flutter_harness`) — **shipped**.

## What ships in mcp_flutter

| Surface | Location | Notes |
|---------|----------|--------|
| `dogfood_reconstruct_start` | `flutter_test_app/lib/agent_dogfood_entries.dart` | Returns `job: reconstruct.start`, `ir_schema`, `harness_smoke`, `route`, checkpoint hints |
| Dogfood eval (static) | `tool/evals/run_dogfood_eval.sh` | IR schema + golden PNG; lint `deconstruct_smoke.hs.yaml`; `deconstruct lint` when sibling repo present |
| Dogfood eval (optional run) | `--run-deconstruct-smoke` | Offline `flutter_harness run deconstruct_smoke.hs.yaml` |
| MCP server | **none** | App-side only (same as `dogfood_visual_reconstruct_info`) — discover via `fmt_list_client_tools_and_resources`, invoke `fmt_client_tool` name `dogfood_reconstruct_start` |

There is **no** `fmt_reconstruct_start` in `mcp_server_dart`; cold-path orchestration stays in the Flutter app dynamic registry until a host-level tool is justified.

## Quick verify (static only)

```bash
cd /path/to/mcp_flutter

dart analyze flutter_test_app/lib/agent_dogfood_entries.dart

bash tool/evals/run_dogfood_eval.sh --skip-runtime
# → ${repo}/.showcase/eval_runs/<id>/deconstruct_static.log
```

**Pass when:**

- `specs/ir_v0.schema.yaml` exists under `HARNESS_ROOT` (default `../flutter_harness`)
- `flutter_test_app/test/goldens/visual_reconstruct.png` exists
- `deconstruct_smoke.hs.yaml` lints; log shows successful `deconstruct lint` when `flutter_visual_reconstruct` is present

## Offline deconstruct smoke

```bash
cd ../flutter_harness
dart run bin/flutter_harness.dart lint \
  harness/examples/visual_reconstruct/deconstruct_smoke.hs.yaml
dart run bin/flutter_harness.dart run \
  harness/examples/visual_reconstruct/deconstruct_smoke.hs.yaml \
  --bundle-dir /tmp/deconstruct_smoke_bundle

cd ../mcp_flutter
bash tool/evals/run_dogfood_eval.sh --skip-runtime --run-deconstruct-smoke
```

Or from repo root with siblings at default paths:

```bash
FLUTTER_MCP_TOOLKIT_ROOT=. bash flutter_harness/tool/harness/check_hs_fixtures.sh
bash tool/evals/run_dogfood_eval.sh --skip-runtime --run-deconstruct-smoke
```

## Runtime invoke (VM / MCP)

```bash
DOGFOOD_VISUAL=1 make web-showcase
export WS_URI='ws://127.0.0.1:8181/<token>/ws'

dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart \
  --vm-service-uri "$WS_URI" \
  exec --name list_client_tools_and_resources --args '{}'

dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart \
  --vm-service-uri "$WS_URI" \
  exec --name client_tool --args '{"name":"dogfood_reconstruct_start","arguments":{}}'
```

Expect `data.job == reconstruct.start`, `data.route == /visual-reconstruct`, and paths under `ir_schema` / `harness_smoke`.

## Deconstruct lint on golden (C2)

```bash
cd ../flutter_visual_reconstruct
dart run deconstruct lint --input ../mcp_flutter/flutter_test_app/test/goldens/visual_reconstruct.png
```

## Cross-repo gates

| Repo | Gate |
|------|------|
| flutter_visual_reconstruct | `deconstruct` CLI + `dart test` |
| flutter_harness | `deconstruct_smoke.hs.yaml` + HS `deconstruct` / `reconstruct` ops |
| mcp_flutter | This doc + `dogfood_reconstruct_start` + eval static/smoke hooks |

## Related

- [Phase C coordination (archived)](../plans/archive/2026-05-26-phase-c-deconstruct-coordination.md)
- [Visual reconstruct plan](../plans/2026-05-26-visual-reconstruct-next.md)
- [WebMCP verification](./2026-05-26-webmcp-verification.md) (warm path; distinct from cold IR)
