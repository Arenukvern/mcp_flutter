# SkillOpt & 2026 research (reference)

## SkillOpt (Microsoft Research)

- Site: https://microsoft.github.io/SkillOpt/
- Paper: https://arxiv.org/abs/2605.23904 — *SkillOpt: Executive Strategy for Self-Evolving Agent Skills* (2026)

**Idea:** Optimize the **skill document**; keep target model + harness **frozen**.

| Phase | Guild manual analogue |
|-------|------------------------|
| Rollout | Run held-out prompts with current SKILL.md |
| Reflect | Separate failure vs success notes |
| Edit | Bounded add/delete/replace (textual learning rate) |
| Gate | Accept only if held-out score improves |
| Export | Merge to `skills/{name}/` + changelog in `sources.md` |

**Ablations that matter:** edit budget, rejected-edit buffer, slow update, optimizer memory (meta)—for Guild, use PR review + `references/evals.md` instead of optimizer memory files.

## SkillsBench

- https://arxiv.org/abs/2602.12670 — benchmark inspiration for vanilla vs skill-augmented pairs.

## Authoring & eval practices

| Source | URL |
|--------|-----|
| Claude skill best practices | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices |
| skills-best-practices | https://github.com/mgechev/skills-best-practices |
| skillgrade | https://github.com/mgechev/skillgrade |
| Lalit Madan SKILL.md guide | https://lalitmadan.com/post/the-skill-md-guide |

## Human-curated vs model-generated

SkillOpt related work **SkillLens** warns that model-only skills underperform human-curated procedure docs—Guild skills should stay **human-reviewed** with eval gates.
