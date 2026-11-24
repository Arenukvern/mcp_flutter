---
'mcp_toolkit': minor
'flutter_mcp_toolkit_core': minor
'flutter_mcp_toolkit_server': minor
'flutter_mcp_toolkit_capability_core': minor
---

Observation vs empty semantics (ADR 0023): `semantic_snapshot` exposes `diff`,
`render`, `labelPrefix`, and `maxNodes`; `wait_for` adds `changed`, timeout
delta, and `time.observe` (defaults **true** — returns a full snapshot envelope
after the delay, increasing default token use for `time` waits). Action tools
support optional `awaitChange`. Doctor warns on unnamed tappable controls.