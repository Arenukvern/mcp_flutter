# Chrome eval design → Agent Skills (reference)

Source: [Design evaluations](https://developer.chrome.com/docs/ai/evals/design) · [Evals course](https://developer.chrome.com/docs/ai/evals)

## Map ThemeBuilder → skills

| Chrome concept | Skill Steward analogue |
|----------------|------------------------|
| Perfect JSON output | Agent **session outcome** (files changed, gates run, charter respected) |
| Faulty structure | Invalid frontmatter, broken links, missing `sources.md` |
| Bad creative output | Wrong procedure, scope creep, domain skill in meta repo |
| Rule-based eval | `pnpm run validate`, `pnpm run eval` (YAML rules) |
| LLM judge + rubric | Offline `references/evals.md` + optional plugin-eval |
| Layered pipeline | `skill-eval-improve` layers 0–4 |

## Workflow (adapted)

1. **Define success/failure** — List failure modes per skill (routing, procedure, charter, outcome).
2. **Split objective vs subjective** — Objective → YAML rules + validator; subjective → rubric in `evals.md`.
3. **Write rubric** — Criteria with pass/partial/fail; no single golden transcript required.
4. **Layer tests** — L0 CI rules → L1 static analyze → L2 human prompts → L3 judge (offline).
5. **Do not** put LLM judge in Skill Steward PR CI ([ADR 0011](../../../docs/decisions/0011-tiered-skill-evals-and-rule-based-ci.mdx)).

## Example rubric (procedure adherence)

```text
1. Skill steps attempted in order (or justified skip)
2. Required SSOT paths cited (not invented commands)
3. Stopped at skill boundary (no unrelated domain work)
4. Plan hygiene applied when skill says extract-and-delete
Score: pass | partial | fail per row
```

## Task-specific metrics (skills meta-layer)

| Metric | T1 behavior-critical expectation |
|--------|-------------------|
| **Alignment** | Follows skill steps and charter |
| **Groundedness** | Links to ADR/FAQ/NORTH_STAR, not hallucinated policy |
| **Concision** | SKILL.md &lt; 500 lines; bulk in `references/` |
| **Correctness** | Validate + eval cases pass |

## Related

- [eval-case-schema.md](eval-case-schema.md)
- [evals-template.md](evals-template.md)
