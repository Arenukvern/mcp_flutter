---
name: multi-agent-handoff
description: Plan and document handoffs, parent lane contracts, and parallel batch contracts between specialized AI agents (foreman, workers, reviewers). Use for multi-agent workflows, subagents, original goal preservation, native gates, claim ceilings, terminal states, baton passes, or guild-style agent coordination.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.0.0"
  category: multi-agent
---

# Multi-agent handoff

Structure work so multiple agents can execute sequentially without losing context.

## When to use

- Splitting a large task across explorer, implementer, and reviewer agents
- Foreman/worker or parent/subagent patterns
- Need a written baton between chat sessions or tools

## Handoff document template

Create or update `HANDOFF.md` (or a section in the task issue) with:

```markdown
## Goal
{one sentence outcome}

## Done
- {completed items}

## Next
1. {ordered steps for the receiving agent}

## Constraints
- {tech stack, style, files not to touch}

## Verification
- {commands or checks that must pass}

## Validation status
- {commands run}
- {commands skipped or blocked, with reason}
- {blocked JSON explained with `steward blocked explain --input <path> --json`, when available}
- {schema/output drift checked with `steward schema check-outputs --json`, when machine-readable output is part of the handoff}
- {claims not proven because validation was skipped or blocked}

## Partial results
- {missing, partial, superseded, or timed-out agents/lenses}

## Context links
- {paths, PRs, prior decisions}

## Artifact capture
- {ADR, FAQ, skill, evidence note, test, validator, generator, or check that should absorb durable learning}
```

## Parallel batch contract

For broad decomposable work, the parent may use a disposable batch section instead of a new plan format. Keep only enough contract to move safely:

- original goal and user acceptance check;
- default native gate and aggregate gates;
- product impact check for the primary artifact, especially when the repo is an
  app, library, CLI/tool, plugin, or prototype;
- detour budget and stop condition;
- integration capacity, merge order, and conflict policy;
- comparison strategy for lane outputs;
- final evidence boundary, claim ceiling, and non-claims;
- acceleration note with three fields: `Saved`, `Cost/duplication`, and `Future hot path`;
- hot-path promotion check for repeated verification or comparison work.

Use this compact shape before dispatching parallel lanes:

```markdown
## Parallel Batch
Original goal: {user-visible outcome}
Acceptance check: {how the parent will know the original goal is satisfied}
Product impact check: {source-owned product behavior/API/UI/perf/doc-user workflow that must change or be proven unchanged}
Default native gate: {repo-native command or reason none exists}
Aggregate gate: {final validation before claiming completion}
Detour budget: {when to stop repairing tools and return to the goal}
Claim ceiling: {strongest claim allowed if all lanes pass}
Non-claims: {adjacent claims this batch cannot prove}
Acceleration note:
- Product impact line: {recognized prefix plus proof; use support_only: Steward scaffolding only when no product surface moved}
- Saved: {time, uncertainty, or risk reduced by running lanes in parallel}
- Cost/duplication: {duplicated work, integration cost, or coordination drag caused or avoided}
- Future hot path: {command, check, skill, script, deletion, or native route created for the next run}

| Lane | Agent/role | Scope | Write set | Forbidden paths | Native gate | Direct fix? | Terminal state |
|------|------------|-------|-----------|-----------------|-------------|-------------|----------------|
| L1 | {owner} | {bounded work} | `{paths}` | `{paths}` | `{command}` | yes/no | pending |
```

Delete or collapse this batch section after synthesis unless it becomes a
review artifact. Do not preserve lane maps as project management state.

## Parent lane contract

Parent-assigned lane contracts are the only write-authority surface. Advisory ecology route `dispatch_lane_candidates`, MoE findings, A2A notes, and reviewer comments are inputs only.

Each assigned lane should state:

- `lane_id`, assigned agent/role, scope, exact `write_set`, and `forbidden_paths`;
- inherited repo rules, required impact checks, permission checks, native gate, and aggregate gate responsibility;
- `direct_fix_allowed: true|false`, claim ceiling, non-claims, and escalation triggers;
- terminal state: `integrated_to_owner`, `rejected`, `blocked_to_current_ledger`, `promoted_to_durable_owner`, `deleted`, `reported_to_parent`, `accepted_as_input`, `partial`, `timed_out`, or `superseded`.

Only a parent lane contract may set `direct_fix_allowed: true`. Direct fixes must be bounded low-risk work with exact write sets, declared forbidden paths, inherited safety rules, required impact/permission checks, and available validation. If validation is skipped or blocked, the result downgrades to `blocked` or `recommendation`; it is not `integrated_to_owner`.

A2A artifacts never authorize writes, widen scope, accept/reject lanes, or launder steward judgment. The parent or explicit A2Human checkpoint owns authorization, synthesis, final claims, and scope changes.

## Landing phase

When a lane proves a fix in a temp clone, fork, worktree, or external checkout,
that proof is `accepted_as_input` until the owner checkout carries the smallest
source-owned diff and reruns the native gate. Do not treat temp proof as
repo-owned evidence by default.

Before claiming a lane is integrated:

1. Isolate the minimal source-owned diff from the temp or worker result.
2. Apply only that diff to the owner checkout.
3. Rerun the lane's native gate in the owner checkout.
4. Update the current ledger or evidence note only if the claim changed.
5. Record `source_owner_status` as `temp_only`,
   `owner_landed_pending_gate`, `owner_gate_passed`, or
   `blocked_owner_dirty`.
6. Mark the terminal state as `integrated_to_owner`, `blocked_to_current_ledger`,
   `accepted_as_input`, or `rejected`.

If the source checkout is dirty or cannot accept the diff safely, record the
temp proof as a candidate and keep the stronger source-owned claim unproven.
After one bounded landing attempt, close the lane as blocked or rejected rather
than creating another proof packet for the same unlanded result.

## Workflow

1. **Decompose** — break the goal into independent slices where possible.
2. **Assign roles** — e.g. Explore (read-only), Implement (write), Review (read-only critique).
3. **Write baton** — fill the template; keep "Next" to ≤7 concrete steps. For parallel work, include the compact batch table before dispatch.
4. **Execute one slice** — receiving agent does only "Next"; updates "Done".
5. **Record proof** — update validation status before claiming completion. Skipped checks and blocked generators are non-proof, not quiet success.
6. **Land source-owned changes** — convert temp or worker proof into the owner checkout and rerun the native gate before strengthening the claim.
7. **Close every lane** — assign a terminal state to each lane or lens, including timed-out, blocked, or superseded work.
8. **Measure acceleration** — fill the acceleration note with what was saved, what duplicated work or coordination cost appeared, and what future command/check/hot path now exists. If nothing was saved, say so and keep the claim ceiling low.
9. **Check product impact** — for product repos, name the source-owned product
   delta or product-native gate reached. If the batch only improved Steward
   scaffolding, proof artifacts, or tools-about-tools, claim orientation or
   harness maintenance only, not product acceleration.
   Use one product impact prefix: `runtime_behavior:`, `public_api:`,
   `product_native_gate:`, `visual_capture:`, `performance_metric:`,
   `release_path:`, `developer_workflow:`, `command_output:`,
   `plugin_install:`, or `support_only:`.
   If `Cost/duplication` is not lower than the saved uncertainty, risk, or
   repeat work, default to `leave_native`, `rejected`, or a low-confidence
   support claim.
10. **Capture durable learning** — if a finding changes future behavior, route it to an ADR, FAQ, skill, evidence note, validator, generator, test, or check.
11. **Re-handoff** — pass updated `HANDOFF.md` to the next agent or subagent.
12. **Close** — delete or archive handoff file when goal is verified.

## Anti-patterns

- Vague "continue working on X" without file paths or acceptance criteria
- Handoffs longer than one screen (split into `references/` or issues)
- Duplicate conflicting instructions across parent and child agents
- Subagents that repeat the parent plan instead of looking for contradiction, stale assumptions, missing evidence, or smaller deletable designs
- Final handoffs that sound complete while validation is skipped, blocked, or only manually inferred
- Clean temp proof presented as source-owned adoption before landing and rerunning the owner checkout's native gate
- Long-running or vanished subagents silently absorbed into parent synthesis without a `partial`, `timed_out`, `blocked`, or `superseded` terminal state
- Parallel work claimed as faster without naming saved uncertainty, duplicated work, and the future command/check/hot path it created
- A batch that closes with green Steward gates but no product delta, product-native gate, screenshot/perf proof, API behavior change, or user-facing workflow improvement while still claiming product acceleration

## Subagent hints (Codex / Cursor / Zed)

- Use read-only agents for exploration and review
- Pass the handoff block verbatim in the subagent prompt
- Prefer `disable-model-invocation: true` on skills that must run only when invoked
- For parallel work, keep agent scopes non-overlapping and declare write ownership before implementation.
- Useful reviewer roles include `Repo Truth Verifier`, `Boundary Leak Reviewer`, `Evidence Ladder Reviewer`, `Doc Collapse Reviewer`, `Harness QA Reviewer`, and `Stale External Assumption Reviewer`.
- Codex custom agents live in `.codex/agents/*.toml` or `~/.codex/agents/*.toml`; define `name`, `description`, and `developer_instructions`, and spawn subagents only when the user explicitly asks for subagent delegation.
- Cursor custom subagents live in `.cursor/agents/*.md` or `~/.cursor/agents/*.md`; each run has isolated context, and background/parallel execution is useful for independent slices.
- Zed parallel work uses separate agent threads or worktrees; use skills for repeatable single-context procedures and threads for independent concurrent work.

## Install

```bash
npx skills add arenukvern/skill_steward --skill multi-agent-handoff
```

## Sources

See [references/sources.md](references/sources.md). When researching, follow `skill-source-citations`.
