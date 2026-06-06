---
name: harness-engineering-lifecycle
description: Design, implement, and integrate generalized validation harnesses across a producer-consumer boundary. Use when refactoring custom validation CLIs/MCPs for large polyrepos, or when deploying a local tool to a sibling project for dogfooding and testing.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.1.0"
  category: harness
---

# Harness Engineering Lifecycle

Evolve repository-specific validation scripts into a generalized, high-performance, declarative harness system, and safely test those changes across a producer-consumer repository boundary.

## When to use

- Evolving custom validation scripts into a central linter engine.
- Extending `steward` CLI features for large polyrepos.
- Testing a local CLI/harness build against a sibling repository to catch path-resolution crashes or integration friction.

## Part 1: The Cascading Agent Surface (Architecture & Generalization)

When engineering a harness for a massive polyrepo, you must follow the **Cascading Agent Surface** guidelines. A strict separation of tools vs skills fails at this scale. Instead, seamlessly link them using domain-agnostic abstractions:

1. **Layer 0 (The Embedded Agent Surface)**: The target application or engine must natively expose its internal state via explicit hooks (e.g., RPC or memory probes). Do not rely on brittle UI scraping or black-box testing.
2. **Layer 1 (The Protocol Adapter)**: Build generalized MCP servers or protocol adapters to connect to Layer 0. These tools provide raw visibility and actuation (e.g., taking screenshots, reading memory) but must contain NO business logic.
3. **Layer 2 (The Orchestrator)**: Build specialized harness CLIs that use their own automation/scripting to chain multiple Layer 1 actions together. The Orchestrator's primary job is the **Fast Feedback Loop**: it must emit structured, diagnostic JSON to pinpoint exactly what broke across boundaries.
4. **Layer 3 (The AI Wrapper)**: Following the `agentskills.io` spec, Skills *can and should* contain thin-wrapper tools (scripts). The Skill acts as the AI's brain: it teaches the AI how to trigger Layer 2, interpret its complex JSON heuristics, and safely execute domain-specific recovery tools.

### Generalization Principles

1. **Decouple transport from engine:** Command interfaces (CLI) and JSON-RPC (MCP) are thin wrappers. All logic lives in a reusable core package.
2. **Declarative configuration:** Use a configuration file (like `steward.yaml`) to specify:
   - **Branding:** Name and description of the harness.
   - **Pipelines:** Aliases mapping user tasks to shell commands.
   - **Documentation lattice:** Maps of labels to specific doc files.
3. **Pruned traversals:** Never perform recursive file-walking (`list(recursive: true)`) without pruning standard build/VCS folders early.
4. **Generalized checks:** Do not hardcode linters. Use parameterized declarative engines (e.g. `disallowed-substrings`).

## Part 2: Cross-Repo Remediation (Testing)

When you make changes to the harness (Producer), you must validate it against dependent downstream projects (Consumer).

1. **Establish Sibling Baseline:** Locate the consumer repository (e.g. `../<consumer-repo-name>`). Run its tests to ensure it starts green. Do not change it yet.
2. **Deploy Local Producer:** Build and install the local development version of your harness.
3. **Capture Adoption Friction:** Run the consumer's validation suite using the local producer build. Document path crashes or fragile rules in a scratchpad.
4. **Core Remediation:** Fix the root causes in the *Producer* codebase. Generalize the fix; do not write consumer-specific hacks.
5. **Consumer Configuration Remediation:** Update the *Consumer* repository to leverage the new generalized features (e.g. updating its `steward.yaml`).
6. **Dual Verification:** Verify that the consumer suite passes, and the producer suite passes.
7. **Durable Knowledge:** Extract any learnings to ADRs or FAQs using the `repository-governance-lifecycle` skill.

## Install

```bash
npx skills add arenukvern/skill_steward --skill harness-engineering-lifecycle
```

## Sources

See [references/sources.md](references/sources.md).
