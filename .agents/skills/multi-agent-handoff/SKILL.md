---
name: multi-agent-handoff
description: Plan and document handoffs between specialized AI agents (foreman, workers, reviewers). Use for multi-agent workflows, subagent delegation, baton passes, or guild-style agent coordination.
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

## Context links
- {paths, PRs, prior decisions}
```

## Workflow

1. **Decompose** — break the goal into independent slices where possible.
2. **Assign roles** — e.g. Explore (read-only), Implement (write), Review (read-only critique).
3. **Write baton** — fill the template; keep "Next" to ≤7 concrete steps.
4. **Execute one slice** — receiving agent does only "Next"; updates "Done".
5. **Re-handoff** — pass updated `HANDOFF.md` to the next agent or subagent.
6. **Close** — delete or archive handoff file when goal is verified.

## Anti-patterns

- Vague "continue working on X" without file paths or acceptance criteria
- Handoffs longer than one screen (split into `references/` or issues)
- Duplicate conflicting instructions across parent and child agents

## Subagent hints (Cursor / Claude Code)

- Use read-only agents for exploration and review
- Pass the handoff block verbatim in the subagent prompt
- Prefer `disable-model-invocation: true` on skills that must run only when invoked

## Install

```bash
npx skills add arenukvern/skill_steward --skill multi-agent-handoff
```

## Sources

See [references/sources.md](references/sources.md). When researching, follow `skill-source-citations`.
