# Security Policy

Flutter MCP Toolkit is intended for local development and debug-mode app
automation. Treat it like a developer tool with access to your running Flutter
app, logs, screenshots, and any custom MCP tools your app registers.

## Reporting A Vulnerability

Please report suspected vulnerabilities privately by emailing
anton@xsoulspace.dev. Include:

- affected package, binary, or workflow
- reproduction steps or proof of concept
- expected impact and any known mitigations
- whether the issue is already public

Do not open a public issue for an unpatched vulnerability.

## Supported Surface

Security review is focused on the current prerelease train, GitHub release
binaries, published pub.dev packages, bundled agent skills, and repository
automation. Older prerelease builds may receive fixes only when the same issue
affects the current train.

## Local Safety Notes

- Run the toolkit only against apps and devices you control.
- Keep `mcp_toolkit` and app-registered dynamic tools in debug/development
  flows unless your app adds its own production authorization boundary.
- Review dynamic tools before exposing mutating app behavior to an agent.
- Keep secrets out of logs, screenshots, generated artifacts, and MCP tool
  results.
