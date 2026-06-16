> **ARCHIVED** — Historical snapshot (iterations 1–11). For current status see [evals README](../README.md) and [dogfood tracker](../../../.showcase/dogfood_web_eval.yaml).

# Dogfood vs intentcall spec — gap matrix

**Date:** 2026-05-26  
**Spec:** Historical IntentCall in-repo design and Bar D pre-extract completion docs were removed after durable extraction to `/Users/anton/mcp/agentkit`; this archived eval remains a snapshot of the old gap analysis.
**Evidence:** [`.showcase/dogfood_web_eval.yaml`](../../../.showcase/dogfood_web_eval.yaml) (iterations 1–10), code + CI on `feat/intentcall-phase1-3`

## Summary

| Verdict | Count |
|---------|-------|
| none | 4 |
| low | 5 |
| medium | 1 |
| high | 3 |

**Dogfood:** iterations 1–7 and **11** scored 100/100. Iterations 8–10 scored 98 with `pass_with_warnings` (visual harness only; runtime + WebMCP green). Tracker: 11 iterations, `pass_with_warnings`.

---

## Gap matrix

| Spec requirement | In-repo status | Evidence | Gap severity |
|------------------|----------------|----------|--------------|
| Web WebMCP (`navigator.modelContext.registerTool`, JS + Dart bootstrap) | Shipped (with Chrome flags) | `agent_web_mcp_bootstrap_web.dart`, `intentcall_webmcp.generated.js`, `make web-showcase`, `webmcp verify`; iter **7** `webmcp_verdict: webmcp_active` | **low** — plain `flutter run -d chrome` omits flags |
| WebMCP registry hot-sync (`WebMcpPublishAdapter`) | Package + tests; not in dogfood app | `intentcall/packages/intentcall_webmcp`; eval note: dogfood uses `AgentWebMcpBootstrap` | **low** |
| Dynamic app tools + delayed registration | Shipped | Iter **4** (21 tools); iter **5** `dogfood_ping`; `agent_dogfood_entries.dart` | **none** (VM path) |
| Dynamic listing name vs qualified descriptor | Documented asymmetry | `INTENTCALL_PLATFORM.md`; tracker `fix_recommendations` | **low** |
| `init intentcall-platform` + `codegen sync` | Shipped | CLI + tests; `make check-contracts`; dogfood static battery | **none** locally |
| CI drift gates on every PR | Partial | Gating: `intentcall_eval.yml` → `dogfood-eval-static`; gap: full `check-contracts`, skills grep | **high** |
| Headless WebMCP / Chrome runtime in CI | Deferred | [evals README](./README.md) — local runtime dogfood | **high** |
| Dogfood app (`flutter_test_app`) | Strong web coverage | 10 iterations; hand-written `AgentCallEntry`; legacy `mcpToolkitTool` demos remain | **low** |
| macOS dogfood parity | Sparse | Integration closure macOS validate-runtime; no macOS iteration tracker file | **medium** |
| CLI exec vs MCP `fmt_*` names | Shipped | `CommandCatalog.resolveExecCommandName`; iter **3**; `INTENTCALL_PLATFORM.md` | **none** |
| ADR 0008 — no Flutter `/agent/invoke` route | Accepted | [0008](../../decisions/0008_web_agent_invoke_js_only.mdx); JS `fetch` **404** expected | **none** for gate |
| `MCPCallEntry` hard cut | Done | Phase 6; `migrate agent-entries --check` in battery | **none** |
| Server `@AgentTool` codegen (≥1 fmt_*) | Pilot only | `fmt_get_recent_logs` codegen; second tool deferred | **low** (by policy) |
| Live manifest from registry | Not done | Manual `web/agent_manifest.json`; tracker `deferred_work` | **high** for automation |
| Visual reconstruct / harness dogfood | Partial | Iter **8–10** metadata tool + `visual_compare_pass`; harness errors recurring | **low** |
| `fmt_migrate_agent_entries` + migration docs | Done | MCP tool + migration skill + phase6 doc | **none** |

---

## Top remaining product gaps (dogfood lens)

1. **PR CI ≠ local `check-contracts`** — migrate/init/codegen partially gated via `dogfood-eval-static`; skills grep and contract suite not all fail PRs.
2. **Manual `web/agent_manifest.json`** — JS manifest tools vs runtime Dart bootstrap mismatch until registry→manifest pipeline ships.
3. **`WebMcpPublishAdapter` not exercised in `flutter_test_app`** — hot-sync path untested in browser for this app.
4. **JS `/agent/invoke` 404** (ADR 0008) — PWA/JS fetch path inert without WebMCP + Dart bootstrap.
5. **macOS / headless eval** — no comparable iteration series to web tracker; runtime CI battery absent.

---

## Suggested iteration focuses (11+)

| Theme | Goal |
|-------|------|
| I11 — CI truth | Promote `check_intentcall_skills_grep.sh` + fail-hard contract steps on PR |
| I12 — macOS dogfood | `run_dogfood_eval.sh --macos --merge` or dedicated tracker YAML |
| I13 — WebMcpPublishAdapter | Wire in dogfood or document bootstrap-only + browser test |
| I14 — Manifest automation | `generateWebAgentManifest` spike or single-workflow README |
| I15 — Visual harness | Green `visual_fidelity` / warm-path on iter 8–10 warnings |

---

## Related

- [Integration completion plan](../../plans/archive/2026-05-26-intentcall-integration-completion-next.md)
- [WebMCP verification](../2026-05-26-webmcp-verification.md)
- [tool_quality_rubric.yaml](../tool_quality_rubric.yaml)
- [intentcall-rollout.yaml](../../tracker/intentcall-rollout.yaml)
