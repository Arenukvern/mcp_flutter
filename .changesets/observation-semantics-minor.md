---
'mcp_toolkit': minor
'flutter_mcp_toolkit_core': minor
'flutter_mcp_toolkit_server': minor
'flutter_mcp_toolkit_capability_core': minor
---

Observation vs empty semantics (ADR 0024): `semantic_snapshot` exposes `diff`,
`render`, `labelPrefix`, and `maxNodes`; `wait_for` adds `changed`, timeout
delta, and optional `awaitChange` on actions. Doctor warns on unnamed tappable
controls.

**Behavior change:** `wait_for` `{kind:"time"}` defaults `observe` to **true**,
returning a peek snapshot envelope after the delay (higher default token use than
`observe:false`). After this release, `time` with default observe uses a peek
that does **not** bump `snapshot_id`, rebind public refs, or consume a ring
slot — refs and `changed` baselines stay stable.

**Included patch scope:** peek snapshots no longer rebind public `s_N` refs
while `snapshot_id` is frozen; timeouts report `lastSnapshotId` at wait start
and `observedRevision` from the latest peek.

**Note:** `wait_for` text/node/stable predicates always evaluate on the full
tree; filter keys apply only to `changed` and timeout delta baselines.
