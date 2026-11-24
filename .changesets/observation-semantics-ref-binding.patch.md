---
'mcp_toolkit': patch
---

Fix peek semantic snapshots rebinding public `s_N` refs while leaving
`snapshot_id` frozen. Timeouts now report `lastSnapshotId` from wait start and
`observedRevision` from the latest peek.