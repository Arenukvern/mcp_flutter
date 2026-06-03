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
npx skills add org/repo --skill my-skill --copy
```
