# Oka consumer repin — `754b4750` (oka main after #20) (2026-11-09)

| Field | Value |
|-------|--------|
| Pin file | `tool/ci/oka_consumer_pin.txt` |
| SHA (full) | `754b47500e56c2a9b29d40f83bf23987ac8c0f1d` |
| Remote verify | `git ls-remote … refs/heads/main` + `gh api …/commits/main` |
| Source | [oka #20](https://github.com/Arenukvern/oka/pull/20) merged to `Arenukvern/oka` **main** |
| Prior pin | `7fd1d5bf039cbbd0125683945c5273e83e7aac1b` (pre-merge PR #18 head) |

## Consumer commits

| SHA | Role |
|-----|------|
| `12a8694abc9d7d0a053e2501830446a2a84825be` | Pin file update |
| `92d17c0ce155e146297ce4579fb3762f43ff9236` | Empty commit to request `pull_request` synchronize |

**Proof head for native gate:** `92d17c0c` (includes pin `754b4750…`).

## Native proof (CI)

_Updated when GitHub Actions completes on proof head._

| Platform | Run | Conclusion | Key gates |
|----------|-----|------------|-----------|
| Android | — | _pending / see below_ | — |
| Linux | — | _pending / see below_ | — |

If **pending:** only `CodeRabbit` reported on PR checks immediately after push; Actions runs for `12a8694a` / `92d17c0c` not yet visible via API (2026-11-09). Branch CI subscription renewed (`cursor/native-flutter-layer-capture-3399`).

**Last full native green on prior pin:** `dbee54a3` + oka `7fd1d5bf` — [run 42618846519](https://github.com/Arenukvern/mcp_flutter/actions/runs/42618846519).

---

## Android gate checklist (when artifacts exist)

- One owned forward during session
- `forwardLinesAtEnd: []`
- App gone; host identities quiet ~10s
- `sessionCleanupIdentityMatch: true`
- Raw failure: `.flutter_mcp/attach-handshake-failure.json` if attach aborts
