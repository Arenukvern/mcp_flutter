# flutter-mcp-toolkit-server

Dart MCP server and CLI for inspecting and driving a **debug** Flutter app. Ships as GitHub Release binaries (`flutter-mcp-toolkit`, `fmtk`, `flutter-mcp-toolkit-server`).

## Install (recommended)

1. **Marketplace / plugin** — see [docs/install/clients.mdx](../docs/install/clients.mdx).
2. **Install script** — `curl -fsSL https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/install.sh | bash`.

Docker and build-from-source are secondary: [docs/install/docker.mdx](../docs/install/docker.mdx), [docs/install/platforms.mdx](../docs/install/platforms.mdx).

## MCP config

```json
{
  "mcpServers": {
    "flutter-mcp-toolkit": {
      "command": "flutter-mcp-toolkit-server",
      "args": []
    }
  }
}
```

Legacy `mcpServers` key `flutter-inspector` pointed at the same binary; use `flutter-mcp-toolkit` for new configs.

## App requirement

Instrument the Flutter app with `mcp_toolkit` (`flutter-mcp-toolkit codegen-init`). Without it, server tools cannot reach UI extensions.

## Golden path

```bash
flutter run --debug
flutter-mcp-toolkit doctor
```

Agent or CLI: discover → semantic snapshot → interact → hot reload.

## Tool and CLI reference

**Do not rely on hard-coded counts in this README.** Live lists:

- MCP tools: [docs/reference/tools.mdx](../docs/reference/tools.mdx) (`make docs-reference`)
- CLI: [docs/reference/cli.mdx](../docs/reference/cli.mdx)

Dump tree tools need `--dumps` on the server (off by default).

## Docs

- [Quickstart](../docs/quickstart.mdx)
- [CLI vs MCP](../docs/concepts/cli-vs-mcp.mdx)
- [Migration v2→v3](../docs/migration/migration_v2_to_v3.mdx)

## Changelog

See [repository CHANGELOG.md](../CHANGELOG.md) — this package does not maintain a separate release log.

## Develop

```bash
make setup && make compile
cd mcp_server_dart && dart test
```

Full contributor gates: `make check-contracts` at repo root.