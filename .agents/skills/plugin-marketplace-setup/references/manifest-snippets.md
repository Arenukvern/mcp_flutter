# Manifest snippets (reference)

Minimal copies—adjust names and paths.

## skills.sh.json (Guild)

Configures repository-level groupings on the [skills.sh](https://skills.sh) registry directory (see [customization docs](https://www.skills.sh/docs/customize)).

```json
{
  "$schema": "https://skills.sh/schemas/skills.sh.schema.json",
  "notGrouped": "bottom",
  "groupings": [
    {
      "title": "My Category",
      "description": "Short description of the category.",
      "skills": ["my-skill"]
    }
  ]
}
```

## Guild plugin.yaml

```yaml
id: my-meta-plugin
version: "0.1.0"
description: One-line purpose
skills:
  - my-skill-id
targets:
  cursor:
    hooks:
      - event: afterFileEdit
        script: hooks/my-hook.sh
        note: Merge hooks.json.snippet into .cursor/hooks.json
```

## Open Plugin v1 manifest (portable)

Use `.plugin/plugin.json` for the vendor-neutral baseline when targeting hosts that implement the Open Plugin spec.

```json
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "Reusable skills and MCP wiring.",
  "skills": "./skills/",
  "mcpServers": "./.mcp.json"
}
```

## Codex plugin.json

Place this at `.codex-plugin/plugin.json`. Include `skills`, `mcpServers`, `apps`, or `hooks` only when the referenced companion files exist.

```json
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "Bundle reusable skills and app integrations.",
  "author": {
    "name": "Your team"
  },
  "skills": "./skills/",
  "mcpServers": "./.mcp.json",
  "hooks": "./hooks/hooks.json",
  "interface": {
    "displayName": "My Plugin",
    "shortDescription": "Reusable skills and apps",
    "longDescription": "Distribute skills, hooks, and MCP integrations together.",
    "developerName": "Your team",
    "category": "Productivity",
    "capabilities": ["Read", "Write"],
    "defaultPrompt": [
      "Use My Plugin to triage repo tasks."
    ]
  }
}
```

## Codex marketplace.json

Repo/team marketplaces live at `.agents/plugins/marketplace.json`; personal marketplaces live at `~/.agents/plugins/marketplace.json`.

```json
{
  "name": "local-example-plugins",
  "interface": {
    "displayName": "Local Example Plugins"
  },
  "plugins": [
    {
      "name": "my-plugin",
      "source": {
        "source": "local",
        "path": "./plugins/my-plugin"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity"
    }
  ]
}
```

Git-backed Codex entry:

```json
{
  "name": "remote-helper",
  "source": {
    "source": "git-subdir",
    "url": "https://github.com/example/codex-plugins.git",
    "path": "./plugins/remote-helper",
    "ref": "main"
  },
  "policy": {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL"
  },
  "category": "Productivity"
}
```

## Claude marketplace.json (repo root)

```json
{
  "name": "my-marketplace",
  "owner": { "name": "Your Org" },
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./plugins/my-plugin",
      "description": "Short description",
      "version": "1.0.0"
    }
  ]
}
```

## Claude plugin.json (per plugin)

```json
{
  "name": "my-plugin",
  "description": "Adds skills and hooks",
  "version": "1.0.0"
}
```

## Cursor marketplace.json (repo root)

```json
{
  "name": "my-cursor-marketplace",
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./plugins/my-plugin",
      "description": "Bundle for Cursor",
      "version": "1.0.0"
    }
  ]
}
```

## Cursor plugin.json (per plugin)

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Rules, skills, MCP, hooks",
  "skills": "./skills/",
  "commands": "./commands/",
  "hooks": "./hooks/hooks.json"
}
```

## Private Claude marketplace (git source)

```json
{
  "plugins": [
    {
      "name": "internal-tools",
      "source": {
        "type": "git",
        "url": "https://github.com/org/private-plugins.git"
      }
    }
  ]
}
```

Set `GITHUB_TOKEN` (or host equivalent) for background auto-updates on private repos.

## npx skills install (end users)

```bash
npx skills add org/repo -a cursor -a claude-code -a codex -y
npx skills add org/repo -a cursor -a claude-code -a codex -a zed -y
npx skills add org/repo --skill my-skill --copy
```
