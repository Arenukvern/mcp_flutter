---
name: plugin-marketplace-setup
description: Designs public or private Agent Skill and plugin marketplaces for Cursor, Claude Code, Codex, Zed, Open Plugin, and npx skills—manifest layout, install matrix, and Skill Steward vs product boundaries. Use when setting up a marketplace, distributing skills/plugins to a team, private registry, .cursor-plugin, .codex-plugin, .plugin, .claude-plugin, or skills.sh publishing.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.0.0"
  category: marketplace
---

# Plugin & skill marketplace setup

Ship **skills** (portable instructions), **plugins** (runtime wiring), and **marketplaces** (catalogs) without mixing them up.

## Three layers (normative)

| Layer | What it is | Install unit | Skill Steward home |
|-------|------------|--------------|------------------|
| **Skill** | `SKILL.md` per [agentskills.io](https://agentskills.io/) | `npx skills add owner/repo --skill name` | `skills/{name}/` |
| **Plugin** | Open Plugin or vendor manifest + hooks/MCP/rules/commands | Per-agent (see matrix) | `plugins/{id}/` ([ADR 0004](../../docs/decisions/0004-plugin-packaging-and-install-path.mdx)) |
| **Marketplace** | Catalog of plugins/skills | Add marketplace, then install plugin | Product repos; Skill Steward uses public Git + skills.sh |

**Rule:** Instructions only → **skill**. Event hooks or multi-file wiring → **plugin** (references skills by id, do not fork `SKILL.md`).

**Skill Steward meta-plugin means:** a declarative manifest, referenced skill IDs, hook/rule snippets, and validated wiring artifacts. It does not mean a host marketplace submission has happened, and it must not silently mutate Cursor/Codex/Claude configuration. Host-specific install steps remain explicit in README/docs.

## Public vs private (decision)

| Goal | Recommended channel | Notes |
|------|---------------------|-------|
| **Public discovery** | GitHub public repo + [skills.sh](https://skills.sh) | `npx skills add owner/repo`; index needs valid `skills/*/SKILL.md` |
| **Team-only skills (any agent)** | Private GitHub/GitLab repo | Same `npx skills add org/private-repo` if agents can clone; use deploy keys / SSO |
| **Cursor team plugins** | [Team marketplace](https://cursor.com/docs/plugins) — Dashboard → Settings → Plugins → Import repo | Teams/Enterprise; private GitHub repo with `.cursor-plugin/marketplace.json` |
| **Claude Code team** | Private git marketplace | `/plugin marketplace add` with token env for auto-update ([Claude docs](https://code.claude.com/docs/en/plugin-marketplaces)) |
| **Codex team** | `$REPO_ROOT/.agents/plugins/marketplace.json` or `~/.agents/plugins/marketplace.json` | Repo/personal marketplace; install from app or CLI |
| **Zed skills** | `.agents/skills/` or `~/.agents/skills/` | Skills only; Zed has no remote skill registry or custom search paths |
| **npm-private skills packages** | Claude marketplace `source.type: npm` | For npm-hosted plugin bundles; uncommon for plain `SKILL.md` trees |

**Skill Steward default:** public `arenukvern/skill_steward` for meta-skills; hooks documented separately (`npx skills` does **not** install Cursor hooks).

## Cross-agent install matrix (skills)

Use [vercel-labs/skills](https://github.com/vercel-labs/skills) as the shared installer:

```bash
npx skills add owner/repo                    # all skills, project scope
npx skills add owner/repo --skill my-skill   # one skill
npx skills add owner/repo -a cursor -a claude-code -a codex -a zed -y
npx skills add owner/repo -g                 # global (~/.agents/skills/)
npx skills add owner/repo --copy             # copy instead of symlink
```

Discovery also reads `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` skill paths (Claude marketplace compatibility).

| Agent | `--agent` flag | Project skills path | Global skills path |
|-------|----------------|---------------------|--------------------|
| Cursor | `cursor` | `.agents/skills/` (Cursor also reads `.cursor/skills/`) | `~/.cursor/skills/` |
| Claude Code | `claude-code` | `.claude/skills/` | `~/.claude/skills/` |
| Codex | `codex` | `.agents/skills/` | `~/.codex/skills/` |
| Zed | `zed` | `.agents/skills/` | `~/.agents/skills/` |
| Copilot, Windsurf, Cline, … | see `npx skills --help` | per CLI table | per CLI table |

**Hooks:** supported on Claude Code, Cline, Kiro—not Cursor via `npx skills`. Cursor hooks need `.cursor/hooks.json` ([Skill Steward example](../../plugins/steward-validate-on-save/)).

## Cross-agent install matrix (plugins)

| Agent | Manifest dir | Marketplace file | Install (typical) |
|-------|--------------|------------------|-------------------|
| **Cursor** | `.cursor-plugin/plugin.json` | `.cursor-plugin/marketplace.json` (multi-plugin repo) | Marketplace UI, team import, or `init` script → `.cursor/plugins/local/` |
| **Claude Code** | `.claude-plugin/plugin.json` | `.claude-plugin/marketplace.json` | `/plugin marketplace add owner/repo` then `/plugin install name@marketplace` |
| **Codex** | `.codex-plugin/plugin.json` | `$REPO_ROOT/.agents/plugins/marketplace.json` or `~/.agents/plugins/marketplace.json` | App plugin directory or `codex plugin add name@marketplace` |
| **Open Plugin v1** | `.plugin/plugin.json` | host-specific | Portable baseline; add vendor manifests only for host-specific overrides |
| **Open skills only** | N/A | N/A | `npx skills add` — **no** MCP/hooks |

Reference product layout: product repository marketplace distribution configs.

## Codex plugin notes

- Keep only `plugin.json` in `.codex-plugin/`; put `skills/`, `.mcp.json`, `.app.json`, `hooks/`, and `assets/` at plugin root.
- Include `skills`, `mcpServers`, `apps`, or `hooks` in `.codex-plugin/plugin.json` only when the companion files/directories exist. Codex also checks default `hooks/hooks.json`.
- Marketplace files live at `$REPO_ROOT/.agents/plugins/marketplace.json` for repo/team catalogs or `~/.agents/plugins/marketplace.json` for personal catalogs.
- Each marketplace entry must include `policy.installation`, `policy.authentication`, and `category`; keep `source.path` relative to the marketplace root and inside that root.
- Codex installs marketplace plugins into `~/.codex/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME/$VERSION/`; local source edits require reinstall/cache refresh before new threads see them.

## Open Plugin portability

- Use `.plugin/plugin.json` when a plugin should be vendor-neutral across Open Plugin hosts.
- Add `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, or `.claude-plugin/plugin.json` only when the host needs a vendor-specific manifest.
- Do not confuse Skill Steward `plugin.yaml` with a host marketplace manifest. It is a local meta-plugin manifest for documenting Skill Steward wiring.

## Scaffold a new marketplace repo

### A. Skills-only marketplace (simplest — Skill Steward style)

```
my-skills/
├── skills/
│   └── my-skill/
│       └── SKILL.md
├── skills.sh.json          # optional: skills.sh categories
├── README.md               # install commands
└── package.json            # optional: pnpm run validate
```

Publish: push public → `npx skills add org/my-skills`. No plugin manifest required. For customizing the repository page by defining groupings and categories in `skills.sh.json`, see the [skills.sh customization docs](https://www.skills.sh/docs/customize).

### B. Codex / Claude / Cursor marketplace (multi-plugin)

```
my-marketplace/
├── .agents/plugins/
│   └── marketplace.json    # Codex catalog
├── .claude-plugin/
│   └── marketplace.json    # Claude catalog, when needed
├── .cursor-plugin/
│   └── marketplace.json    # Cursor catalog, when needed
└── plugins/
    └── my-plugin/
        ├── .plugin/plugin.json
        ├── .codex-plugin/plugin.json
        ├── .claude-plugin/plugin.json
        ├── .cursor-plugin/plugin.json
        ├── skills/
        ├── hooks/
        └── .mcp.json
```

Codex entry: `"source": {"source": "local", "path": "./plugins/my-plugin"}` plus policy/category. Claude and Cursor keep their own marketplace shapes. Use only the vendor trees the target agents need.

### C. Skill Steward meta-plugin (hooks + skill refs)

```
plugins/my-hook-pack/
├── plugin.yaml
├── README.md               # manual .cursor/hooks.json steps
├── hooks.json.snippet
└── hooks/
```

Canonical skills stay in `skills/`. See [templates/plugin/](../../templates/plugin/).

## Private marketplace checklist

1. **Repo access** — team can `git clone` (HTTPS token, SSH, or GHE app for Cursor team marketplaces).
2. **Secrets** — never commit tokens; document `GITHUB_TOKEN` / `GITLAB_TOKEN` for Claude auto-update on private marketplaces.
3. **Install docs** — one README block per channel (skills CLI vs Claude `/plugin` vs Cursor dashboard).
4. **Versioning** — bump `version` in plugin manifest per release; skills use git SHA via `npx skills update`.
5. **CI** — validate skills (`pnpm run validate` / `dart run :steward validate` in Skill Steward); product repos add contract tests.
6. **Scope** — project install (committed `.agents/skills/`) vs `-g` global; document team norm.

## Skill Steward vs product repo

| Concern | Skill Steward | Product (e.g. product MCP) |
|---------|-------------|------------------------------|
| Skills | Meta only (`skill-authoring-lifecycle`, `repository-governance-lifecycle`, …) | Domain + MCP skills |
| Plugins | Meta hooks (`steward-validate-on-save`) | Full bundle: MCP + skills + init |
| CLI | `steward validate` | `[toolkit-cli] init <agent>` |
| Marketplace | Public Git + skills.sh | Claude/Codex git + Cursor submit + Smithery |

Do not put product MCP servers in Skill Steward. Cross-promote: `npx skills add arenukvern/skill_steward --skill mcp-harness-repo-maintainer`.

## Workflow: add a distributable skill to Skill Steward

1. Follow [skill-authoring-lifecycle](../skill-authoring-lifecycle/SKILL.md) — `skills/{name}/SKILL.md`.
2. Register in `skills.sh.json` + root `README.md`.
3. `pnpm run validate` in skill_steward.
4. After merge to `main`, public repo is installable via `npx skills add arenukvern/skill_steward --skill {name}`.
5. Optional: submit to skills.sh leaderboard (automatic for public repos with valid skills).

## Workflow: add a Skill Steward plugin

1. Copy `templates/plugin/` → `plugins/{id}/`.
2. List referenced skills in `plugin.yaml` (ids only).
3. Document install (Cursor hooks merge, etc.).
4. Update [plugins/README.md](../../plugins/README.md).

## Anti-patterns

- Putting hooks only in `skills/` and expecting `npx skills` to wire Cursor
- Duplicating `SKILL.md` inside every plugin directory
- Private marketplace docs that only mention one agent
- Eternal plan files in marketplace repos (see [plan hygiene](../../docs/start_here/executable-plans.mdx))

## Additional resources

- [distribution-matrix.md](references/distribution-matrix.md) — full channel table
- [manifest-snippets.md](references/manifest-snippets.md) — minimal JSON/YAML examples
- [ADR 0004](../../docs/decisions/0004-plugin-packaging-and-install-path.mdx)
- [ADR 0006](../../docs/decisions/0006-guild-harness-meta-vs-product-clis.mdx)
- [skills.sh customization docs](https://www.skills.sh/docs/customize)

## Install this skill

```bash
npx skills add arenukvern/skill_steward --skill plugin-marketplace-setup
```

## Sources

See [references/sources.md](references/sources.md). When researching, follow `skill-source-citations`.
