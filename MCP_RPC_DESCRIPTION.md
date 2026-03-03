# MCP RPC Surface

This file summarizes the current MCP-facing tools/resources implemented by `mcp_server_dart`.

## Core VM Tools

- `connect_debug_app`: Explicitly select/connect to a debug target.
- `hot_reload_flutter`: Trigger Flutter hot reload.
- `hot_restart_flutter`: Trigger Flutter hot restart.
- `get_vm`: Return Dart VM details.
- `get_extension_rpcs`: List available extension RPCs.
- `get_active_ports`: Scan active Flutter/Dart debug ports.

## Flutter App Data Tools

- `get_app_errors`: Return recent captured app errors.
- `get_screenshots`: Capture screenshots from app views.
- `get_view_details`: Return view metrics/details.

When resources are enabled (`--resources`), equivalent data is also available via:

- `visual://localhost/app/errors/latest`
- `visual://localhost/app/errors/{count}`
- `visual://localhost/view/screenshots`
- `visual://localhost/view/details`

When resources are disabled (`--no-resources`), these capabilities are exposed as tools only.

## Optional Debug Dump Tools

Disabled by default. Enable with `--dumps`.

- `debug_dump_layer_tree`
- `debug_dump_semantics_tree`
- `debug_dump_render_tree`
- `debug_dump_focus_tree`

## Dynamic Registry Tools

Enabled by default (`--dynamics`):

- `listClientToolsAndResources`
- `runClientTool`
- `runClientResource`
- `getRegistryStats` (debug mode utility)

## Connection Selection Contract

VM-dependent calls support optional nested `arguments.connection` with:

- `targetId` (preferred; full VM websocket URI)
- `mode` (`auto`, `manual`, `uri`)
- `host`
- `port`
- `uri`
- `forceReconnect`

If multiple targets exist and no explicit target is supplied, calls return `connection_selection_required` with `availableTargets` and retry guidance.
