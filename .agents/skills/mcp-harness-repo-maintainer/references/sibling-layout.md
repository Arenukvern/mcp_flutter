# Sibling layout (reference)

Canonical peer layout from sibling agentic workspace patterns.

## Directory

```text
<workspace>/
  <plugin_repo>/                # toolkit + MCP/plugin init
  <library_repo>/               # SDK platform / domain libraries
  <harness_repo>/               # CLI/harness runner
  <visual_sidecar>/             # visual sidecar / comparison tool
  <media_assets>/               # LFS/media assets (optional)
  <meta_governance_repo>/       # meta skills & validation (e.g., skill_steward)
```

## Dependency direction

```text
<media_assets> → <harness_repo> → <plugin_repo> (core capability modules)
                        ↓
              <visual_sidecar> (visual validation engine)
<library_repo> ← platform SDK / packages (integrated & verified in plugin/MCP repos)
<meta_governance_repo> → meta-skills and validation rules only (no runtime dep on above)
```

## Path overrides

Workspaces/repositories should support developer-friendly path overrides for sibling directories during local development (e.g., Cargo path overrides, npm/pnpm workspaces, Python sys.path or poetry path overrides, Dart `pubspec_overrides.yaml`).

**Example (Dart/Flutter pubspec overrides in `<harness_repo>`):**

```yaml
dependency_overrides:
  plugin_core:
    path: ../<plugin_repo>/packages/core
```

**Example (npm/pnpm workspace overrides in `<plugin_repo>`):**
Configure workspace dependency overrides in the package manager manifest to target local platform library path development.

## Dogfood warm path (integration smoke)

1. **MCP/Server**: launch product server in test mode (e.g. `DOGFOOD=1`)
2. **Harness runner**: execute harness test integration suite (e.g. fixture run task)
3. **Visual comparator**: compare output artifacts using verification profiles
4. **Golden comparison**: check produced visual/data artifacts against checked-in golden results

## Maintainer commands by repo

| Archetype Role | Before Merge Task | Example CLI Command |
|------|----------------|---|
| **Product MCP** | Verify tool schemas and contracts | `[task-runner] check-contracts` (e.g. `just check-contracts`) |
| **Platform Libs** | Execute package analysis and unit tests | `[task-runner] test` (e.g. `npm run test` or `dart test`) |
| **CLI Harness** | Run integration tests and fixtures | `[task-runner] check` or test suite execution |
| **Visual Sidecar**| Validate comparison profiles and verdict logic | `profile-cli validate` |
| **Meta Steward** | Run validation linter on skills and docs | `pnpm run validate`, `pnpm run docs:check` |

## Cross-install docs

- **Product Users**: run client-facing setup CLI (`[tool] init <agent>`) + optional `npx skills add [repo-path]`
- **Harness Contributors**: clone sibling repositories; read the respective `docs/NORTH_STAR.mdx`
- **Skill Steward Meta**: `npx skills add arenukvern/skill_steward --skill mcp-harness-repo-maintainer`
