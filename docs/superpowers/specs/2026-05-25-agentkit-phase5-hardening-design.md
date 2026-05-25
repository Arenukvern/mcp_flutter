# Agentkit Phase 5 — Hardening Design

**Status:** Approved (2026-05-26)  
**Program:** Phases 1–4 complete (in-repo milestone). Phase 5 sequences follow-up without changing runtime behavior until B/C execute.  
**Tracker:** [../tracker/agentkit-rollout.yaml](../tracker/agentkit-rollout.yaml)  
**Rollout:** [../plans/2026-05-25-agentkit-rollout.md](../plans/2026-05-25-agentkit-rollout.md)

---

## Summary

Phase 5 hardens the agentkit program after the registry-backed MCP resource and hot-sync work (Phase 4). Work splits into three sub-phases: **A** documentation and tracker honesty, **B** runtime consolidation in the consumer workspace, **C** authoring and optional codegen. No requirement to extract a standalone repo or remove shims in this phase unless explicitly scheduled in B/C.

---

## Sub-phase A — Documentation & program hygiene

**Status:** Done (2026-05-26)

Goals:

- Align [rollout](../plans/2026-05-25-agentkit-rollout.md) phase table with tracker (phases 1–4 `done`, Phase 5 row).
- Set honest `program.status` and `deferred_work` in tracker.
- Correct closure language: WebMCP and Gemma are **shipped adapters** (Gemma is **example-only**, not product-wired to `flutter_gemma`).
- Mark phase 1–3 implementation plans as historical; point to this spec for follow-up.
- Note Phase 1 codegen: **annotations-only** (`agentkit_codegen`); no `build_runner` generator yet.

Checklist (5-A):

- [x] Rollout phase map and current action updated
- [x] Tracker `phase5` + `deferred_work`
- [x] Phase 3 exit criteria wording (webmcp/gemma)
- [x] Closure reports phase1/phase3 wording
- [x] Historical banners on phase plans 1–3
- [x] This hardening spec published

---

## Sub-phase B — Runtime consolidation (done)

**Status:** Done (2026-05-26)

- Single clear attach path for `AgentRuntime` in `mcp_server_dart` / toolkit host (reduce duplicate registration bridges).
- Confirm dynamic registry ↔ registry hot-sync coverage for tools and resources (build on Phase 4).
- Deprecation notes for any remaining dual-publish paths; document migration for capability authors.
- Validation matrix unchanged: existing `dart test` / `dart analyze` gates per tracker phase rows.

Non-goals for B:

- Standalone agentkit monorepo extract.
- Removing `mcp_flutter` public re-export shims.

---

## Sub-phase C — Authoring & codegen (done)

**Status:** Done (2026-05-26)

Goals:

- `agentkit_codegen`: optional `build_runner` generator for `@AgentTool` → `RegisteredAgentIntent` (pilot one package).
- Client/server symmetry documented in design spec (hand-written + codegen both first-class).
- Example: one hand-written and one generated tool in `flutter_test_app` or toolkit example.
- Apple/Android manifest codegen: expand from “started” to documented author workflow.

Checklist (5-C):

- [x] `AgentToolGenerator` + `build.yaml` in `agentkit_codegen`
- [x] Test fixture + `build_test` coverage
- [x] `@Deprecated` on `MCPCallEntry`; `toAgentCallEntry()` bridge
- [x] `mcp_toolkit/example/agent_call_entry_starter.dart`
- [x] `agentkit_apple` / `agentkit_android` README author workflows
- [x] Closure report + tracker 5c done

Non-goals for C:

- Mandatory codegen for all consumers.
- Gemma product integration (`flutter_gemma` wiring in shipping app).

---

## Explicit deferrals (out of Phase 5 unless rescoped)

| Item | Rationale |
|------|-----------|
| Standalone **agentkit** monorepo split | Consumer workspace milestone sufficient; extract when release/versioning needs it |
| **Public shim** removal | Deprecation window; breaking importers without semver bump |
| **Gemma product wiring** | `agentkit_gemma` ships example-only registrar callbacks; `flutter_gemma` stays app-owned |
| Full **repo split** CI / publish pipeline | Program hygiene does not block in-repo delivery |

---

## Key design decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Phase 5 scope | A → B → C sequence | Docs honesty first; runtime/codegen change only with gates |
| Program complete vs milestone | `complete_milestone` + `deferred_work` | Phases 1–4 gates passed; split/shims/codegen generator remain |
| WebMCP / Gemma naming | “Adapter shipped”, not “stub” | Packages and tests exist; Gemma is example-only by policy |
| Codegen in Phase 1 closure | Annotations-only | Generator belongs in Phase 5-C, not retroactive Phase 1 failure |
| Phase 5-C codegen | Pilot in `agentkit_codegen` test fixture | Server/flutter_test_app codegen deferred; hand-written path first-class |
| Phase 4 in tracker | Separate `phase4` row | Registry resources / hot-sync is distinct from Phase 3 adapter ship |
| No Dart edits in 5-A | Docs/yaml only | Reduces risk; B/C own code changes |

---

## References

- Design spec: [2026-05-25-agentkit-design.md](2026-05-25-agentkit-design.md)
- Phase 4 closure: [../closure/2026-05-25-agentkit-phase4-registry-resources.md](../closure/2026-05-25-agentkit-phase4-registry-resources.md)
- Self-closing loop: [../agentkit-self-closing-loop.md](../agentkit-self-closing-loop.md)
