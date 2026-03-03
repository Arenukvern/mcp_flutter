# Configuration

This project uses command-line flags (not `.env` variables) for runtime configuration.

## MCP Server (`mcp_server_dart/bin/main.dart`)

The MCP server runs over `stdin/stdout` JSON-RPC. It does not expose an MCP TCP port.

| Option | Default | Description |
| --- | --- | --- |
| `--dart-vm-host` | `localhost` | Host for connecting to Dart VM service |
| `--dart-vm-port` | `8181` | Port for connecting to Dart VM service |
| `--resources` / `--no-resources` | `true` | Enable resource registration |
| `--images` / `--no-images` | `true` | Enable image/screenshot support |
| `--dumps` / `--no-dumps` | `false` | Enable debug dump tools |
| `--dynamics` / `--no-dynamics` | `true` | Enable dynamic registry tools |
| `--await-dnd` / `--no-await-dnd` | `false` | Wait for DTD dynamic connection on startup |
| `--save-images` / `--no-save-images` | `false` | Save screenshots to files instead of base64 |
| `--flutter-project-dir` | _(none)_ | Flutter project dir for `flutter attach --machine` discovery |
| `--flutter-device` | _(none)_ | Discovery device (for example `chrome`) |
| `--flutter-discovery-timeout-ms` | `2500` | Machine discovery timeout in milliseconds |
| `--log-level` | `critical` | `debug/info/notice/warning/error/critical/alert/emergency` |
| `--environment` | `production` | `development` or `production` |
| `-h`, `--help` | _(none)_ | Show usage |

## CLI v2 (`mcp_server_dart/bin/flutter_mcp_cli.dart`)

CLI defaults are mostly aligned with server flags, with these additional global options:

| Option | Default | Description |
| --- | --- | --- |
| `--vm-service-uri` | _(none)_ | Explicit VM websocket URI fallback (`ws://.../ws`) |
| `--state-file` | `.flutter_mcp/state.json` | CLI state file path |
| `--log-level` | `error` | CLI logging default |

## Connection Targeting

Server startup is non-blocking and does not force selecting a VM target up front.

Resolution order for VM-dependent operations:

1. Reuse active healthy connection.
2. Reuse sticky target if still discoverable.
3. Auto-attach when exactly one target is discovered.
4. Return `connection_selection_required` when multiple targets exist and no explicit target is provided.

### Per-request Override

VM-dependent tools accept optional nested `arguments.connection`:

```json
{
  "name": "debug_dump_render_tree",
  "arguments": {
    "connection": {
      "targetId": "ws://127.0.0.1:59490/<token>/ws"
    }
  }
}
```

Supported `connection` fields:

- `targetId` (preferred, full VM websocket URI)
- `mode` (`auto`, `manual`, `uri`)
- `host`
- `port`
- `uri`
- `forceReconnect`

`targetId` hard break: legacy `host:port` values are rejected. Use URI target IDs or `connection.uri`.

Strict schema note: flat aliases such as `arguments.port`, `arguments.host`, and `arguments.uri` are rejected.

### CLI/Daemon Contracts

The same nested `connection` object is accepted by:

- CLI one-shot: `exec --args '{"connection":{"targetId":"ws://127.0.0.1:59490/<token>/ws"}}'`
- daemon `command/execute`: `params.args.connection`
- daemon `watch/start`: `params.args.connection`
- `snapshot create`: per-step `args.commands[i].args.connection`

Selector conflict rule:

- `connect` and `session_start` reject mixed native selector fields (`mode`, `targetId`, `host`, `port`, `uri`, `force`) together with nested `connection`.

### Resource URI Targeting

Resource reads can specify connection target via query params:

- `targetId`
- `mode`
- `host`
- `port`
- `uri`
- `forceReconnect`

Example:

- `visual://localhost/view/details?targetId=ws%3A%2F%2F127.0.0.1%3A59490%2F%3Ctoken%3E%2Fws`
