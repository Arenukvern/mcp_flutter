# Sources

| Topic | URL | Used for |
|-------|-----|----------|
| SkillOpt | https://microsoft.github.io/SkillOpt/ | Bounded edit + gate loop |
| SkillOpt paper | https://arxiv.org/abs/2605.23904 | Rollout/reflect/edit methodology |
| SkillsBench | https://arxiv.org/abs/2602.12670 | Paired eval inspiration |
| Claude skill best practices | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices | Human eval workflow |
| skills-best-practices | https://github.com/mgechev/skills-best-practices | skillgrade, disclosure |
| skillgrade | https://github.com/mgechev/skillgrade | Regression testing |
| Codex plugin-eval | ~/.codex/plugins/cache/openai-curated/plugin-eval/ | Static analyze + benchmark |
| Skill Steward validator | https://github.com/arenukvern/skill_steward/blob/main/scripts/validate-skills.mjs | Layer 0 gate |
| Skill Steward eval runner | https://github.com/arenukvern/skill_steward/blob/main/scripts/eval-skill.mjs | Layer 0b Tier 1 |
| Chrome eval design | https://developer.chrome.com/docs/ai/evals/design | Failure modes, rubrics |
| Chrome evals course | https://developer.chrome.com/docs/ai/evals | Layered pipeline |
| ADR 0011 | https://github.com/arenukvern/skill_steward/blob/main/docs/decisions/0011-tiered-skill-evals-and-rule-based-ci.mdx | Tier policy |

## Changelog

- 2026-05-29: v1.1 — Chrome eval reference, eval-case schema, Tier 1 CI (`pnpm run eval`)
- 2026-05-29: initial (SkillOpt, plugin-eval, SkillsBench, skillgrade)
