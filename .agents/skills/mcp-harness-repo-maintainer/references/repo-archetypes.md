# Repo archetypes (reference)

Classification for sibling agentic repositories/monorepos.

**Shared shape:** CLI and MCP (when present) are **thin**; **core** holds logic. See [core-and-interfaces.md](core-and-interfaces.md).

## Comparison table

| | **A Product MCP** | **B Platform Libs** | **C CLI Harness** | **D Visual Sidecar** | **E Meta Steward** |
|---|-------------------|----------------|-------------------|----------------------|------------------|
| **Example Folder** | `<product_mcp>` | `<platform_libs>` | `<cli_harness>` | `<visual_sidecar>` | `<meta_steward>` |
| **Primary ship unit** | Plugin + MCP binary / server | Package manager modules | Runner CLI + test fixtures | Profile definitions + comparison CLI | Portable skills / checklists |
| **MCP server in-repo** | Yes | Wire-adapter module only | No (consumes product MCP) | No | No |
| **plugin/mcp.json** | Yes | No | No | No | No |
| **init \<agent\>** | Yes (e.g. `[tool] init`) | No | No | No | No |
| **Marketplace manifests** | `.cursor` + `.claude` + `.codex` | Rare | Optional skills only | No | N/A (e.g., skills.sh) |
| **Contract CI** | manifest check tasks / gates | package lint + dry-run publish | fixture script checks | test runner + configuration linter | validation & documentation lint |
| **Dogfood application** | Test/example application | via integration smoke test | harness/runner examples | comparison goldens | N/A |
| **ADR location** | `decisions/` + `docs/decisions/` | minimal | `decisions/` | `decisions/` | `docs/decisions/` |
| **Superpowers / specs**| `docs/superpowers/` | API/release documentation | `plans/`, `specs/` | `specs/`, `plans/` | executable plans (optional) |

## Decision tree

```text
Does the repo expose an MCP server agents call in chat?
  No → Does it ship Agent Skills for npx skills only?
    Yes, meta/process → E (Meta Steward)
    Yes, domain workflows in a product → skills under plugin/ or skills/ (supporting)
  No → Is the main artifact a CLI over apps/tests?
    Yes, test harness / simulator → C (CLI Harness)
    Yes, visual comparison / profiles only → D (Visual Sidecar)
  Yes → Does it publish multi-package SDK for others?
    Yes → B (Platform Libs) + integration test in A
    No → A (Product MCP)
```

## What to copy when forking

| From Reference Product MCP | Copy to new product MCP | Skip for guild/harness |
|------------------|-------------------------|-------------------------|
| `plugin/` + `mcp.json` | Yes | Yes — meta only |
| `init` command + config writers | Yes | Yes |
| skill serialization / sync scripts | Yes | Yes |
| contract validation tools | Pattern yes | Adapt to local package manager |
| agent overview docs | Yes | Shorten for guild |
| tool capability layout | If VM/debug product | Yes |
