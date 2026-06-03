# Codex plugin-eval (reference)

Local path (example): `~/.codex/plugins/cache/openai-curated/plugin-eval/*/`

## Skills in bundle

| Skill | Purpose |
|-------|---------|
| `plugin-eval` | Umbrella router |
| `evaluate-skill` | Skill-specific analyze + benchmark init |
| `improve-skill` | Rewrite brief from findings |
| `evaluate-plugin` | Full plugin bundle |
| `metric-pack-designer` | Custom rubrics |

## Key commands

```bash
plugin-eval start <path> --request "Evaluate this skill." --format markdown
plugin-eval analyze <path> --format markdown
plugin-eval explain-budget <path> --format markdown
plugin-eval init-benchmark <path>
plugin-eval benchmark <path> --dry-run
plugin-eval measurement-plan <path> --observed-usage <usage.jsonl> --format markdown
plugin-eval compare before.json after.json
```

## Skill-specific priorities (from evaluate-skill)

- frontmatter validity
- `name` / `description` quality
- progressive disclosure
- broken relative links
- oversized SKILL.md
- helper script quality (TS/Python)

## Install plugin-eval

From Codex plugin cache checkout (Node ≥20):

```bash
cd <plugin-eval-root>
npm link   # optional global `plugin-eval`
node ./scripts/plugin-eval.js analyze <skill-path> --format markdown
```

## Map to Guild

| plugin-eval | Guild |
|-------------|-------|
| `analyze` | `pnpm run validate` + `skill-authoring-lifecycle` |
| `init-benchmark` | `references/evals.md` prompt suite |
| `improve-skill` | `skill-eval-improve` bounded edit loop |
| `compare` | Before/after eval JSON in PR |
