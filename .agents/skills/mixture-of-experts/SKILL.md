---
name: mixture-of-experts
description: Run a Mixture of Experts (MoE) audit on any topic, plan, codebase, or process. Dynamically spawns specialized subagents with different critical lenses to cross-reference findings and detect flaws, overlap, or drift. Use when designing architectures, analyzing complex code, verifying multi-step plans, or looking for duplicated intent in a repo.
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
   Invent 2-3 specialized experts whose lenses are highly relevant but orthogonal to the topic. For example:
   - *For repo governance:* "Codebase Auditor", "Skills Analyst"
   - *For a system architecture:* "Security Specialist", "Scalability Engineer", "Cost Analyst"
   - *For a frontend component:* "Accessibility Auditor", "Performance Expert"
3. **Spawn Subagents**
   Use your `invoke_subagent` capability to launch these experts independently. Give them explicit prompts to audit the target topic through their specific lens.
4. **Cross-reference Findings**
   Wait for all subagents to report back. Synthesize their independent critiques. Look for structural contradictions, missed edge cases, or (in the case of repo skills) duplicated intent.
5. **Draft Learnings or Plan**
   Generate a formal artifact (`consolidation_learnings.md` or `implementation_plan.md`) summarizing the multi-faceted critique and proposing actionable changes.
6. **Present to User**
   Stop and ask the user to approve the proposed actions.

## Install

```bash
npx skills add arenukvern/skill_steward --skill mixture-of-experts
```

## Sources

See [references/sources.md](references/sources.md).
