# Agentkit Self-Closing Implementation Loop

> **Purpose:** After each phase, a dedicated **Closer** agent verifies the repo against the design spec, regenerates the **current** phase plan if gaps remain, or authors the **next** phase plan when exit criteria pass. Repeat until the full [agentkit design spec](specs/2026-05-25-agentkit-design.md) is implemented.

**Rollout tracker:** [plans/2026-05-25-agentkit-rollout.md](plans/2026-05-25-agentkit-rollout.md)  
**Program state (YAML):** [tracker/agentkit-rollout.yaml](tracker/agentkit-rollout.yaml)

---

## Roles

| Role | Skill(s) | Writes code? | Owns |
|------|----------|--------------|------|
| **Implementer** | `executing-plans` or `subagent-driven-development` | Yes | Task checkboxes in active phase plan |
| **Closer** | `verification-before-completion`, `writing-plans`, `receiving-code-review` | No (may edit plans/docs only) | Phase gate, plan regeneration, rollout tracker |

**Rule:** The same agent must not Implement and Close the same phase without a **fresh context** (new session or explicit handoff). Closer treats Implementer claims as untrusted until verified.

**Parallel tasks inside a phase:** Use `dispatching-parallel-agents` + `subagent-driven-development` (one subagent per disjoint task slice). Do **not** use `engineering-loop` — it is not part of this program.

---

## Program status ladder

| Status | Meaning |
|--------|---------|
| `complete_in_repo` | Phase 6 Bar D gate (registry cut, emitters, migration CLI) |
| `complete_in_repo_product` | Phase 8 product gate (init, plugin, `fmt_migrate`, dogfood CI) — **current in-repo ceiling** |
| Phase 7 extract | Standalone monorepo + pub.dev — **in progress** (7.1–7.3, 7.6 done; 7.4–7.5, 7.7 pending — see [tracker](tracker/agentkit-rollout.yaml)) |

Do not treat closure footers using `complete_in_repo_integrated` as tracker values.

## Loop (until in-repo product + optional extract)

```text
┌─────────────────────────────────────────────────────────────┐
│  READ: design spec + rollout tracker + active phase plan     │
└───────────────────────────────┬─────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────┐
│  IMPLEMENTER: execute phase plan tasks (bounded slices)        │
└───────────────────────────────┬─────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────┐
│  CLOSER: Phase Gate (mandatory)                              │
│  1. Run phase exit verification commands                     │
│  2. Spec coverage audit (design § → evidence in repo)        │
│  3. Write closure report                                     │
└───────────────────────────────┬─────────────────────────────┘
                                ▼
                    ┌───────────┴───────────┐
                    │ gaps or failures?    │
                    └───────────┬───────────┘
              YES ◄─────────────┼─────────────► NO
                │                               │
                ▼                               ▼
┌───────────────────────────┐   ┌───────────────────────────────┐
│ REGENERATE same-phase plan │   │ Mark phase `done` in tracker │
│ (only open + fix tasks)    │   │ REGENERATE next-phase plan   │
│ IMPLEMENTER continues      │   │ if more phases → loop          │
└───────────────────────────┘   │ else → program `complete`      │
                                └───────────────────────────────┘
```

---

## Phase Gate checklist (Closer)

### 1. Verification (evidence required)

Run every command listed in the phase plan **Task N: exit verification** and in the rollout tracker `validation` block. Record exit codes and failure counts verbatim.

**Default Phase 1 commands:**

```bash
cd /Users/anton/mcp/mcp_flutter
make check-agentkit-integration
cd agentkit && make test && make analyze
cd mcp_server_dart && dart test
cd mcp_server_dart && dart run bin/flutter_mcp_cli.dart schema --name fmt_wait
cd mcp_server_dart && dart run bin/flutter_mcp_cli.dart capabilities
make dogfood-eval-static
# Runtime dogfood (optional): make web-showcase → export WS_URI → make dogfood-eval
```

Add phase-specific commands when the plan introduces them.

### 2. Spec coverage audit

For each row in the phase’s **Spec coverage checklist**:

| Column | Closer fills |
|--------|----------------|
| Requirement | From design spec / phase plan |
| Evidence | File path + symbol or test name |
| Status | `pass` \| `fail` \| `partial` \| `deferred` |
| Gap note | What is missing if not `pass` |

Cross-check the **design spec** sections not in the phase checklist — if implemented early, note `pass (ahead)`; if missing, add to gap list.

### 3. Closure report artifact

Write after every gate attempt:

**Path:** `docs/superpowers/closure/YYYY-MM-DD-agentkit-<phase-id>.md`

**Template:**

```markdown
# Closure: agentkit <phase-id>

**Date:** YYYY-MM-DD  
**Verdict:** `pass` | `fail`  
**Plan version closed:** <git sha or plan date>

## Verification evidence

| Command | Exit | Summary |
|---------|------|---------|
| ... | 0 | 42 passed |

## Spec coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| ... | pass | packages/agentkit_core/... |

## Gaps (if fail)

1. ...

## Plan action

- [ ] Regenerated `plans/2026-05-25-agentkit-<phase>.md` (same phase, vN+1)
- [ ] Regenerated `plans/2026-05-25-agentkit-phase<N+1>.md` (next phase)
- [ ] Updated `tracker/agentkit-rollout.yaml`
```

### 4. Verdict rules

| Verdict | Condition |
|---------|-----------|
| **pass** | All exit commands exit 0; all phase checklist rows `pass` or approved `deferred`; design phase exit paragraph satisfied |
| **fail** | Any test/analyze failure, missing deliverable, or checklist `fail` / `partial` without documented deferral |

**On fail:** Closer **must** regenerate the **same** phase plan — do not advance the tracker to the next phase.

**On pass:** Closer updates tracker, regenerates **next** phase plan from design spec (using `writing-plans` skill), sets active phase to next.

---

## Plan regeneration rules (Closer)

### Same phase (repair plan)

1. Copy forward **completed** tasks unchanged (checkbox `[x]`).
2. Add **Fix:** tasks for each gap with exact file paths and verification command.
3. Remove obsolete tasks superseded by implementation.
4. Bump plan header: `**Plan revision:** v2 (post-closure YYYY-MM-DD)` and link closure report.
5. Do **not** duplicate full code samples from v1 unless the fix changes the API.

### Next phase (forward plan)

1. Read design spec **Migration phases** for the next phase only.
2. Include **Spec coverage checklist** mapped to design sections.
3. Include **File map**, **Task N** bite-sized steps, **exit verification**, and **Phase Gate** pointer to this document.
4. Set prerequisite: `previous_phase.status == done` in tracker.

### Program complete

When Phase 3 (or final phase in tracker) passes gate:

1. Set `program.status: complete` in `tracker/agentkit-rollout.yaml`.
2. Write `docs/superpowers/closure/YYYY-MM-DD-agentkit-program-complete.md`.
3. Optional: run `gitnexus_detect_changes` and `npx gitnexus analyze` per repo policy.

---

## Prompts (copy for agents)

### Implementer (start of phase)

```text
Implement agentkit <phase-id> using docs/superpowers/plans/<phase-plan>.md.
Follow executing-plans / subagent-driven-development. Do not mark phase complete.
When all task checkboxes you can complete are done, stop and report: tasks done, tasks blocked, commands not yet run.
```

### Closer (after implementer stops or claims done)

```text
You are the Closer for agentkit <phase-id>. Do not implement features.
REQUIRED: verification-before-completion + writing-plans.
1. Run all exit verification commands in the phase plan; paste evidence.
2. Audit spec coverage checklist vs repo; list gaps.
3. Write docs/superpowers/closure/YYYY-MM-DD-agentkit-<phase-id>.md.
4. If fail: regenerate same-phase plan (v+1) with Fix tasks only for gaps.
5. If pass: update docs/superpowers/tracker/agentkit-rollout.yaml; regenerate next phase plan; set active_phase to next.
6. Repeat until tracker program.status is complete.
```

### Parallel implementers (optional, disjoint tasks)

```text
Split the active phase plan into disjoint tasks (no overlapping file paths).
Dispatch one subagent per task via subagent-driven-development.
When the batch finishes, run the Closer gate once — do not claim partial completion without verification.
```

---

## Integration with mcp_flutter repo

| Artifact | Path |
|----------|------|
| Design spec (source of truth) | `docs/superpowers/specs/2026-05-25-agentkit-design.md` |
| Active phase plan | `docs/superpowers/plans/2026-05-25-agentkit-phase<N>.md` |
| Rollout overview | `docs/superpowers/plans/2026-05-25-agentkit-rollout.md` |
| Machine tracker | `docs/superpowers/tracker/agentkit-rollout.yaml` |
| Closure reports | `docs/superpowers/closure/` |
| This loop | `docs/superpowers/agentkit-self-closing-loop.md` |

**AGENTS.md / CLAUDE.md:** Point agentkit work at this loop before starting implementation.

---

## Key design decisions

| Decision | Choice |
|----------|--------|
| Who closes a phase | Separate Closer agent with fresh verification |
| Failed gate | Regenerate **same** phase plan, never skip ahead |
| Passed gate | Regenerate **next** phase plan from design spec |
| Completion | Tracker `program.status: complete` only after final phase gate |
| Evidence | Closure markdown + command output tables required |
| Orchestration | Implementer + Closer only — **no** `engineering-loop` |
