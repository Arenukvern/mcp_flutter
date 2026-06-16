---
name: mixture-of-experts
description: Run a Mixture of Experts (MoE) audit on any topic, plan, codebase, evidence archive, or process. Dynamically spawns specialized subagents with different critical lenses to cross-reference findings and detect flaws, overlap, retention issues, or drift. Use when designing architectures, analyzing complex code, verifying multi-step plans, classifying evidence artifacts, or looking for duplicated intent in a repo.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.1.0"
  category: governance
---

# Mixture of Experts (MoE) Audit

The Mixture of Experts pattern is a powerful critical-thinking framework. It prevents tunnel vision by forcing multiple independent "expert personas" to analyze a single topic from completely different angles, before cross-referencing their findings.

It can be applied to literally anything: a codebase, a feature plan, a deployment process, or a repository's governance skills.

## When to use

- "Review this architecture plan using a mixture of experts"
- "Do we have skills with duplicated intent?"
- "Audit this deployment script for security and performance"
- You encounter a complex design decision and need rigorous, multi-faceted critique.

## Workflow

1. **Identify the Topic**
   Understand what the user wants to audit (e.g. "repo skills overlap", "new caching architecture", "release process").
2. **Define Expert Personas**
   Invent 2-3 specialized experts whose lenses are highly relevant but orthogonal to the topic. Use more than 3 only when the user explicitly asks for broad subagent coverage or when the domains are truly independent; default maximum is 4. Do not spawn agents to restate the parent plan.
   For each expert, write a short ownership contract:
   - `Role`: the critical lens.
   - `Scope`: what evidence or subsystem they inspect.
   - `Out of scope`: what they must not decide or edit.
   - `Expected output`: findings, contradiction, or artifact recommendation.
   - `Fallback`: what to do if the lens times out or returns partial evidence.
   - `Integration contract`: exact docs, checks, skills, or code surfaces their finding would affect.

   Examples:
   - *For repo governance:* "Codebase Auditor", "Skills Analyst"
   - *For a system architecture:* "Security Specialist", "Scalability Engineer", "Cost Analyst"
   - *For a frontend component:* "Accessibility Auditor", "Performance Expert"
   - *For product claims or external platform support:* **"Evidence / Validation QA"**. This lens asks what claim is being made, what evidence proves exactly that claim, what validation or source freshness is required, and what remains a non-claim. Use it when a thread touches platform support, generated assets, cross-repo cleanup, benchmark proof, public compatibility, or external APIs.
   - *For evidence archives, PDSA loops, dogfood notes, templates, and proof packets:* **"Evidence / Retention QA"**. This lens asks whether the artifact is an ADR, current ledger, historical evidence, public reproducibility card, template, check/tool candidate, or deletion candidate; whether it is for maintainer routing, current status, historical provenance, or public audit; what claim it protects; whether it has status/type/limitations/non-claims; and what next disposition prevents stale-proof drift.
   - *For E2E Execution & Evals (Dogfooding):* **"Harness QA Expert"**. When a workflow, toolchain, typed action, or benchmark loop changes, include a Harness QA lens. Use a subagent when available; otherwise run the lens sequentially and label it. If the change claims H2+ maturity or changes action/benchmark behavior, capture a review artifact in the final or PR summary: scope, repo used, commands/actions exercised, evidence level reached, and remaining non-proof. Docs-only alignment can use softer wording and does not need a separate artifact unless it changes a readiness claim.
   - *For stewardship, tools, harnesses, or growing products:* **"Generational Architecture Skeptic"**. This lens asks what can be deleted, collapsed, kept native, moved to docs/FAQ, extracted to a public API, generated from schema, or promoted to harness proof. It must ask whether the design helps the next repo, next agent, next version, and next maintainer, or instead creates path magic, one-consumer hacks, overclaims, "full adoption" drift, or tool dependency loops. The clean promise is: Skill Steward helps a repo notice when it has outgrown its current shape, choose the smallest next layer, and prove the change reduces future work.
   - *For stalled PDSA, repeated blockers, evidence loops, or repo pain:* **"Loop Compression / Pain Tutor"**. This lens asks what original user goal is being delayed, which owner can be fixed now, which native gate proves the fix, which surface can disappear, and whether the pain should become an error message, FAQ row, test, schema, script, action candidate, or current-ledger update instead of another evidence artifact.
3. **Spawn Subagents**
   Use the available subagent capability for the current host to launch these experts independently. Give them explicit prompts to audit the target topic through their specific lens. Keep read-only lenses read-only unless the user explicitly asked for implementation. If no subagent tool is available, run the expert lenses sequentially and label the output as a non-parallel MoE.
4. **Cross-reference Findings**
   Wait for all subagents to report back, or stop at the declared fallback point. Synthesize their independent critiques. Look for structural contradictions, missed edge cases, maintenance traps, and (in the case of repo skills) duplicated intent. If a lens times out or returns unusable evidence, label it as `missing_lens`, `partial_lens`, `timed_out_lens`, or `superseded_lens`; either retry, continue with downgraded confidence, or state that the missing lens blocks a stronger claim. Include a compact lens-status summary whenever the MoE result affects implementation, evidence, or a readiness claim.

   Example lens-status summary:

   ```markdown
   | Lens | Status | Integration |
   |------|--------|-------------|
   | Evidence QA | integrated | limited the claim ceiling |
   | Operations QA | partial | accepted as input, not proof |
   | Skeptic | timed_out | no stronger claim based on this lens |
   ```

   When the Skeptic lens is active, name the smallest useful layer and any deletion/collapse option before recommending new tools; for broad surface-shape questions, also name whether the useful move is split, compress, promote, demote, delete, or stay native. When the Evidence / Retention QA lens is active, name the artifact status, claim protected, and retention/disposition route before recommending new evidence. If the critique would change durable docs, skills, contracts, or tooling, create or recommend a Pattern Promotion Review under `docs/evidence/` instead of creating a new doctrine.
   For broad repo pain, MoE may discover possible lane candidates and contradictions between lanes. These findings are advisory critique inputs only: they do not authorize writes, assign workers, accept results, or replace parent synthesis. Parent lane contracts and direct-fix authority belong to `multi-agent-handoff`.
5. **Choose output mode**
   - **Read-only critique mode:** If the user asks to analyze, discuss, criticize, or validate only, summarize findings in chat. Do not create files or plans.
   - **Implementation planning mode:** If the user asks for a plan or approved changes, draft a concise implementation plan or learning artifact.
   - **Execution mode:** If the user explicitly approves implementation, apply the smallest scoped changes and validate them. If validation, generators, or freshness checks are skipped or blocked, record exact commands not run, why, and what claim is therefore not proven.
6. **Present to User**
   Lead with critical findings, contradictions, and actionable recommendations. End the synthesis with one disposition:
   - `chat_only`: useful critique, no durable change.
   - `promote_to_artifact`: update an ADR, FAQ, evidence note, skill, docs map, or Pattern Promotion Review.
   - `convert_to_check`: repeated deterministic truth should become a test, validator, generator freshness check, or harness probe.
   - `compress_existing`: merge overlapping guidance or navigation while preserving child truths.
   - `delete_or_retire`: remove stale guidance, evidence, or scaffolding after useful truth lands elsewhere.
   - `leave_native`: keep the work in the repo's existing command, framework, or owner surface.

   If implementation follows from the MoE, hand off the execution through
   `multi-agent-handoff` or keep it in the parent with an explicit claim
   ceiling. MoE findings alone are not terminal lane states and do not make
   temp or worker proof source-owned.
   Ask for approval only when the next step would mutate files or widen scope.

Compact rule: **spawn for independence, synthesize for contradiction, persist only what changes future behavior.**

## Install

```bash
npx skills add arenukvern/skill_steward --skill mixture-of-experts
```

## Sources

See [references/sources.md](references/sources.md).
