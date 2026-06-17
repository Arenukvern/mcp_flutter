# Eval case schema (`evals/cases/*.yaml`)

Version: **1** · [ADR 0011](../../../docs/decisions/0011-tiered-skill-evals-and-rule-based-ci.mdx)

Rule-based cases run in CI via `pnpm run eval`. They do **not** execute agents or LLM judges.

## File location

```text
skills/{skill-name}/evals/cases/{id}.yaml
```

T1 behavior-critical skills require **≥2** case files plus `references/evals.md` (human/LLM suite).

## Case shape

```yaml
id: unique-kebab-id
skill: directory-name          # must match skills/{skill}/
routing: should_trigger | should_not_trigger
input: "Representative user prompt for humans and weak routing hints"
rules:
  - kind: file_exists
    path: references/evals.md
  - kind: description_includes_any
    terms: ["charter", "governance"]
  - kind: description_excludes_all
    terms: ["weather forecast"]
  - kind: body_includes_any
    path: SKILL.md              # or references/foo.md
    terms: ["docs/NORTH_STAR"]
  - kind: body_excludes_all
    path: SKILL.md
    terms: ["deprecated-pattern"]
```

## Rule kinds (CI)

| kind | Checks |
|------|--------|
| `file_exists` | Path under skill root |
| `description_includes_any` | ≥1 term in frontmatter `description` (case-insensitive) |
| `description_excludes_all` | No term in `description` |
| `body_includes_any` | ≥1 term in `SKILL.md` body or `path` file |
| `body_excludes_all` | No term in target file |

## Routing hints (weak)

`scripts/eval-skill.mjs` warns (fails) when:

- `should_trigger`: no token (length > 4) from `input` appears in `description`
- `should_not_trigger`: ≥3 such tokens overlap

This is **not** production agent routing. Pair with `references/evals.md` for real behavior.

## Offline only (not in YAML)

- LLM judge + rubric ([Chrome eval design](chrome-eval-design.md))
- Held-out prompt pass rate ([evals-template.md](evals-template.md))
- Codex `plugin-eval benchmark`
