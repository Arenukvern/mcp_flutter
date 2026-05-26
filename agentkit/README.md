# agentkit

> ⚠️ **Pre-release (`0.1.x`)** — Highly experimental. APIs may change without notice. **Not for production.** See [PRE_RELEASE.md](PRE_RELEASE.md).

Transport-agnostic agent intent platform (extracted from [mcp_flutter](https://github.com/Arenukvern/mcp_flutter)).

## Packages

| Package | Role |
|---------|------|
| `agentkit_schema` | Wire types, validation, `AgentResult` |
| `agentkit_core` | Registry, runtime, `AgentCallEntry` |
| `agentkit_mcp` | MCP publish adapter (`dart_mcp`) |
| `agentkit_webmcp` | WebMCP hot-sync adapter |
| `agentkit_platform` | Native/web emitters + Flutter plugin |
| `agentkit_codegen` | Optional `@AgentTool` codegen |
| `agentkit_testing` | Contract / invoke test helpers |
| `agentkit_gemma` / `agentkit_apple` / `agentkit_android` | Optional surface adapters |

## Development

```bash
dart pub get
make test
make analyze   # xsoulspace_lints (library.yaml)
```

Location: `mcp_flutter/agentkit/` (nested workspace until a separate Git remote is cut).

Consumer integration tests remain in the parent repo (`make check-agentkit-integration`). Regression checklist: [docs/agentkit/REGRESSION_CHECKLIST.md](../docs/agentkit/REGRESSION_CHECKLIST.md).

## Flutter MCP Toolkit

App authors should prefer **`mcp_toolkit`** + `flutter-mcp-toolkit` CLI. Agentkit packages are for platform work and advanced integration — expect churn.

## Extract status

Phase 7: workspace at `agentkit/`; pub.dev dry-run green; publish pending credentials.
