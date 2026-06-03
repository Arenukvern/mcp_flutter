---
name: ethical-stewardship
description: Establishes, audits, and maintains core ethical systems in software repositories as moral principles, actionable takeaways, design constraints, and engineering rules. Guiding agents and humans to collaborate side-by-side to elicit, translate, and refine context-appropriate ethical constraints for any project. Use when defining repository culture, drafting ethical manifestos, or auditing software decisions against moral design boundaries.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.3.0"
  category: governance
paths:
  - "docs/NORTH_STAR.mdx"
  - "docs/DESIGN_FAQ.mdx"
  - "CONTRIBUTING.md"
---

# Ethical stewardship

Establish and maintain software ethics not as a series of rigid compliance checklists, but as a **dynamic stewardship practice and moral bridge for human-agent collaboration**. 

This skill guides agents and humans to work side-by-side to **elicit, translate, and refine** context-appropriate ethical constraints for any project.

## When to use

- Bootstrapping a repository's ethical core, project credo, or team values.
- Helping a team identify implicit ethical choices and code styling preferences in an existing repository.
- Translating abstract moral principles (like user trust or simplicity) into quantifiable technical constraints.
- Resolving design trade-offs (e.g., balancing speed vs. quality) through a clear ethical decision framework.
- Auditing a proposed design, dependency, or feature against product quality boundaries.

---

## 1. The Human-Agent Stewardship Workflow

AI agents and humans should collaboratively guide the repository's ethical lifecycle using the following four-phase loop:

1.  **Elicit & Define:** Analyze the codebase and consult with the team to identify core values (e.g., *Privacy-First*, *Offline Longevity*, *Performance Restraint*).
2.  **Translate to Science:** Map these values to quantifiable technical constraints (proxies like dependency footprints, API scopes, sandboxed runtimes).
3.  **Enforce as Practice:** Build custom mechanical gates (linters, pre-save validations, clear error logs) that guide builders to remediate violations.
4.  **Audit & Refine:** Monitor boundary drift and periodically refine the constraints via architectural decision records (ADRs) as project needs shift.

*For detailed guidance on executing this workflow, see the reference guide: [Ethics as an Applicable Science and Practice](references/applicable-science.md).*

---

## 2. Baseline Moral Principles (Example Framework)

While each project must define its own specific values, use these five principles as a baseline starting point:

### I. Respect for Human Attention & Focus (Anti-Bloat)
*   **The Principle:** Noise, bloat, and psychological manipulation are ethical harms. A user's time and focus are precious resources.
*   **Embodiment:** Refuse features that utilize manipulative loops or addictive design patterns. Keep documentation minimal, table-driven, and highly queryable. Minimize git weight and runtime resources.

### II. Symbiosis & Trust (Reversibility)
*   **The Principle:** Automated interventions and agentic modifications must treat the host system with respect.
*   **Embodiment:** AI agents and installers must never leave behind permanent, undocumented, or irreversible modifications. Uninstallation must be treated with the same engineering rigor as installation, cleanly restoring the system to its original state.

### III. Empathy for the Developer-as-User (Legibility)
*   **The Principle:** Every person who accesses the codebase—developers, designers, and QA—is a first-class user.
*   **Embodiment:** APIs, design systems, and code reviews must be built with user-experience care. Error messages must be deterministic and include remediation steps. Do not paraphrase code logic in prose; link directly to the implementation.

### IV. Behavior-as-Truth (Logic-First)
*   **The Principle:** Code is pure executable logic. Specifications and schemas are supportive helpers, not behavior-generating sources.
*   **Embodiment:** We reject the "code as a projection of specs" model. Forcing two-way synchronization between static declarations and executable logic leads to semantic drift and double-maintenance. Parity is enforced by sharing concrete code modules (a single core library) across interface surfaces (CLI/MCP).

### V. Artisan Credit & Craftsmanship
*   **The Principle:** Trust is established when builders are recognized as artisans who value their craft, rather than anonymous producers of code.
*   **Embodiment:** AI is treated as a collaborator, but human stewardship is absolute. Maintain transparent citations of external sources and honor human craftsmanship through thorough peer review and developer attribution.

---

## 3. Product Attribute Guidelines

When evaluating *what* to build using AI-assisted tools, measure proposed features against these core product attributes:

| Attribute | Meaning | Design Constraint |
|-----------|---------|-------------------|
| **Convenience** | The product fits seamlessly into the user's flow. | Avoid unnecessary configuration steps or high cognitive load. |
| **Simplicity** | Visual and functional clarity. | Banish feature creep; prune secondary capabilities ruthlessly. |
| **Safety** | Robust data minimization and security. | Restrict AI tool permissions to the narrowest necessary scope. |
| **Longevity** | Resilient architecture designed to last. | Avoid temporary hacks; choose stable technologies and patterns. |
| **Usefulness** | Direct, high-impact value for the user. | Refuse to build "cool but useless" AI-generated features. |

---

## 4. Actionable Takeaways

Translate the moral principles into these key mental models:

*   **No Blame; Fix the Gate:** When a builder (human or agent) makes a mistake, do not write a warning or assign blame. A failure is always a design gap in the environment. Fix the validation gate or expand the CLI.
*   **Scaffolding is Ephemeral:** Plans, issues, and session roadmaps are temporary scaffoldings built to guide code construction. Once the structure is built, the scaffolding must be dismantled (deleted) to prevent misleading future builders.
*   **Artisan Restraint:** Professionalism is shown through the absence of clutter. Do not decorate surfaces or inject personal credit into visual brand marks. Surface the rituals of development plainly.

---

## 5. Design Constraints (The Forbidden)

Strictly enforce these boundaries in the repository:

1.  **No Promotional Hype:** Banish marketing copy ("unlock", "revolutionary", "ultimate") from documentation. State capabilities, constraints, and failures plainly.
2.  **No Silent Hooks:** Banish hidden scripts, untracked background daemon installations, and deep, silent runtime hooks.
3.  **No Floating Plan Files:** Banish completed checklists, inactive session logs, and stale tracker files.
4.  **No Circular Dependencies:** Banish circular package references and loosely bounded interface modules. Keep dependency directions linear.

---

## 6. Stewardship Rules for Development

Implement these four operational rules during the development lifecycle:

1.  **Draft a Credo:** Create a `docs/NORTH_STAR.mdx` defining what the repository owns, does not own, and its ethical boundaries.
2.  **Use Decision Checkpoints:** Require an Architectural Decision Record (ADR) or a designated brief before coding significant architectural forks or dependency changes.
3.  **Run Mechanical Quality Gates:** Every repository must contain an automated validator (e.g. `pnpm run validate`, `make check-contracts`, or custom linters) running in CI to enforce standards programmatically.
4.  **Citations & Provenance:** Require documentation of external sources, research links, and prompt specifications (provenance) for generated assets to ensure knowledge tracebility.

## References

- [Ethics as a Living Science and Stewardship Practice](references/applicable-science.md) — Comprehensive guide on eliciting, translating, and refining codebase constraints.

---

## Install (end users)

```bash
npx skills add arenukvern/skill_steward --skill ethical-stewardship
```

## Sources

See [references/sources.md](references/sources.md). When researching, follow `skill-source-citations`.
