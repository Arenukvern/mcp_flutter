> ⚠️ **Pre-release (0.1.x)** — Highly experimental. APIs may change without notice. Not for production. [Details](../../PRE_RELEASE.md).


# agentkit_platform

Platform emitters, `PlatformSync`, and optional Flutter plugin for native invoke + web WebMCP artifacts.

## Manifest workflow (I4)

`web/agent_manifest.json` is **checked in** and refreshed by CLI — not generated live from `AgentRegistry` yet.

```bash
flutter-mcp-toolkit codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir <app>
```

Use `--check` in CI (`make check-agentkit-integration`).

### One-time hooks

```bash
flutter-mcp-toolkit init agentkit-platform --project-dir <flutter_app>
```

### Future

Registry-backed `generateWebAgentManifest` is deferred — edit `agent_manifest.json`, then `codegen sync`.